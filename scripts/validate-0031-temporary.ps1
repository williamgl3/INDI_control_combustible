[CmdletBinding()]
param(
  [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $false
}

$cleanupFailureExitCode = 70

function Test-TemporaryName([string]$Name) {
  return $Name -match '^indi-0031-test-[a-f0-9]{12}-(postgres|network|volume)$' -and
    $Name -notin @('backend_indi_pgdata', 'backend_indi_uploads')
}

function Test-ResourceMissingMessage([string]$Kind, [string]$Name, [string]$Message) {
  $escapedName = [Regex]::Escape($Name)
  switch ($Kind) {
    'container' { return $Message -match "(?i)No such (object|container):?\s*$escapedName" }
    'volume' { return $Message -match "(?i)No such volume:?\s*$escapedName" }
    'network' { return $Message -match "(?i)network\s+$escapedName\s+not found" }
    default { return $false }
  }
}

function Get-DeletionDecision {
  param(
    [string]$Kind,
    [string]$Name,
    [string]$ExpectedLabel,
    [int]$InspectExitCode,
    [AllowEmptyString()][string]$ActualLabel,
    [AllowEmptyString()][string]$InspectError
  )

  if (-not (Test-TemporaryName $Name)) { return 'blocked-invalid-name' }
  if ($InspectExitCode -eq 0) {
    if ($ActualLabel -ceq $ExpectedLabel) { return 'delete' }
    return 'blocked-label'
  }
  if (Test-ResourceMissingMessage $Kind $Name $InspectError) { return 'already-clean' }
  return 'blocked-inspection'
}

function Get-FinalExitCode([int]$PrimaryExitCode, [int]$CleanupExitCode) {
  if ($PrimaryExitCode -ne 0) { return $PrimaryExitCode }
  if ($CleanupExitCode -ne 0) { return $cleanupFailureExitCode }
  return 0
}

function Normalize-FailureCode([object]$Code) {
  if ($Code -is [int] -and $Code -ne 0) { return [int]$Code }
  return 1
}

function Get-ExactLabelFromInspectJson {
  param(
    [string]$Kind,
    [AllowEmptyString()][string]$Json
  )

  try {
    $parsed = ConvertFrom-Json -InputObject $Json -ErrorAction Stop
  } catch {
    return [pscustomobject]@{
      Success = $false
      ActualLabel = ''
      Reason = 'invalid-json'
    }
  }

  $parsedItems = New-Object System.Collections.Generic.List[object]
  if ($parsed -is [System.Array]) {
    foreach ($item in $parsed) { $parsedItems.Add($item) }
  } elseif ($null -ne $parsed) {
    $parsedItems.Add($parsed)
  }

  if ($parsedItems.Count -ne 1) {
    return [pscustomobject]@{
      Success = $false
      ActualLabel = ''
      Reason = 'unexpected-object-count'
    }
  }

  $resource = $parsedItems[0]
  $labels = switch ($Kind) {
    'container' {
      $configProperty = $resource.PSObject.Properties['Config']
      if ($null -eq $configProperty -or $null -eq $configProperty.Value) {
        $null
      } else {
        $labelsProperty = $configProperty.Value.PSObject.Properties['Labels']
        if ($null -eq $labelsProperty) { $null } else { $labelsProperty.Value }
      }
    }
    'volume' {
      $labelsProperty = $resource.PSObject.Properties['Labels']
      if ($null -eq $labelsProperty) { $null } else { $labelsProperty.Value }
    }
    'network' {
      $labelsProperty = $resource.PSObject.Properties['Labels']
      if ($null -eq $labelsProperty) { $null } else { $labelsProperty.Value }
    }
    default { $null }
  }
  if ($null -eq $labels) {
    return [pscustomobject]@{
      Success = $false
      ActualLabel = ''
      Reason = 'labels-missing'
    }
  }

  $labelProperty = $labels.PSObject.Properties['indi.temporary-0031']
  if ($null -eq $labelProperty -or [string]::IsNullOrEmpty([string]$labelProperty.Value)) {
    return [pscustomobject]@{
      Success = $false
      ActualLabel = ''
      Reason = 'exact-label-missing'
    }
  }

  return [pscustomobject]@{
    Success = $true
    ActualLabel = [string]$labelProperty.Value
    Reason = 'ok'
  }
}

function Invoke-WithTemporaryEnvironment {
  param(
    [AllowNull()][string]$DatabaseUrl,
    [bool]$EnableIntegration,
    [scriptblock]$Action
  )

  $databaseUrlExisted = Test-Path Env:DATABASE_URL
  $integrationFlagExisted = Test-Path Env:RUN_MARIMBA_INTEGRATION
  $previousDatabaseUrl = if ($databaseUrlExisted) { $env:DATABASE_URL } else { $null }
  $previousIntegrationFlag = if ($integrationFlagExisted) { $env:RUN_MARIMBA_INTEGRATION } else { $null }
  $result = [pscustomobject]@{ ExitCode = 1 }

  try {
    if ($null -eq $DatabaseUrl) { Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue }
    else { $env:DATABASE_URL = $DatabaseUrl }

    if ($EnableIntegration) { $env:RUN_MARIMBA_INTEGRATION = '1' }
    else { Remove-Item Env:RUN_MARIMBA_INTEGRATION -ErrorAction SilentlyContinue }

    & $Action $result
    return [int]$result.ExitCode
  } finally {
    if ($databaseUrlExisted) { $env:DATABASE_URL = $previousDatabaseUrl }
    else { Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue }

    if ($integrationFlagExisted) { $env:RUN_MARIMBA_INTEGRATION = $previousIntegrationFlag }
    else { Remove-Item Env:RUN_MARIMBA_INTEGRATION -ErrorAction SilentlyContinue }
  }
}

function Remove-TemporaryDockerResource {
  param(
    [string]$Kind,
    [string]$Name,
    [string]$ExpectedLabel
  )

  if (-not (Test-TemporaryName $Name)) {
    Write-Error "Limpieza bloqueada por nombre inseguro: $Name" -ErrorAction Continue
    return 70
  }

  $inspectOutput = switch ($Kind) {
    'container' { & docker container inspect $Name 2>&1 }
    'volume' { & docker volume inspect $Name 2>&1 }
    'network' { & docker network inspect $Name 2>&1 }
    default {
      Write-Error "Tipo de recurso Docker no permitido: $Kind" -ErrorAction Continue
      return 70
    }
  }
  $inspectExitCode = $LASTEXITCODE
  $inspectText = ($inspectOutput | Out-String).Trim()
  $actualLabel = ''
  $inspectError = if ($inspectExitCode -ne 0) { $inspectText } else { '' }
  if ($inspectExitCode -eq 0) {
    $labelResult = Get-ExactLabelFromInspectJson $Kind $inspectText
    if (-not $labelResult.Success) {
      Write-Error "Limpieza bloqueada: inspección JSON inválida para el recurso exacto $Kind '$Name' ($($labelResult.Reason))." -ErrorAction Continue
      return 70
    }
    $actualLabel = $labelResult.ActualLabel
  }
  $decision = Get-DeletionDecision $Kind $Name $ExpectedLabel $inspectExitCode $actualLabel $inspectError

  if ($decision -eq 'already-clean') { return 0 }
  if ($decision -ne 'delete') {
    Write-Error "Limpieza bloqueada por seguridad para el recurso exacto $Kind '$Name' ($decision)." -ErrorAction Continue
    return 70
  }

  switch ($Kind) {
    'container' { & docker container rm --force $Name | Out-Host }
    'volume' { & docker volume rm $Name | Out-Host }
    'network' { & docker network rm $Name | Out-Host }
  }
  $removeExitCode = $LASTEXITCODE
  if ($removeExitCode -ne 0) {
    Write-Error "Falló la limpieza del recurso exacto $Kind '$Name' con código $removeExitCode." -ErrorAction Continue
    return 70
  }
  return 0
}

function Invoke-SelfTests {
  $failures = 0
  function Assert-Equal($Expected, $Actual, [string]$Case) {
    if ($Expected -cne $Actual) {
      Write-Error "Self-test falló: $Case. Esperado='$Expected', actual='$Actual'." -ErrorAction Continue
      $script:selfTestFailures++
    }
  }

  $script:selfTestFailures = 0
  $suffix = '012345abcdef'
  $validName = "indi-0031-test-$suffix-container" -replace '-container$', '-postgres'
  Assert-Equal 'delete' (Get-DeletionDecision 'container' $validName $suffix 0 $suffix '') 'etiqueta exacta'
  Assert-Equal 'blocked-label' (Get-DeletionDecision 'container' $validName $suffix 0 'otro' '') 'etiqueta distinta'
  Assert-Equal 'blocked-label' (Get-DeletionDecision 'container' $validName $suffix 0 '' '') 'etiqueta ausente'
  Assert-Equal 'blocked-invalid-name' (Get-DeletionDecision 'container' 'backend-db-1' $suffix 0 $suffix '') 'nombre inválido'
  Assert-Equal 'already-clean' (Get-DeletionDecision 'container' $validName $suffix 1 '' "No such container: $validName") 'recurso inexistente'
  Assert-Equal 0 (Get-FinalExitCode 0 0) 'éxito total'
  Assert-Equal 2 (Get-FinalExitCode 2 0) 'falla principal'
  Assert-Equal 70 (Get-FinalExitCode 0 70) 'falla de limpieza'
  Assert-Equal 2 (Get-FinalExitCode 2 70) 'falla principal y limpieza'
  Assert-Equal 1 (Normalize-FailureCode $null) 'excepción sin código'

  $containerJson = '[{"Config":{"Labels":{"indi.temporary-0031":"012345abcdef"}}}]'
  $volumeJson = '[{"Labels":{"indi.temporary-0031":"012345abcdef"}}]'
  $missingLabelJson = '[{"Labels":{"otra.etiqueta":"valor"}}]'
  $differentLabelJson = '[{"Labels":{"indi.temporary-0031":"fedcba654321"}}]'
  $multipleObjectsJson = '[{"Labels":{"indi.temporary-0031":"012345abcdef"}},{"Labels":{"indi.temporary-0031":"012345abcdef"}}]'
  $containerLabel = Get-ExactLabelFromInspectJson 'container' $containerJson
  $volumeLabel = Get-ExactLabelFromInspectJson 'volume' $volumeJson
  $missingLabel = Get-ExactLabelFromInspectJson 'volume' $missingLabelJson
  $differentLabel = Get-ExactLabelFromInspectJson 'network' $differentLabelJson
  $malformedJson = Get-ExactLabelFromInspectJson 'container' '{no-es-json'
  $emptyArray = Get-ExactLabelFromInspectJson 'volume' '[]'
  $multipleObjects = Get-ExactLabelFromInspectJson 'network' $multipleObjectsJson
  Assert-Equal $true $containerLabel.Success 'JSON de contenedor válido'
  Assert-Equal $suffix $containerLabel.ActualLabel 'etiqueta exacta con punto en contenedor'
  Assert-Equal $true $volumeLabel.Success 'JSON de volumen válido'
  Assert-Equal $suffix $volumeLabel.ActualLabel 'propiedad con punto en volumen'
  Assert-Equal $false $missingLabel.Success 'JSON sin etiqueta exacta'
  Assert-Equal 'exact-label-missing' $missingLabel.Reason 'motivo de etiqueta ausente'
  Assert-Equal $true $differentLabel.Success 'JSON con etiqueta distinta es analizable'
  Assert-Equal 'fedcba654321' $differentLabel.ActualLabel 'valor distinto se conserva para comparación exacta'
  Assert-Equal $false $malformedJson.Success 'JSON mal formado'
  Assert-Equal 'invalid-json' $malformedJson.Reason 'motivo de JSON mal formado'
  Assert-Equal $false $emptyArray.Success 'arreglo vacío'
  Assert-Equal 'unexpected-object-count' $emptyArray.Reason 'motivo de arreglo vacío'
  Assert-Equal $false $multipleObjects.Success 'más de un objeto'
  Assert-Equal 'unexpected-object-count' $multipleObjects.Reason 'motivo de cardinalidad múltiple'

  $expectedImage = 'postgres:18'
  $temporaryVolumeName = "indi-0031-test-$suffix-volume"
  $temporaryMount = "type=volume,source=$temporaryVolumeName,target=/var/lib/postgresql"
  Assert-Equal 'postgres:18' $expectedImage 'imagen PostgreSQL 18'
  Assert-Equal $true ($temporaryMount.EndsWith('target=/var/lib/postgresql')) 'destino raíz versionado'
  Assert-Equal $false ($temporaryMount -match 'target=/var/lib/postgresql/data(?:,|$)') 'destino antiguo ausente'
  Assert-Equal $false ($temporaryMount -match 'source=(backend_indi_pgdata|backend_indi_uploads)(?:,|$)') 'volúmenes persistentes excluidos'

  $originalDatabaseUrlExists = Test-Path Env:DATABASE_URL
  $originalIntegrationExists = Test-Path Env:RUN_MARIMBA_INTEGRATION
  $originalDatabaseUrl = if ($originalDatabaseUrlExists) { $env:DATABASE_URL } else { $null }
  $originalIntegration = if ($originalIntegrationExists) { $env:RUN_MARIMBA_INTEGRATION } else { $null }
  try {
    $env:DATABASE_URL = 'previous-test-value'
    $env:RUN_MARIMBA_INTEGRATION = 'previous-test-flag'
    $environmentCode = Invoke-WithTemporaryEnvironment 'temporary-test-value' $true {
      param($result)
      if ($env:DATABASE_URL -cne 'temporary-test-value' -or $env:RUN_MARIMBA_INTEGRATION -cne '1') {
        $result.ExitCode = 1
      } else {
        $result.ExitCode = 0
      }
    }
    Assert-Equal 0 $environmentCode 'entorno temporal dentro de la acción'
    Assert-Equal 'previous-test-value' $env:DATABASE_URL 'restauración DATABASE_URL'
    Assert-Equal 'previous-test-flag' $env:RUN_MARIMBA_INTEGRATION 'restauración RUN_MARIMBA_INTEGRATION'
  } finally {
    if ($originalDatabaseUrlExists) { $env:DATABASE_URL = $originalDatabaseUrl }
    else { Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue }
    if ($originalIntegrationExists) { $env:RUN_MARIMBA_INTEGRATION = $originalIntegration }
    else { Remove-Item Env:RUN_MARIMBA_INTEGRATION -ErrorAction SilentlyContinue }
  }

  return $script:selfTestFailures
}

if ($SelfTest) {
  $selfTestExitCode = Invoke-SelfTests
  exit $selfTestExitCode
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $repoRoot 'backend'
$suffix = ([Guid]::NewGuid().ToString('N')).Substring(0, 12)
$resourcePrefix = "indi-0031-test-$suffix"
$containerName = "$resourcePrefix-postgres"
$networkName = "$resourcePrefix-network"
$volumeName = "$resourcePrefix-volume"
$databaseName = "indi_0031_${suffix}_test"
$databaseUser = "indi_test_$suffix"
$passwordBytes = New-Object byte[] 30
$randomGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
$randomGenerator.GetBytes($passwordBytes)
$randomGenerator.Dispose()
$databasePassword = [Convert]::ToBase64String($passwordBytes)
$expectedLabel = $suffix
$harnessLabel = "indi.temporary-0031=$expectedLabel"
$primaryExitCode = 0
$cleanupExitCode = 0
$continueMain = $true

foreach ($name in @($containerName, $networkName, $volumeName)) {
  if (-not (Test-TemporaryName $name)) {
    Write-Error "Nombre temporal inseguro: $name" -ErrorAction Continue
    $primaryExitCode = 1
    $continueMain = $false
  }
}

try {
  if ($continueMain) {
    & docker info *> $null
    $dockerInfoExitCode = $LASTEXITCODE
    if ($dockerInfoExitCode -ne 0) {
      $primaryExitCode = $dockerInfoExitCode
      $continueMain = $false
    }
  }

  if ($continueMain) {
    & docker network create --label $harnessLabel $networkName | Out-Null
    $networkCreateExitCode = $LASTEXITCODE
    if ($networkCreateExitCode -ne 0) {
      $primaryExitCode = $networkCreateExitCode
      $continueMain = $false
    }
  }

  if ($continueMain) {
    & docker volume create --label $harnessLabel $volumeName | Out-Null
    $volumeCreateExitCode = $LASTEXITCODE
    if ($volumeCreateExitCode -ne 0) {
      $primaryExitCode = $volumeCreateExitCode
      $continueMain = $false
    }
  }

  if ($continueMain) {
    & docker run --detach `
      --name $containerName `
      --label $harnessLabel `
      --network $networkName `
      --publish '127.0.0.1::5432' `
      --mount "type=volume,source=$volumeName,target=/var/lib/postgresql" `
      --env "POSTGRES_DB=$databaseName" `
      --env "POSTGRES_USER=$databaseUser" `
      --env "POSTGRES_PASSWORD=$databasePassword" `
      postgres:18 | Out-Null
    $containerCreateExitCode = $LASTEXITCODE
    if ($containerCreateExitCode -ne 0) {
      $primaryExitCode = $containerCreateExitCode
      $continueMain = $false
    }
  }

  if ($continueMain) {
    $ready = $false
    $lastReadyExitCode = 1
    for ($attempt = 1; $attempt -le 60; $attempt++) {
      & docker exec $containerName pg_isready --username $databaseUser --dbname $databaseName *> $null
      $lastReadyExitCode = $LASTEXITCODE
      if ($lastReadyExitCode -eq 0) {
        $ready = $true
        break
      }
      Start-Sleep -Seconds 1
    }
    if (-not $ready) {
      $primaryExitCode = Normalize-FailureCode $lastReadyExitCode
      $continueMain = $false
    }
  }

  if ($continueMain) {
    $portMappingOutput = & docker port $containerName '5432/tcp' 2>&1
    $portCommandExitCode = $LASTEXITCODE
    if ($portCommandExitCode -ne 0) {
      $primaryExitCode = $portCommandExitCode
      $continueMain = $false
    } else {
      $portMapping = ($portMappingOutput | Out-String).Trim()
      if ($portMapping -notmatch '^127\.0\.0\.1:(\d+)$') {
        $primaryExitCode = 1
        $continueMain = $false
      } else {
        $hostPort = [int]$Matches[1]
        if ($hostPort -eq 5432 -or $databaseName -notmatch '_test$') {
          $primaryExitCode = 1
          $continueMain = $false
        }
      }
    }
  }

  if ($continueMain) {
    $escapedUser = [Uri]::EscapeDataString($databaseUser)
    $escapedPassword = [Uri]::EscapeDataString($databasePassword)
    $temporaryDatabaseUrl = "postgresql://${escapedUser}:${escapedPassword}@127.0.0.1:$hostPort/$databaseName"

    Push-Location $backendPath
    try {
      $migrateExitCode = Invoke-WithTemporaryEnvironment $temporaryDatabaseUrl $false {
        param($result)
        & npm run migrate | Out-Host
        $result.ExitCode = $LASTEXITCODE
      }
      if ($migrateExitCode -ne 0) {
        $primaryExitCode = $migrateExitCode
        $continueMain = $false
      }

      if ($continueMain) {
        & npm run build | Out-Host
        $buildExitCode = $LASTEXITCODE
        if ($buildExitCode -ne 0) {
          $primaryExitCode = $buildExitCode
          $continueMain = $false
        }
      }

      if ($continueMain) {
        $testExitCode = Invoke-WithTemporaryEnvironment $temporaryDatabaseUrl $true {
          param($result)
          & npm test | Out-Host
          $result.ExitCode = $LASTEXITCODE
        }
        if ($testExitCode -ne 0) {
          $primaryExitCode = $testExitCode
          $continueMain = $false
        }
      }
    } finally {
      Pop-Location
    }
  }
} catch {
  if ($primaryExitCode -eq 0) { $primaryExitCode = 1 }
  Write-Error "Fallo principal del harness; se conservará el código $primaryExitCode." -ErrorAction Continue
} finally {
  foreach ($resource in @(
    @{ Kind = 'container'; Name = $containerName },
    @{ Kind = 'volume'; Name = $volumeName },
    @{ Kind = 'network'; Name = $networkName }
  )) {
    try {
      $resourceCleanupCode = Remove-TemporaryDockerResource $resource.Kind $resource.Name $expectedLabel
      if ($resourceCleanupCode -ne 0) { $cleanupExitCode = 70 }
    } catch {
      $cleanupExitCode = 70
      Write-Error "Excepción durante la limpieza segura de '$($resource.Name)'." -ErrorAction Continue
    }
  }
}

$finalExitCode = Get-FinalExitCode $primaryExitCode $cleanupExitCode
if ($cleanupExitCode -ne 0) {
  Write-Error "La limpieza tuvo fallos; código reservado $cleanupFailureExitCode. Código final: $finalExitCode." -ErrorAction Continue
}
exit $finalExitCode

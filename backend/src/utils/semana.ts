/// Réplica exacta de `frontend/lib/core/semana_util.dart` — semana real
/// lunes 00:00 a domingo 23:59:59 (NO "últimos 7 días"). Cualquier cambio
/// aquí debe reflejarse también en el frontend, y viceversa.
///
/// TODO-SPEC: no hay definición de "semana laboral" en SPEC.md (podría
/// empezar en domingo o en otro huso horario según la obra) — se usa
/// lunes-domingo, hora local del servidor, por ser el estándar ISO más
/// común en México (mismo criterio ya aplicado en el frontend).

/// `0` = lunes ... `6` = domingo (a diferencia de `Date.getDay()`, donde
/// `0` = domingo).
function diaIsoDesdeInicioDeSemana(fecha: Date): number {
  const diaJs = fecha.getDay(); // 0=domingo..6=sábado
  return diaJs === 0 ? 6 : diaJs - 1;
}

export function inicioDeSemana(fecha: Date): Date {
  const soloFecha = new Date(fecha.getFullYear(), fecha.getMonth(), fecha.getDate());
  soloFecha.setDate(soloFecha.getDate() - diaIsoDesdeInicioDeSemana(soloFecha));
  return soloFecha;
}

/// Primer instante de la semana SIGUIENTE — límite superior exclusivo.
export function finDeSemana(fecha: Date): Date {
  const inicio = inicioDeSemana(fecha);
  const fin = new Date(inicio);
  fin.setDate(fin.getDate() + 7);
  return fin;
}

export function estaEnSemanaDe(fecha: Date, semanaDeReferencia: Date): boolean {
  const inicio = inicioDeSemana(semanaDeReferencia);
  const fin = finDeSemana(semanaDeReferencia);
  return fecha >= inicio && fecha < fin;
}

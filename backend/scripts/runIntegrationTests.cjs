const { spawnSync } = require('node:child_process');
const { dirname, join } = require('node:path');

const vitest = join(dirname(require.resolve('vitest')), 'vitest.mjs');
const resultado = spawnSync(process.execPath, [vitest, 'run'], {
  cwd: process.cwd(),
  env: {
    ...process.env,
    RUN_MARIMBA_INTEGRATION: '1',
    RUN_IDEMPOTENCY_INTEGRATION: '1',
    RUN_PASSWORD_RESET_INTEGRATION: '1',
  },
  stdio: 'inherit',
});

if (resultado.error) throw resultado.error;
process.exitCode = resultado.status ?? 1;

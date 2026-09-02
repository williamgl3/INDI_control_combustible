import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    setupFiles: ['./test/setup.ts'],
    // Cada archivo de test corre con su propio registro de módulos, así
    // que los mocks de `pg`/pool (vi.mock por archivo) no se filtran de
    // un test a otro.
    include: ['test/**/*.test.ts'],
  },
});

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const migrationPath = fileURLToPath(
  new URL('../src/db/migrations/0031_marimba_partidas_inventario.sql', import.meta.url),
);
const sql = readFileSync(migrationPath, 'utf8');

describe('contrato declarativo de la migración 0031', () => {
  it('separa el inventario por unidad y combustible exacto', () => {
    expect(sql).toContain('tipo_combustible VARCHAR(50) NOT NULL');
    expect(sql).toContain(
      'ON movimientos_inventario_marimba(marimba_id, tipo_combustible, creado_en)',
    );
    expect(sql).toContain(
      'FOREIGN KEY (carga_partida_id, marimba_id, carga_partida_tipo, tipo_combustible)',
    );
  });

  it('ata carga, solicitud y partida mediante claves compuestas', () => {
    expect(sql).toContain('ADD COLUMN solicitud_id UUID REFERENCES solicitudes_autorizacion(id)');
    expect(sql).toContain('FOREIGN KEY (carga_id, solicitud_id, vehiculo_id)');
    expect(sql).toContain(
      'FOREIGN KEY (solicitud_partida_id, solicitud_id, vehiculo_id, tipo, tipo_combustible)',
    );
    expect(sql).toContain('FOREIGN KEY (carga_partida_id, carga_id, concepto)');
    expect(sql).toContain(
      'FOREIGN KEY (despacho_id, recorrido_id, marimba_id, tipo_combustible)',
    );
  });

  it('conserva cantidad_declarada nullable y sin default', () => {
    expect(sql).toContain('ADD COLUMN cantidad_declarada BOOLEAN,');
    expect(sql).not.toMatch(/cantidad_declarada\s+BOOLEAN\s+NOT NULL/i);
    expect(sql).not.toMatch(/cantidad_declarada\s+BOOLEAN[^,;]*DEFAULT/i);
  });

  it('no reinterpreta ni elimina datos históricos', () => {
    expect(sql).not.toMatch(/\bUPDATE\b/i);
    expect(sql).not.toMatch(/\bDELETE\b/i);
    expect(sql).not.toMatch(/\bDROP\s+(TABLE|COLUMN)\b/i);
    expect(sql).not.toMatch(/\bRENAME\b/i);
  });
});

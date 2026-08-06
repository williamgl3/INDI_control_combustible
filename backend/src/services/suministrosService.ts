import { pool } from '../db/pool';
import type { Suministro } from '../types';

interface FilaSuministro {
  id: string;
  chofer_id: string;
  gasolinera: string;
  litros: string;
  foto_ticket_path: string | null;
  pipa_id: string | null;
  pipa_nombre: string | null;
  pipa_modelo: string | null;
  pipa_numero_economico: string | null;
  creado_en: Date;
}

function aSuministro(fila: FilaSuministro): Suministro {
  return {
    id: fila.id,
    choferId: fila.chofer_id,
    gasolinera: fila.gasolinera,
    litros: Number(fila.litros),
    fotoTicketPath: fila.foto_ticket_path,
    pipaId: fila.pipa_id,
    pipaNombre: fila.pipa_nombre,
    pipaModelo: fila.pipa_modelo,
    pipaNumeroEconomico: fila.pipa_numero_economico,
    creadoEn: fila.creado_en.toISOString(),
  };
}

export async function crearSuministro(datos: {
  choferId: string;
  gasolinera: string;
  litros: number;
  fotoTicketPath?: string | null | undefined;
  pipaId?: string | null | undefined;
  pipaNombre?: string | null | undefined;
  pipaModelo?: string | null | undefined;
  pipaNumeroEconomico?: string | null | undefined;
}): Promise<Suministro> {
  const { rows } = await pool.query<FilaSuministro>(
    `INSERT INTO suministros (chofer_id, gasolinera, litros, foto_ticket_path,
                              pipa_id, pipa_nombre, pipa_modelo, pipa_numero_economico)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [
      datos.choferId,
      datos.gasolinera,
      datos.litros,
      datos.fotoTicketPath ?? null,
      datos.pipaId ?? null,
      datos.pipaNombre ?? null,
      datos.pipaModelo ?? null,
      datos.pipaNumeroEconomico ?? null,
    ],
  );
  return aSuministro(rows[0]!);
}

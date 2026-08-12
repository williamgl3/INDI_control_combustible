import { Router } from 'express';
import { requireAuth } from '../middleware/auth';

export const suministrosRouter = Router();
suministrosRouter.use(requireAuth as never);

// Flujo legado: se conserva la ruta para que clientes anteriores reciban
// una respuesta explícita, pero ninguna escritura llega al servicio/DB.
suministrosRouter.post('/', (_req, res) => {
  res.status(410).json({
    error:
      'El registro de suministros fue sustituido por partidas de carga, inventario de unidad abastecedora y despachos.',
  });
});

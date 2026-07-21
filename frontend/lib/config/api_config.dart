class ApiConfig {
  // Railway (producción) no responde ahora mismo — 404 "Application not
  // found" en toda ruta, ver bitácora. Mientras se soluciona el deploy,
  // se apunta al backend corriendo local con `npm run dev` en
  // C:\Users\William\Desktop\INDI_backend_work\backend.
  static const String baseUrl = 'http://localhost:3000';
  // static const String baseUrl = 'https://indi-backend.up.railway.app';
}

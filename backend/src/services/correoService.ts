import nodemailer from 'nodemailer';

function configuracion() {
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const password = process.env.SMTP_PASSWORD;
  const from = process.env.SMTP_FROM;
  const resetUrl = process.env.PASSWORD_RESET_PUBLIC_URL;
  if (!host || !user || !password || !from || !resetUrl) {
    throw new Error('La entrega de recuperación no está configurada.');
  }
  const port = Number(process.env.SMTP_PORT ?? 587);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('SMTP_PORT no es válido.');
  }
  return { host, user, password, from, resetUrl, port };
}

export async function enviarRecuperacionPassword(destinatario: string, token: string) {
  const config = configuracion();
  const enlace = new URL(config.resetUrl);
  enlace.searchParams.set('token', token);
  const transport = nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user: config.user, pass: config.password },
  });
  await transport.sendMail({
    from: config.from,
    to: destinatario,
    subject: 'Restablece tu contraseña de INDI Combustible',
    text: `Abre este enlace para crear una nueva contraseña:\n\n${enlace}\n\nSi no solicitaste este cambio, ignora este mensaje.`,
  });
}

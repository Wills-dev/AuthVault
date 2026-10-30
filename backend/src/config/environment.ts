export function validateEnvironment(env: Record<string, unknown>) {
  if (!["development", "test", "production"].includes(String(env.NODE_ENV))) {
    throw new Error("NODE_ENV must be development, test or production");
  }
  try {
    const database = new URL(String(env.DATABASE_URL));
    if (
      !["postgres:", "postgresql:"].includes(database.protocol) ||
      !database.password
    )
      throw new Error();
  } catch {
    throw new Error("DATABASE_URL must be a PostgreSQL URL with credentials");
  }
  if (!/^[a-f0-9]{64}$/i.test(String(env.AUDIT_HMAC_KEY)))
    throw new Error("AUDIT_HMAC_KEY requires 32 random bytes encoded as hex");
  for (const key of ["OTP_HMAC_KEY", "ACCESS_JWT_KEY"]) {
    if (
      !/^[a-f0-9]{64}$/i.test(String(env[key])) ||
      String(env[key]).toLowerCase() ===
        String(env.AUDIT_HMAC_KEY).toLowerCase()
    )
      throw new Error(`${key} requires an independent 32-byte hex secret`);
  }
  if (
    String(env.OTP_HMAC_KEY).toLowerCase() ===
    String(env.ACCESS_JWT_KEY).toLowerCase()
  )
    throw new Error("Authentication keys must be independent");
  const smtpPort = Number(env.SMTP_PORT ?? 1025),
    cooldown = Number(env.OTP_RESEND_SECONDS ?? 60);
  if (!Number.isInteger(cooldown) || cooldown < 60 || cooldown > 600)
    throw new Error("OTP resend cooldown must be 60–600 seconds");
  if (
    !Number.isInteger(smtpPort) ||
    smtpPort < 1 ||
    smtpPort > 65535 ||
    !env.SMTP_HOST ||
    !env.SMTP_FROM
  )
    throw new Error("Configure SMTP_HOST, SMTP_PORT and SMTP_FROM");
  if (env.NODE_ENV === "production" && (!env.SMTP_USER || !env.SMTP_PASSWORD))
    throw new Error("Production SMTP authentication is required");
  const ttl = Number(env.PENDING_TTL_SECONDS ?? 600);
  const port = Number(env.PORT ?? 3000);
  if (!Number.isInteger(ttl) || ttl < 60 || ttl > 900)
    throw new Error("Pending lifetime must be 60–900 seconds");
  if (!Number.isInteger(port) || port < 1 || port > 65535)
    throw new Error("Invalid port");
  return {
    ...env,
    SMTP_PORT: smtpPort,
    SMTP_SECURE: String(env.SMTP_SECURE) === "true",
    OTP_RESEND_SECONDS: cooldown,
    PENDING_TTL_SECONDS: ttl,
    PORT: port,
    HOST: env.HOST ?? "127.0.0.1",
  };
}

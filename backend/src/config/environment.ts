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
  const ttl = Number(env.PENDING_TTL_SECONDS ?? 600);
  const port = Number(env.PORT ?? 3000);
  if (!Number.isInteger(ttl) || ttl < 60 || ttl > 900)
    throw new Error("Pending lifetime must be 60–900 seconds");
  if (!Number.isInteger(port) || port < 1 || port > 65535)
    throw new Error("Invalid port");
  return {
    ...env,
    PENDING_TTL_SECONDS: ttl,
    PORT: port,
    HOST: env.HOST ?? "127.0.0.1",
  };
}

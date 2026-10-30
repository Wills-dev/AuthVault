// Append missing Phase 5 development settings; never overwrite existing credentials.
import { readFileSync, appendFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { parse } from "dotenv";
const env = parse(readFileSync(".env"));
if (env.NODE_ENV !== "development")
  throw new Error("Development .env required");
const defaults = {
  OTP_HMAC_KEY: randomBytes(32).toString("hex"),
  ACCESS_JWT_KEY: randomBytes(32).toString("hex"),
  SMTP_HOST: "127.0.0.1",
  SMTP_PORT: "1025",
  SMTP_FROM: "security@authvault.local",
  SMTP_SECURE: "false",
  OTP_RESEND_SECONDS: "60",
};
for (const [key, value] of Object.entries(defaults))
  if (!(key in env))
    appendFileSync(".env", `\n${key}=${value}\n`, { mode: 0o600 });
console.log(
  "Missing local authentication settings added; existing settings preserved.",
);

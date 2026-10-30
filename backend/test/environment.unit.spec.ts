import { describe, expect, it } from "@jest/globals";
import { validateEnvironment } from "../src/config/environment.js";
const fixture = () => ({
  NODE_ENV: "test",
  DATABASE_URL: "postgresql://fixture:fixture@127.0.0.1/authvault_test",
  AUDIT_HMAC_KEY: "a".repeat(64),
  OTP_HMAC_KEY: "b".repeat(64),
  ACCESS_JWT_KEY: "c".repeat(64),
  SMTP_HOST: "127.0.0.1",
  SMTP_FROM: "test@example.test",
});
describe("security environment boundaries", () => {
  it("accepts complete local settings with bounded defaults", () => {
    const env = validateEnvironment(fixture());
    expect(env.OTP_RESEND_SECONDS).toBe(60);
    expect(env.SMTP_SECURE).toBe(false);
  });
  it.each(["AUDIT_HMAC_KEY", "OTP_HMAC_KEY", "ACCESS_JWT_KEY"])(
    "rejects missing/short %s",
    (key) => {
      expect(() =>
        validateEnvironment({ ...fixture(), [key]: "short" }),
      ).toThrow();
    },
  );
  it("rejects reused authentication secrets", () => {
    expect(() =>
      validateEnvironment({ ...fixture(), OTP_HMAC_KEY: "c".repeat(64) }),
    ).toThrow();
  });
  it.each([0, 59, 601, 1.5])(
    "rejects unsafe resend cooldown %s",
    (OTP_RESEND_SECONDS) => {
      expect(() =>
        validateEnvironment({ ...fixture(), OTP_RESEND_SECONDS }),
      ).toThrow();
    },
  );
  it("requires authenticated SMTP for production", () => {
    expect(() =>
      validateEnvironment({ ...fixture(), NODE_ENV: "production" }),
    ).toThrow();
  });
  it.each(["http://not-a-database", "postgresql://fixture@localhost/db"])(
    "rejects unsuitable database URL",
    (DATABASE_URL) => {
      expect(() =>
        validateEnvironment({ ...fixture(), DATABASE_URL }),
      ).toThrow();
    },
  );
  it("rejects equivalent hex keys even when their letter case differs", () => {
    expect(() =>
      validateEnvironment({ ...fixture(), ACCESS_JWT_KEY: "B".repeat(64) }),
    ).toThrow();
  });
});

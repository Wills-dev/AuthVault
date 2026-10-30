import "reflect-metadata";
import { describe, it, expect, beforeAll } from "@jest/globals";
import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import { PasswordService } from "../src/auth/password.service.js";
import { RegisterDto, LoginDto } from "../src/auth/auth.dto.js";
import { validateEnvironment } from "../src/config/environment.js";
import { secretHash } from "../src/auth/auth.service.js";

describe("password and input boundary", () => {
  const passwords = new PasswordService();
  beforeAll(async () => passwords.onModuleInit());
  it("hashes with salted Argon2id and verifies correct/incorrect passwords", async () => {
    const input = "a unique test passphrase";
    const first = await passwords.hash(input);
    const second = await passwords.hash(input);
    expect(first).toMatch(/^\$argon2id\$v=19\$/);
    expect(first.split("$")[3].split(",").sort()).toEqual([
      "m=65536",
      "p=1",
      "t=3",
    ]);
    expect(first).not.toEqual(second);
    expect(first).not.toContain(input);
    expect(await passwords.verify(first, input)).toBe(true);
    expect(await passwords.verify(first, "wrong password")).toBe(false);
    expect(await passwords.verify(undefined, input)).toBe(false);
  });
  it("normalizes email/name but preserves password whitespace", async () => {
    const dto = plainToInstance(RegisterDto, {
      fullName: "  Test User  ",
      email: "  TEST@Example.COM ",
      password: "  long passphrase  ",
    });
    expect(await validate(dto)).toHaveLength(0);
    expect(dto.email).toBe("test@example.com");
    expect(dto.fullName).toBe("Test User");
    expect(dto.password).toBe("  long passphrase  ");
  });
  it.each(["short", " ".repeat(20), "x".repeat(129)])(
    "rejects weak or excessive registration passwords",
    async (password) => {
      const dto = plainToInstance(RegisterDto, {
        fullName: "Test User",
        email: "test@example.com",
        password,
      });
      expect((await validate(dto)).length).toBeGreaterThan(0);
    },
  );
  it("rejects malformed registration fields", async () => {
    expect(
      (
        await validate(
          plainToInstance(RegisterDto, {
            fullName: " ",
            email: "bad",
            password: 123,
          }),
        )
      ).length,
    ).toBeGreaterThan(0);
    expect(
      (
        await validate(
          plainToInstance(LoginDto, { email: "a@example.com", password: "" }),
        )
      ).length,
    ).toBeGreaterThan(0);
  });
  it("hashes attempt secrets deterministically without storing the secret", () => {
    expect(secretHash("test-secret")).toHaveLength(64);
    expect(secretHash("test-secret")).not.toBe("test-secret");
    expect(secretHash("test-secret")).not.toBe(secretHash("other-secret"));
  });
  it("rejects missing secrets and invalid lifetimes", () => {
    expect(() => validateEnvironment({ NODE_ENV: "production" })).toThrow();
    expect(() =>
      validateEnvironment({
        NODE_ENV: "test",
        DATABASE_URL: "postgresql://test:generated@localhost/db",
        AUDIT_HMAC_KEY: "a".repeat(64),
        PENDING_TTL_SECONDS: 999999,
      }),
    ).toThrow();
  });
});

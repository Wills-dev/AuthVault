import { SignJWT, decodeJwt } from "jose";
import "reflect-metadata";
import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
} from "@jest/globals";
import { NestFactory } from "@nestjs/core";
import type { INestApplication } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { SMTPServer } from "smtp-server";
import { generateKeyPairSync, randomUUID, sign } from "node:crypto";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { AppModule } from "../src/app.module.js";
import { PrismaService } from "../src/prisma/prisma.service.js";
import { configure } from "../src/configure.js";
type Attempt = { attemptId: string; attemptToken: string; subjectId: string };
type Issued = { challengeId: string; expiresAt: string; resendAt: string };
type Tokens = { accessToken: string; refreshToken: string };
describe("OTP SMTP and complete sessions with real PostgreSQL", () => {
  let app: INestApplication, db: PrismaService, smtp: SMTPServer;
  let mail: string[] = [];
  let rejectMail = false;
  beforeAll(async () => {
    if (
      process.env.RUN_DB_TESTS !== "1" ||
      !new URL(process.env.DATABASE_URL!).pathname.endsWith("/authvault_test")
    )
      throw new Error("Isolated runner required");
    smtp = new SMTPServer({
      authOptional: true,
      disabledCommands: ["AUTH", "STARTTLS"],
      logger: false,
      onData(stream, _session, done) {
        let raw = "";
        stream.on("data", (part) => (raw += String(part)));
        stream.on("end", () => {
          if (rejectMail) return done(new Error("Test rejection"));
          mail.push(raw);
          done();
        });
      },
    });
    await new Promise<void>((resolve) => smtp.listen(0, "127.0.0.1", resolve));
    app = await NestFactory.create(AppModule, {
      logger: false,
      bodyParser: false,
    });
    configure(app);
    await app.init();
    db = app.get(PrismaService);
    app
      .get(ConfigService)
      .set("SMTP_PORT", (smtp.server.address() as AddressInfo).port);
  });
  beforeEach(async () => {
    mail = [];
    rejectMail = false;
    await db.rateLimit.deleteMany();
  });
  afterAll(async () => {
    if (db) {
      await db.user.deleteMany({
        where: { email: { endsWith: "@otp.example.test" } },
      });
      await db.rateLimit.deleteMany();
    }
    if (app) await app.close();
    if (smtp) await new Promise<void>((resolve) => smtp.close(() => resolve()));
  });
  const api = () => request(app.getHttpServer());
  const send = (a: Attempt) =>
    api()
      .post("/v1/otp/send")
      .set("X-MFA-Token", a.attemptToken)
      .send({ attemptId: a.attemptId });
  const verify = (a: Attempt, c: Issued, code: string) =>
    api()
      .post("/v1/otp/verify")
      .set("X-MFA-Token", a.attemptToken)
      .send({ attemptId: a.attemptId, challengeId: c.challengeId, code });
  const code = () => {
    const value = mail.at(-1)?.match(/Your sign-in code: (\d{6})/)?.[1];
    if (!value) throw new Error("SMTP fixture did not receive a code");
    return value;
  };
  const wrong = (actual: string) =>
    String((Number(actual) + 1) % 1_000_000).padStart(6, "0");
  async function pending() {
    const email = `${randomUUID()}@otp.example.test`,
      password = "OTP integration passphrase";
    const registration = (
      await api()
        .post("/v1/auth/register")
        .send({ email, password, fullName: "OTP Fixture" })
        .expect(201)
    ).body as Attempt;
    const keys = generateKeyPairSync("ec", { namedCurve: "prime256v1" }),
      credentialId = randomUUID();
    async function proof(a: Attempt, purpose: string) {
      const challenge = (
        await api()
          .post("/v1/biometric/challenge")
          .set("X-MFA-Token", a.attemptToken)
          .send({
            attemptId: a.attemptId,
            credentialId,
            purpose,
            publicKey:
              purpose === "ENROLMENT"
                ? keys.publicKey
                    .export({ type: "spki", format: "der" })
                    .toString("base64")
                : "",
          })
          .expect(200)
      ).body;
      await api()
        .post(
          purpose === "ENROLMENT"
            ? "/v1/biometric/enrol"
            : "/v1/biometric/verify",
        )
        .set("X-MFA-Token", a.attemptToken)
        .send({
          attemptId: a.attemptId,
          credentialId,
          challengeId: challenge.challengeId,
          signature: sign(
            "sha256",
            Buffer.from(challenge.payload, "base64url"),
            keys.privateKey,
          ).toString("base64"),
        })
        .expect(200);
    }
    await send(registration).expect(403);
    await proof(registration, "ENROLMENT");
    const a = (
      await api().post("/v1/auth/login").send({ email, password }).expect(200)
    ).body as Attempt;
    await proof(a, "LOGIN");
    return a;
  }
  async function complete() {
    const a = await pending(),
      c = (await send(a).expect(200)).body as Issued;
    return {
      a,
      c,
      tokens: (await verify(a, c, code()).expect(200)).body as Tokens,
    };
  }
  it("accepts SMTP, stores HMAC only, completes MFA once and protects account routes", async () => {
    const a = await pending(),
      sent = await send(a).expect(200),
      c = sent.body as Issued,
      actual = code();
    expect(JSON.stringify(sent.body)).not.toContain(actual);
    const saved = await db.otpChallenge.findUniqueOrThrow({
      where: { id: c.challengeId },
    });
    expect(saved.codeMac).toMatch(/^[a-f0-9]{64}$/);
    expect(saved.codeMac).not.toContain(actual);
    expect(
      new Date(c.expiresAt).getTime() - saved.createdAt.getTime(),
    ).toBeGreaterThan(295000);
    await api()
      .get("/v1/users/me")
      .set("Authorization", `Bearer ${a.attemptToken}`)
      .expect(401);
    const tokens = (await verify(a, c, actual).expect(200)).body as Tokens;
    await api()
      .get("/v1/users/me")
      .set("Authorization", `Bearer ${tokens.accessToken}`)
      .expect(200);
    const security = await api()
      .get("/v1/users/me/security")
      .set("Authorization", `Bearer ${tokens.accessToken}`)
      .expect(200);
    expect(security.body.lastAuthentication).not.toBeNull();
    await verify(a, c, actual).expect(401);
    expect(
      await db.authSession.count({ where: { attemptId: a.attemptId } }),
    ).toBe(1);
  });
  it("rejects invalid and expired codes without consuming them", async () => {
    const a = await pending(),
      c = (await send(a).expect(200)).body as Issued;
    await verify(a, c, wrong(code())).expect(400);
    expect(
      (
        await db.otpChallenge.findUniqueOrThrow({
          where: { id: c.challengeId },
        })
      ).failures,
    ).toBe(1);
    await db.otpChallenge.update({
      where: { id: c.challengeId },
      data: { expiresAt: new Date(0) },
    });
    const expired = await verify(a, c, code()).expect(400);
    expect(expired.body.error.code).toBe("OTP_EXPIRED");
  });
  it("binds a challenge to its attempt and verified device", async () => {
    const first = await pending(),
      c = (await send(first).expect(200)).body as Issued,
      actual = code(),
      second = await pending();
    await verify(second, c, actual).expect(400);
    const attempt = await db.authAttempt.findUniqueOrThrow({
      where: { id: first.attemptId },
    });
    await db.biometricCredential.update({
      where: { id: attempt.verifiedCredentialId! },
      data: { revokedAt: new Date() },
    });
    await verify(first, c, actual).expect(401);
  });
  it("enforces cooldown and invalidates previous codes only after accepted replacement", async () => {
    const a = await pending(),
      first = (await send(a).expect(200)).body as Issued,
      old = code();
    await send(a).expect(429);
    await db.otpChallenge.update({
      where: { id: first.challengeId },
      data: { resendAt: new Date(0) },
    });
    const second = (await send(a).expect(200)).body as Issued,
      actual = code();
    await verify(a, first, old).expect(400);
    await verify(a, second, actual).expect(200);
  });
  it("commits five failures and locks the user across attempts", async () => {
    const a = await pending(),
      c = (await send(a).expect(200)).body as Issued,
      invalid = wrong(code());
    for (let i = 0; i < 5; i++) await verify(a, c, invalid).expect(400);
    expect(
      (
        await db.otpChallenge.findUniqueOrThrow({
          where: { id: c.challengeId },
        })
      ).failures,
    ).toBe(5);
    await verify(a, c, code()).expect(429);
    await send(a).expect(429);
    expect(
      (await db.user.findUniqueOrThrow({ where: { id: a.subjectId } }))
        .otpLockedUntil,
    ).not.toBeNull();
  });
  it("consumes concurrent verification at most once", async () => {
    const a = await pending(),
      c = (await send(a).expect(200)).body as Issued,
      actual = code();
    const results = await Promise.all([
      verify(a, c, actual),
      verify(a, c, actual),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 401]);
    expect(
      await db.authSession.count({ where: { attemptId: a.attemptId } }),
    ).toBe(1);
  });
  it("rolls back challenge creation when SMTP rejects mail", async () => {
    const a = await pending();
    rejectMail = true;
    const response = await send(a).expect(503);
    expect(response.body.error.code).toBe("EMAIL_UNAVAILABLE");
    expect(
      await db.otpChallenge.count({ where: { attemptId: a.attemptId } }),
    ).toBe(0);
    expect(mail).toHaveLength(0);
  });
  it("rate limits issuance and verification after valid context", async () => {
    const a = await pending(),
      c = (await send(a).expect(200)).body as Issued;
    for (let i = 0; i < 5; i++) await send(a).expect(429);
    const limited = await send(a).expect(429);
    expect(limited.body.error.code).toBe("RATE_LIMITED");
    for (let i = 0; i < 15; i++)
      await verify(a, { ...c, challengeId: randomUUID() }, "000000").expect(
        400,
      );
    const result = await verify(a, c, code()).expect(429);
    expect(result.body.error.code).toBe("RATE_LIMITED");
  });
  it("rotates refresh tokens and revokes the family on replay", async () => {
    const { tokens } = await complete();
    const next = (
      await api()
        .post("/v1/auth/refresh")
        .send({ refreshToken: tokens.refreshToken })
        .expect(200)
    ).body as Tokens;
    expect(next.refreshToken).not.toBe(tokens.refreshToken);
    await api()
      .post("/v1/auth/refresh")
      .send({ refreshToken: tokens.refreshToken })
      .expect(401);
    await api()
      .post("/v1/auth/refresh")
      .send({ refreshToken: next.refreshToken })
      .expect(401);
    await api()
      .get("/v1/users/me")
      .set("Authorization", `Bearer ${next.accessToken}`)
      .expect(401);
  });
  it("atomically detects concurrent refresh reuse and revokes the winner too", async () => {
    const { tokens } = await complete();
    const results = await Promise.all([
      api()
        .post("/v1/auth/refresh")
        .send({ refreshToken: tokens.refreshToken }),
      api()
        .post("/v1/auth/refresh")
        .send({ refreshToken: tokens.refreshToken }),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 401]);
    const winner = results.find((r) => r.status === 200)!.body as Tokens;
    await api()
      .get("/v1/users/me")
      .set("Authorization", `Bearer ${winner.accessToken}`)
      .expect(401);
  });
  it("logout revokes refresh and access through live session checks", async () => {
    const { tokens } = await complete();
    await api()
      .post("/v1/auth/logout")
      .send({ refreshToken: tokens.refreshToken })
      .expect(204);
    await api()
      .get("/v1/users/me")
      .set("Authorization", `Bearer ${tokens.accessToken}`)
      .expect(401);
    await api()
      .post("/v1/auth/refresh")
      .send({ refreshToken: tokens.refreshToken })
      .expect(401);
  });
  it("rejects expired sessions", async () => {
    const { a, tokens } = await complete();
    await db.authSession.updateMany({
      where: { attemptId: a.attemptId },
      data: { expiresAt: new Date(0) },
    });
    await api()
      .get("/v1/users/me")
      .set("Authorization", `Bearer ${tokens.accessToken}`)
      .expect(401);
    await api()
      .post("/v1/auth/refresh")
      .send({ refreshToken: tokens.refreshToken })
      .expect(401);
  });
  it("rejects expired JWTs, missing factors, wrong audience/issuer and disallowed algorithm", async () => {
    const { tokens } = await complete();
    const original = decodeJwt(tokens.accessToken),
      key = Buffer.from(process.env.ACCESS_JWT_KEY!, "hex");
    for (const variant of [
      { ...original, exp: Math.floor(Date.now() / 1000) - 10 },
      { ...original, amr: ["pwd"] },
      { ...original, aud: "another-app" },
      { ...original, iss: "another-service" },
    ]) {
      const token = await new SignJWT(variant)
        .setProtectedHeader({ alg: "HS256", typ: "at+jwt" })
        .sign(key);
      await api()
        .get("/v1/users/me")
        .set("Authorization", `Bearer ${token}`)
        .expect(401);
    }
    const token = await new SignJWT(original)
      .setProtectedHeader({ alg: "HS384", typ: "at+jwt" })
      .sign(Buffer.alloc(48, 1));
    await api()
      .get("/v1/users/me")
      .set("Authorization", `Bearer ${token}`)
      .expect(401);
  });
  it("SMTP replacement failure preserves the earlier valid challenge", async () => {
    const a = await pending(),
      first = (await send(a).expect(200)).body as Issued,
      actual = code();
    await db.otpChallenge.update({
      where: { id: first.challengeId },
      data: { resendAt: new Date(0) },
    });
    rejectMail = true;
    await send(a).expect(503);
    expect(
      await db.otpChallenge.count({ where: { attemptId: a.attemptId } }),
    ).toBe(1);
    await verify(a, first, actual).expect(200);
  });
  it("caps accepted deliveries independently of cooldown", async () => {
    const a = await pending();
    for (let i = 0; i < 3; i++) {
      const c = (await send(a).expect(200)).body as Issued;
      await db.otpChallenge.update({
        where: { id: c.challengeId },
        data: { resendAt: new Date(0) },
      });
    }
    const capped = await send(a).expect(429);
    expect(capped.body.error.code).toBe("OTP_SEND_LIMIT");
    expect(mail).toHaveLength(3);
  });
});

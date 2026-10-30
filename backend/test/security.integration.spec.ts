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
import { randomUUID } from "node:crypto";
import request from "supertest";
import { AppModule } from "../src/app.module.js";
import { PrismaService } from "../src/prisma/prisma.service.js";
import { configure } from "../src/configure.js";
describe("phase 6 adversarial API surface", () => {
  let app: INestApplication, db: PrismaService;
  const api = () => request(app.getHttpServer());
  const fixture = () => ({
    email: `${randomUUID()}@security.example.test`,
    fullName: "Security Fixture",
    password: "security fixture passphrase",
  });
  beforeAll(async () => {
    if (
      process.env.RUN_DB_TESTS !== "1" ||
      !new URL(process.env.DATABASE_URL!).pathname.endsWith("/authvault_test")
    )
      throw new Error("Isolated local runner required");
    app = await NestFactory.create(AppModule, {
      logger: false,
      bodyParser: false,
    });
    configure(app);
    await app.init();
    db = app.get(PrismaService);
  });
  beforeEach(async () => {
    await db.rateLimit.deleteMany();
  });
  afterAll(async () => {
    if (db) {
      await db.user.deleteMany({
        where: { email: { endsWith: "@security.example.test" } },
      });
      await db.rateLimit.deleteMany();
    }
    if (app) await app.close();
  });
  it("rejects stage flags, key replacement flags and JSON SQL payloads", async () => {
    await api()
      .post("/v1/auth/register")
      .send({ ...fixture(), stage: "COMPLETED", authenticated: true })
      .expect(400);
    await api()
      .post("/v1/auth/login")
      .send({ email: { $ne: null }, password: "fixture" })
      .expect(400);
    await api()
      .post("/v1/auth/login")
      .send({ email: "' OR 1=1 --", password: "fixture" })
      .expect(400);
  });
  it("treats unknown users and wrong passwords identically at login", async () => {
    const input = fixture();
    await api().post("/v1/auth/register").send(input).expect(201);
    const known = await api()
      .post("/v1/auth/login")
      .send({ email: input.email, password: "wrong" })
      .expect(401);
    const unknown = await api()
      .post("/v1/auth/login")
      .send({ email: fixture().email, password: "wrong" })
      .expect(401);
    expect(known.body.error.code).toBe(unknown.body.error.code);
    expect(known.body.error.message).toBe(unknown.body.error.message);
  });
  it("documents confirmed registration enumeration instead of claiming resistance", async () => {
    const input = fixture();
    await api().post("/v1/auth/register").send(input).expect(201);
    await api().post("/v1/auth/register").send(input).expect(400);
  });
  it("rejects OTP send/verify before biometric completion and all pending Bearers", async () => {
    const input = fixture(),
      registration = (
        await api().post("/v1/auth/register").send(input).expect(201)
      ).body;
    const login = (
      await api()
        .post("/v1/auth/login")
        .send({ email: input.email, password: input.password })
        .expect(200)
    ).body;
    for (const a of [registration, login]) {
      await api()
        .post("/v1/otp/send")
        .set("X-MFA-Token", a.attemptToken)
        .send({ attemptId: a.attemptId })
        .expect(403);
      await api()
        .post("/v1/otp/verify")
        .set("X-MFA-Token", a.attemptToken)
        .send({
          attemptId: a.attemptId,
          challengeId: randomUUID(),
          code: "000000",
        })
        .expect(403);
      await api()
        .get("/v1/users/me")
        .set("Authorization", `Bearer ${a.attemptToken}`)
        .expect(401);
    }
  });
  it("isolates pending credentials across accounts and expiration", async () => {
    const first = (
      await api().post("/v1/auth/register").send(fixture()).expect(201)
    ).body;
    const second = (
      await api().post("/v1/auth/register").send(fixture()).expect(201)
    ).body;
    await api()
      .get(`/v1/auth/pending/${first.attemptId}`)
      .set("X-MFA-Token", second.attemptToken)
      .expect(401);
    await db.authAttempt.update({
      where: { id: first.attemptId },
      data: { expiresAt: new Date(0) },
    });
    await api()
      .post("/v1/otp/send")
      .set("X-MFA-Token", first.attemptToken)
      .send({ attemptId: first.attemptId })
      .expect(401);
  });
  it("does not trust forwarded IP headers to evade brute-force limits", async () => {
    const email = fixture().email;
    for (let i = 0; i < 10; i++)
      await api()
        .post("/v1/auth/login")
        .set("X-Forwarded-For", `192.0.2.${i + 1}`)
        .send({ email, password: "wrong" })
        .expect(401);
    const denied = await api()
      .post("/v1/auth/login")
      .set("X-Forwarded-For", "198.51.100.1")
      .send({ email, password: "wrong" })
      .expect(429);
    expect(Number(denied.headers["retry-after"])).toBeGreaterThan(0);
  });
  it("sets security headers/no-store and grants no cross-origin browser access", async () => {
    const response = await api()
      .get("/v1/health/live")
      .set("Origin", "https://untrusted.example")
      .expect(200);
    expect(response.headers["cache-control"]).toBe("no-store");
    expect(response.headers["x-content-type-options"]).toBe("nosniff");
    expect(response.headers["access-control-allow-origin"]).toBeUndefined();
    expect(response.headers["x-powered-by"]).toBeUndefined();
    await api().get("/v1/users/me").expect(401);
    await api().get(`/v1/users/${randomUUID()}`).expect(404);
  });
  it("rejects client-fabricated authenticated state and unsigned/wrong-key access JWTs", async () => {
    const payload = Buffer.from(
      JSON.stringify({
        sub: randomUUID(),
        sid: randomUUID(),
        authenticated: true,
        amr: ["pwd", "biometric", "email_otp"],
        exp: Math.floor(Date.now() / 1000) + 300,
      }),
    ).toString("base64url");
    for (const alg of ["none", "HS256"]) {
      const header = Buffer.from(
        JSON.stringify({ alg, typ: "at+jwt" }),
      ).toString("base64url");
      await api()
        .get("/v1/users/me")
        .set(
          "Authorization",
          `Bearer ${header}.${payload}.${alg === "none" ? "" : "ZmFrZQ"}`,
        )
        .set("X-User-Id", randomUUID())
        .expect(401);
    }
  });
});

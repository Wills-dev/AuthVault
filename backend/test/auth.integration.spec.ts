import "reflect-metadata";
import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from "@jest/globals";
import { NestFactory } from "@nestjs/core";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { randomUUID } from "node:crypto";
import { AppModule } from "../src/app.module.js";
import { configure } from "../src/configure.js";
import { PrismaService } from "../src/prisma/prisma.service.js";
import { Prisma } from "../src/generated/prisma/client.js";
import { AuthRepository } from "../src/auth/auth.repository.js";
import { secretHash } from "../src/auth/auth.service.js";

// No silently skipped database test: run through scripts/test-integration.mjs.
describe("real PostgreSQL HTTP authentication", () => {
  let app: INestApplication;
  let prisma: PrismaService;
  const password = "integration fixture passphrase";
  const registration = () => ({
    fullName: "Fixture User",
    email: `${randomUUID()}@example.test`,
    password,
  });
  beforeAll(async () => {
    if (
      process.env.RUN_DB_TESTS !== "1" ||
      !new URL(process.env.DATABASE_URL!).pathname.endsWith("/authvault_test")
    )
      throw new Error(
        "Use npm run test:integration with isolated authvault_test database",
      );
    app = await NestFactory.create(AppModule, {
      logger: false,
      bodyParser: false,
    });
    configure(app);
    await app.init();
    prisma = app.get(PrismaService);
  });
  beforeEach(async () => {
    jest.restoreAllMocks();
    await prisma.rateLimit.deleteMany();
  });
  afterAll(async () => {
    if (prisma) {
      await prisma.rateLimit.deleteMany();
      await prisma.user.deleteMany({
        where: { email: { endsWith: "@example.test" } },
      });
      await prisma.auditEvent.deleteMany({ where: { userId: null } });
    }
    if (app) await app.close();
  });
  it("rejects malformed and oversized JSON without exposing submitted content", async () => {
    const malformed = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .set("Content-Type", "application/json")
      .send("{invalid")
      .expect(400);
    expect(malformed.body.error.code).toBe("VALIDATION_ERROR");
    expect(malformed.body.error.requestId).toBeDefined();
    const oversized = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ password: "x".repeat(9000) })
      .expect(413);
    expect(oversized.body.error.code).toBe("PAYLOAD_TOO_LARGE");
  });
  it("reports liveness and actual database readiness", async () => {
    expect(
      (await request(app.getHttpServer()).get("/v1/health/live")).body,
    ).toEqual({ status: "ok" });
    expect(
      (await request(app.getHttpServer()).get("/v1/health/ready")).body
        .database,
    ).toBe("reachable");
  });
  it("registers normalized unique users and stores only password/attempt hashes", async () => {
    const dto = registration();
    const response = await request(app.getHttpServer())
      .post("/v1/auth/register")
      .send({ ...dto, email: ` ${dto.email.toUpperCase()} ` })
      .expect(201);
    expect(response.body.stage).toBe("PENDING_ENROLMENT");
    expect(Object.keys(response.body).sort()).toEqual([
      "attemptId",
      "attemptToken",
      "expiresAt",
      "stage",
      "subjectId",
    ]);
    expect(response.body.attemptToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const user = await prisma.user.findUniqueOrThrow({
      where: { email: dto.email },
    });
    expect(user.passwordHash).toMatch(/^\$argon2id\$/);
    expect(user.passwordHash).not.toContain(password);
    const attempt = await prisma.authAttempt.findUniqueOrThrow({
      where: { id: response.body.attemptId },
    });
    expect(attempt.tokenHash).toBe(secretHash(response.body.attemptToken));
    expect(attempt.expiresAt.getTime()).toBeGreaterThan(Date.now());
    expect(attempt.expiresAt.getTime()).toBeLessThanOrEqual(
      Date.now() + 600000,
    );
    expect(response.headers["cache-control"]).toBe("no-store");
    const duplicate = await request(app.getHttpServer())
      .post("/v1/auth/register")
      .send(dto)
      .expect(400);
    expect(duplicate.body.error.code).toBe("REGISTRATION_UNAVAILABLE");
    expect(JSON.stringify(duplicate.body)).not.toContain(dto.email);
  });
  it("rejects invalid, weak, oversized and extra input without creating an account", async () => {
    const dto = registration();
    for (const input of [
      { ...dto, password: "short" },
      { ...dto, fullName: " " },
      { ...dto, email: "bad" },
      { ...dto, password: "x".repeat(129) },
      { ...dto, stage: "COMPLETED" },
    ]) {
      const response = await request(app.getHttpServer())
        .post("/v1/auth/register")
        .send(input)
        .expect(400);
      expect(response.body.error.code).toBe("VALIDATION_ERROR");
      expect(JSON.stringify(response.body)).not.toContain(password);
    }
    expect(
      await prisma.user.findUnique({ where: { email: dto.email } }),
    ).toBeNull();
  });
  it("validates password only into pending biometric stage; never issues access", async () => {
    const dto = registration();
    await request(app.getHttpServer())
      .post("/v1/auth/register")
      .send(dto)
      .expect(201);
    const login = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email: dto.email, password })
      .expect(200);
    expect(login.body.stage).toBe("PENDING_BIOMETRIC");
    expect(login.body.accessToken).toBeUndefined();
    expect(login.body.refreshToken).toBeUndefined();
    expect(await prisma.authSession.count()).toBe(0);
    expect(await prisma.refreshToken.count()).toBe(0);
    await request(app.getHttpServer())
      .get(`/v1/auth/pending/${login.body.attemptId}`)
      .set("X-MFA-Token", login.body.attemptToken)
      .expect(200);
    for (const path of ["/v1/users/me", "/v1/users/me/security"]) {
      const denied = await request(app.getHttpServer())
        .get(path)
        .set("Authorization", `Bearer ${login.body.attemptToken}`)
        .set("X-MFA-Token", login.body.attemptToken)
        .expect(401);
      expect(denied.body.error.code).toBe("SESSION_INVALID");
    }
    const user = await prisma.user.findUniqueOrThrow({
      where: { email: dto.email },
    });
    const events = await prisma.auditEvent.findMany({
      where: { userId: user.id },
    });
    expect(events.map((e) => e.kind)).toEqual(
      expect.arrayContaining(["REGISTRATION_CREATED", "PASSWORD_ACCEPTED"]),
    );
    expect(JSON.stringify(events)).not.toContain(password);
    expect(JSON.stringify(events)).not.toContain(login.body.attemptToken);
  });
  it("uses identical errors for unknown user and incorrect password", async () => {
    const dto = registration();
    await request(app.getHttpServer()).post("/v1/auth/register").send(dto);
    const wrong = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email: dto.email, password: "wrong" })
      .expect(401);
    const missing = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email: registration().email, password: "wrong" })
      .expect(401);
    expect(wrong.body.error.code).toBe("INVALID_CREDENTIALS");
    expect(wrong.body.error.message).toBe(missing.body.error.message);
    expect(
      await prisma.auditEvent.count({ where: { kind: "PASSWORD_REJECTED" } }),
    ).toBeGreaterThanOrEqual(2);
  });
  it("rejects missing/wrong attempt secrets, expired and revoked attempts", async () => {
    const response = await request(app.getHttpServer())
      .post("/v1/auth/register")
      .send(registration())
      .expect(201);
    const path = `/v1/auth/pending/${response.body.attemptId}`;
    await request(app.getHttpServer()).get(path).expect(401);
    await request(app.getHttpServer())
      .get(path)
      .set("X-MFA-Token", "x".repeat(43))
      .expect(401);
    await request(app.getHttpServer())
      .delete(path)
      .set("X-MFA-Token", response.body.attemptToken)
      .expect(204);
    await request(app.getHttpServer())
      .get(path)
      .set("X-MFA-Token", response.body.attemptToken)
      .expect(401);
    const second = await request(app.getHttpServer())
      .post("/v1/auth/register")
      .send(registration())
      .expect(201);
    await prisma.authAttempt.update({
      where: { id: second.body.attemptId },
      data: { expiresAt: new Date(0) },
    });
    await request(app.getHttpServer())
      .get(`/v1/auth/pending/${second.body.attemptId}`)
      .set("X-MFA-Token", second.body.attemptToken)
      .expect(401);
  });
  it("enforces account rate limit with Retry-After", async () => {
    const email = registration().email;
    for (let index = 0; index < 10; index++)
      await request(app.getHttpServer())
        .post("/v1/auth/login")
        .send({ email, password: "wrong" })
        .expect(401);
    const limited = await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({ email, password: "wrong" })
      .expect(429);
    expect(limited.body.error.code).toBe("RATE_LIMITED");
    expect(Number(limited.headers["retry-after"])).toBeGreaterThan(0);
  });
  it("enforces IP limits even when account identifiers change", async () => {
    // Validation failures are cheap but still consume IP quota.
    for (let index = 0; index < 30; index++)
      await request(app.getHttpServer())
        .post("/v1/auth/login")
        .send({})
        .expect(400);
    await request(app.getHttpServer())
      .post("/v1/auth/login")
      .send({})
      .expect(429);
  });
  it("fails closed and redacts database errors", async () => {
    jest.spyOn(app.get(AuthRepository), "register").mockRejectedValueOnce(
      new Prisma.PrismaClientKnownRequestError("sensitive database detail", {
        code: "P1001",
        clientVersion: "7.10.1",
      }),
    );
    const response = await request(app.getHttpServer())
      .post("/v1/auth/register")
      .send(registration())
      .expect(503);
    expect(response.body.error.code).toBe("SERVICE_UNAVAILABLE");
    expect(JSON.stringify(response.body)).not.toContain("sensitive");
    expect(response.body.error.requestId).toBeDefined();
  });
});

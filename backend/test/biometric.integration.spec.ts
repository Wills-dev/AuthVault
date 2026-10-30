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
import { generateKeyPairSync, randomUUID, sign } from "node:crypto";
import request from "supertest";
import { AppModule } from "../src/app.module.js";
import { AuthService } from "../src/auth/auth.service.js";
import { Prisma } from "../src/generated/prisma/client.js";
import { configure } from "../src/configure.js";
import { PrismaService } from "../src/prisma/prisma.service.js";
// Exportable software keys are server-test fixtures, NOT evidence of Android key protection.
const keyFixture = (curve = "prime256v1") => {
  const keys = generateKeyPairSync("ec", { namedCurve: curve });
  return {
    ...keys,
    id: randomUUID(),
    encoded: keys.publicKey
      .export({ type: "spki", format: "der" })
      .toString("base64"),
  };
};
type Attempt = {
  attemptId: string;
  attemptToken: string;
  subjectId: string;
  stage: string;
};
type Challenge = { challengeId: string; payload: string };
describe("biometric protocol with real PostgreSQL", () => {
  let app: INestApplication;
  let db: PrismaService;
  const password = "biometric integration passphrase";
  beforeAll(async () => {
    if (
      process.env.RUN_DB_TESTS !== "1" ||
      !new URL(process.env.DATABASE_URL!).pathname.endsWith("/authvault_test")
    )
      throw new Error("Use isolated integration runner");
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
        where: { email: { endsWith: "@biometric.example.test" } },
      });
      await db.rateLimit.deleteMany();
    }
    if (app) await app.close();
  });
  async function register() {
    const email = `${randomUUID()}@biometric.example.test`;
    const result = await request(app.getHttpServer())
      .post("/v1/auth/register")
      .send({ fullName: "Biometric Fixture", email, password })
      .expect(201);
    return { email, attempt: result.body as Attempt };
  }
  async function login(email: string): Promise<Attempt> {
    return (
      await request(app.getHttpServer())
        .post("/v1/auth/login")
        .send({ email, password })
        .expect(200)
    ).body as Attempt;
  }
  function challenge(
    attempt: Attempt,
    key: ReturnType<typeof keyFixture>,
    purpose = "ENROLMENT",
  ) {
    return request(app.getHttpServer())
      .post("/v1/biometric/challenge")
      .set("X-MFA-Token", attempt.attemptToken)
      .send({
        attemptId: attempt.attemptId,
        credentialId: key.id,
        purpose,
        publicKey: purpose === "ENROLMENT" ? key.encoded : "",
      });
  }
  function proof(
    attempt: Attempt,
    key: ReturnType<typeof keyFixture>,
    value: Challenge,
    enrolment = true,
    signature?: string,
  ) {
    return request(app.getHttpServer())
      .post(enrolment ? "/v1/biometric/enrol" : "/v1/biometric/verify")
      .set("X-MFA-Token", attempt.attemptToken)
      .send({
        attemptId: attempt.attemptId,
        credentialId: key.id,
        challengeId: value.challengeId,
        signature:
          signature ??
          sign(
            "sha256",
            Buffer.from(value.payload, "base64url"),
            key.privateKey,
          ).toString("base64"),
      });
  }
  async function enrolled() {
    const user = await register();
    const key = keyFixture();
    const issued = (await challenge(user.attempt, key).expect(200))
      .body as Challenge;
    await proof(user.attempt, key, issued).expect(200);
    return { ...user, key, issued };
  }
  it("enrols a signature proof and verifies login only into PENDING_OTP", async () => {
    const user = await enrolled();
    const credential = await db.biometricCredential.findUniqueOrThrow({
      where: { id: user.key.id },
    });
    expect(credential.publicKey).toBe(user.key.encoded);
    expect(credential.userId).toBe(user.attempt.subjectId);
    const status = await request(app.getHttpServer())
      .get(`/v1/auth/pending/${user.attempt.attemptId}`)
      .set("X-MFA-Token", user.attempt.attemptToken)
      .expect(200);
    expect(status.body.stage).toBe("ENROLMENT_COMPLETE");
    const attempt = await login(user.email);
    const issued = (await challenge(attempt, user.key, "LOGIN").expect(200))
      .body as Challenge;
    const payload = JSON.parse(
      Buffer.from(issued.payload, "base64url").toString("utf8"),
    ) as Record<string, string>;
    expect(payload).toMatchObject({
      protocol: "authvault.biometric.v1",
      purpose: "LOGIN",
      attemptId: attempt.attemptId,
      subjectId: attempt.subjectId,
      credentialId: user.key.id,
    });
    expect(payload.nonce).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const verified = await proof(attempt, user.key, issued, false).expect(200);
    expect(verified.body.stage).toBe("PENDING_OTP");
    expect(verified.body.accessToken).toBeUndefined();
    expect(verified.body.refreshToken).toBeUndefined();
    expect(await db.authSession.count()).toBe(0);
    for (const path of ["/v1/users/me", "/v1/users/me/security"])
      await request(app.getHttpServer())
        .get(path)
        .set("Authorization", `Bearer ${attempt.attemptToken}`)
        .expect(403);
    expect(
      await db.auditEvent.count({
        where: { userId: attempt.subjectId, kind: "BIOMETRIC_VERIFIED" },
      }),
    ).toBe(1);
  });
  it("rejects invalid signatures and altered signed bytes", async () => {
    const user = await register();
    const key = keyFixture();
    const issued = (await challenge(user.attempt, key).expect(200))
      .body as Challenge;
    await proof(
      user.attempt,
      key,
      issued,
      true,
      sign(
        "sha256",
        Buffer.from(issued.payload, "base64url"),
        keyFixture().privateKey,
      ).toString("base64"),
    ).expect(401);
    await proof(
      user.attempt,
      key,
      issued,
      true,
      sign("sha256", Buffer.from("altered"), key.privateKey).toString("base64"),
    ).expect(401);
    expect(
      await db.biometricCredential.count({
        where: { userId: user.attempt.subjectId },
      }),
    ).toBe(0);
    await proof(user.attempt, key, issued).expect(200);
  });
  it("rejects expired and superseded challenges", async () => {
    const user = await register();
    const key = keyFixture();
    const first = (await challenge(user.attempt, key).expect(200))
      .body as Challenge;
    const latest = (await challenge(user.attempt, key).expect(200))
      .body as Challenge;
    await proof(user.attempt, key, first).expect(401);
    await db.biometricChallenge.update({
      where: { id: latest.challengeId },
      data: { expiresAt: new Date(0) },
    });
    await proof(user.attempt, key, latest).expect(401);
  });
  it("rejects replayed enrolment and login proofs", async () => {
    const user = await enrolled();
    await proof(user.attempt, user.key, user.issued).expect(401);
    const attempt = await login(user.email);
    const issued = (await challenge(attempt, user.key, "LOGIN").expect(200))
      .body as Challenge;
    await proof(attempt, user.key, issued, false).expect(200);
    await proof(attempt, user.key, issued, false).expect(401);
  });
  it("rejects cross-user, unknown-credential and cross-attempt proofs", async () => {
    const first = await enrolled();
    const second = await register();
    const other = await login(second.email);
    await challenge(other, first.key, "LOGIN").expect(401);
    await challenge(other, keyFixture(), "LOGIN").expect(401);
    const attempt = await login(first.email);
    const next = await login(first.email);
    const issued = (await challenge(attempt, first.key, "LOGIN").expect(200))
      .body as Challenge;
    await proof(next, first.key, issued, false).expect(401);
  });
  it("rejects wrong stage, expired/revoked attempts and password-only replacement", async () => {
    const user = await enrolled();
    const attempt = await login(user.email);
    await challenge(attempt, keyFixture(), "ENROLMENT").expect(401);
    await challenge(user.attempt, user.key, "LOGIN").expect(401);
    await db.authAttempt.update({
      where: { id: attempt.attemptId },
      data: { expiresAt: new Date(0) },
    });
    await challenge(attempt, user.key, "LOGIN").expect(401);
    const next = await login(user.email);
    await db.authAttempt.update({
      where: { id: next.attemptId },
      data: { stage: "REVOKED" },
    });
    await challenge(next, user.key, "LOGIN").expect(401);
  });
  it.each([true, false])(
    "consumes a concurrent challenge at most once (enrolment=%s)",
    async (enrolment) => {
      const user = await register();
      const key = keyFixture();
      const registrationChallenge = (
        await challenge(user.attempt, key).expect(200)
      ).body as Challenge;
      let attempt = user.attempt;
      let issued = registrationChallenge;
      if (!enrolment) {
        await proof(attempt, key, issued).expect(200);
        attempt = await login(user.email);
        issued = (await challenge(attempt, key, "LOGIN").expect(200))
          .body as Challenge;
      }
      const results = await Promise.all([
        proof(attempt, key, issued, enrolment),
        proof(attempt, key, issued, enrolment),
      ]);
      expect(results.map((r) => r.status).sort()).toEqual([200, 401]);
      expect(
        (
          await db.biometricChallenge.findUniqueOrThrow({
            where: { id: issued.challengeId },
          })
        ).consumedAt,
      ).not.toBeNull();
    },
  );
  it("rejects credentials revoked after challenge issuance", async () => {
    const user = await enrolled();
    const attempt = await login(user.email);
    const issued = (await challenge(attempt, user.key, "LOGIN").expect(200))
      .body as Challenge;
    await db.biometricCredential.update({
      where: { id: user.key.id },
      data: { revokedAt: new Date() },
    });
    await proof(attempt, user.key, issued, false).expect(401);
    await challenge(attempt, user.key, "LOGIN").expect(401);
  });
  it("rejects unsupported keys and client authentication flags", async () => {
    const user = await register();
    await challenge(user.attempt, keyFixture("secp384r1")).expect(401);
    await request(app.getHttpServer())
      .post("/v1/biometric/enrol")
      .set("X-MFA-Token", user.attempt.attemptToken)
      .send({ attemptId: user.attempt.attemptId, verified: true })
      .expect(400);
  });
  it("limits proofs and does not charge attempt quota for unauthenticated requests", async () => {
    const user = await register();
    const key = keyFixture();
    for (let i = 0; i < 5; i++)
      await challenge(
        { ...user.attempt, attemptToken: "x".repeat(43) },
        key,
      ).expect(401);
    const issued = (await challenge(user.attempt, key).expect(200))
      .body as Challenge;
    for (let i = 0; i < 5; i++)
      await proof(user.attempt, key, issued, true, "AQIDBAUGBwg=").expect(401);
    await proof(user.attempt, key, issued).expect(429);
  });
  it("reports datastore outages safely instead of disguising them as rejected proof", async () => {
    const user = await register();
    const spy = jest
      .spyOn(app.get(AuthService), "context")
      .mockRejectedValueOnce(
        new Prisma.PrismaClientKnownRequestError("private database detail", {
          code: "P1001",
          clientVersion: "7.10.1",
        }),
      );
    try {
      const result = await challenge(user.attempt, keyFixture()).expect(503);
      expect(result.body.error.code).toBe("SERVICE_UNAVAILABLE");
      expect(JSON.stringify(result.body)).not.toContain(
        "private database detail",
      );
    } finally {
      spy.mockRestore();
    }
  });
});

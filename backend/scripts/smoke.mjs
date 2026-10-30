import "dotenv/config";
import assert from "node:assert/strict";
import { randomBytes, randomUUID } from "node:crypto";
import pg from "pg";
const base = process.env.SMOKE_API_URL ?? "http://127.0.0.1:3000/v1";
if (
  !["127.0.0.1", "localhost"].includes(new URL(base).hostname) ||
  process.env.NODE_ENV !== "development"
)
  throw new Error("Smoke test is for a local development backend only.");
const email = `smoke-${randomUUID()}@example.test`;
const password = randomBytes(24).toString("base64url");
const post = (path, data) =>
  fetch(`${base}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
try {
  const ready = await fetch(`${base}/health/ready`);
  assert.equal(ready.status, 200);
  const register = await post("/auth/register", {
    fullName: "Local smoke fixture",
    email,
    password,
  });
  assert.equal(register.status, 201);
  const enrolment = await register.json();
  assert.equal(enrolment.stage, "PENDING_ENROLMENT");
  const login = await post("/auth/login", { email, password });
  assert.equal(login.status, 200);
  const pending = await login.json();
  assert.equal(pending.stage, "PENDING_BIOMETRIC");
  assert.equal(pending.accessToken, undefined);
  assert.equal(pending.refreshToken, undefined);
  const status = await fetch(`${base}/auth/pending/${pending.attemptId}`, {
    headers: { "X-MFA-Token": pending.attemptToken },
  });
  assert.equal(status.status, 200);
  const protectedResponse = await fetch(`${base}/users/me`, {
    headers: { Authorization: `Bearer ${pending.attemptToken}` },
  });
  assert.equal(protectedResponse.status, 403);
  const wrong = await post("/auth/login", {
    email,
    password: randomBytes(24).toString("base64url"),
  });
  assert.equal(wrong.status, 401);
  const revoke = await fetch(`${base}/auth/pending/${pending.attemptId}`, {
    method: "DELETE",
    headers: { "X-MFA-Token": pending.attemptToken },
  });
  assert.equal(revoke.status, 204);
  console.log(
    "PASS: readiness 200, registration 201, login 200 pending only, status 200, protected resource 403, incorrect password 401, revocation 204.",
  );
} finally {
  const database = new pg.Client({
    connectionString: process.env.DATABASE_URL,
  });
  await database.connect();
  try {
    await database.query("BEGIN");
    await database.query(
      'DELETE FROM "AuditEvent" WHERE "userId" IN (SELECT id FROM "User" WHERE email=$1)',
      [email],
    );
    await database.query('DELETE FROM "User" WHERE email=$1', [email]);
    await database.query("COMMIT");
  } finally {
    await database.end();
  }
}

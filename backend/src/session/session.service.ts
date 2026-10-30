import { Injectable, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { SignJWT, jwtVerify } from "jose";
import { PrismaService } from "../prisma/prisma.service.js";
import type { Prisma, AuthSession } from "../generated/prisma/client.js";
const hash = (s: string) => createHash("sha256").update(s).digest("hex");
export const invalidSession = () =>
  new UnauthorizedException({
    code: "SESSION_INVALID",
    message: "Your session is unavailable. Please sign in again.",
  });
@Injectable()
export class SessionService {
  constructor(
    private readonly db: PrismaService,
    private readonly config: ConfigService,
  ) {}
  private key() {
    return Buffer.from(this.config.getOrThrow<string>("ACCESS_JWT_KEY"), "hex");
  }
  private async credentials(
    tx: Prisma.TransactionClient,
    session: AuthSession,
  ) {
    const refreshToken = randomBytes(32).toString("base64url");
    await tx.refreshToken.create({
      data: {
        sessionId: session.id,
        tokenHash: hash(refreshToken),
        expiresAt: session.expiresAt,
      },
    });
    const accessExpiresAt = new Date(
      Math.min(Date.now() + 300_000, session.expiresAt.getTime()),
    );
    const accessToken = await new SignJWT({
      sid: session.id,
      amr: ["pwd", "biometric", "email_otp"],
    })
      .setProtectedHeader({ alg: "HS256", typ: "at+jwt" })
      .setSubject(session.userId)
      .setIssuer("authvault")
      .setAudience("authvault-mobile")
      .setJti(randomUUID())
      .setIssuedAt()
      .setExpirationTime(Math.floor(accessExpiresAt.getTime() / 1000))
      .sign(this.key());
    return {
      accessToken,
      refreshToken,
      accessExpiresAt: accessExpiresAt.toISOString(),
      sessionExpiresAt: session.expiresAt.toISOString(),
    };
  }
  async create(
    tx: Prisma.TransactionClient,
    userId: string,
    attemptId: string,
    credentialId: string,
  ) {
    const session = await tx.authSession.create({
      data: {
        userId,
        attemptId,
        credentialId,
        expiresAt: new Date(Date.now() + 7 * 86400_000),
      },
    });
    return this.credentials(tx, session);
  }
  async refresh(token: string) {
    const result = await this.db.$transaction(async (tx) => {
      const initial = await tx.refreshToken.findUnique({
        where: { tokenHash: hash(token) },
      });
      if (!initial) return null;
      await tx.$queryRaw`SELECT id FROM "AuthSession" WHERE id = ${initial.sessionId}::uuid FOR UPDATE`;
      const saved = await tx.refreshToken.findUniqueOrThrow({
        where: { id: initial.id },
      });
      const session = await tx.authSession.findUniqueOrThrow({
        where: { id: saved.sessionId },
      });
      if (session.revokedAt || session.expiresAt.getTime() <= Date.now())
        return null;
      const credential = session.credentialId
        ? await tx.biometricCredential.findUnique({
            where: { id: session.credentialId },
          })
        : null;
      if (
        saved.consumedAt ||
        saved.revokedAt ||
        saved.expiresAt.getTime() <= Date.now() ||
        !credential ||
        credential.revokedAt ||
        credential.userId !== session.userId
      ) {
        await this.revoke(
          tx,
          session.id,
          saved.consumedAt ? "REFRESH_REPLAY" : "SESSION_REVOKED",
        );
        return null;
      }
      await tx.refreshToken.update({
        where: { id: saved.id },
        data: { consumedAt: new Date() },
      });
      await tx.auditEvent.create({
        data: { userId: session.userId, kind: "SESSION_REFRESHED" },
      });
      return this.credentials(tx, session);
    });
    if (!result) throw invalidSession();
    return result;
  }
  private async revoke(
    tx: Prisma.TransactionClient,
    id: string,
    kind = "SESSION_LOGOUT",
  ) {
    const session = await tx.authSession.update({
      where: { id },
      data: { revokedAt: new Date() },
    });
    await tx.auditEvent.create({ data: { userId: session.userId, kind } });
    await tx.refreshToken.updateMany({
      where: { sessionId: id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
  async logout(token: string) {
    await this.db.$transaction(async (tx) => {
      const saved = await tx.refreshToken.findUnique({
        where: { tokenHash: hash(token) },
      });
      if (!saved) return;
      await tx.$queryRaw`SELECT id FROM "AuthSession" WHERE id = ${saved.sessionId}::uuid FOR UPDATE`;
      await this.revoke(tx, saved.sessionId);
    });
  }
  async authorize(token: string) {
    let verified;
    try {
      verified = await jwtVerify(token, this.key(), {
        algorithms: ["HS256"],
        issuer: "authvault",
        audience: "authvault-mobile",
        typ: "at+jwt",
        requiredClaims: ["sub", "sid", "exp", "iat", "jti", "amr"],
      });
    } catch {
      throw invalidSession();
    }
    const { payload, protectedHeader } = verified;
    if (
      !Array.isArray(payload.amr) ||
      !["pwd", "biometric", "email_otp"].every((method) =>
        (payload.amr as unknown[]).includes(method),
      ) ||
      protectedHeader.typ !== "at+jwt" ||
      typeof payload.sid !== "string" ||
      typeof payload.sub !== "string"
    )
      throw invalidSession();
    const session = await this.db.authSession.findUnique({
      where: { id: payload.sid },
    });
    if (
      !session ||
      session.userId !== payload.sub ||
      session.revokedAt ||
      session.expiresAt.getTime() <= Date.now()
    )
      throw invalidSession();
    const credential = session.credentialId
      ? await this.db.biometricCredential.findUnique({
          where: { id: session.credentialId },
        })
      : null;
    if (
      !credential ||
      credential.userId !== session.userId ||
      credential.revokedAt
    )
      throw invalidSession();
    return session;
  }
}

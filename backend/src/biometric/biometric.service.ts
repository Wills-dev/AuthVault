import {
  Injectable,
  UnauthorizedException,
  HttpException,
} from "@nestjs/common";
import {
  createHash,
  createPublicKey,
  randomBytes,
  randomUUID,
  timingSafeEqual,
  verify,
} from "node:crypto";
import { BiometricRepository } from "./biometric.repository.js";
import { RateLimitService } from "../auth/rate-limit.service.js";
import { AuthService, secretHash } from "../auth/auth.service.js";
import { ChallengeDto, ChallengePurpose, ProofDto } from "./biometric.dto.js";
import { Prisma } from "../generated/prisma/client.js";

const digest = (value: Buffer) =>
  createHash("sha256").update(value).digest("hex");
const rejected = () =>
  new UnauthorizedException({
    code: "BIOMETRIC_REJECTED",
    message:
      "Biometric proof or authentication context is unavailable. Start again or retry with a fresh challenge.",
  });
@Injectable()
export class BiometricService {
  constructor(
    private readonly repository: BiometricRepository,
    private readonly limits: RateLimitService,
    private readonly auth: AuthService,
  ) {}
  private async attempt(
    tx: Prisma.TransactionClient,
    id: string,
    token: string | undefined,
    stage: string,
  ) {
    if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token)) throw rejected();
    const attempt = await this.repository.lockAttempt(tx, id);
    const equal = timingSafeEqual(
      Buffer.from(secretHash(token), "hex"),
      Buffer.from(attempt?.tokenHash ?? "0".repeat(64), "hex"),
    );
    if (
      !equal ||
      !attempt ||
      attempt.expiresAt.getTime() <= Date.now() ||
      attempt.stage !== stage
    )
      throw rejected();
    return attempt;
  }
  private key(encoded: string) {
    try {
      const bytes = Buffer.from(encoded, "base64");
      if (bytes.toString("base64") !== encoded) throw rejected();
      const key = createPublicKey({ key: bytes, format: "der", type: "spki" });
      if (
        key.asymmetricKeyType !== "ec" ||
        key.asymmetricKeyDetails?.namedCurve !== "prime256v1"
      )
        throw rejected();
      const canonical = key.export({ format: "der", type: "spki" });
      if (!canonical.equals(bytes)) throw rejected();
      return { key, encoded, hash: digest(bytes) };
    } catch {
      throw rejected();
    }
  }
  private async limit(id: string, operation: string) {
    const retry = await this.limits.consume(
      `biometric:${operation}:${id}`,
      5,
      600,
    );
    if (retry)
      throw new HttpException(
        {
          code: "RATE_LIMITED",
          message: "Too many biometric attempts. Start again later.",
        },
        429,
      );
  }
  async challenge(input: ChallengeDto, token?: string) {
    const context = await this.auth
      .context(input.attemptId, token)
      .catch((error: unknown) => {
        if (error instanceof UnauthorizedException) throw rejected();
        throw error;
      });
    if (
      context.stage !==
      (input.purpose === ChallengePurpose.ENROLMENT
        ? "PENDING_ENROLMENT"
        : "PENDING_BIOMETRIC")
    )
      throw rejected();
    await this.limit(input.attemptId, "issue");
    return this.repository.transaction(async (tx) => {
      const enrolment = input.purpose === ChallengePurpose.ENROLMENT;
      const attempt = await this.attempt(
        tx,
        input.attemptId,
        token,
        enrolment ? "PENDING_ENROLMENT" : "PENDING_BIOMETRIC",
      );
      await this.repository.lockUser(tx, attempt.userId);
      let publicKey: string;
      if (enrolment) {
        // A password login cannot mint an enrolment context or replace an existing key.
        if (
          await tx.biometricCredential.count({
            where: { userId: attempt.userId },
          })
        )
          throw rejected();
        if (
          await tx.biometricCredential.findUnique({
            where: { id: input.credentialId },
          })
        )
          throw rejected();
        publicKey = this.key(input.publicKey).encoded;
      } else {
        if (input.publicKey !== "") throw rejected();
        await tx.$queryRaw`SELECT "id" FROM "BiometricCredential" WHERE "id" = ${input.credentialId}::uuid FOR UPDATE`;
        const credential = await tx.biometricCredential.findUnique({
          where: { id: input.credentialId },
        });
        if (
          !credential ||
          credential.userId !== attempt.userId ||
          credential.revokedAt
        )
          throw rejected();
        publicKey = credential.publicKey;
      }
      const key = this.key(publicKey);
      const id = randomUUID();
      const expiresAt = new Date(
        Math.min(attempt.expiresAt.getTime(), Date.now() + 120000),
      );
      const payload = Buffer.from(
        JSON.stringify({
          protocol: "authvault.biometric.v1",
          challengeId: id,
          purpose: input.purpose,
          subjectId: attempt.userId,
          attemptId: attempt.id,
          credentialId: input.credentialId,
          publicKeyHash: key.hash,
          nonce: randomBytes(32).toString("base64url"),
          expiresAt: expiresAt.toISOString(),
        }),
        "utf8",
      ).toString("base64url");
      // Issuing a new challenge invalidates all earlier challenges for this attempt.
      await tx.biometricChallenge.updateMany({
        where: { attemptId: attempt.id, consumedAt: null },
        data: { consumedAt: new Date() },
      });
      await tx.biometricChallenge.create({
        data: {
          id,
          attemptId: attempt.id,
          purpose: input.purpose,
          credentialId: input.credentialId,
          registeredCredentialId: enrolment ? null : input.credentialId,
          publicKeyHash: key.hash,
          publicKey: enrolment ? publicKey : null,
          payload,
          expiresAt,
        },
      });
      return {
        challengeId: id,
        payload,
        purpose: input.purpose,
        credentialId: input.credentialId,
        subjectId: attempt.userId,
        attemptId: attempt.id,
        expiresAt: expiresAt.toISOString(),
        algorithm: "ES256_DER",
      };
    });
  }
  async prove(input: ProofDto, purpose: ChallengePurpose, token?: string) {
    const context = await this.auth
      .context(input.attemptId, token)
      .catch((error: unknown) => {
        if (error instanceof UnauthorizedException) throw rejected();
        throw error;
      });
    if (
      context.stage !==
      (purpose === ChallengePurpose.ENROLMENT
        ? "PENDING_ENROLMENT"
        : "PENDING_BIOMETRIC")
    )
      throw rejected();
    await this.limit(input.attemptId, "proof");
    // Attempt row lock serializes issuance, proof consumption and stage transition.
    return this.repository
      .transaction(async (tx) => {
        const enrolment = purpose === ChallengePurpose.ENROLMENT;
        const attempt = await this.attempt(
          tx,
          input.attemptId,
          token,
          enrolment ? "PENDING_ENROLMENT" : "PENDING_BIOMETRIC",
        );
        await this.repository.lockUser(tx, attempt.userId);
        const challenge = await tx.biometricChallenge.findUnique({
          where: { id: input.challengeId },
        });
        if (
          !challenge ||
          challenge.attemptId !== attempt.id ||
          challenge.purpose !== purpose ||
          challenge.credentialId !== input.credentialId ||
          challenge.consumedAt ||
          challenge.expiresAt.getTime() <= Date.now()
        )
          throw rejected();
        let publicKey: string;
        if (enrolment) {
          if (
            await tx.biometricCredential.count({
              where: { userId: attempt.userId },
            })
          )
            throw rejected();
          publicKey = challenge.publicKey!;
        } else {
          await tx.$queryRaw`SELECT "id" FROM "BiometricCredential" WHERE "id" = ${input.credentialId}::uuid FOR UPDATE`;
          const credential = await tx.biometricCredential.findUnique({
            where: { id: input.credentialId },
          });
          if (
            !credential ||
            credential.userId !== attempt.userId ||
            credential.revokedAt ||
            challenge.registeredCredentialId !== credential.id
          )
            throw rejected();
          publicKey = credential.publicKey;
        }
        const parsed = this.key(publicKey);
        if (parsed.hash !== challenge.publicKeyHash) throw rejected();
        try {
          const signature = Buffer.from(input.signature, "base64");
          if (
            signature.toString("base64") !== input.signature ||
            signature.length < 8 ||
            signature.length > 72 ||
            !verify(
              "sha256",
              Buffer.from(challenge.payload, "base64url"),
              parsed.key,
              signature,
            )
          )
            throw rejected();
        } catch {
          throw rejected();
        }
        const now = new Date();
        const consumed = await tx.biometricChallenge.updateMany({
          where: { id: challenge.id, consumedAt: null, expiresAt: { gt: now } },
          data: { consumedAt: now },
        });
        if (consumed.count !== 1) throw rejected();
        if (enrolment)
          await tx.biometricCredential.create({
            data: {
              id: input.credentialId,
              userId: attempt.userId,
              deviceId: input.credentialId,
              publicKey,
            },
          });
        const stage = enrolment ? "ENROLMENT_COMPLETE" : "PENDING_OTP";
        const moved = await tx.authAttempt.updateMany({
          where: {
            id: attempt.id,
            stage: attempt.stage,
            expiresAt: { gt: now },
          },
          data: { stage },
        });
        if (moved.count !== 1) throw rejected();
        await tx.auditEvent.create({
          data: {
            userId: attempt.userId,
            kind: enrolment ? "BIOMETRIC_ENROLLED" : "BIOMETRIC_VERIFIED",
          },
        });
        return {
          attemptId: attempt.id,
          subjectId: attempt.userId,
          credentialId: input.credentialId,
          stage,
          expiresAt: attempt.expiresAt.toISOString(),
        };
      })
      .catch(async (error: unknown) => {
        await this.repository.rejected(context.userId);
        throw error;
      });
  }
}

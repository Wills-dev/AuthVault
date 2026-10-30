import {
  HttpException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  createHmac,
  randomInt,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import { AuthService, secretHash } from "../auth/auth.service.js";
import { RateLimitService } from "../auth/rate-limit.service.js";
import { PrismaService } from "../prisma/prisma.service.js";
import type { Prisma } from "../generated/prisma/client.js";
import { SessionService } from "../session/session.service.js";
import { MailService } from "./mail.service.js";
import type { VerifyOtpDto } from "./otp.dto.js";
const fail = (code: string, message: string, status = 400) =>
  new HttpException({ code, message }, status);
@Injectable()
export class OtpService {
  constructor(
    private readonly db: PrismaService,
    private readonly auth: AuthService,
    private readonly limits: RateLimitService,
    private readonly config: ConfigService,
    private readonly mail: MailService,
    private readonly sessions: SessionService,
  ) {}
  private mac(
    id: string,
    user: string,
    attempt: string,
    device: string,
    code: string,
  ) {
    return createHmac(
      "sha256",
      Buffer.from(this.config.getOrThrow<string>("OTP_HMAC_KEY"), "hex"),
    )
      .update(JSON.stringify([id, user, attempt, device, code]))
      .digest("hex");
  }
  private async context(
    tx: Prisma.TransactionClient,
    id: string,
    token: string,
  ) {
    await tx.$queryRaw`SELECT id FROM "AuthAttempt" WHERE id = ${id}::uuid FOR UPDATE`;
    const attempt = await tx.authAttempt.findUnique({ where: { id } });
    if (
      !attempt ||
      attempt.stage !== "PENDING_OTP" ||
      attempt.expiresAt.getTime() <= Date.now() ||
      attempt.tokenHash !== secretHash(token) ||
      !attempt.verifiedCredentialId
    )
      throw new UnauthorizedException({
        code: "ATTEMPT_INVALID",
        message: "Please start a new sign-in.",
      });
    await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${attempt.userId}::uuid FOR UPDATE`;
    const user = await tx.user.findUniqueOrThrow({
      where: { id: attempt.userId },
    });
    await tx.$queryRaw`SELECT id FROM "BiometricCredential" WHERE id = ${attempt.verifiedCredentialId}::uuid FOR UPDATE`;
    const credential = await tx.biometricCredential.findUnique({
      where: { id: attempt.verifiedCredentialId },
    });
    if (!credential || credential.revokedAt || credential.userId !== user.id)
      throw new UnauthorizedException({
        code: "ATTEMPT_INVALID",
        message: "Please start a new sign-in.",
      });
    if (user.otpLockedUntil && user.otpLockedUntil.getTime() > Date.now())
      throw fail(
        "OTP_LOCKED",
        "Too many incorrect codes. Try signing in again in 15 minutes.",
        429,
      );
    return { attempt, user, device: credential.id };
  }
  async send(id: string, token: string | undefined) {
    const pending = await this.auth.context(id, token);
    if (pending.stage !== "PENDING_OTP")
      throw fail(
        "OTP_UNAVAILABLE",
        "Email verification is unavailable for this attempt.",
        403,
      );
    if (await this.limits.consume(`otp-send:${id}`, 6, 600))
      throw fail(
        "RATE_LIMITED",
        "Too many code requests. Please try later.",
        429,
      );
    return this.db.$transaction(
      async (tx) => {
        const { attempt, user, device } = await this.context(tx, id, token!);
        const previous = await tx.otpChallenge.findFirst({
          where: { attemptId: id },
          orderBy: { createdAt: "desc" },
        });
        if (previous && previous.resendAt.getTime() > Date.now())
          throw fail(
            "OTP_COOLDOWN",
            "Please wait before requesting another code.",
            429,
          );
        if ((await tx.otpChallenge.count({ where: { attemptId: id } })) >= 3)
          throw fail(
            "OTP_SEND_LIMIT",
            "Code request limit reached. Please start a new sign-in.",
            429,
          );
        const challengeId = randomUUID(),
          code = randomInt(0, 1_000_000).toString().padStart(6, "0");
        await this.mail.sendOtp(user.email, code);
        const now = new Date(),
          expiresAt = new Date(
            Math.min(now.getTime() + 300_000, attempt.expiresAt.getTime()),
          ),
          resendAt = new Date(
            now.getTime() +
              this.config.getOrThrow<number>("OTP_RESEND_SECONDS") * 1000,
          );
        await tx.otpChallenge.updateMany({
          where: { attemptId: id, invalidatedAt: null, consumedAt: null },
          data: { invalidatedAt: now },
        });
        await tx.otpChallenge.create({
          data: {
            id: challengeId,
            attemptId: id,
            codeMac: this.mac(challengeId, user.id, id, device, code),
            expiresAt,
            resendAt,
          },
        });
        await tx.auditEvent.create({
          data: { userId: user.id, kind: "OTP_SMTP_ACCEPTED" },
        });
        return {
          challengeId,
          expiresAt: expiresAt.toISOString(),
          resendAt: resendAt.toISOString(),
          delivery: "SMTP_ACCEPTED",
        };
      },
      { timeout: 20000, maxWait: 5000 },
    );
  }
  async verify(input: VerifyOtpDto, token: string | undefined) {
    const pending = await this.auth.context(input.attemptId, token);
    if (pending.stage !== "PENDING_OTP")
      throw fail(
        "OTP_UNAVAILABLE",
        "Email verification is unavailable for this attempt.",
        403,
      );
    if (await this.limits.consume(`otp-verify:${input.attemptId}`, 15, 600))
      throw fail(
        "RATE_LIMITED",
        "Too many verification requests. Please try later.",
        429,
      );
    const result = await this.db.$transaction(async (tx) => {
      const { attempt, user, device } = await this.context(
        tx,
        input.attemptId,
        token!,
      );
      const challenge = await tx.otpChallenge.findUnique({
        where: { id: input.challengeId },
      });
      if (
        !challenge ||
        challenge.attemptId !== attempt.id ||
        challenge.consumedAt ||
        challenge.invalidatedAt
      )
        return { error: "OTP_INVALID" } as const;
      if (challenge.expiresAt.getTime() <= Date.now())
        return { error: "OTP_EXPIRED" } as const;
      if (challenge.failures >= 5) return { error: "OTP_EXHAUSTED" } as const;
      if (
        !timingSafeEqual(
          Buffer.from(
            this.mac(challenge.id, user.id, attempt.id, device, input.code),
            "hex",
          ),
          Buffer.from(challenge.codeMac, "hex"),
        )
      ) {
        const exhausted = challenge.failures + 1 >= 5;
        await tx.otpChallenge.update({
          where: { id: challenge.id },
          data: { failures: { increment: 1 } },
        });
        if (exhausted)
          await tx.user.update({
            where: { id: user.id },
            data: { otpLockedUntil: new Date(Date.now() + 900_000) },
          });
        await tx.auditEvent.create({
          data: {
            userId: user.id,
            kind: exhausted ? "OTP_EXHAUSTED" : "OTP_REJECTED",
          },
        });
        return { error: exhausted ? "OTP_EXHAUSTED" : "OTP_INVALID" } as const;
      }
      await tx.otpChallenge.update({
        where: { id: challenge.id },
        data: { consumedAt: new Date() },
      });
      await tx.authAttempt.update({
        where: { id: attempt.id },
        data: { stage: "COMPLETED" },
      });
      const credentials = await this.sessions.create(
        tx,
        user.id,
        attempt.id,
        device,
      );
      await tx.auditEvent.create({
        data: { userId: user.id, kind: "MFA_COMPLETED" },
      });
      return { credentials };
    });
    if ("error" in result)
      throw fail(
        result.error!,
        result.error === "OTP_EXPIRED"
          ? "This code has expired. Request a new code."
          : result.error === "OTP_EXHAUSTED"
            ? "Too many incorrect codes. Try signing in again in 15 minutes."
            : "This code is invalid. Check the six digits and try again.",
      );
    return result.credentials;
  }
}

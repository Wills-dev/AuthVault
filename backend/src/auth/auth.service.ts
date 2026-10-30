import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { Prisma } from "../generated/prisma/client.js";
import { UsersRepository } from "../users/users.repository.js";
import { AuthRepository } from "./auth.repository.js";
import { PasswordService } from "./password.service.js";
import { RateLimitService } from "./rate-limit.service.js";
import type { LoginDto, RegisterDto } from "./auth.dto.js";

export const secretHash = (token: string) =>
  createHash("sha256").update(token).digest("hex");
@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersRepository,
    private readonly auth: AuthRepository,
    private readonly passwords: PasswordService,
    private readonly config: ConfigService,
    private readonly limits: RateLimitService,
  ) {}
  private pending() {
    return {
      token: randomBytes(32).toString("base64url"),
      expiresAt: new Date(
        Date.now() +
          this.config.getOrThrow<number>("PENDING_TTL_SECONDS") * 1000,
      ),
    };
  }
  private response(
    attempt: { id: string; userId: string; stage: string; expiresAt: Date },
    token: string,
  ) {
    return {
      subjectId: attempt.userId,
      attemptId: attempt.id,
      attemptToken: token,
      stage: attempt.stage,
      expiresAt: attempt.expiresAt.toISOString(),
    };
  }
  async register(input: RegisterDto) {
    // Hash even on conflicts. The unique database constraint decides concurrent registrations.
    const passwordHash = await this.passwords.hash(input.password);
    const pending = this.pending();
    try {
      const attempt = await this.auth.register(
        { email: input.email, fullName: input.fullName, passwordHash },
        secretHash(pending.token),
        pending.expiresAt,
      );
      return this.response(attempt, pending.token);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw new BadRequestException({
          code: "REGISTRATION_UNAVAILABLE",
          message: "Unable to create an account with these details.",
        });
      }
      throw error;
    }
  }
  async login(input: LoginDto) {
    const user = await this.users.findByEmail(input.email);
    if (!(await this.passwords.verify(user?.passwordHash, input.password))) {
      await this.auth.failed(this.limits.fingerprint(input.email));
      throw new UnauthorizedException({
        code: "INVALID_CREDENTIALS",
        message: "Email or password is incorrect.",
      });
    }
    const pending = this.pending();
    const attempt = await this.auth.login(
      user!.id,
      secretHash(pending.token),
      pending.expiresAt,
    );
    return this.response(attempt, pending.token);
  }
  async context(id: string, token: string | undefined) {
    if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token))
      throw this.invalidAttempt();
    const attempt = await this.auth.findAttempt(id);
    const supplied = Buffer.from(secretHash(token), "hex");
    const expected = Buffer.from(attempt?.tokenHash ?? "0".repeat(64), "hex");
    if (
      !timingSafeEqual(supplied, expected) ||
      !attempt ||
      attempt.expiresAt.getTime() <= Date.now() ||
      ![
        "PENDING_ENROLMENT",
        "ENROLMENT_COMPLETE",
        "PENDING_BIOMETRIC",
        "PENDING_OTP",
      ].includes(attempt.stage)
    )
      throw this.invalidAttempt();
    return attempt;
  }
  async status(id: string, token: string | undefined) {
    const attempt = await this.context(id, token);
    return {
      subjectId: attempt.userId,
      attemptId: attempt.id,
      stage: attempt.stage,
      expiresAt: attempt.expiresAt.toISOString(),
    };
  }
  async revoke(id: string, token: string | undefined) {
    await this.status(id, token);
    await this.auth.revoke(id);
  }
  private invalidAttempt() {
    return new UnauthorizedException({
      code: "ATTEMPT_INVALID",
      message:
        "This authentication attempt is unavailable or expired. Start again.",
    });
  }
}

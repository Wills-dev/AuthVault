import {
  CanActivate,
  ExecutionContext,
  HttpException,
  Injectable,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createHmac } from "node:crypto";
import type { Request, Response } from "express";
import { PrismaService } from "../prisma/prisma.service.js";
@Injectable()
export class RateLimitService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}
  fingerprint(value: string) {
    return createHmac(
      "sha256",
      this.config.getOrThrow<string>("AUDIT_HMAC_KEY"),
    )
      .update(value)
      .digest("hex");
  }
  async consume(subject: string, limit: number, seconds: number) {
    const now = Date.now();
    const bucket = Math.floor(now / (seconds * 1000));
    const key = this.fingerprint(`${subject}:${bucket}`);
    const expiresAt = new Date((bucket + 1) * seconds * 1000);
    const result = await this.prisma.$queryRaw<{ count: number }[]>`
      INSERT INTO "RateLimit" ("key", "count", "expiresAt") VALUES (${key}, 1, ${expiresAt})
      ON CONFLICT ("key") DO UPDATE SET "count" = "RateLimit"."count" + 1 RETURNING "count"`;
    if (result[0].count > limit)
      return Math.max(1, Math.ceil((expiresAt.getTime() - now) / 1000));
    return 0;
  }
}
@Injectable()
export class AuthRateLimitGuard implements CanActivate {
  constructor(private readonly limits: RateLimitService) {}
  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<Request>();
    const response = context.switchToHttp().getResponse<Response>();
    let retry = await this.limits.consume(`ip:${request.ip}`, 30, 60);
    const body = request.body as Record<string, unknown> | undefined;
    if (!retry && typeof body?.email === "string") {
      retry = Math.max(
        retry,
        await this.limits.consume(
          `account:${body.email.slice(0, 254).trim().toLowerCase()}`,
          10,
          900,
        ),
      );
    }
    if (retry) {
      response.setHeader("Retry-After", retry);
      throw new HttpException(
        {
          code: "RATE_LIMITED",
          message: "Too many attempts. Please try again later.",
        },
        429,
      );
    }
    return true;
  }
}

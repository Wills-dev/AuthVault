import { Controller, Get, Req, UseGuards } from "@nestjs/common";
import {
  SessionGuard,
  type AuthorizedRequest,
} from "../session/session.module.js";
import { PrismaService } from "../prisma/prisma.service.js";
@Controller("users")
@UseGuards(SessionGuard)
export class UsersController {
  constructor(private readonly db: PrismaService) {}
  @Get("me") me(@Req() request: AuthorizedRequest) {
    return this.db.user.findUniqueOrThrow({
      where: { id: request.subjectId },
      select: { id: true, email: true, fullName: true, createdAt: true },
    });
  }
  @Get("me/security") async security(@Req() request: AuthorizedRequest) {
    const [lastAuthentication, biometricCredentials, activeSessions] =
      await Promise.all([
        this.db.auditEvent.findFirst({
          where: { userId: request.subjectId, kind: "MFA_COMPLETED" },
          orderBy: { createdAt: "desc" },
          select: { createdAt: true },
        }),
        this.db.biometricCredential.count({
          where: { userId: request.subjectId, revokedAt: null },
        }),
        this.db.authSession.count({
          where: {
            userId: request.subjectId,
            revokedAt: null,
            expiresAt: { gt: new Date() },
          },
        }),
      ]);
    return {
      lastAuthentication: lastAuthentication?.createdAt ?? null,
      biometricCredentials,
      activeSessions,
      authenticationMethods: [
        "Password",
        "Device biometric signature",
        "Email OTP",
      ],
    };
  }
}

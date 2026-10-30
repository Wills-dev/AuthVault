import { Injectable } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service.js";
import { MfaStage } from "../generated/prisma/enums.js";
@Injectable()
export class AuthRepository {
  constructor(private readonly prisma: PrismaService) {}
  async register(
    data: { email: string; fullName: string; passwordHash: string },
    tokenHash: string,
    expiresAt: Date,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({ data });
      const attempt = await tx.authAttempt.create({
        data: {
          userId: user.id,
          tokenHash,
          expiresAt,
          stage: MfaStage.PENDING_ENROLMENT,
        },
      });
      await tx.auditEvent.create({
        data: { userId: user.id, kind: "REGISTRATION_CREATED" },
      });
      return attempt;
    });
  }
  async login(userId: string, tokenHash: string, expiresAt: Date) {
    return this.prisma.$transaction(async (tx) => {
      const attempt = await tx.authAttempt.create({
        data: {
          userId,
          tokenHash,
          expiresAt,
          stage: MfaStage.PENDING_BIOMETRIC,
        },
      });
      await tx.auditEvent.create({
        data: { userId, kind: "PASSWORD_ACCEPTED" },
      });
      return attempt;
    });
  }
  failed(subjectHash: string) {
    return this.prisma.auditEvent.create({
      data: { kind: "PASSWORD_REJECTED", subjectHash },
    });
  }
  findAttempt(id: string) {
    return this.prisma.authAttempt.findUnique({ where: { id } });
  }
  revoke(id: string) {
    return this.prisma.authAttempt.updateMany({
      where: {
        id,
        stage: { in: [MfaStage.PENDING_ENROLMENT, MfaStage.PENDING_BIOMETRIC] },
      },
      data: { stage: MfaStage.REVOKED },
    });
  }
}

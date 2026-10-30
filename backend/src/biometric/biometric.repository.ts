import { Injectable } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service.js";
import { Prisma } from "../generated/prisma/client.js";
@Injectable()
export class BiometricRepository {
  constructor(private readonly prisma: PrismaService) {}
  transaction<T>(work: (tx: Prisma.TransactionClient) => Promise<T>) {
    return this.prisma.$transaction(work, { timeout: 10000 });
  }
  rejected(userId: string) {
    return this.prisma.auditEvent.create({
      data: { userId, kind: "BIOMETRIC_PROOF_REJECTED" },
    });
  }
  async lockAttempt(tx: Prisma.TransactionClient, id: string) {
    await tx.$queryRaw`SELECT "id" FROM "AuthAttempt" WHERE "id" = ${id}::uuid FOR UPDATE`;
    return tx.authAttempt.findUnique({ where: { id } });
  }
  async lockUser(tx: Prisma.TransactionClient, id: string) {
    await tx.$queryRaw`SELECT "id" FROM "User" WHERE "id" = ${id}::uuid FOR UPDATE`;
  }
}

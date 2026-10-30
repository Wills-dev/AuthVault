import { Controller, Get, Module } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service.js";
@Controller("health")
class HealthController {
  constructor(private readonly prisma: PrismaService) {}
  @Get("live") live() {
    return { status: "ok" };
  }
  @Get("ready") async ready() {
    await this.prisma.$queryRaw`SELECT 1`;
    return { status: "ok", database: "reachable" };
  }
}
@Module({ controllers: [HealthController] })
export class HealthModule {}

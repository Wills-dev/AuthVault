import { Module } from "@nestjs/common";
import { UsersController } from "./users.controller.js";
import { UsersRepository } from "./users.repository.js";
import { PendingOnlyGuard } from "./pending-only.guard.js";
@Module({
  controllers: [UsersController],
  providers: [UsersRepository, PendingOnlyGuard],
  exports: [UsersRepository],
})
export class UsersModule {}

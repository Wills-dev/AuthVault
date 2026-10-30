import { Module } from "@nestjs/common";
import { UsersController } from "./users.controller.js";
import { UsersRepository } from "./users.repository.js";
import { SessionModule } from "../session/session.module.js";
@Module({
  imports: [SessionModule],
  controllers: [UsersController],
  providers: [UsersRepository],
  exports: [UsersRepository],
})
export class UsersModule {}

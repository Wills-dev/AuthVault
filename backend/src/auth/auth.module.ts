import { Module } from "@nestjs/common";
import { UsersModule } from "../users/users.module.js";
import { AuthController } from "./auth.controller.js";
import { AuthService } from "./auth.service.js";
import { AuthRepository } from "./auth.repository.js";
import { PasswordService } from "./password.service.js";
import { AuthRateLimitGuard, RateLimitService } from "./rate-limit.service.js";
@Module({
  imports: [UsersModule],
  controllers: [AuthController],
  exports: [AuthService, AuthRateLimitGuard, RateLimitService],
  providers: [
    AuthService,
    AuthRepository,
    PasswordService,
    AuthRateLimitGuard,
    RateLimitService,
  ],
})
export class AuthModule {}

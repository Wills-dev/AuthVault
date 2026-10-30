import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { BiometricController } from "./biometric.controller.js";
import { BiometricService } from "./biometric.service.js";
import { BiometricRepository } from "./biometric.repository.js";
@Module({
  imports: [AuthModule],
  controllers: [BiometricController],
  providers: [BiometricService, BiometricRepository],
})
export class BiometricModule {}

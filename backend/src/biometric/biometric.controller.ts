import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Post,
  UseGuards,
} from "@nestjs/common";
import { AuthRateLimitGuard } from "../auth/rate-limit.service.js";
import { BiometricService } from "./biometric.service.js";
import { ChallengeDto, ChallengePurpose, ProofDto } from "./biometric.dto.js";
@Controller("biometric")
@UseGuards(AuthRateLimitGuard)
export class BiometricController {
  constructor(private readonly biometrics: BiometricService) {}
  @Post("challenge") @HttpCode(200) challenge(
    @Body() body: ChallengeDto,
    @Headers("x-mfa-token") token?: string,
  ) {
    return this.biometrics.challenge(body, token);
  }
  @Post("enrol") @HttpCode(200) enrol(
    @Body() body: ProofDto,
    @Headers("x-mfa-token") token?: string,
  ) {
    return this.biometrics.prove(body, ChallengePurpose.ENROLMENT, token);
  }
  @Post("verify") @HttpCode(200) verify(
    @Body() body: ProofDto,
    @Headers("x-mfa-token") token?: string,
  ) {
    return this.biometrics.prove(body, ChallengePurpose.LOGIN, token);
  }
}

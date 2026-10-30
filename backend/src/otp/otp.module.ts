import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Module,
  Post,
  UseGuards,
} from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { AuthRateLimitGuard } from "../auth/rate-limit.service.js";
import { SessionModule } from "../session/session.module.js";
import { MailService } from "./mail.service.js";
import { OtpService } from "./otp.service.js";
import { SendOtpDto, VerifyOtpDto } from "./otp.dto.js";
@Controller("otp")
@UseGuards(AuthRateLimitGuard)
export class OtpController {
  constructor(private readonly otp: OtpService) {}
  @Post("send") @HttpCode(200) send(
    @Body() input: SendOtpDto,
    @Headers("x-mfa-token") token?: string,
  ) {
    return this.otp.send(input.attemptId, token);
  }
  @Post("verify") @HttpCode(200) verify(
    @Body() input: VerifyOtpDto,
    @Headers("x-mfa-token") token?: string,
  ) {
    return this.otp.verify(input, token);
  }
}
@Module({
  imports: [AuthModule, SessionModule],
  controllers: [OtpController],
  providers: [OtpService, MailService],
})
export class OtpModule {}

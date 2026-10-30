import { IsString, IsUUID, Matches } from "class-validator";
export class SendOtpDto {
  @IsUUID("4") attemptId!: string;
}
export class VerifyOtpDto extends SendOtpDto {
  @IsUUID("4") challengeId!: string;
  @IsString() @Matches(/^\d{6}$/) code!: string;
}

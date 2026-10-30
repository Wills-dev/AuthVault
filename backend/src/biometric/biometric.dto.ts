import { IsUUID, IsString, Matches, MaxLength, IsEnum } from "class-validator";
export enum ChallengePurpose {
  ENROLMENT = "ENROLMENT",
  LOGIN = "LOGIN",
}
export class ChallengeDto {
  @IsUUID("4") attemptId!: string;
  @IsUUID("4") credentialId!: string;
  @IsEnum(ChallengePurpose) purpose!: ChallengePurpose;
  // Enrolment-only field. Login rejects a supplied public key in service logic.
  @IsString()
  @MaxLength(256)
  @Matches(/^[A-Za-z0-9+/]*={0,2}$/)
  publicKey!: string;
}
export class ProofDto {
  @IsUUID("4") attemptId!: string;
  @IsUUID("4") credentialId!: string;
  @IsUUID("4") challengeId!: string;
  @IsString()
  @MaxLength(128)
  @Matches(/^[A-Za-z0-9+/]+={0,2}$/)
  signature!: string;
}

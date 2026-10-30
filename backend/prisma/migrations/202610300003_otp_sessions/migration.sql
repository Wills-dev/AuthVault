-- AlterTable
ALTER TABLE "User" ADD COLUMN     "otpLockedUntil" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "AuthAttempt" ADD COLUMN     "verifiedCredentialId" UUID;

-- AlterTable
ALTER TABLE "OtpChallenge" ADD COLUMN     "invalidatedAt" TIMESTAMP(3),
ADD COLUMN     "resendAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- AlterTable
ALTER TABLE "AuthSession" ADD COLUMN     "attemptId" UUID,
ADD COLUMN     "credentialId" UUID;

-- CreateIndex
CREATE UNIQUE INDEX "AuthSession_attemptId_key" ON "AuthSession"("attemptId");

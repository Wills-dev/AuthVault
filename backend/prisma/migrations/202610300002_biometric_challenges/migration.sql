-- CreateEnum
CREATE TYPE "BiometricPurpose" AS ENUM ('ENROLMENT', 'LOGIN');

-- AlterEnum
ALTER TYPE "MfaStage" ADD VALUE 'ENROLMENT_COMPLETE';

-- CreateTable
CREATE TABLE "BiometricChallenge" (
    "id" UUID NOT NULL,
    "attemptId" UUID NOT NULL,
    "purpose" "BiometricPurpose" NOT NULL,
    "credentialId" UUID NOT NULL,
    "registeredCredentialId" UUID,
    "publicKeyHash" CHAR(64) NOT NULL,
    "publicKey" TEXT,
    "payload" VARCHAR(2048) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BiometricChallenge_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "BiometricChallenge_attemptId_purpose_createdAt_idx" ON "BiometricChallenge"("attemptId", "purpose", "createdAt");

-- CreateIndex
CREATE INDEX "BiometricChallenge_expiresAt_idx" ON "BiometricChallenge"("expiresAt");

-- AddForeignKey
ALTER TABLE "BiometricChallenge" ADD CONSTRAINT "BiometricChallenge_attemptId_fkey" FOREIGN KEY ("attemptId") REFERENCES "AuthAttempt"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BiometricChallenge" ADD CONSTRAINT "BiometricChallenge_registeredCredentialId_fkey" FOREIGN KEY ("registeredCredentialId") REFERENCES "BiometricCredential"("id") ON DELETE CASCADE ON UPDATE CASCADE;


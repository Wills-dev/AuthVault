import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import nodemailer from "nodemailer";
@Injectable()
export class MailService {
  constructor(private readonly config: ConfigService) {}
  async sendOtp(to: string, code: string) {
    const c = this.config;
    const transport = nodemailer.createTransport({
      host: c.getOrThrow<string>("SMTP_HOST"),
      port: c.getOrThrow<number>("SMTP_PORT"),
      secure: c.get<boolean>("SMTP_SECURE"),
      requireTLS: c.get<string>("NODE_ENV") === "production",
      auth: c.get<string>("SMTP_USER")
        ? {
            user: c.getOrThrow<string>("SMTP_USER"),
            pass: c.getOrThrow<string>("SMTP_PASSWORD"),
          }
        : undefined,
      connectionTimeout: 5000,
      greetingTimeout: 5000,
      socketTimeout: 5000,
      logger: false,
      debug: false,
    });
    try {
      const result = await transport.sendMail({
        from: c.getOrThrow<string>("SMTP_FROM"),
        to,
        subject: "Your AuthVault sign-in code",
        text: `AuthVault\nYour sign-in code: ${code}\nValid for five minutes and one use. Never share this code. If you did not request this sign-in, do not enter or share it.`,
        html: `<div style="font-family:Arial;color:#122039;max-width:480px;margin:auto;padding:32px"><h2>AuthVault</h2><h1>Confirm your sign-in</h1><p>Use this code to finish signing in securely.</p><p style="font-size:32px;letter-spacing:8px;font-weight:bold">${code}</p><p>Valid for <strong>five minutes</strong> and one use.</p><hr><p>Never share this code. If you did not request this sign-in, do not enter or share it.</p></div>`,
      });
      if (
        !result.accepted.some(
          (a) => String(a).toLowerCase() === to.toLowerCase(),
        ) ||
        result.rejected.length
      )
        throw new Error();
    } catch {
      throw new ServiceUnavailableException({
        code: "EMAIL_UNAVAILABLE",
        message:
          "The email provider could not accept your code. Please try again.",
      });
    } finally {
      transport.close();
    }
  }
}

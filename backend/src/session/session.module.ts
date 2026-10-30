import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Module,
} from "@nestjs/common";
import type { Request } from "express";
import { SessionService, invalidSession } from "./session.service.js";
export type AuthorizedRequest = Request & { subjectId: string };
@Injectable()
export class SessionGuard implements CanActivate {
  constructor(private readonly sessions: SessionService) {}
  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<AuthorizedRequest>();
    const bearer = request.headers.authorization?.match(
      /^Bearer ([A-Za-z0-9_.-]+)$/,
    )?.[1];
    if (!bearer) throw invalidSession();
    request.subjectId = (await this.sessions.authorize(bearer)).userId;
    return true;
  }
}
@Module({
  providers: [SessionService, SessionGuard],
  exports: [SessionService, SessionGuard],
})
export class SessionModule {}

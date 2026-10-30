import { CanActivate, ForbiddenException, Injectable } from "@nestjs/common";

/** There is intentionally no completed-session authentication mechanism yet. */
@Injectable()
export class PendingOnlyGuard implements CanActivate {
  canActivate(): never {
    throw new ForbiddenException({
      code: "MFA_REQUIRED",
      message: "Complete all authentication steps to access this resource.",
    });
  }
}

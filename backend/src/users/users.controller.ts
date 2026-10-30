import { Controller, Get, UseGuards } from "@nestjs/common";
import { PendingOnlyGuard } from "./pending-only.guard.js";
@Controller("users")
@UseGuards(PendingOnlyGuard)
export class UsersController {
  @Get("me") me(): never {
    throw new Error(
      "Unreachable until completed-session authentication exists",
    );
  }
  @Get("me/security") security(): never {
    throw new Error(
      "Unreachable until completed-session authentication exists",
    );
  }
}

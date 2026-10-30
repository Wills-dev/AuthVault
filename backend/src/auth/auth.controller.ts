import { SessionService } from "../session/session.service.js";
import { RefreshDto } from "../session/session.dto.js";
import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from "@nestjs/common";
import { AuthService } from "./auth.service.js";
import { LoginDto, RegisterDto } from "./auth.dto.js";
import { AuthRateLimitGuard } from "./rate-limit.service.js";
@Controller("auth")
@UseGuards(AuthRateLimitGuard)
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly sessions: SessionService,
  ) {}
  @Post("refresh") @HttpCode(200) refresh(@Body() input: RefreshDto) {
    return this.sessions.refresh(input.refreshToken);
  }
  @Post("logout") @HttpCode(204) logout(@Body() input: RefreshDto) {
    return this.sessions.logout(input.refreshToken);
  }
  @Post("register") register(@Body() input: RegisterDto) {
    return this.auth.register(input);
  }
  @Post("login") @HttpCode(200) login(@Body() input: LoginDto) {
    return this.auth.login(input);
  }
  @Get("pending/:id") status(
    @Param("id", new ParseUUIDPipe()) id: string,
    @Headers("x-mfa-token") token?: string,
  ) {
    return this.auth.status(id, token);
  }
  @Delete("pending/:id") @HttpCode(204) revoke(
    @Param("id", new ParseUUIDPipe()) id: string,
    @Headers("x-mfa-token") token?: string,
  ) {
    return this.auth.revoke(id, token);
  }
}

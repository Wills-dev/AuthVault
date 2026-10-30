import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  Logger,
} from "@nestjs/common";
import type { Request, Response } from "express";
import { Prisma } from "../generated/prisma/client.js";
@Catch()
export class ApiErrorFilter implements ExceptionFilter {
  private readonly logger = new Logger("ApiError");
  catch(error: unknown, host: ArgumentsHost) {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<Request>();
    const requestId = response.getHeader("X-Request-Id");
    let status = 500;
    let code = "INTERNAL_ERROR";
    let message = "The request could not be completed.";
    const parserStatus =
      typeof error === "object" && error !== null && "status" in error
        ? error.status
        : null;
    if (
      parserStatus === 413 ||
      (parserStatus === 400 && error instanceof SyntaxError)
    ) {
      status = parserStatus;
      code = status === 413 ? "PAYLOAD_TOO_LARGE" : "VALIDATION_ERROR";
      message =
        status === 413
          ? "Request payload is too large."
          : "Request body must be valid JSON.";
    } else if (error instanceof HttpException) {
      status = error.getStatus();
      const detail = error.getResponse();
      const safe =
        typeof detail === "object"
          ? (detail as { code?: string; message?: unknown })
          : {};
      code =
        safe.code ??
        (status === 413
          ? "PAYLOAD_TOO_LARGE"
          : status === 400
            ? "VALIDATION_ERROR"
            : status === 404
              ? "NOT_FOUND"
              : "REQUEST_REJECTED");
      message =
        typeof safe.message === "string" && safe.code
          ? safe.message
          : status === 400
            ? "Check the submitted fields and try again."
            : "The request could not be completed.";
    } else if (
      error instanceof Prisma.PrismaClientKnownRequestError ||
      error instanceof Prisma.PrismaClientInitializationError ||
      (error instanceof Error &&
        /ECONNREFUSED|connection|timeout/i.test(error.message))
    ) {
      status = 503;
      code = "SERVICE_UNAVAILABLE";
      message = "The service is temporarily unavailable. Try again later.";
    }
    if (status >= 500)
      this.logger.error({
        event: "request_failed",
        requestId,
        status,
        method: request.method,
      });
    response.status(status).json({ error: { code, message, requestId } });
  }
}

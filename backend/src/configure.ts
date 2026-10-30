import { ValidationPipe, type INestApplication } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import express from "express";
import helmet from "helmet";
import type { NextFunction, Request, Response } from "express";
import { ApiErrorFilter } from "./common/api-error.filter.js";
export function configure(app: INestApplication) {
  app.use((_request: Request, response: Response, next: NextFunction) => {
    response.setHeader("X-Request-Id", randomUUID());
    response.setHeader("Cache-Control", "no-store");
    next();
  });
  app.use(helmet());
  app.use(express.json({ limit: "8kb" }));
  app.setGlobalPrefix("v1");
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
      validationError: { target: false, value: false },
    }),
  );
  app.useGlobalFilters(new ApiErrorFilter());
  app.enableShutdownHooks();
}

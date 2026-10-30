import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { AppModule } from "./app.module.js";
import { configure } from "./configure.js";
async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bodyParser: false });
  configure(app);
  const config = app.get(ConfigService);
  await app.listen(
    config.getOrThrow<number>("PORT"),
    config.getOrThrow<string>("HOST"),
  );
}
bootstrap().catch(() => {
  console.error(
    "Backend startup failed. Check configuration and database availability.",
  );
  process.exitCode = 1;
});

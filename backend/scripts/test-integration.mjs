import "dotenv/config";
import { spawnSync } from "node:child_process";
const url = process.env.TEST_DATABASE_URL;
if (!url || !new URL(url).pathname.endsWith("/authvault_test"))
  throw new Error(
    "TEST_DATABASE_URL must target the isolated authvault_test database.",
  );
const env = {
  ...process.env,
  DATABASE_URL: url,
  NODE_ENV: "test",
  RUN_DB_TESTS: "1",
  NODE_OPTIONS: "--experimental-vm-modules",
};
for (const args of [
  ["prisma", "migrate", "deploy"],
  ["jest", "--runInBand", "--testPathPatterns=integration"],
]) {
  const result = spawnSync("npx", args, { env, stdio: "inherit" });
  if (result.status !== 0) process.exit(result.status ?? 1);
}

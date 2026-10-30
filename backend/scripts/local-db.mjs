// Dedicated loopback-only development cluster. No system service changes.
import { randomBytes } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  unlinkSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import pg from "pg";
const bin = process.env.POSTGRES_BIN ?? "/opt/homebrew/opt/postgresql@17/bin";
const local = resolve(".local");
const data = resolve(".local/postgres");
const run = (name, args) => {
  const result = spawnSync(`${bin}/${name}`, args, { encoding: "utf8" });
  if (result.status !== 0)
    throw new Error(
      `${name} failed. Check PostgreSQL installation and .local/postgres.log.`,
    );
};
if (!existsSync(`${bin}/initdb`))
  throw new Error(
    "PostgreSQL missing. Run: brew install postgresql@17 (or set POSTGRES_BIN).",
  );
mkdirSync(local, { recursive: true, mode: 0o700 });
if (!existsSync(".env")) {
  const password = randomBytes(32).toString("hex");
  const url = `postgresql://authvault:${password}@127.0.0.1:55432/authvault`;
  writeFileSync(
    ".env",
    `NODE_ENV=development\nHOST=127.0.0.1\nPORT=3000\nDATABASE_URL=${url}\nTEST_DATABASE_URL=${url}_test\nAUDIT_HMAC_KEY=${randomBytes(32).toString("hex")}\nPENDING_TTL_SECONDS=600\n`,
    { mode: 0o600 },
  );
}
const env = Object.fromEntries(
  readFileSync(".env", "utf8")
    .trim()
    .split("\n")
    .map((line) => {
      const split = line.indexOf("=");
      return [line.slice(0, split), line.slice(split + 1)];
    }),
);
const url = new URL(env.DATABASE_URL);
if (
  url.hostname !== "127.0.0.1" ||
  url.port !== "55432" ||
  url.username !== "authvault" ||
  url.pathname !== "/authvault"
)
  throw new Error(
    "Existing .env is not the dedicated local cluster configuration. Start your configured database manually.",
  );
const adminFile = resolve(".local/admin-password");
if (!existsSync(adminFile))
  writeFileSync(adminFile, randomBytes(32).toString("hex"), { mode: 0o600 });
const adminPassword = readFileSync(adminFile, "utf8");
if (!existsSync(`${data}/PG_VERSION`)) {
  const pwfile = resolve(".local/init-password");
  writeFileSync(pwfile, `${adminPassword}\n`, { mode: 0o600 });
  try {
    run("initdb", [
      "-D",
      data,
      "--username=authvault_admin",
      "--auth=scram-sha-256",
      `--pwfile=${pwfile}`,
      "--encoding=UTF8",
      "--locale=C",
    ]);
  } finally {
    unlinkSync(pwfile);
  }
}
if (spawnSync(`${bin}/pg_ctl`, ["-D", data, "status"]).status !== 0)
  run("pg_ctl", [
    "-D",
    data,
    "-l",
    resolve(".local/postgres.log"),
    "-o",
    "-p 55432 -h 127.0.0.1 -k /tmp",
    "-w",
    "start",
  ]);
const admin = new pg.Client({
  host: "127.0.0.1",
  port: 55432,
  user: "authvault_admin",
  password: adminPassword,
  database: "postgres",
});
await admin.connect();
try {
  const role = await admin.query(
    "SELECT 1 FROM pg_roles WHERE rolname = 'authvault'",
  );
  if (!role.rowCount) {
    const password = decodeURIComponent(url.password);
    if (!/^[a-f0-9]{64}$/.test(password))
      throw new Error("Local bootstrap requires a generated hex password.");
    await admin.query(
      `CREATE ROLE authvault LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD '${password}'`,
    );
  }
  for (const name of ["authvault", "authvault_test"]) {
    const database = await admin.query(
      "SELECT 1 FROM pg_database WHERE datname = $1",
      [name],
    );
    if (!database.rowCount)
      await admin.query(`CREATE DATABASE ${name} OWNER authvault`);
  }
} finally {
  await admin.end();
}
console.log(
  "PostgreSQL ready on 127.0.0.1:55432; application/test databases use a non-superuser role.",
);

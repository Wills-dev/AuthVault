// Run from backend after coverage tests; emits non-secret measured evidence.
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from "node:fs";
const read = (p) => JSON.parse(readFileSync(p, "utf8"));
const destination = "../docs/evidence/phase-6";
mkdirSync(destination, { recursive: true });
const write = (name, data) =>
  writeFileSync(
    `${destination}/${name}.json`,
    JSON.stringify(data, null, 2) + "\n",
  );
const backend = read("coverage/coverage-summary.json"),
  backendModules = {};
for (const [file, data] of Object.entries(backend)) {
  if (file === "total") continue;
  const part = file.replaceAll("\\", "/").split("/src/").at(-1).split("/")[0],
    name = part.endsWith(".ts") ? "bootstrap/configure" : part;
  const group = (backendModules[name] ??= {
    lines: { total: 0, covered: 0 },
    branches: { total: 0, covered: 0 },
  });
  for (const metric of ["lines", "branches"])
    for (const field of ["total", "covered"])
      group[metric][field] += data[metric][field];
}
for (const group of Object.values(backendModules))
  for (const value of Object.values(group))
    value.percent = value.total
      ? Number(((100 * value.covered) / value.total).toFixed(2))
      : null;
const flutterFiles = {};
let source;
for (const line of readFileSync("../coverage/lcov.info", "utf8").split("\n")) {
  if (line.startsWith("SF:")) source = line.slice(3).replaceAll("\\", "/");
  if (source && line.startsWith("DA:")) {
    const value = (flutterFiles[source] ??= { total: 0, covered: 0 });
    value.total++;
    if (Number(line.split(",")[1]) > 0) value.covered++;
  }
}
const flutterModules = {},
  flutterTotal = { total: 0, covered: 0 };
for (const [file, value] of Object.entries(flutterFiles)) {
  const name = file
      .split("/")
      .slice(0, file.startsWith("lib/features/") ? 3 : 2)
      .join("/"),
    group = (flutterModules[name] ??= { total: 0, covered: 0 });
  for (const field of ["total", "covered"]) {
    group[field] += value[field];
    flutterTotal[field] += value[field];
  }
}
for (const value of Object.values(flutterModules))
  value.percent = Number(((100 * value.covered) / value.total).toFixed(2));
const sources = readdirSync("../lib", { recursive: true })
  .filter((n) => n.endsWith(".dart"))
  .map((n) => `lib/${n.replaceAll("\\", "/")}`);
write("coverage-summary", {
  backendTotal: backend.total,
  backendModules,
  flutterModules,
  flutterTotal,
  unreportedFlutterSources: sources.filter((p) => !flutterFiles[p]),
  flutterBranches: "not collected by flutter test --coverage",
  exclusions:
    "Backend generated Prisma and main.ts; Flutter reported libraries only; Kotlin uninstrumented",
});
const measured = read(".test-results/phase-6-performance.json");
write("performance", measured);
const summary = {};
for (const name of Object.keys(measured.samples[0])) {
  const values = measured.samples.map((s) => s[name]).sort((a, b) => a - b),
    n = values.length,
    round = (v) => Number(v.toFixed(2));
  summary[name] = {
    n,
    min: round(values[0]),
    median: round(
      n % 2
        ? values[Math.floor(n / 2)]
        : (values[n / 2 - 1] + values[n / 2]) / 2,
    ),
    max: round(values.at(-1)),
    p95NearestRank: round(values[Math.ceil(0.95 * n) - 1]),
  };
}
write("performance-summary", summary);
console.log("Wrote non-secret measured coverage/performance summaries.");

// Sends only public hosted package names/versions to OSV. Run from backend.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
const packages = [];
let current;
for (const line of readFileSync("../pubspec.lock", "utf8").split("\n")) {
  const name = line.match(/^  ([a-zA-Z0-9_]+):$/);
  if (name) {
    if (current?.source === "hosted") packages.push(current);
    current = { name: name[1] };
  }
  const field = line.match(/^    (source|version):\s*"?([^"\n]+)"?\s*$/);
  if (current && field) current[field[1]] = field[2].trim();
}
if (current?.source === "hosted") packages.push(current);
const response = await fetch("https://api.osv.dev/v1/querybatch", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    queries: packages.map((p) => ({
      package: { name: p.name, ecosystem: "Pub" },
      version: p.version,
    })),
  }),
  signal: AbortSignal.timeout(30000),
});
if (!response.ok)
  throw new Error("OSV unavailable; no successful audit claimed.");
const data = await response.json();
if (data.results?.length !== packages.length)
  throw new Error("Incomplete OSV response; no successful audit claimed.");
const results = packages.map((p, i) => ({
  ...p,
  advisories: (data.results[i].vulns ?? []).map((v) => v.id),
}));
mkdirSync("../docs/evidence/phase-6", { recursive: true });
writeFileSync(
  "../docs/evidence/phase-6/pub-audit.json",
  JSON.stringify(
    { source: "OSV querybatch", ecosystem: "Pub", results },
    null,
    2,
  ) + "\n",
);
const affected = results.filter((p) => p.advisories.length);
console.log(
  JSON.stringify({
    packagesQueried: results.length,
    packagesWithAdvisories: affected,
  }),
);
if (affected.length) process.exitCode = 1;

// Local test tooling only. Never imported by the production application.
import { SMTPServer } from "smtp-server";
import { createServer } from "node:http";
const messages = [];
new SMTPServer({
  authOptional: true,
  disabledCommands: ["AUTH", "STARTTLS"],
  logger: false,
  size: 32768,
  onData(stream, session, callback) {
    let raw = "";
    stream.on("data", (part) => {
      raw += part.toString();
    });
    stream.on("end", () => {
      if (raw.length > 32768) return callback(new Error("Message too large"));
      messages.push({
        to: session.envelope.rcptTo.map((r) => r.address),
        raw,
        receivedAt: Date.now(),
      });
      while (messages.length > 50) messages.shift();
      callback();
    });
  },
}).listen(1025, "127.0.0.1");
createServer((req, res) => {
  if (req.method !== "GET" || req.url !== "/messages") {
    res.writeHead(404);
    res.end();
    return;
  }
  res.setHeader("Content-Type", "application/json");
  res.setHeader("Cache-Control", "no-store");
  res.end(
    JSON.stringify(messages.filter((m) => m.receivedAt > Date.now() - 600000)),
  );
}).listen(8025, "127.0.0.1");
process.stdout.write(
  "Development mailbox listening on loopback SMTP 1025 and HTTP 8025. Message contents are never logged.\n",
);

import fs from "fs";

export function loadEnv(path = ".env"): void {
  if (!fs.existsSync(path)) return;
  for (const line of fs.readFileSync(path, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const index = trimmed.indexOf("=");
    if (index < 0) continue;
    const key = trimmed.slice(0, index);
    const value = trimmed.slice(index + 1);
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

export function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

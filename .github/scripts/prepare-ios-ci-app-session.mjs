#!/usr/bin/env node
import { mkdir, rename, writeFile } from "node:fs/promises";
import { dirname, resolve, sep } from "node:path";

const MAX_TOKEN_CHARS = 16 * 1024;
const MAX_LIFETIME_SECONDS = 5 * 60 * 60;

function required(name) {
  const value = String(process.env[name] || "").trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function privateActionsPath(value, runnerTemp) {
  const path = resolve(value);
  const root = resolve(runnerTemp);
  if (!path.startsWith(`${root}${sep}`)) {
    throw new Error("CI application session must live under RUNNER_TEMP.");
  }
  return path;
}

function validCredential(value) {
  return value.length >= 24 && value.length <= MAX_TOKEN_CHARS && !/\s/u.test(value);
}

function normalizeBaseUrl(value) {
  const url = new URL(String(value || "https://api.ombhrum.com"));
  const local = ["127.0.0.1", "localhost", "::1"].includes(url.hostname);
  if ((!local && url.protocol !== "https:") || (local && !["http:", "https:"].includes(url.protocol))) {
    throw new Error("Fabushi API must use HTTPS outside loopback.");
  }
  if (url.username || url.password || url.search || url.hash) {
    throw new Error("Fabushi API URL must not contain credentials, query, or fragment data.");
  }
  return url.toString().replace(/\/$/u, "");
}

if (process.env.GITHUB_ACTIONS !== "true") {
  throw new Error("Protected application sessions can be prepared only inside GitHub Actions.");
}

const username = required("FABUSHI_CI_TEST_USERNAME");
const password = String(process.env.FABUSHI_CI_TEST_PASSWORD || "");
if (!password) throw new Error("FABUSHI_CI_TEST_PASSWORD is required.");
const deviceId = required("DEVICE_ID");
if (!/^gha-[0-9]+-[0-9]+-ios-app$/u.test(deviceId)) {
  throw new Error("DEVICE_ID must be an isolated iOS GitHub Actions test device id.");
}
const runId = required("GITHUB_RUN_ID");
const runAttempt = required("GITHUB_RUN_ATTEMPT");
if (!/^[0-9]+$/u.test(runId) || !/^[0-9]+$/u.test(runAttempt)) {
  throw new Error("GitHub run identity is invalid.");
}

const outputPath = privateActionsPath(
  required("FABUSHI_CI_ACCOUNT_SESSION_FILE"),
  required("RUNNER_TEMP"),
);
const baseUrl = normalizeBaseUrl(process.env.FABUSHI_API_BASE_URL);
const controller = new AbortController();
const timer = setTimeout(() => controller.abort(), 15_000);
timer.unref?.();

let response;
try {
  response = await fetch(`${baseUrl}/api/auth/login`, {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({ username, password, deviceId }),
    signal: controller.signal,
  });
} finally {
  clearTimeout(timer);
}
const text = await response.text();
let payload = {};
try { payload = text ? JSON.parse(text) : {}; } catch {
  throw new Error("Fabushi account login returned invalid JSON.");
}
if (!response.ok) {
  const code = String(payload?.error?.code || payload?.code || `http_${response.status}`);
  throw new Error(`Fabushi protected account login failed: ${code}`);
}

const accessToken = String(payload?.accessToken || "").trim();
const refreshToken = String(payload?.refreshToken || "").trim();
const tokenType = String(payload?.tokenType || "Bearer");
const sourceDeviceId = String(payload?.deviceId || "").trim();
const userId = String(payload?.userId || payload?.user?.id || "").trim();
const nestedUserId = String(payload?.user?.id || "").trim();
const normalizedUsername = String(payload?.username || payload?.user?.username || username).trim();
const expiresAt = Number(payload?.accessTokenExpiresAt || 0);
const now = Math.floor(Date.now() / 1000);

if (!validCredential(accessToken) || !validCredential(refreshToken)) {
  throw new Error("Fabushi account login did not return a normal refreshable session.");
}
if (tokenType !== "Bearer" || sourceDeviceId !== deviceId || !normalizedUsername || !userId || nestedUserId !== userId) {
  throw new Error("Fabushi account login returned an inconsistent account identity.");
}
if (!Number.isSafeInteger(expiresAt) || expiresAt <= now + 30 || expiresAt > now + MAX_LIFETIME_SECONDS) {
  throw new Error("Fabushi access token is not valid for a bounded CI application session.");
}

const exported = {
  accessToken,
  tokenType: "Bearer",
  accessTokenExpiresAt: expiresAt,
  sessionId: `ci-runner:${runId}:${runAttempt}`,
  deviceId,
  username: normalizedUsername,
  userId,
  user: payload.user,
  provider: "github-actions",
  ciRunner: true,
};

await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
const temporary = `${outputPath}.${process.pid}.tmp`;
await writeFile(temporary, `${JSON.stringify(exported, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
await rename(temporary, outputPath);
process.stdout.write("Prepared bounded refresh-token-free iOS application session.\n");

#!/usr/bin/env node
import { mkdir, rename, writeFile } from "node:fs/promises";
import { dirname, resolve, sep } from "node:path";

const MAX_SESSION_BYTES = 64 * 1024;
const MAX_LIFETIME_SECONDS = 5 * 60 * 60;
const REQUEST_TIMEOUT_MS = 15_000;

function required(name) {
  const value = String(process.env[name] || "").trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function privateRunnerPath(value, runnerTemp, name) {
  const path = resolve(value);
  const root = resolve(runnerTemp);
  if (!path.startsWith(`${root}${sep}`)) {
    throw new Error(`${name} must live under RUNNER_TEMP.`);
  }
  return path;
}

function normalizeBaseURL(value) {
  const parsed = new URL(String(value || "https://api.ombhrum.com"));
  const local = ["127.0.0.1", "localhost", "::1"].includes(parsed.hostname);
  if ((!local && parsed.protocol !== "https:") || (local && !["http:", "https:"].includes(parsed.protocol))) {
    throw new Error("FABUSHI_API_BASE_URL must use HTTPS outside loopback.");
  }
  if (parsed.username || parsed.password || parsed.search || parsed.hash) {
    throw new Error("FABUSHI_API_BASE_URL must not contain credentials, query, or fragment data.");
  }
  return parsed.toString().replace(/\/$/u, "");
}

function validCredential(value) {
  return value.length >= 24 && value.length <= 16 * 1024 && !/\s/u.test(value);
}

function validDeviceId(value) {
  return /^gha-[0-9]+-[0-9]+-ios-app$/u.test(value);
}

async function requestLogin(baseURL, username, password, deviceId) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  timer.unref?.();
  try {
    const response = await fetch(`${baseURL}/api/auth/login`, {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      body: JSON.stringify({ username, password, deviceId }),
      signal: controller.signal,
    });
    const text = await response.text();
    let payload = {};
    try { payload = text ? JSON.parse(text) : {}; } catch {
      throw new Error("Fabushi account service returned invalid JSON.");
    }
    if (!response.ok) {
      const code = String(payload?.error?.code || payload?.code || `http_${response.status}`);
      throw new Error(`Fabushi CI login failed: ${code}`);
    }
    return payload;
  } finally {
    clearTimeout(timer);
  }
}

if (process.env.GITHUB_ACTIONS !== "true") {
  throw new Error("Bounded CI sessions can be prepared only inside GitHub Actions.");
}

const username = required("FABUSHI_CI_TEST_USERNAME");
const password = required("FABUSHI_CI_TEST_PASSWORD");
const deviceId = required("DEVICE_ID");
const runId = required("GITHUB_RUN_ID");
const runAttempt = required("GITHUB_RUN_ATTEMPT");
const runnerTemp = required("RUNNER_TEMP");
const outputPath = privateRunnerPath(
  required("FABUSHI_CI_ACCOUNT_SESSION_FILE"),
  runnerTemp,
  "FABUSHI_CI_ACCOUNT_SESSION_FILE",
);
if (!validDeviceId(deviceId)) throw new Error("DEVICE_ID must be a protected iOS GitHub Actions device id.");
if (!/^[0-9]+$/u.test(runId) || !/^[0-9]+$/u.test(runAttempt)) {
  throw new Error("GitHub run identity is invalid.");
}

const payload = await requestLogin(
  normalizeBaseURL(process.env.FABUSHI_API_BASE_URL),
  username,
  password,
  deviceId,
);

const accessToken = String(payload?.accessToken || "").trim();
const refreshToken = String(payload?.refreshToken || "").trim();
const tokenType = String(payload?.tokenType || "Bearer");
const sourceDeviceId = String(payload?.deviceId || "").trim();
const sourceUsername = String(payload?.username || payload?.user?.username || "").trim();
const userId = String(payload?.userId || payload?.user?.id || "").trim();
const nestedUserId = String(payload?.user?.id || "").trim();
const expiresAt = Number(payload?.accessTokenExpiresAt || 0);
const now = Math.floor(Date.now() / 1000);

if (!validCredential(accessToken) || !validCredential(refreshToken)) {
  throw new Error("Fabushi login did not return a complete refreshable session.");
}
if (tokenType !== "Bearer" || sourceDeviceId !== deviceId || !sourceUsername || !userId || nestedUserId !== userId) {
  throw new Error("Fabushi login returned an inconsistent account identity.");
}
if (!Number.isSafeInteger(expiresAt) || expiresAt <= now + 30 || expiresAt > now + MAX_LIFETIME_SECONDS) {
  throw new Error("Fabushi access token is outside the bounded CI lifetime.");
}

const bounded = {
  accessToken,
  tokenType: "Bearer",
  accessTokenExpiresAt: expiresAt,
  sessionId: `ci-runner:${runId}:${runAttempt}`,
  deviceId,
  username: sourceUsername,
  userId,
  user: payload.user,
  provider: "github-actions",
  ciRunner: true,
};
const serialized = `${JSON.stringify(bounded, null, 2)}\n`;
if (Buffer.byteLength(serialized) > MAX_SESSION_BYTES) {
  throw new Error("Bounded Fabushi CI session is unexpectedly large.");
}

await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
const temporary = `${outputPath}.${process.pid}.tmp`;
await writeFile(temporary, serialized, { encoding: "utf8", mode: 0o600 });
await rename(temporary, outputPath);
process.stdout.write("Prepared bounded refresh-token-free Fabushi iOS application session.\n");

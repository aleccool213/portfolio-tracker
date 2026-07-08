#!/usr/bin/env node
// Screenshot a running page — for quick visual verification of UI changes.
//
// Usage:
//   node script/screenshot.js <url> [outPath] [width] [height]
//   node script/screenshot.js http://127.0.0.1:3005/ tmp/shot.png 420 900
//
// Why this wrapper exists (friction we hit):
//   * Playwright is installed as a GLOBAL node module in this environment
//     (/opt/node22/lib/node_modules), so a plain `require('playwright')` or ESM
//     `import ... from 'playwright'` fails to resolve. We require it by absolute
//     path via createRequire below.
//   * The bundled Chromium lives at /opt/pw-browsers/chromium and must be passed
//     explicitly as executablePath — do NOT run `playwright install`.
// Both paths fall back to the defaults if the module resolves normally, so this
// also works in a standard local checkout where playwright is a dev dependency.

const { createRequire } = require("node:module");

function loadPlaywright() {
  try {
    return require("playwright");
  } catch (_) {
    const globalReq = createRequire("/opt/node22/lib/node_modules/");
    return globalReq("playwright");
  }
}

const url = process.argv[2] || "http://127.0.0.1:3000/";
const out = process.argv[3] || "tmp/shot.png";
const width = parseInt(process.argv[4] || "420", 10);
const height = parseInt(process.argv[5] || "900", 10);

const executablePath = process.env.PW_CHROMIUM || "/opt/pw-browsers/chromium";

(async () => {
  const { chromium } = loadPlaywright();
  const launchOpts = {};
  const fs = require("node:fs");
  if (fs.existsSync(executablePath)) launchOpts.executablePath = executablePath;

  const browser = await chromium.launch(launchOpts);
  const page = await browser.newPage({ viewport: { width, height } });
  await page.goto(url, { waitUntil: "networkidle" });
  await page.screenshot({ path: out, fullPage: true });
  await browser.close();
  console.log(`Saved screenshot: ${out}`);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});

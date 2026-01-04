const { exec } = require('child_process');
const { promisify } = require('util');
const http = require('http');
const https = require('https');

const execAsync = promisify(exec);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function mergeHeaders(base, extra) {
  return { ...(base || {}), ...(extra || {}) };
}

function getExtraHeaders() {
  let headers = {};
  if (process.env.PW_HEADER_NAME && process.env.PW_HEADER_VALUE) {
    headers[process.env.PW_HEADER_NAME] = process.env.PW_HEADER_VALUE;
  }
  if (process.env.PW_EXTRA_HEADERS) {
    try {
      const parsed = JSON.parse(process.env.PW_EXTRA_HEADERS);
      headers = mergeHeaders(headers, parsed);
    } catch (err) {
      console.warn('PW_EXTRA_HEADERS is not valid JSON');
    }
  }
  return headers;
}

function getContextOptionsWithHeaders(options = {}) {
  const extra = getExtraHeaders();
  if (!Object.keys(extra).length) return options;
  return {
    ...options,
    extraHTTPHeaders: mergeHeaders(options.extraHTTPHeaders, extra),
  };
}

async function createContext(browser, options = {}) {
  return browser.newContext(getContextOptionsWithHeaders(options));
}

async function safeClick(page, selector, { retries = 3, timeout = 8000 } = {}) {
  for (let attempt = 0; attempt < retries; attempt += 1) {
    try {
      await page.waitForSelector(selector, { timeout });
      await page.click(selector);
      return;
    } catch (err) {
      if (attempt === retries - 1) throw err;
      await sleep(300);
    }
  }
}

async function safeType(page, selector, value) {
  await page.waitForSelector(selector, { timeout: 8000 });
  await page.click(selector, { clickCount: 3 });
  await page.fill(selector, value);
}

async function takeScreenshot(page, label = 'screenshot') {
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const path = `/tmp/${label}-${ts}.png`;
  await page.screenshot({ path, fullPage: true });
  return path;
}

async function handleCookieBanner(page) {
  const candidates = [
    'button:has-text("Accept")',
    'button:has-text("Accept all")',
    'button:has-text("Allow all")',
    'button:has-text("Agree")',
    'button:has-text("OK")',
  ];
  for (const sel of candidates) {
    const el = page.locator(sel);
    if (await el.count()) {
      try {
        await el.first().click();
        return true;
      } catch {
        // ignore
      }
    }
  }
  return false;
}

async function extractTableData(page, selector) {
  await page.waitForSelector(selector, { timeout: 8000 });
  return page.$$eval(selector, (tables) => {
    const table = tables[0];
    if (!table) return [];
    const rows = Array.from(table.querySelectorAll('tr'));
    return rows.map((row) =>
      Array.from(row.querySelectorAll('th,td')).map((cell) => cell.textContent?.trim() || '')
    );
  });
}

async function headRequest(url) {
  const lib = url.startsWith('https') ? https : http;
  return new Promise((resolve) => {
    const req = lib.request(url, { method: 'HEAD', timeout: 5000 }, (res) => {
      res.resume();
      resolve({ ok: true, status: res.statusCode || 0 });
    });
    req.on('error', () => resolve({ ok: false, status: 0 }));
    req.on('timeout', () => {
      req.destroy();
      resolve({ ok: false, status: 0 });
    });
    req.end();
  });
}

async function detectDevServers() {
  let output = '';
  try {
    const { stdout } = await execAsync('ss -ltn');
    output = stdout || '';
  } catch {
    return [];
  }

  const ports = new Set();
  for (const line of output.split('\n')) {
    const match = line.match(/:(\d+)\s/);
    if (!match) continue;
    const port = Number(match[1]);
    if ((port >= 3000 && port <= 3999) || (port >= 8000 && port <= 8999)) {
      ports.add(port);
    }
  }

  const results = [];
  for (const port of Array.from(ports).sort((a, b) => a - b)) {
    const url = `http://127.0.0.1:${port}`;
    let res = await headRequest(url);
    if (!res.ok) {
      res = await new Promise((resolve) => {
        const req = http.request(url, { method: 'GET', timeout: 5000 }, (resp) => {
          resp.resume();
          resolve({ ok: true, status: resp.statusCode || 0 });
        });
        req.on('error', () => resolve({ ok: false, status: 0 }));
        req.on('timeout', () => {
          req.destroy();
          resolve({ ok: false, status: 0 });
        });
        req.end();
      });
    }
    if (res.ok) {
      results.push({ url, port, status: res.status });
    }
  }
  return results;
}

module.exports = {
  createContext,
  detectDevServers,
  extractTableData,
  getContextOptionsWithHeaders,
  handleCookieBanner,
  safeClick,
  safeType,
  takeScreenshot,
};

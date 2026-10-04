// Locate a Chrome/Chromium binary: $CHROME_BIN, macOS Chrome, Playwright's
// bundled Chromium (preinstalled in Claude Code cloud sessions), then the usual
// Linux paths. Returns null if none exists.
const path = require('path');
const fs = require('fs');

function findChrome() {
  if (process.env.CHROME_BIN) return process.env.CHROME_BIN;
  const candidates = ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
  const pwDir = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  try {
    for (const d of fs.readdirSync(pwDir).filter((n) => /^chromium-\d+$/.test(n)).sort().reverse()) {
      candidates.push(path.join(pwDir, d, 'chrome-linux', 'chrome'));
    }
  } catch (_) {}
  candidates.push('/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome');
  return candidates.find((c) => fs.existsSync(c)) || null;
}

module.exports = { findChrome };

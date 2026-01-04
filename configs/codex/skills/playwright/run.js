const fs = require('fs');
const path = require('path');
const vm = require('vm');

function isFile(p) {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}

function runFile(filePath) {
  const abs = path.resolve(process.cwd(), filePath);
  if (!isFile(abs)) {
    console.error(`File not found: ${abs}`);
    process.exit(1);
  }
  require(abs);
}

function runInline(code) {
  const wrapped = `(async () => {\n${code}\n})().catch((err) => {\n  console.error(err);\n  process.exit(1);\n});`;
  vm.runInThisContext(wrapped, { filename: 'inline-playwright.js' });
}

function main() {
  const args = process.argv.slice(2);
  if (!args.length) {
    console.error('Usage: node run.js <script.js> | "<inline code>"');
    process.exit(1);
  }

  const maybePath = path.resolve(process.cwd(), args[0]);
  if (args.length === 1 && isFile(maybePath)) {
    runFile(args[0]);
    return;
  }

  runInline(args.join(' '));
}

main();

// Parses every Mermaid block in the given Markdown files (default: all tracked *.md files)
// and reports the blocks that Mermaid cannot parse.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>');
globalThis.window = dom.window;
globalThis.document = dom.window.document;
const { default: mermaid } = await import('mermaid');
mermaid.initialize({ startOnLoad: false });

const files =
  process.argv.length > 2
    ? process.argv.slice(2)
    : execFileSync('git', ['ls-files', '*.md'], { encoding: 'utf8' }).split('\n').filter(Boolean);

const blockPattern = /^```mermaid\n([\s\S]*?)^```$/gm;
let blocks = 0;
let failures = 0;

for (const file of files) {
  const text = readFileSync(file, 'utf8');
  for (const match of text.matchAll(blockPattern)) {
    blocks += 1;
    const line = text.slice(0, match.index).split('\n').length;
    try {
      await mermaid.parse(match[1]);
    } catch (error) {
      failures += 1;
      console.error(`${file}:${line}: ${error.message.split('\n').slice(0, 4).join('\n  ')}`);
    }
  }
}

if (failures > 0) {
  console.error(`${failures} of ${blocks} Mermaid blocks failed to parse.`);
  process.exit(1);
}
console.log(`${blocks} Mermaid blocks parsed.`);

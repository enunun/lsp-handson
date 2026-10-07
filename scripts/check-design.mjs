// Compares the module dependencies drawn in design/c4-component.md with the imports in the code.
//
// In the diagram, a module is a node whose label is the module name, e.g. Calc_Parser["Calc.Parser"],
// and `A --> B` (one arrow per line) means "A imports B". Nodes whose ID starts with `ext_` stand for things outside the
// package (libraries) and are not compared. Imports of modules outside the package are ignored.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';

const packages = execFileSync('git', ['ls-files', '*.cabal'], { encoding: 'utf8' })
  .split('\n')
  .filter(Boolean)
  .map(dirname)
  .filter((dir) => existsSync(join(dir, 'design', 'c4-component.md')))
  // An exercise may start with a design document that has no diagram yet.
  .filter((dir) => readFileSync(join(dir, 'design', 'c4-component.md'), 'utf8').includes('```mermaid'));

function moduleFiles(dir) {
  return execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', 'src', 'app'], {
    cwd: dir,
    encoding: 'utf8',
  })
    .split('\n')
    .filter((file) => file.endsWith('.hs'));
}

function moduleName(dir, file) {
  const source = readFileSync(join(dir, file), 'utf8');
  const match = source.match(/^module\s+([\w.]+)/m);
  return match ? match[1] : 'Main';
}

function codeEdges(dir) {
  const files = moduleFiles(dir);
  const modules = new Map(files.map((file) => [moduleName(dir, file), file]));
  const edges = new Set();
  for (const [name, file] of modules) {
    const source = readFileSync(join(dir, file), 'utf8');
    for (const match of source.matchAll(/^import\s+(?:qualified\s+)?([\w.]+)/gm)) {
      if (modules.has(match[1])) edges.add(`${name} --> ${match[1]}`);
    }
  }
  return { modules: new Set(modules.keys()), edges };
}

function diagramEdges(dir) {
  const text = readFileSync(join(dir, 'design', 'c4-component.md'), 'utf8');
  const labels = new Map();
  const edges = new Set();
  for (const block of text.matchAll(/^```mermaid\n([\s\S]*?)^```$/gm)) {
    const body = block[1];
    for (const line of body.split('\n')) {
      if (/^\s*subgraph\b/.test(line)) continue;
      for (const node of line.matchAll(/\b(\w+)\["([^"]+)"\]/g)) labels.set(node[1], node[2]);
      const arrow = line.match(/^\s*(\w+)(?:\["[^"]*"\])?\s*-->(?:\|[^|]*\|)?\s*(\w+)/);
      if (arrow) edges.add([arrow[1], arrow[2]]);
    }
  }
  const named = new Set();
  for (const [from, to] of edges) {
    if (from.startsWith('ext_') || to.startsWith('ext_')) continue;
    named.add(`${labels.get(from) ?? from} --> ${labels.get(to) ?? to}`);
  }
  return { labels, edges: named };
}

let problems = 0;
for (const dir of packages) {
  const code = codeEdges(dir);
  const diagram = diagramEdges(dir);
  const where = relative(process.cwd(), join(dir, 'design', 'c4-component.md'));
  const drawnModules = new Set([...diagram.labels.entries()].filter(([id]) => !id.startsWith('ext_')).map(([, l]) => l));
  for (const name of code.modules) {
    if (!drawnModules.has(name)) {
      problems += 1;
      console.error(`${where}: module ${name} is missing from the diagram`);
    }
  }
  for (const name of drawnModules) {
    if (!code.modules.has(name)) {
      problems += 1;
      console.error(`${where}: module ${name} is drawn but does not exist in the code`);
    }
  }
  for (const edge of code.edges) {
    if (!diagram.edges.has(edge)) {
      problems += 1;
      console.error(`${where}: ${edge} is in the code but not in the diagram`);
    }
  }
  for (const edge of diagram.edges) {
    if (!code.edges.has(edge)) {
      problems += 1;
      console.error(`${where}: ${edge} is in the diagram but not in the code`);
    }
  }
}

if (problems > 0) {
  console.error(`${problems} mismatches between design documents and code.`);
  process.exit(1);
}
console.log(`Design documents match the code in ${packages.length} packages.`);

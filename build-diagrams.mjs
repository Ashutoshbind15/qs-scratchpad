import { build } from 'esbuild';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = path.dirname(fileURLToPath(import.meta.url));
const output = path.join(repo, 'editor/generated');
const setting = path.join(repo, '.build/scribblesvg-path');
// Remember an explicit path so desktop launches use the same checkout.
const source = path.resolve(process.env.SCRIBBLESVG_LOCAL_PATH
  || (existsSync(setting) ? readFileSync(setting, 'utf8').trim() : path.join(homedir(), 'ScribbleSVG')));
const aliases = {
  '@scribblesvg/core': path.join(source, 'packages/core/index.ts'),
  '@scribblesvg/react-utils/editor': path.join(source, 'packages/react-utils/src/editor/index.ts'),
  '@scribblesvg/react-utils/renderer': path.join(source, 'packages/react-utils/src/diagram-renderer.tsx'),
  '@scribblesvg/react-utils/editor.css': path.join(source, 'packages/react-utils/src/editor.css'),
  // Use one React runtime, including when the source checkout has node_modules.
  react: path.join(repo, 'node_modules/react'),
  'react-dom': path.join(repo, 'node_modules/react-dom'),
  roughjs: path.join(repo, 'node_modules/roughjs'),
};
for (const filename of Object.values(aliases)) {
  if (!existsSync(filename)) {
    // A prepared installation remains usable if its source checkout is moved.
    if (!process.env.SCRIBBLESVG_LOCAL_PATH && existsSync(path.join(output, 'diagrams.js'))
        && existsSync(path.join(output, 'diagrams.css'))) {
      console.warn(`ScribbleSVG source unavailable at ${source}; keeping the existing local bundle.`);
      process.exit(0);
    }
    console.error(`Missing ${filename}\nClone https://github.com/Ashutoshbind15/ScribbleSVG.git into ~/ScribbleSVG,\nor run SCRIBBLESVG_LOCAL_PATH=/path/to/ScribbleSVG ./prepare-editor.`);
    process.exit(1);
  }
}

function sourceFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const filename = path.join(directory, entry.name);
    if (entry.name === 'node_modules' || entry.name === 'dist') return [];
    return entry.isDirectory() ? sourceFiles(filename) : [filename];
  }).sort();
}
const inputs = [
  fileURLToPath(import.meta.url), path.join(repo, 'package-lock.json'),
  path.join(repo, 'editor/diagrams.jsx'),
  ...sourceFiles(path.join(source, 'packages/core')),
  ...sourceFiles(path.join(source, 'packages/react-utils/src')),
];
const hash = createHash('sha256').update(source);
for (const filename of inputs) hash.update(filename).update(readFileSync(filename));
const key = hash.digest('hex');
const stamp = path.join(output, 'source-key');
if (existsSync(stamp) && readFileSync(stamp, 'utf8') === key
    && existsSync(path.join(output, 'diagrams.js')) && existsSync(path.join(output, 'diagrams.css'))) {
  process.exit(0);
}
const result = await build({
  absWorkingDir: repo,
  entryPoints: ['editor/diagrams.jsx'],
  outfile: path.join(output, 'diagrams.js'),
  bundle: true, format: 'iife', platform: 'browser', target: 'chrome110',
  jsx: 'automatic', minify: true, write: false, alias: aliases,
  define: { 'process.env.NODE_ENV': '"production"' },
  // Do not inherit compiler/JSX settings from the external checkout.
  tsconfigRaw: { compilerOptions: { jsx: 'react-jsx' } },
});
mkdirSync(output, { recursive: true });
for (const file of result.outputFiles) {
  writeFileSync(`${file.path}.new`, file.contents);
  renameSync(`${file.path}.new`, file.path);
}
writeFileSync(stamp, key);
mkdirSync(path.dirname(setting), { recursive: true });
writeFileSync(setting, source);
console.log(`Bundled local ScribbleSVG from ${source}`);

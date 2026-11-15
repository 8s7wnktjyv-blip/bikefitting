// Baut die neue FYF-Plattform (Vorschau) nach app/dist.
// Design: alle <style>-Blöcke werden unverändert aus der bisherigen App (index.html) übernommen,
// damit Farben, Schriften und Bausteine gleich bleiben. Schriften liegen lokal (keine Google-Server).
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync, cpSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const req = createRequire(import.meta.url);
let esb; try { esb = req('esbuild'); } catch { esb = req('/opt/npm-tools/node_modules/esbuild'); }
const { build } = esb;
const dist = join(here, 'dist');
mkdirSync(dist, { recursive: true });

const legacy = readFileSync(join(here, '..', 'index.html'), 'utf8');
// nur die Stile im <head> – weitere <style>-Blöcke stehen in Druckvorlagen innerhalb des Codes
const head = legacy.slice(0, legacy.indexOf('</head>'));
const css = [...head.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(m => m[1]).join('\n');
writeFileSync(join(dist, 'fyf.css'), '/* aus index.html übernommen – nicht hier bearbeiten */\n' + css);
cpSync(join(here, 'src', 'shell.css'), join(dist, 'shell.css'));
cpSync(join(here, 'public', 'fonts'), join(dist, 'fonts'), { recursive: true });

await build({
  entryPoints: [join(here, 'src', 'main.tsx')],
  bundle: true, minify: true, sourcemap: false, format: 'esm', target: ['es2020', 'safari15'],
  outfile: join(dist, 'app.js'), jsx: 'automatic', loader: { '.tsx': 'tsx', '.ts': 'ts' },
  nodePaths: [process.env.NODE_PATH || '/opt/npm-tools/node_modules', join(here, 'node_modules')],
  define: { 'process.env.NODE_ENV': '"production"' }, logLevel: 'info',
});

writeFileSync(join(dist, 'index.html'), `<!doctype html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'; img-src 'self' data: blob:; connect-src 'self' https://*.supabase.co http://localhost:* http://127.0.0.1:*; base-uri 'self'; form-action 'self'">
<meta name="robots" content="noindex">
<title>FYF Plattform (Vorschau)</title>
<link rel="stylesheet" href="fyf.css"><link rel="stylesheet" href="shell.css">
</head><body><div id="root"></div><script type="module" src="app.js"></script></body></html>`);
console.log('fertig: app/dist');

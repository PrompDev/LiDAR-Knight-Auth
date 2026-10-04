#!/usr/bin/env node
// Checks every SVG in lidar-knight/art/ (or the files given):
//   - well-formed XML (tags balanced, attributes quoted, no stray < or &)
//   - one <svg> root with role="img", an aria-label and a <title>
//   - no <text>, <image>, <script>, <foreignObject>, external references or fonts
//   - no background shape: only <path>, <rect>, <circle>, <title>, <style>
//   - every fill is a palette colour
//   node lidar-knight/dotmatrix/check.mjs [file.svg ...]

import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PALETTE } from './render.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const artDir = join(here, '..', 'art');
const files = process.argv.length > 2 ? process.argv.slice(2)
  : readdirSync(artDir).filter(f => f.endsWith('.svg')).map(f => join(artDir, f));

const ALLOWED = new Set(['svg', 'title', 'style', 'path', 'rect', 'circle']);
const COLOURS = new Set(Object.values(PALETTE).map(c => c.toUpperCase()));

function check(src) {
  const errs = [];
  const stack = [];
  let i = 0, roots = 0;
  const attrRe = /^(?:\s+[A-Za-z_:][\w:.-]*="[^"<]*")*\s*$/;
  while (i < src.length) {
    const lt = src.indexOf('<', i);
    const text = src.slice(i, lt === -1 ? src.length : lt);
    if (/&(?!(amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)/.test(text)) errs.push('bare & in text');
    if (lt === -1) { if (text.trim() && !stack.length) errs.push('text after root'); break; }
    const gt = src.indexOf('>', lt);
    if (gt === -1) { errs.push('unterminated tag'); break; }
    const tag = src.slice(lt + 1, gt);
    const m = /^(\/?)([A-Za-z][\w:-]*)([\s\S]*?)(\/?)$/.exec(tag);
    if (!m) { errs.push(`bad tag <${tag.slice(0, 30)}>`); break; }
    const [, close, name, attrs, self] = m;
    if (close) {
      if (stack.pop() !== name) errs.push(`mismatched </${name}>`);
    } else {
      if (!attrRe.test(attrs)) errs.push(`bad attributes on <${name}>`);
      if (/&(?!(amp|lt|gt|quot|apos);)/.test(attrs)) errs.push(`bare & in <${name}> attributes`);
      if (!ALLOWED.has(name)) errs.push(`element <${name}> not allowed`);
      if (!stack.length) roots++;
      for (const [, col] of attrs.matchAll(/fill="([^"]*)"/g)) if (!COLOURS.has(col.toUpperCase())) errs.push(`fill ${col} is not a palette colour`);
      if (/(href|url\(|@import|@font-face)/.test(attrs)) errs.push(`external reference in <${name}>`);
      if (!self) stack.push(name);
    }
    i = gt + 1;
  }
  if (stack.length) errs.push(`unclosed <${stack.join('>, <')}>`);
  if (roots !== 1) errs.push(`${roots} root elements`);
  if (!/^<svg [^>]*role="img"/.test(src)) errs.push('root must be <svg> with role="img"');
  if (!/^<svg [^>]*aria-label="[^"]+"/.test(src)) errs.push('missing aria-label');
  if (!/<title>[^<]+<\/title>/.test(src)) errs.push('missing <title>');
  if (/@import|url\(|font-family/.test(src)) errs.push('external resource or font in <style>');
  return errs;
}

let bad = 0;
for (const f of files) {
  const errs = check(readFileSync(f, 'utf8'));
  if (errs.length) { bad++; console.log(`FAIL ${basename(f)}: ${[...new Set(errs)].join('; ')}`); }
  else console.log(`ok   ${basename(f)}`);
}
console.log(`${files.length - bad}/${files.length} SVGs pass`);
process.exit(bad ? 1 : 0);

#!/usr/bin/env node
// LiDAR-Knight Auth dot-matrix renderer. No dependencies (Node 18+).
//
// Every letter is built from separate square dots on a strict grid. The SVGs it
// writes have a transparent background, no <text>, no fonts and no background
// shape, so they read the same on light and dark pages.
//
//   node render.mjs --text "SAFETY" --out safety.svg
//   node render.mjs --text "LiDAR-Knight Auth" --out title.svg --scale 8 --haze scan
//   node render.mjs --text "004 104" --out code.svg --scale 8 --diamonds
//
// Options
//   --text     text to draw; "\n" starts a new line
//   --out      output file (default: stdout)
//   --scale    dot pitch in px (default 6). Alias: --pitch
//   --dot      dot size in px (default: pitch-1 up to 6, then 3/4 of the pitch)
//   --color    palette name (red, cream, redDim, redDeep, hot) or #hex (default red)
//   --haze     none | scan | field (default none)
//   --diamonds outline diamond markers at both ends of each line
//   --shape    square | round (default square)
//   --cream    draw highlight dots (the dot of a lowercase i) in cream instead of the main colour
//   --upper    upper-case the text first
//   --pad      empty cells around the drawing (default 1)
//   --label    accessible name (default: the text)
//
// The same module exports DotCanvas and the glyph table for build-art.mjs.

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

// ---- palette -----------------------------------------------------------------
export const PALETTE = {
  red: '#FF2A12',     // every dot that carries information
  cream: '#FFD8CC',   // rare highlight dots (invisible on white: never alone)
  redDim: '#7A1A10',  // haze and disabled states only, never text
  redDeep: '#3A160A', // pressed-state fill at low density
  hot: '#FF5A2A',     // hover glow on the close button only
  black: '#000000',
};

// 4x4 ordered (Bayer) dither matrix. A cell at (x, y) is lit when
// level * 16 > BAYER4[y % 4][x % 4].
export const BAYER4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];
export const bayerLit = (level, x, y) => level * 16 > BAYER4[((y % 4) + 4) % 4][((x % 4) + 4) % 4];

// ---- glyphs -----------------------------------------------------------------
// Rows top to bottom, separated by spaces. '#' = dot, '*' = highlight dot,
// '.' = empty. Cap height is 7 rows (rows 0..6, baseline at row 6). Lowercase
// letters with descenders use rows 7 and 8. Width is the row length.
export const GLYPHS = {
  // digits ('0' has a dot inside so it never reads as 8 or O)
  '0': '.###. #...# #...# #.#.# #...# #...# .###.',
  '1': '..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.',
  '2': '.###. #...# ....# ...#. ..#.. .#... #####',
  '3': '####. ....# ....# .###. ....# ....# ####.',
  '4': '...#. ..##. .#.#. #..#. ##### ...#. ...#.',
  '5': '##### #.... ####. ....# ....# #...# .###.',
  '6': '..##. .#... #.... ####. #...# #...# .###.',
  '7': '##### ....# ...#. ..#.. .#... .#... .#...',
  '8': '.###. #...# #...# .###. #...# #...# .###.',
  '9': '.###. #...# #...# .#### ....# ...#. .##..',
  // upper case
  A: '.###. #...# #...# ##### #...# #...# #...#',
  B: '####. #...# #...# ####. #...# #...# ####.',
  C: '.###. #...# #.... #.... #.... #...# .###.',
  D: '####. #...# #...# #...# #...# #...# ####.',
  E: '##### #.... #.... ####. #.... #.... #####',
  F: '##### #.... #.... ####. #.... #.... #....',
  G: '.###. #...# #.... #.### #...# #...# .####',
  H: '#...# #...# #...# ##### #...# #...# #...#',
  I: '.###. ..#.. ..#.. ..#.. ..#.. ..#.. .###.',
  J: '..### ...#. ...#. ...#. ...#. #..#. .##..',
  K: '#...# #..#. #.#.. ##... #.#.. #..#. #...#',
  L: '#.... #.... #.... #.... #.... #.... #####',
  M: '#...# ##.## #.#.# #.#.# #...# #...# #...#',
  N: '#...# #...# ##..# #.#.# #..## #...# #...#',
  O: '.###. #...# #...# #...# #...# #...# .###.',
  P: '####. #...# #...# ####. #.... #.... #....',
  Q: '.###. #...# #...# #...# #.#.# #..#. .##.#',
  R: '####. #...# #...# ####. #.#.. #..#. #...#',
  S: '.#### #.... #.... .###. ....# ....# ####.',
  T: '##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..',
  U: '#...# #...# #...# #...# #...# #...# .###.',
  V: '#...# #...# #...# #...# #...# .#.#. ..#..',
  W: '#...# #...# #...# #.#.# #.#.# #.#.# .#.#.',
  X: '#...# #...# .#.#. ..#.. .#.#. #...# #...#',
  Y: '#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..',
  Z: '##### ....# ...#. ..#.. .#... #.... #####',
  // lower case
  a: '..... ..... .###. ....# .#### #...# .####',
  b: '#.... #.... #.##. ##..# #...# #...# ####.',
  c: '..... ..... .###. #.... #.... #...# .###.',
  d: '....# ....# .##.# #..## #...# #...# .####',
  e: '..... ..... .###. #...# ##### #.... .###.',
  f: '..##. .#..# .#... ###.. .#... .#... .#...',
  g: '..... ..... .#### #...# #...# #...# .#### ....# .###.',
  h: '#.... #.... #.##. ##..# #...# #...# #...#',
  i: '..*.. ..... .##.. ..#.. ..#.. ..#.. .###.', // the special i: its dot is the highlight
  j: '...*. ..... ..##. ...#. ...#. ...#. ...#. #..#. .##..',
  k: '#.... #.... #..#. #.#.. ##... #.#.. #..#.',
  l: '.##.. ..#.. ..#.. ..#.. ..#.. ..#.. .###.',
  m: '..... ..... ##.#. #.#.# #.#.# #...# #...#',
  n: '..... ..... #.##. ##..# #...# #...# #...#',
  o: '..... ..... .###. #...# #...# #...# .###.',
  p: '..... ..... ####. #...# #...# #...# ####. #.... #....',
  q: '..... ..... .#### #...# #...# #...# .#### ....# ....#',
  r: '..... ..... #.##. ##..# #.... #.... #....',
  s: '..... ..... .###. #.... .###. ....# ####.',
  t: '.#... .#... ###.. .#... .#... .#..# ..##.',
  u: '..... ..... #...# #...# #...# #..## .##.#',
  v: '..... ..... #...# #...# #...# .#.#. ..#..',
  w: '..... ..... #...# #...# #.#.# #.#.# .#.#.',
  x: '..... ..... #...# .#.#. ..#.. .#.#. #...#',
  y: '..... ..... #...# #...# #...# #...# .#### ....# .###.',
  z: '..... ..... ##### ...#. ..#.. .#... #####',
  // punctuation and symbols
  '-': '..... ..... ..... .###. ..... ..... .....',
  '_': '..... ..... ..... ..... ..... ..... #####',
  '.': '..... ..... ..... ..... ..... ..... ..#..',
  ',': '..... ..... ..... ..... ..... ..#.. ..#.. .#...',
  ':': '..... ..#.. ..... ..... ..... ..#.. .....',
  ';': '..... ..#.. ..... ..... ..#.. ..#.. .#...',
  '!': '..#.. ..#.. ..#.. ..#.. ..#.. ..... ..#..',
  '?': '.###. #...# ....# ...#. ..#.. ..... ..#..',
  "'": '..#.. ..#.. .#... ..... ..... ..... .....',
  '"': '.#.#. .#.#. .#.#. ..... ..... ..... .....',
  '/': '....# ....# ...#. ..#.. .#... #.... #....',
  '\\': '#.... #.... .#... ..#.. ...#. ....# ....#',
  '|': '..#.. ..#.. ..#.. ..#.. ..#.. ..#.. ..#..',
  '(': '...#. ..#.. .#... .#... .#... ..#.. ...#.',
  ')': '.#... ..#.. ...#. ...#. ...#. ..#.. .#...',
  '[': '.###. .#... .#... .#... .#... .#... .###.',
  ']': '.###. ...#. ...#. ...#. ...#. ...#. .###.',
  '<': '...#. ..#.. .#... #.... .#... ..#.. ...#.',
  '>': '.#... ..#.. ...#. ....# ...#. ..#.. .#...',
  '=': '..... ..... ##### ..... ##### ..... .....',
  '+': '..... ..#.. ..#.. ##### ..#.. ..#.. .....',
  '*': '..... ..#.. #.#.# .###. #.#.# ..#.. .....',
  '#': '.#.#. .#.#. ##### .#.#. ##### .#.#. .#.#.',
  '$': '..#.. .#### #.#.. .###. ..#.# ####. ..#..',
  '%': '##... ##..# ...#. ..#.. .#... #..## ...##',
  '&': '.##.. #..#. #.#.. .#... #.#.# #..#. .##.#',
  '@': '.###. #...# #.### #.#.# #.### #.... .####',
  '~': '..... ..... .#... #.#.# ...#. ..... .....',
  '×': '..... #...# .#.#. ..#.. .#.#. #...# .....',
  '·': '. . . # . . .',
  '◆': '... ... .#. ### .#. ... ...',       // filled 3x3 diamond: bullets, separators
  '◇': '..... ..#.. .#.#. #...# .#.#. ..#.. .....', // outline diamond: markers
};

const SPACE_COLS = 3; // a word space advances 3 columns (plus the 1-column gap)
export const LINE_ROWS = 10; // line height in rows

export function glyph(ch) {
  const src = GLYPHS[ch] ?? GLYPHS[ch.toUpperCase()] ?? GLYPHS['?'];
  const rows = src.split(' ');
  return { rows, w: rows[0].length };
}

// Width of a line in grid columns.
export function measureCols(line) {
  let cols = 0;
  for (const ch of line) cols += ch === ' ' ? SPACE_COLS : glyph(ch).w + 1;
  return Math.max(0, cols - 1);
}

export const defaultDot = pitch => (pitch <= 6 ? Math.max(1, pitch - 1) : Math.round(pitch * 0.75));

export function resolveColor(c) {
  if (!c) return PALETTE.red;
  if (PALETTE[c]) return PALETTE[c];
  if (/^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$/.test(c)) return c.toUpperCase();
  throw new Error(`unknown colour "${c}" (use a palette name or #hex)`);
}

// Small deterministic PRNG so the art is identical on every run.
export function rng(seed = 0x1d4a2) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const r2 = n => Math.round(n * 100) / 100;

// ---- canvas -----------------------------------------------------------------
// Coordinates are in px. Each dot is a square (or round) mark of `size` px whose
// top-left corner is at (x, y). Later dots at the same spot replace earlier ones.
export class DotCanvas {
  constructor({ shape = 'square' } = {}) {
    this.shape = shape;
    this.dots = new Map();
    this.keepout = []; // rects haze must not enter: [x0, y0, x1, y1]
    this.css = [];
  }

  dot(x, y, size, { color = PALETTE.red, opacity = 1, cls = null, style = null } = {}) {
    x = Math.round(x); y = Math.round(y);
    this.dots.set(`${x},${y},${size}`, { x, y, size, color: resolveColor(color), opacity, cls, style });
  }

  // Draws one or more lines. Returns the drawn size in px.
  text(str, x, y, { pitch = 6, dot = defaultDot(pitch), color = 'red', highlight = null, opacity = 1,
    upper = false, keepout = 1, cls = null } = {}) {
    const lines = String(upper ? str.toUpperCase() : str).split('\n');
    let maxCols = 0;
    lines.forEach((line, li) => {
      let gx = 0;
      const gy0 = li * LINE_ROWS;
      for (const ch of line) {
        if (ch === ' ') { gx += SPACE_COLS; continue; }
        const g = glyph(ch);
        g.rows.forEach((row, ry) => [...row].forEach((c, rx) => {
          if (c === '.') return;
          const col = c === '*' && highlight ? highlight : color;
          this.dot(x + (gx + rx) * pitch, y + (gy0 + ry) * pitch, dot, { color: col, opacity, cls });
        }));
        gx += g.w + 1;
      }
      maxCols = Math.max(maxCols, gx - 1);
    });
    const w = maxCols * pitch, h = ((lines.length - 1) * LINE_ROWS + 7) * pitch;
    if (keepout) this.keepout.push([x - keepout * pitch, y - keepout * pitch, x + w + keepout * pitch, y + h + (keepout + 2) * pitch]);
    return { w, h, cols: maxCols };
  }

  // Diamond centred on cell (cx, cy) of a grid with the given pitch and origin.
  diamond(x, y, r, { pitch = 6, dot = defaultDot(pitch), fill = false, color = 'red', opacity = 1, cls = null } = {}) {
    for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
      const d = Math.abs(dx) + Math.abs(dy);
      if (fill ? d <= r : d === r) this.dot(x + dx * pitch, y + dy * pitch, dot, { color, opacity, cls });
    }
    this.keepout.push([x - (r + 1) * pitch, y - (r + 1) * pitch, x + (r + 2) * pitch, y + (r + 2) * pitch]);
  }

  // Dotted rectangle outline, one dot thick.
  outline(x, y, w, h, { pitch = 4, dot = defaultDot(pitch), color = 'red', opacity = 1 } = {}) {
    const nx = Math.round(w / pitch), ny = Math.round(h / pitch);
    for (let i = 0; i <= nx; i++) { this.dot(x + i * pitch, y, dot, { color, opacity }); this.dot(x + i * pitch, y + ny * pitch, dot, { color, opacity }); }
    for (let j = 1; j < ny; j++) { this.dot(x, y + j * pitch, dot, { color, opacity }); this.dot(x + nx * pitch, y + j * pitch, dot, { color, opacity }); }
  }

  // Ordered-dither haze. `level(gx, gy, u, v)` returns a density 0..1 for each
  // grid cell; u and v are 0..1 across the area. Cells inside keep-out rects
  // stay empty so haze never touches text.
  haze(x0, y0, x1, y1, { pitch = 4, dot = defaultDot(pitch), level = () => 3 / 16, color = 'red', opacity = 0.5,
    offset = [0, 0], respectKeepout = true } = {}) {
    const nx = Math.floor((x1 - x0) / pitch), ny = Math.floor((y1 - y0) / pitch);
    for (let gy = 0; gy <= ny; gy++) for (let gx = 0; gx <= nx; gx++) {
      const px = x0 + gx * pitch, py = y0 + gy * pitch;
      if (respectKeepout && this.keepout.some(([a, b, c, d]) => px + dot > a && px < c && py + dot > b && py < d)) continue;
      const L = level(gx, gy, nx ? gx / nx : 0, ny ? gy / ny : 0);
      if (L > 0 && bayerLit(L, gx + offset[0], gy + offset[1])) {
        const k = `${Math.round(px)},${Math.round(py)},${dot}`;
        if (!this.dots.has(k)) this.dot(px, py, dot, { color, opacity });
      }
    }
  }

  // Horizontal scan line: dense in the middle, fading out at both ends.
  scanLine(x0, x1, y, { pitch = 4, rows = 2, peak = 0.6, opacity = 0.85, color = 'red' } = {}) {
    this.haze(x0, y, x1, y + (rows - 1) * pitch, {
      pitch, color, opacity, respectKeepout: false,
      level: (gx, gy, u) => (1 - Math.abs(u * 2 - 1)) * peak * (gy === 0 ? 1 : 0.5),
    });
  }

  bounds() {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const d of this.dots.values()) {
      x0 = Math.min(x0, d.x); y0 = Math.min(y0, d.y);
      x1 = Math.max(x1, d.x + d.size); y1 = Math.max(y1, d.y + d.size);
    }
    return x0 === Infinity ? [0, 0, 0, 0] : [x0, y0, x1, y1];
  }

  // Serialise. `pad` is extra px on every side; `frame` = [x0, y0, x1, y1]
  // fixes the drawing area instead of fitting it to the dots.
  toSVG({ label = 'dot-matrix image', pad = 0, frame = null } = {}) {
    const [bx0, by0, bx1, by1] = frame ?? this.bounds();
    const ox = pad - bx0, oy = pad - by0;
    const W = Math.ceil(bx1 - bx0 + pad * 2), H = Math.ceil(by1 - by0 + pad * 2);
    const groups = new Map(), singles = [];
    const mark = d => {
      const x = d.x + ox, y = d.y + oy, s = d.size;
      if (this.shape === 'round') { const r = s / 2; return `M${r2(x)} ${r2(y + r)}a${r2(r)} ${r2(r)} 0 1 0 ${s} 0a${r2(r)} ${r2(r)} 0 1 0 -${s} 0z`; }
      return `M${x} ${y}h${s}v${s}h-${s}z`;
    };
    for (const d of this.dots.values()) {
      if (d.cls || d.style) { singles.push(d); continue; }
      const k = `${d.color}|${d.opacity}`;
      if (!groups.has(k)) groups.set(k, []);
      groups.get(k).push(mark(d));
    }
    const parts = [];
    for (const [k, ds] of groups) {
      const [color, op] = k.split('|');
      parts.push(`<path fill="${color}"${+op < 1 ? ` fill-opacity="${op}"` : ''} d="${ds.join('')}"/>`);
    }
    for (const d of singles) {
      const x = d.x + ox, y = d.y + oy;
      const attrs = `fill="${d.color}"${d.opacity < 1 ? ` fill-opacity="${d.opacity}"` : ''}${d.cls ? ` class="${esc(d.cls)}"` : ''}${d.style ? ` style="${esc(d.style)}"` : ''}`;
      parts.push(this.shape === 'round'
        ? `<circle cx="${r2(x + d.size / 2)}" cy="${r2(y + d.size / 2)}" r="${r2(d.size / 2)}" ${attrs}/>`
        : `<rect x="${x}" y="${y}" width="${d.size}" height="${d.size}" ${attrs}/>`);
    }
    const style = this.css.length ? `<style>${this.css.join('')}</style>` : '';
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}"` +
      ` shape-rendering="crispEdges" role="img" aria-label="${esc(label)}"><title>${esc(label)}</title>${style}${parts.join('')}</svg>\n`;
  }
}

// ---- one-call helper used by the CLI -------------------------------------------
export function renderText(text, { scale = 6, dot, color = 'red', haze = 'none', diamonds = false, shape = 'square',
  cream = false, upper = false, pad = 1, label } = {}) {
  const pitch = +scale, d = dot ? +dot : defaultDot(pitch);
  const c = new DotCanvas({ shape });
  const lines = String(upper ? text.toUpperCase() : text).split('\n');
  const left = diamonds ? 6 * pitch : 0; // room for the left marker
  const size = c.text(lines.join('\n'), left, 0, { pitch, dot: d, color, highlight: cream ? 'cream' : null });
  if (diamonds) lines.forEach((line, i) => {
    const cy = (i * LINE_ROWS + 3) * pitch;
    c.diamond(2 * pitch, cy, 2, { pitch, dot: d, color });
    c.diamond(left + (measureCols(line) + 4) * pitch, cy, 2, { pitch, dot: d, color });
  });
  const right = left + size.w + (diamonds ? 6 * pitch : 0);
  if (haze === 'scan') c.scanLine(-pitch, right + pitch, size.h + 3 * pitch, { pitch, color });
  if (haze === 'field') {
    c.haze(-3 * pitch, -3 * pitch, right + 3 * pitch, size.h + 3 * pitch, {
      pitch, color, opacity: 0.5,
      level: (gx, gy, u, v) => 1 / 16 + (u < 0.25 && v > 0.5 ? 2 / 16 : 0) + (u > 0.75 && v < 0.5 ? 2 / 16 : 0),
    });
  }
  return c.toSVG({ label: label ?? text.replace(/\n/g, ' '), pad: pad * pitch });
}

// ---- CLI ----------------------------------------------------------------------
function parseArgs(argv) {
  const o = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const k = a.slice(2);
    if (['diamonds', 'cream', 'upper', 'help'].includes(k)) { o[k] = true; continue; }
    o[k] = argv[++i];
  }
  return o;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const o = parseArgs(process.argv.slice(2));
  if (o.help || o.text == null) {
    console.log('usage: node render.mjs --text "TEXT" [--out file.svg] [--scale 6] [--dot 5] [--color red|#hex]\n' +
      '                      [--haze none|scan|field] [--diamonds] [--shape square|round] [--cream] [--upper] [--pad 1] [--label "..."]');
    process.exit(o.help ? 0 : 1);
  }
  try {
    const svg = renderText(o.text.replace(/\\n/g, '\n'), {
      scale: o.scale ?? o.pitch ?? 6, dot: o.dot, color: o.color, haze: o.haze ?? 'none', diamonds: !!o.diamonds,
      shape: o.shape ?? 'square', cream: !!o.cream, upper: !!o.upper, pad: o.pad != null ? +o.pad : 1, label: o.label,
    });
    if (o.out) { writeFileSync(o.out, svg); console.log(`${o.out}  ${svg.length} bytes`); }
    else process.stdout.write(svg);
  } catch (e) {
    console.error(`render.mjs: ${e.message}`);
    process.exit(1);
  }
}

#!/usr/bin/env node
// Regenerates every dot-matrix image the READMEs use, into lidar-knight/art/.
//   node lidar-knight/dotmatrix/build-art.mjs
// Output is deterministic: running it twice gives byte-identical files.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DotCanvas, measureCols, PALETTE } from './render.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const OUT = join(here, '..', 'art');
mkdirSync(OUT, { recursive: true });

const written = [];
const save = (name, svg) => { writeFileSync(join(OUT, name), svg); written.push(`${name}  ${svg.length} B`); };

// README art always draws the highlight dot (the dot of the i) in red: cream
// disappears on GitHub's white background. The app uses cream.
const README = { color: 'red', highlight: null };

// ---- 1. hero wordmark ---------------------------------------------------------
{
  const P = 8, c = new DotCanvas();
  const t = c.text('LiDAR-Knight Auth', 0, 0, { pitch: P, ...README });
  c.scanLine(-2 * P, t.w + 2 * P, t.h + 4 * P, { pitch: P, rows: 2, peak: 0.6 });
  save('title.svg', c.toSVG({ label: 'LiDAR-Knight Auth', pad: P }));
}

// ---- 2. emblem: outline diamond around a dot keyhole ---------------------------
{
  const P = 6, c = new DotCanvas(), R = 12, cx = 0, cy = 0;
  // keyhole: round head, narrow neck, flared foot
  const KEYHOLE = ['..###..', '.#####.', '.#####.', '.#####.', '..###..', '...#...', '..###..', '..###..', '.#####.'];
  KEYHOLE.forEach((row, ry) => [...row].forEach((ch, rx) => { if (ch === '#') c.dot(cx + (rx - 3) * P, cy + (ry - 5) * P, 5); }));
  c.keepout.push([cx - 5 * P, cy - 7 * P, cx + 6 * P, cy + 6 * P]);
  c.diamond(cx, cy, R, { pitch: P });
  c.keepout.pop(); // the big diamond's own keep-out would block the inner haze
  c.diamond(cx, cy - R * P, 1, { pitch: P, fill: true });               // bright point at the top
  // faint outer ring, every other dot
  for (let dy = -(R + 3); dy <= R + 3; dy++) for (let dx = -(R + 3); dx <= R + 3; dx++)
    if (Math.abs(dx) + Math.abs(dy) === R + 3 && ((dx % 2) + 2) % 2 === 0) c.dot(cx + dx * P, cy + dy * P, 5, { opacity: 0.45 });
  // haze inside the diamond, thicker towards the lower-left and upper-right
  const H = 3; // haze runs at a finer pitch than the outline
  c.haze(cx - (R - 1) * P, cy - (R - 1) * P, cx + R * P, cy + R * P, {
    pitch: H, dot: 2, opacity: 0.5, offset: [1, 2],
    level: (gx, gy, u, v) => {
      const dx = u * 2 - 1, dy = v * 2 - 1;
      if (Math.abs(dx) + Math.abs(dy) > 0.86) return 0;
      return 2 / 16 + ((dx < -0.1 && dy > 0.1) || (dx > 0.1 && dy < -0.1) ? 4 / 16 : 0);
    },
  });
  save('emblem.svg', c.toSVG({ label: 'Emblem: a keyhole inside a diamond, drawn in red dots', pad: P }));
}

// ---- 3. section headers ----------------------------------------------------------
const HEADERS = {
  'what-it-is': 'WHAT IT IS',
  'where-it-comes-from': 'WHERE IT COMES FROM',
  safety: 'SAFETY',
  'what-leaves-the-device': 'WHAT LEAVES THE DEVICE',
  install: 'INSTALL',
  build: 'BUILD',
  'report-a-problem': 'REPORT A PROBLEM',
  credits: 'CREDITS',
  license: 'LICENSE',
  'changes-from-upstream': 'CHANGES FROM UPSTREAM',
  'the-rest-of-this-repo': 'THE REST OF THIS REPO',
};
for (const [slug, text] of Object.entries(HEADERS)) {
  const P = 6, c = new DotCanvas();
  c.text('◆', 0, 0, { pitch: P });
  const t = c.text(text, 5 * P, 0, { pitch: P, ...README });
  // a one-row scan line that fades out to the right
  c.haze(0, 9 * P, 5 * P + t.w + 6 * P, 9 * P, { pitch: P, respectKeepout: false, opacity: 0.8, level: (gx, gy, u) => (1 - u) * 0.75 });
  save(`h-${slug}.svg`, c.toSVG({ label: text.charAt(0) + text.slice(1).toLowerCase(), pad: P }));
}

// ---- 4. code mock: one selected row, live countdown ------------------------------
{
  const c = new DotCanvas();
  const X = 48, W = 640, H = 196, M = 28; // card origin, size, inner margin
  const P4 = { pitch: 4, dot: 3 };

  // line 1: issuer, separator, account
  const issuer = 'EXAMPLE ◆';
  c.text(issuer, X + M, M, { ...P4 });
  c.text('me@example.com', X + M + (measureCols(issuer) + 4) * 4, M, { ...P4, opacity: 0.7 });

  // line 2: the code, grouped 3 + 3
  const yCode = M + 52;
  const code = c.text('004 104', X + M, yCode, { pitch: 8, dot: 6 });

  // next code, right edge, half strength
  const nextW = measureCols('271 828') * 4;
  const xNext = X + W - M - nextW;
  c.text('next', xNext, yCode + code.h - 28 - 40, { ...P4, opacity: 0.5 });
  c.text('271 828', xNext, yCode + code.h - 28, { ...P4, opacity: 0.5 });

  // line 3: countdown, one dot per second; lit dots go out from the right and
  // the next one to go blinks at 2 Hz. Static frame: 19 s left.
  const yBar = yCode + code.h + 20, LEFT = 19, N = 30, CP = 10;
  const kf = [];
  for (let i = 0; i < N; i++) {
    c.dot(X + M + i * CP, yBar, 6, { opacity: i < LEFT ? 1 : 0.2, cls: `c c${i}` });
    const a = ((N - 1 - i) / N) * 100, b = ((N - i) / N) * 100, q = 100 / (N * 4); // q = 0.25 s
    const p = n => `${+n.toFixed(4)}%`;
    kf.push(`@keyframes k${i}{0%{fill-opacity:1}${p(a)}{fill-opacity:1}${p(a + q)}{fill-opacity:.35}${p(a + 2 * q)}{fill-opacity:1}` +
      `${p(a + 3 * q)}{fill-opacity:.35}${p(b)}{fill-opacity:.2}100%{fill-opacity:.2}}.c${i}{animation-name:k${i}}`);
  }
  c.css.push(`.c{animation:none 30s step-end -${N - LEFT}s infinite}`, ...kf,
    '@media (prefers-reduced-motion:reduce){.c{animation:none!important}}');

  // selected row: full-strength dotted outline and outline diamonds at both ends
  c.outline(X, 0, W, H, { pitch: 4, dot: 3 });
  c.diamond(X - 24, H / 2, 3, { pitch: 4, dot: 3 });
  c.diamond(X + W + 24, H / 2, 3, { pitch: 4, dot: 3 });

  // haze outside the card, thicker towards the lower-left and upper-right
  c.keepout.push([X - 8, -8, X + W + 8, H + 8]);
  c.haze(0, -36, X + W + 48, H + 36, {
    pitch: 4, dot: 3, opacity: 0.4, offset: [2, 1],
    level: (gx, gy, u, v) => {
      const ll = Math.max(0, 1 - Math.hypot(u, 1 - v) * 1.6), ur = Math.max(0, 1 - Math.hypot(1 - u, v) * 1.6);
      return Math.min(6 / 16, (ll + ur) * 0.5);
    },
  });
  save('code-mock.svg', c.toSVG({ label: 'Example code row for me@example.com: 004 104, with a dotted countdown and the next code 271 828', pad: 4,
    frame: [0, -36, X + W + 48, H + 36] }));
}

// ---- 5. divider ---------------------------------------------------------------------
{
  const c = new DotCanvas(), P = 4, W = 720, cx = W / 2;
  c.diamond(cx, 8, 3, { pitch: P, dot: 3 });
  c.diamond(cx, 8, 1, { pitch: P, dot: 3, fill: true });
  c.haze(0, 4, W, 12, {
    pitch: P, dot: 3, opacity: 0.85, respectKeepout: true,
    level: (gx, gy, u) => (1 - Math.abs(u * 2 - 1)) * (gy === 1 ? 1 : 0.35),
  });
  save('divider.svg', c.toSVG({ label: 'Divider', pad: 4, frame: [0, -8, W, 24] }));
}

// ---- 6. tagline with a blinking cursor --------------------------------------------
{
  const c = new DotCanvas(), P = 4;
  const t = c.text('> two-factor codes, made of dots', 0, 0, { pitch: P, dot: 3 });
  for (let dy = 0; dy < 7; dy++) for (let dx = 0; dx < 2; dx++) c.dot(t.w + (2 + dx) * P, dy * P, 3, { cls: 'cur' });
  c.css.push('.cur{animation:b 1s step-end infinite}@keyframes b{50%{fill-opacity:0}}',
    '@media (prefers-reduced-motion:reduce){.cur{animation:none}}');
  save('tagline.svg', c.toSVG({ label: '> two-factor codes, made of dots', pad: P }));
}

// ---- 7. badges -----------------------------------------------------------------------
const BADGES = {
  agpl: 'AGPL-3.0',
  fork: 'FORK OF ENTE AUTH',
  offline: 'OFFLINE-FIRST',
  totp: 'TOTP · RFC 6238',
};
for (const [slug, text] of Object.entries(BADGES)) {
  const P = 3, c = new DotCanvas();
  c.text('◆', 4 * P, 4 * P, { pitch: P, dot: 2 });
  const t = c.text(text, 9 * P, 4 * P, { pitch: P, dot: 2 });
  c.outline(0, 0, t.w + 13 * P, 15 * P, { pitch: P, dot: 2, opacity: 0.6 });
  save(`badge-${slug}.svg`, c.toSVG({ label: text, pad: 1 }));
}

console.log(`wrote ${written.length} files to ${OUT}\n  ${written.join('\n  ')}`);
console.log(`palette: red ${PALETTE.red} (all information), cream ${PALETTE.cream} (app highlights only)`);

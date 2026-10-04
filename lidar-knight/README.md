<div align="center">

<img src="art/title.svg" alt="LiDAR-Knight Auth" width="806">

</div>

```text
> ls lidar-knight/
  dotmatrix/render.mjs ..... dot-matrix font and SVG renderer (node, no dependencies)
  dotmatrix/build-art.mjs .. regenerates every image the READMEs use
  dotmatrix/check.mjs ...... checks the SVGs are well-formed and follow the rules below
  art/ ..................... the generated SVGs
```

This folder holds the visual layer of the repository. Every image here is drawn from code: separate square dots on a strict grid, with a transparent background. There are no fonts, no `<text>` elements, no background shapes and no external files, so each image reads the same on GitHub's light and dark themes.

<img src="art/divider.svg" alt="" width="728">

## Generate

Run these from the repository root. Node 18 or newer, no `npm install` needed.

```sh
node lidar-knight/dotmatrix/build-art.mjs   # rewrite everything in lidar-knight/art/
node lidar-knight/dotmatrix/check.mjs       # well-formed XML, palette colours only, no text/fonts/links
```

The output is deterministic: running the build twice gives byte-identical files, so a diff shows only real changes.

To make a single image:

```sh
node lidar-knight/dotmatrix/render.mjs --text "SAFETY" --out safety.svg
node lidar-knight/dotmatrix/render.mjs --text "LiDAR-Knight Auth" --out title.svg --scale 8 --haze scan
node lidar-knight/dotmatrix/render.mjs --text "004 104" --out code.svg --scale 8 --diamonds
node lidar-knight/dotmatrix/render.mjs --text "line one\nline two" --out two.svg --haze field
```

| Option | Default | Meaning |
|---|---|---|
| `--text` | (required) | The text. `\n` starts a new line. |
| `--out` | stdout | Output file. |
| `--scale` (or `--pitch`) | `6` | Distance between dot centres in px. |
| `--dot` | pitch − 1 (up to 6), then ¾ of the pitch | Dot size in px. The gap between dots is what makes it read as a point cloud. |
| `--color` | `red` | A palette name (below) or `#hex`. |
| `--haze` | `none` | `scan` adds a dithered scan line under the text. `field` adds sparse haze around it. |
| `--diamonds` | off | Outline diamond markers at both ends of each line. |
| `--shape` | `square` | `square` or `round`. Square is the house style. |
| `--cream` | off | Draws the dot of a lowercase `i` or `j` in cream. Leave it off for READMEs, because cream disappears on white. |
| `--upper` | off | Upper-cases the text first. |
| `--pad` | `1` | Empty cells around the drawing. |
| `--label` | the text | Accessible name: `aria-label` and `<title>`. |

`render.mjs` also exports `DotCanvas`, `GLYPHS`, `PALETTE`, `BAYER4` and `measureCols` for scripts like `build-art.mjs`.

## The font

- **Grid.** Each cell is 5 columns × 7 rows, and the baseline is row 6. Lowercase `g j p q y` and the comma use two descender rows below it.
- **Spacing.** Each glyph advances 6 columns (its width plus a 1-column gap). A space is 3 more columns. Lines are 10 rows apart.
- **Character set.** `0-9`, `A-Z`, `a-z`, and `- _ . , : ; ! ? ' " / \ | ( ) [ ] < > = + * # $ % & @ ~ × ·`, plus `◆` (a filled 3×3 diamond, used for bullets and separators) and `◇` (an outline diamond, used for markers). Anything else draws as `?`.
- **Zero.** `0` has a dot in the middle, so it never reads as `O` or `8`.
- **The `i`.** The dot of a lowercase `i` is a highlight dot. It is cream in the app and red in READMEs.

## Palette

| Token | Hex | Use |
|---|---|---|
| `red` | `#FF2A12` | Every dot that carries information: text, digits, outlines. Contrast is about 3.8:1 on GitHub light (`#FFFFFF`) and about 5.0:1 on GitHub dark (`#0D1117`), which passes the 3:1 rule for large text and graphics on both. |
| `cream` | `#FFD8CC` | Highlight dots only, at most about 3% of all dots: the dot of the `i`, an expiring countdown, a copy flash, a toggle knob. Decoration only, because it is about 1.3:1 on white. |
| `redDim` | `#7A1A10` | Haze and disabled states. Never text. |
| `redDeep` | `#3A160A` | Pressed-state fill at low density. |
| `hot` | `#FF5A2A` | Hover glow on a close button. Nothing else. |
| `black` | `#000000` | The base under translucent app surfaces. In READMEs the background is transparent. |

**Shading** is never a gradient. It uses a 4×4 ordered (Bayer) dither: a dot at `(x, y)` is lit when `level × 16 > M[y mod 4][x mod 4]`.

```text
 0  8  2 10
12  4 14  6
 3 11  1  9
15  7 13  5
```

**Motion** is used sparingly:

- The code mock's countdown loses one dot per second, and the next dot to go out blinks at 2 Hz.
- The tagline cursor blinks.
- Both are CSS inside the SVG, and both stop when the viewer has asked for reduced motion.

## Current images (`art/`)

| File | What it is |
|---|---|
| `title.svg` | The wordmark, pitch 8, with a dithered scan line |
| `emblem.svg` | A dot keyhole inside an outline diamond, with haze inside it |
| `tagline.svg` | `> two-factor codes, made of dots` with a blinking cursor |
| `code-mock.svg` | One selected code row: `004 104`, a live 30-dot countdown and the next code |
| `divider.svg` | A dithered rule with a diamond at the centre |
| `h-*.svg` | Section headers, pitch 6, with a scan line that fades to the right |
| `badge-*.svg` | Dotted-outline badges: `FORK OF ENTE AUTH`, `AGPL-3.0`, `OFFLINE-FIRST`, `TOTP · RFC 6238` |

## Assets to generate

These images are for an image model to make, or for drawing by hand. All of them are **transparent PNGs with real alpha** unless a row says otherwise.

| File | Size | Content |
|---|---|---|
| `lidar-knight/art/hero.png` | 1600×560 | The app window floating in dot haze, with the code `001 104` visible. |
| `lidar-knight/art/screens/list.png` | 900×1200 | Mock of the code list: the rows look like `code-mock.svg`, under a dot title bar. |
| `lidar-knight/art/screens/focus.png` | 900×1200 | Mock of the single-code view: big digits, with the countdown as a ring of 30 square dots. |
| `lidar-knight/art/screens/empty.png` | 900×1200 | Mock of the empty state: an outline diamond, `NO CODES YET`, and a dotted `+` button. |
| `lidar-knight/art/divider-scan.png` | 1600×24 | A horizontal Bayer scan line, dense in the middle and fading out at both ends. |
| `mobile/apps/auth/assets/brand/icon-1024.png` | 1024×1024 | App icon: an outline diamond of square dots around a dot keyhole, with a cream dot at the top point. **Also make an opaque version on `#000000` for iOS**, because iOS icons must not have alpha. |
| `mobile/apps/auth/assets/brand/lock-art.png` | 1080×1920 | Lock-screen art: the outline diamond emblem, centred in abstract dot haze. |
| `lidar-knight/art/social-preview.png` | 1280×640, **opaque `#000000`** | GitHub social card: the wordmark and the diamond emblem. |
| tray icons and favicons | 16, 32, 64 | **Draw these by hand on the grid.** Image models cannot place exact pixels at these sizes. |

**Prompt style line.** Add this to every prompt:

> Abstract LiDAR point-cloud render made ONLY of tiny separated square dots on a strict pixel grid; hot red-orange #FF2A12 dots, rare cream #FFD8CC highlight dots; all shading by 4x4 ordered Bayer dithering; no gradients, no blur, no glow, no anti-aliasing, no outlines, no text, no characters or figures; fully transparent background (true alpha, no checkerboard, no black fill); flat, crisp, orthographic.

**Post-processing is required.** Image models produce soft, off-grid dots, and often paint a fake checkerboard where the transparency should be. For every generated image:

1. Downsample it to the dot pitch, so that one pixel is one dot.
2. Threshold it with the Bayer matrix to black, red and cream only.
3. Redraw each lit pixel as a square dot with a 1 px gap.
4. Set the black pixels to alpha 0. Skip this step for the two opaque files.

**Keep out of every image:**

- any text other than the wordmark and the code digits
- people, figures, creatures or characters
- buildings, landscapes or scenery
- screenshots of anything except this app
- any colour outside the palette

## Rules for new art

- Square dots, a strict grid and a transparent background.
- Use red for anything that carries information. Use cream only for highlights.
- Shade with Bayer dithering only.
- Give every image alt text, plus an `aria-label` and a `<title>` in the SVG.
- Run `check.mjs` before committing.

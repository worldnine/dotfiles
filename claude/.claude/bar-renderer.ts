#!/usr/bin/env bun
/**
 * bar-renderer.ts - 高解像度バーレンダラー
 *
 * 背景色 + eighth-block 遷移セルで 10セル × 8段階 = 80段階の解像度を実現。
 *
 * 描画方式:
 *   - Filled セル: スペース + 背景色
 *   - 遷移セル:   eighth-block (▏▎▍▌▋▊▉) + FG=バー色 / BG=空色
 *   - Empty セル:  スペース + 暗い背景色
 *   - マーカー:    │ + FG=ピンク / BG=セルの状態に応じた色
 *
 * 使用方法:
 *   bun run bar-renderer.ts <pct> <width> [<target>] [<color>]
 *   bun run bar-renderer.ts <pct1> <width1> <target1> <color1> -- <pct2> ...
 *
 * 引数:
 *   pct    - 使用率 0-100
 *   width  - バー幅（セル数、デフォルト 10）
 *   target - ペーシングターゲット 0-100（-1 で無効、デフォルト -1）
 *   color  - "default" | "orange" | "red"（デフォルト "default"）
 *
 * 出力: 1行につき1本の ANSI エスケープ付きバー文字列
 */

// eighth-block: index 0 = 1/8幅、index 6 = 7/8幅
const EIGHTH_BLOCKS = ["▏", "▎", "▍", "▌", "▋", "▊", "▉"];
const SUB_PER_CELL = 8;

type ColorName = "default" | "orange" | "red";
type RGB = [number, number, number];

// バーのフィル色（背景色として使用、暗めに調整）
const FILLED: Record<ColorName, RGB> = {
  default: [100, 110, 135],
  orange: [180, 100, 0],
  red: [180, 60, 60],
};

// 空セルの背景色（暗いブルーグレー）
const EMPTY: RGB = [50, 50, 65];

// ペーシングマーカーの前景色（ANSI 174 相当の淡ピンク）
const MARKER: RGB = [215, 135, 135];

const bg = (r: number, g: number, b: number) => `\x1b[48;2;${r};${g};${b}m`;
const fg = (r: number, g: number, b: number) => `\x1b[38;2;${r};${g};${b}m`;
const RST = "\x1b[0m";

interface BarSpec {
  pct: number;
  width: number;
  target: number;
  color: ColorName;
}

function render(s: BarSpec): string {
  const fill = FILLED[s.color] ?? FILLED.default;
  const total = s.width * SUB_PER_CELL;

  // サブレベル数を計算（0〜total）
  let filled = Math.round((s.pct / 100) * total);
  filled = Math.max(0, Math.min(total, filled));

  // >0% なら最低1サブレベル保証（最小バー表示）
  if (s.pct > 0 && filled === 0) filled = 1;

  const fullCells = Math.floor(filled / SUB_PER_CELL);
  const partial = filled % SUB_PER_CELL; // 0-7

  // ターゲット位置（セル単位、-1 = 無効）
  const tgt =
    s.target >= 0 && s.target <= 100
      ? Math.min(Math.floor((s.target / 100) * s.width), s.width - 1)
      : -1;

  let out = "";
  for (let i = 0; i < s.width; i++) {
    if (i === tgt) {
      // ペーシングマーカー: BG はセルのフィル状態で決定
      const isFilled =
        i < fullCells || (i === fullCells && partial >= SUB_PER_CELL / 2);
      const cbg = isFilled ? fill : EMPTY;
      out += bg(...cbg) + fg(...MARKER) + "│" + RST;
    } else if (i < fullCells) {
      // 完全にフィルされたセル: スペース + バー色BG
      out += bg(...fill) + " " + RST;
    } else if (i === fullCells && partial > 0) {
      // 遷移セル: eighth-block + FG=バー色 / BG=空色
      out += bg(...EMPTY) + fg(...fill) + EIGHTH_BLOCKS[partial - 1] + RST;
    } else {
      // 空セル: スペース + 暗いBG
      out += bg(...EMPTY) + " " + RST;
    }
  }
  return out;
}

function parse(args: string[]): BarSpec {
  return {
    pct: Math.max(0, Math.min(100, parseInt(args[0]) || 0)),
    width: parseInt(args[1]) || 10,
    target: args.length > 2 ? parseInt(args[2]) : -1,
    color: (args.length > 3 ? args[3] : "default") as ColorName,
  };
}

// --- メイン: 引数解析（`--` 区切りで複数バー対応） ---
const argv = process.argv.slice(2);
const groups: string[][] = [];
let cur: string[] = [];

for (const a of argv) {
  if (a === "--") {
    if (cur.length) groups.push(cur);
    cur = [];
  } else {
    cur.push(a);
  }
}
if (cur.length) groups.push(cur);

for (const g of groups) {
  process.stdout.write(render(parse(g)) + "\n");
}

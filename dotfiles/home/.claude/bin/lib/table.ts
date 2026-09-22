/**
 * Column layout for terminal output, shared by the printed list and the
 * picker so both align the same way and neither owns the arithmetic.
 */
import stringWidth from "string-width";

export interface Tone {
  readonly color?:
    | "black"
    | "red"
    | "green"
    | "yellow"
    | "blue"
    | "magenta"
    | "cyan"
    | "white"
    | "gray";
  readonly dim?: boolean;
  readonly bold?: boolean;
}

export interface Column {
  readonly key: string;
  readonly header: string;
  /** How the column's cells are drawn, by both renderers. */
  readonly tone?: Tone;
  readonly align?: "left" | "right";
  /** Exact width, for content whose size is known (a timestamp, a count). */
  readonly width?: number;
  /** Lower bound when sharing out what's left; below this the column is cut. */
  readonly min?: number;
  readonly max?: number;
  /**
   * Which end to cut when the text doesn't fit. Paths elide from the start,
   * since sibling worktrees differ only in their tail.
   */
  readonly elide?: "start" | "end";
  /** Absorbs the width left over once the other columns are placed. */
  readonly flex?: boolean;
  /** Dropped entirely when the terminal is too narrow for everything. */
  readonly optional?: boolean;
}

export const GAP = "  ";

/**
 * Widths per column, leaving out any there was no room for.
 *
 * A narrow terminal should lose context before it loses content, so the order
 * of sacrifice is: shrink the sized columns toward their minimums, then drop
 * the optional ones, and only ever give the flexible column what is left. The
 * flexible column is never dropped, because it holds the thing being listed.
 */
export const layout = (
  columns: readonly Column[],
  available: number,
): ReadonlyMap<string, number> => {
  const attempt = (shown: readonly Column[]): ReadonlyMap<string, number> | undefined => {
    const flexible = shown.find((column) => column.flex);
    const gaps = GAP.length * Math.max(shown.length - 1, 0);
    const sized = shown.filter((column) => column !== flexible);
    const natural = new Map(
      sized.map((column) => [column.key, column.width ?? column.max ?? column.min ?? 0]),
    );
    const floor = (column: Column): number => column.width ?? column.min ?? 0;

    const spare = () =>
      available -
      gaps -
      [...natural.values()].reduce((total, width) => total + width, 0) -
      (flexible?.min ?? 0);

    // Take from the widest shrinkable column first, so one long path gives way
    // before several short ones are squeezed to nothing.
    while (spare() < 0) {
      const shrinkable = sized
        .filter((column) => natural.get(column.key)! > floor(column))
        .sort((left, right) => natural.get(right.key)! - natural.get(left.key)!);
      const widest = shrinkable[0];
      if (!widest) return undefined;
      natural.set(
        widest.key,
        Math.max(floor(widest), natural.get(widest.key)! + spare()),
      );
    }

    return new Map([
      ...natural,
      ...(flexible
        ? ([[flexible.key, (flexible.min ?? 0) + spare()]] as const)
        : ([] as const)),
    ]);
  };

  const droppable = columns.filter((column) => column.optional);
  // Drop optional columns last-first, so the ones nearest the content go last.
  return (
    [...Array(droppable.length + 1).keys()]
      .map((dropped) => {
        const gone = new Set(droppable.slice(droppable.length - dropped));
        return columns.filter((column) => !gone.has(column));
      })
      .map((shown) => attempt(shown))
      .find((result) => result !== undefined) ??
    new Map([[columns.find((column) => column.flex)?.key ?? columns[0]!.key, available]])
  );
};

const ELLIPSIS = "…";

/** Cut `text` to `width` display columns, marking where it was cut. */
export const truncate = (text: string, width: number, elide: "start" | "end"): string => {
  if (stringWidth(text) <= width) return text;
  if (width <= 1) return ELLIPSIS.slice(0, width);

  const characters = [...text];
  const room = width - 1;
  if (elide === "start") {
    const kept = characters.reduceRight<string>(
      (accumulated, character) =>
        stringWidth(character + accumulated) <= room ? character + accumulated : accumulated,
      "",
    );
    return `${ELLIPSIS}${kept}`;
  }
  const kept = characters.reduce<string>(
    (accumulated, character) =>
      stringWidth(accumulated + character) <= room ? accumulated + character : accumulated,
    "",
  );
  return `${kept}${ELLIPSIS}`;
};

export interface CellOptions {
  readonly elide?: "start" | "end";
  readonly align?: "left" | "right";
  /** Off for the last column of a row, which would only trail whitespace. */
  readonly pad?: boolean;
}

/** Cut and pad `text` so it occupies exactly `width` display columns. */
export const cell = (
  text: string,
  width: number,
  { elide = "end", align = "left", pad = true }: CellOptions = {},
): string => {
  const cut = truncate(text, width, elide);
  if (!pad) return align === "right" ? cut.padStart(width) : cut;
  const padding = " ".repeat(Math.max(width - stringWidth(cut), 0));
  return align === "right" ? padding + cut : cut + padding;
};

const DAY = 24 * 60 * 60 * 1000;

/**
 * A short, fixed-width age: minutes and hours for today, days for the past
 * week, then the calendar date. Six columns is enough for all three, where a
 * full timestamp costs sixteen and says less at a glance.
 */
export const age = (moment: Date, now: Date = new Date()): string => {
  const elapsed = now.getTime() - moment.getTime();
  if (elapsed < 60 * 60 * 1000) return `${Math.max(Math.round(elapsed / 60_000), 1)}m`;
  if (elapsed < DAY) return `${Math.round(elapsed / (60 * 60 * 1000))}h`;
  if (elapsed < 7 * DAY) return `${Math.round(elapsed / DAY)}d`;
  return moment.toLocaleDateString("en-US", { month: "short", day: "numeric" });
};

export const AGE_WIDTH = 6;

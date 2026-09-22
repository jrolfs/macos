/**
 * A filterable table for the helpers to pick a row from.
 *
 * Drawn on stderr, so a caller can read the choice off stdout: the shell
 * function wrapping one of these wants the id, not the interface. Typing
 * filters, since a picker worth using is one you don't have to scroll.
 *
 * Columns come from the same layout the printed list uses, so a thread looks
 * the same whether you are picking it or reading about it, and both follow the
 * width of the terminal they are in.
 */
import { Box, render, Text, useApp, useInput, useStdout } from "ink";
import { useCallback, useEffect, useMemo, useState } from "react";

import { cell, GAP, layout, type Column } from "./table.ts";

export interface PickerItem {
  readonly key: string;
  /** Text per column key, matching the columns handed to the picker. */
  readonly cells: Readonly<Record<string, string>>;
}

export interface PickerOptions {
  readonly items: readonly PickerItem[];
  readonly columns: readonly Column[];
  readonly heading: string;
  /** How many rows of the list to show at once. */
  readonly rows?: number;
}

interface Span {
  readonly start: number;
  readonly end: number;
}

/**
 * How well `haystack` matches `needle`, or undefined for not at all.
 *
 * Matching is by subsequence, so `flpl` finds "FloorPlan" the way the fuzzy
 * finder this replaces did, but scoring has to rank as well as admit: over
 * fifty threads, a loose query matches a third of them and the ones that
 * contain it outright are what you meant. Whole-word and contiguous matches
 * therefore beat scattered ones, and shorter spans beat longer.
 */
const score = (haystack: string, needle: string): number | undefined => {
  if (!needle) return 0;
  const target = haystack.toLowerCase();
  const query = needle.toLowerCase();

  const direct = target.indexOf(query);
  if (direct !== -1) return 1000 - Math.min(direct, 500);

  const span = [...query].reduce<Span | undefined>((found, character) => {
    if (!found) return undefined;
    const at = target.indexOf(character, found.end);
    return at === -1 ? undefined : { start: Math.min(found.start, at), end: at + 1 };
  }, { start: Number.MAX_SAFE_INTEGER, end: 0 });

  return span ? 500 - Math.min(span.end - span.start, 500) : undefined;
};

// Escape sequences and stray control bytes would otherwise become filter text
// that matches nothing.
const CONTROL_CHARACTERS = /[\u0000-\u001f\u007f]/gu;

const MARKER = "▍";

/** Terminal width, following resizes. */
const useWidth = (stream: NodeJS.WriteStream): number => {
  const [width, setWidth] = useState(stream.columns || 80);
  useEffect(() => {
    const onResize = () => setWidth(stream.columns || 80);
    stream.on("resize", onResize);
    return () => {
      stream.off("resize", onResize);
    };
  }, [stream]);
  return width;
};

interface PickerProps extends PickerOptions {
  readonly onChoose: (item: PickerItem | undefined) => void;
}

const Picker = ({ items, columns, heading, rows = 12, onChoose }: PickerProps) => {
  const { exit } = useApp();
  const { stdout } = useStdout();
  const [filter, setFilter] = useState("");
  const [cursor, setCursor] = useState(0);

  // Two for the border, two for the padding, one for the selection marker.
  const width = Math.max(useWidth(stdout) - 5, 20);
  const widths = useMemo(() => layout(columns, width), [columns, width]);
  const shown = columns.filter((column) => widths.has(column.key));

  const matching = useCallback(
    (needle: string) =>
      items
        .map((item) => ({ item, score: score(Object.values(item.cells).join(" "), needle) }))
        .filter((scored) => scored.score !== undefined)
        // Sort is stable, so equally good matches stay in the order they came,
        // which for threads is newest first.
        .sort((left, right) => right.score! - left.score!)
        .map((scored) => scored.item),
    [items],
  );
  const visible = useMemo(() => matching(filter), [matching, filter]);
  // Filtering can shorten the list under the cursor between renders.
  const selected = Math.min(cursor, Math.max(visible.length - 1, 0));

  useInput((input, key) => {
    const choose = (item: PickerItem | undefined) => {
      onChoose(item);
      exit();
    };
    if (key.escape || (key.ctrl && input === "c")) return choose(undefined);
    if (key.return) return choose(visible[selected]);
    if (key.downArrow || (key.ctrl && input === "n")) {
      return setCursor(Math.min(selected + 1, visible.length - 1));
    }
    if (key.upArrow || (key.ctrl && input === "p")) {
      return setCursor(Math.max(selected - 1, 0));
    }
    if (key.backspace || key.delete) {
      setCursor(0);
      return setFilter(filter.slice(0, -1));
    }
    if (!input || key.ctrl || key.meta) return;

    // Typed characters arrive in chunks, not one per keystroke, so a return
    // can land in the middle of one and never be reported as key.return.
    // Whatever precedes it is the filter, and the pick applies to that.
    const [typed = "", ...remainder] = input.split(/[\r\n]/);
    const next = filter + typed.replaceAll(CONTROL_CHARACTERS, "");
    if (remainder.length) return choose(matching(next)[0]);
    setCursor(0);
    setFilter(next);
  });

  const start = Math.max(0, Math.min(selected - Math.floor(rows / 2), visible.length - rows));
  const window = visible.slice(start, start + rows);

  return (
    <Box flexDirection="column" borderStyle="round" borderDimColor paddingX={1}>
      <Box>
        <Text bold>{heading}</Text>
        <Text dimColor>
          {GAP}
          {visible.length === items.length
            ? `${items.length}`
            : `${visible.length} of ${items.length}`}
        </Text>
      </Box>

      <Box>
        <Text color="cyan">❯ </Text>
        <Text>{filter || ""}</Text>
        {filter ? undefined : <Text dimColor>type to filter</Text>}
      </Box>

      <Box>
        <Text dimColor>{" "}</Text>
        {shown.map((column, index) => (
          <Text key={column.key} dimColor>
            {index ? GAP : ""}
            {cell(column.header, widths.get(column.key)!, {
              align: column.align,
              pad: index < shown.length - 1,
            })}
          </Text>
        ))}
      </Box>

      {window.map((item, index) => {
        const current = start + index === selected;
        return (
          <Box key={item.key}>
            <Text color="cyan">{current ? MARKER : " "}</Text>
            {shown.map((column, position) => (
              <Text
                key={column.key}
                color={current ? "cyan" : column.tone?.color}
                dimColor={!current && column.tone?.dim}
                bold={current || column.tone?.bold}
              >
                {position ? GAP : ""}
                {cell(item.cells[column.key] ?? "", widths.get(column.key)!, {
                  elide: column.elide,
                  align: column.align,
                  pad: position < shown.length - 1,
                })}
              </Text>
            ))}
          </Box>
        );
      })}

      {visible.length ? undefined : <Text dimColor> nothing matches</Text>}
      <Text dimColor>↑↓ move · ⏎ pick · esc cancel</Text>
    </Box>
  );
};

/**
 * Show the list and resolve with what was picked, or undefined if cancelled.
 *
 * Requires a terminal on stdin for key input; callers without one should print
 * a plain list instead.
 */
export const pick = async (options: PickerOptions): Promise<PickerItem | undefined> => {
  let chosen: PickerItem | undefined;
  const instance = render(
    <Picker
      {...options}
      onChoose={(item) => {
        chosen = item;
      }}
    />,
    {
      stdout: process.stderr as NodeJS.WriteStream,
      exitOnCtrlC: false,
      // Ink routes console output through its own renderer, which would send
      // a caller's result to stderr along with the interface.
      patchConsole: false,
    },
  );
  await instance.waitUntilExit();
  return chosen;
};

/**
 * A filterable list for the helpers to pick from.
 *
 * Drawn on stderr, so a caller can read the choice off stdout: the shell
 * function wrapping one of these wants the id, not the interface. Typing
 * filters, since a picker worth using is one you don't have to scroll.
 */
import { Box, render, Text, useApp, useInput } from "ink";
import { useCallback, useMemo, useState } from "react";

export interface PickerItem {
  readonly key: string;
  readonly label: string;
  /** Dimmed line under the label, for a path or other context. */
  readonly detail?: string;
}

export interface PickerOptions {
  readonly items: readonly PickerItem[];
  readonly heading: string;
  /** How many rows of the list to show at once. */
  readonly rows?: number;
}

/**
 * Whether every character of `needle` appears in `haystack`, in order.
 *
 * Subsequence rather than substring, so `flpl` finds "FloorPlan" the way the
 * fuzzy finder this replaces did.
 */
const matches = (haystack: string, needle: string): boolean => {
  const target = haystack.toLowerCase();
  const end = [...needle.toLowerCase()].reduce<number | undefined>((index, character) => {
    if (index === undefined) return undefined;
    const found = target.indexOf(character, index);
    return found === -1 ? undefined : found + 1;
  }, 0);
  return end !== undefined;
};

// Escape sequences and stray control bytes would otherwise become filter
// text that matches nothing.
const CONTROL_CHARACTERS = /[\u0000-\u001f\u007f]/gu;

interface PickerProps extends PickerOptions {
  readonly onChoose: (item: PickerItem | undefined) => void;
}

const Picker = ({ items, heading, rows = 12, onChoose }: PickerProps) => {
  const { exit } = useApp();
  const [filter, setFilter] = useState("");
  const [cursor, setCursor] = useState(0);

  const matching = useCallback(
    (needle: string) =>
      items.filter((item) => matches(`${item.label} ${item.detail ?? ""}`, needle)),
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
          {"  "}
          {visible.length}/{items.length}
        </Text>
      </Box>
      <Box>
        <Text color="cyan">❯ </Text>
        <Text>{filter}</Text>
        <Text dimColor>{filter ? "" : "type to filter"}</Text>
      </Box>
      {window.map((item, index) => {
        const current = start + index === selected;
        return (
          <Box key={item.key} flexDirection="column">
            <Text color={current ? "cyan" : undefined} wrap="truncate-end">
              {current ? "▍" : " "} {item.label}
            </Text>
            {item.detail ? (
              <Text dimColor wrap="truncate-end">
                {"   "}
                {item.detail}
              </Text>
            ) : undefined}
          </Box>
        );
      })}
      {visible.length === 0 ? <Text dimColor> nothing matches</Text> : undefined}
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

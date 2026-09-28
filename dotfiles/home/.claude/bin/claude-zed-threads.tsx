#!/usr/bin/env bun
/**
 * List Claude Code threads started by Zed's ACP client, with their home dirs.
 *
 * Zed drives Claude Code non-interactively over the Agent Client Protocol, so
 * the threads it starts land in the same per-project store as the terminal CLI
 * (`~/.claude/projects/<slug>/<id>.jsonl`) but with a different fingerprint:
 * the first JSONL record carries `operation: "enqueue"` and no `mode:
 * "normal"`, whereas interactive terminal sessions are `mode: "normal"` with no
 * `operation`.
 *
 * The built-in `/resume` picker mixes both together *and* is scoped to the
 * current project directory. Zed history is siloed per working directory, so
 * threads you started elsewhere never appear. This isolates the Zed/ACP threads
 * and can widen the scope to every worktree of the current repo (`--repo`) or
 * everything (`--all`).
 *
 * At a terminal the threads are a table sized to the window, with the title
 * taking whatever the fixed columns leave and the worktree column dropped
 * entirely when there is no room for it. Piped, the output is the older plain
 * form with a resume command under each thread, because that is what the
 * /resume-zed slash command reads.
 *
 * `--pick` opens the same table as a filterable picker and writes `id<TAB>cwd`
 * for the chosen thread to stdout, which is what lets the shell function
 * around it cd into the thread's directory before resuming: the picker draws
 * on stderr so stdout carries nothing but the answer. Ink and React only load
 * on that path, so listing stays as cheap as it was.
 *
 * Any scripted `claude -p` run is also non-interactive and will appear here; in
 * a repo working directory these are almost always Zed threads in practice.
 */
import { basename, resolve } from "node:path";
import * as z from "zod";

import { paintFor } from "./lib/ansi.ts";
import { fail, flag, parse } from "./lib/cli.ts";
import { age, AGE_WIDTH, cell, GAP, layout, type Column } from "./lib/table.ts";
import {
  displayFor,
  momentOf,
  resumeCommand,
  zedThreads,
  type Scope,
  type ZedThread,
} from "./lib/threads.ts";

const USAGE = "usage: claude-zed-threads [-d DIR] [--repo | --all] [--sk | --pick]";

// Sibling worktrees share a long prefix and differ at the end, which is why
// this column elides from the start. The bounds keep one very long branch name
// from starving the titles.
const WHERE_MIN = 12;
const WHERE_MAX = 32;

const columnsFor = (threads: readonly ZedThread[], multi: boolean): readonly Column[] => [
  {
    key: "age",
    header: "when",
    width: AGE_WIDTH,
    align: "right",
    tone: { dim: true },
  },
  ...(multi
    ? ([
        {
          key: "where",
          header: "worktree",
          min: WHERE_MIN,
          max: Math.min(
            WHERE_MAX,
            Math.max(WHERE_MIN, ...threads.map((thread) => basename(thread.cwd).length)),
          ),
          elide: "start",
          optional: true,
          tone: { color: "blue" },
        },
      ] as const)
    : []),
  { key: "thread", header: "thread", flex: true, min: 24, elide: "end" },
];

const cellsFor = (thread: ZedThread): Readonly<Record<string, string>> => ({
  age: age(momentOf(thread)),
  where: thread.cwd ? basename(thread.cwd) : "?",
  thread: thread.title || "(untitled)",
});

const printTable = (threads: readonly ZedThread[], columns: readonly Column[]): void => {
  const paint = paintFor(process.stdout);
  const widths = layout(columns, (process.stdout.columns || 80) - 1);
  const shown = columns.filter((column) => widths.has(column.key));

  const line = (
    values: Readonly<Record<string, string>>,
    tone: (column: Column) => Parameters<typeof paint>[1],
  ): string =>
    shown
      .map((column, index) =>
        paint(
          cell(values[column.key] ?? "", widths.get(column.key)!, {
            elide: column.elide,
            align: column.align,
            pad: index < shown.length - 1,
          }),
          tone(column),
        ),
      )
      .join(GAP);

  console.log(
    line(
      Object.fromEntries(shown.map((column) => [column.key, column.header])),
      () => ({ dim: true }),
    ),
  );
  threads.forEach((thread) =>
    console.log(line(cellsFor(thread), (column) => column.tone)),
  );
  console.log(paint("pick one to resume with: resume-zed", { dim: true }));
};

const main = async (): Promise<number> => {
  const argv = process.argv.slice(2);
  if (argv.includes("-h") || argv.includes("--help")) {
    console.log(USAGE);
    return 0;
  }

  const args = parse({
    argv,
    usage: USAGE,
    options: {
      dir: { type: "string", short: "d" },
      repo: { type: "boolean" },
      all: { type: "boolean" },
      sk: { type: "boolean" },
      pick: { type: "boolean" },
    },
    schema: z
      .object({
        dir: z.string().default(process.cwd()),
        repo: flag,
        all: flag,
        sk: flag,
        pick: flag,
        positionals: z.array(z.string()).max(0, "takes no positionals"),
      })
      .refine((value) => !(value.repo && value.all), "pass --repo or --all, not both")
      .refine((value) => !(value.sk && value.pick), "pass --sk or --pick, not both"),
  });

  const directory = resolve(args.dir);
  const scope: Scope = args.repo ? "repo" : args.all ? "all" : "here";
  const threads = zedThreads(directory, scope);
  // Only a widened scope can turn up threads from more than one directory, so
  // that is when a row has to say which one it came from.
  const multi = scope !== "here";

  if (args.sk) {
    threads.forEach((thread) =>
      console.log(`${thread.sessionId}\t${thread.cwd}\t${displayFor(thread, multi)}`),
    );
    return 0;
  }

  if (args.pick) {
    if (!process.stdin.isTTY) return fail("--pick needs a terminal on stdin");
    if (!threads.length) return fail(`no Zed/ACP threads found (${scope}: ${directory})`);

    // Imported here rather than at the top so listing doesn't pay for Ink.
    const { pick } = await import("./lib/picker.tsx");
    const chosen = await pick({
      heading: `zed threads · ${scope}`,
      columns: columnsFor(threads, multi),
      items: threads.map((thread) => ({ key: thread.sessionId, cells: cellsFor(thread) })),
    });
    if (!chosen) return 1;
    const thread = threads.find((candidate) => candidate.sessionId === chosen.key)!;
    process.stdout.write(`${thread.sessionId}\t${thread.cwd}\n`);
    return 0;
  }

  if (!threads.length) {
    console.log(`No Zed/ACP threads found (${scope}: ${directory})`);
    return 0;
  }

  if (process.stdout.isTTY) {
    printTable(threads, columnsFor(threads, multi));
    return 0;
  }

  threads.forEach((thread) => {
    console.log(displayFor(thread, multi));
    console.log(`    ${resumeCommand(thread, multi)}`);
  });
  return 0;
};

process.exitCode = await main();

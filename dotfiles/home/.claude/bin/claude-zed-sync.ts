#!/usr/bin/env bun
/**
 * Carry Zed's agent-panel history for Claude Code threads between machines.
 *
 * Zed drives Claude Code over ACP, and for those threads it stores only a
 * pointer: a `sidebar_threads` row naming the agent, the session id, the folder
 * paths and a title. The conversation itself lives in Claude's own store
 * (`~/.claude/projects/<slug>/<session-id>.jsonl`), which claude-sync already
 * replicates, and Zed reopens a thread by asking the agent to resume that
 * session id. Making a thread appear on another machine is therefore a matter
 * of copying one row, not the transcript.
 *
 * `export` writes this machine's rows to
 * `~/.claude/projects/.zed-threads/<host>.json`, so they ride claude-sync's
 * bucket alongside the transcripts they point at, with no sync configuration to
 * add. `import` reads what the other machines exported and inserts the rows
 * this machine lacks. One file per machine, so two machines never write the
 * same file and there is nothing to merge.
 *
 * A thread whose transcript hasn't arrived is skipped rather than imported
 * dead, because Zed would offer it in the panel and then fail to load it. The
 * store is keyed by absolute working directory, so a repo living at a different
 * path on each machine needs `--map`, and Claude's retention cleanup deletes
 * transcripts long before Zed forgets the thread: expect a good share of any
 * machine's history to be unsyncable for that reason alone.
 *
 * `move` re-roots threads on a different directory, for work that starts in a
 * main checkout and continues in a worktree cut for it. The transcript moves
 * with them, since Claude resumes from the store keyed to the directory it is
 * running in, which `claude-mv-project` handles.
 *
 * What the row does and doesn't decide is worth knowing before reaching for
 * this. Zed runs a thread in whatever workspace you open it from, spawning the
 * agent with that workspace's root as its working directory, and writes the
 * folder paths back to the row afterwards. So the row says where a thread last
 * ran, and re-rooting it only holds if the new directory is itself a Zed
 * workspace and the thread is opened there. Open it from a window still rooted
 * at the old directory and Zed runs it there again and puts the row back, which
 * looks like the move having silently failed.
 *
 * Moving the transcript is the half that always matters: without it the agent
 * starts in the new directory, finds no session of that id in the store keyed
 * to it, and the thread cannot resume at all.
 *
 * Zed reads this table when it starts and writes to it as threads change, so a
 * row inserted underneath a running Zed may not show up until a restart, and
 * stands to be lost if Zed rewrites the table first. Hence the refusal to write
 * while it runs, with `--force` for when you know better.
 */
import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, readdirSync, readFileSync, renameSync, statSync, writeFileSync } from "node:fs";
import { hostname } from "node:os";
import { basename, join, resolve } from "node:path";
import * as z from "zod";

import { fail, flag, parse, repeatable } from "./lib/cli.ts";
import { HOME, PROJECTS_ROOT, storeFor, transcriptFor } from "./lib/store.ts";
import {
  CARRIED,
  closeReadable,
  columnsOf,
  DEFAULT_DB,
  describe,
  exportSchema,
  localThreads,
  openReadable,
  stableJson,
  threadIdFor,
  threadSchema,
  zedOwns,
  zedRunning,
  type Thread,
} from "./lib/zed.ts";

// Inside the project store because that is what claude-sync already carries:
// its "sessions" scope is a fixed allowlist (projects, history.jsonl, tasks,
// plans) and the only way to add a sibling directory is `scope: full`, which
// would also start uploading settings, agents and credentials. Subdirectories
// of projects/ ride along as-is, dot-prefixed so nothing scanning for project
// stores treats it as one.
const EXPORT_DIR = join(PROJECTS_ROOT, ".zed-threads");

const USAGE = `usage: claude-zed-sync <export|import|status|move> [options]

  export [--keep-missing]                publish this machine's threads
  import [--map OLD=NEW] [-v] [--force]  adopt other machines' threads
  status                                 what is here and what has arrived
  move OLD NEW [--session ID] [--all]    re-root threads on another directory

  common: --db PATH --host NAME -n/--dry-run --exclude GLOB`;

const expandUser = (path: string): string =>
  path.startsWith("~") ? join(HOME, path.slice(1)) : path;

const commonOptions = {
  db: { type: "string" },
  host: { type: "string" },
  "dry-run": { type: "boolean", short: "n" },
  exclude: { type: "string", multiple: true },
} as const;

const commonSchema = {
  db: z.string().default(DEFAULT_DB),
  host: z
    .string()
    .default(hostname().split(".")[0]!.toLowerCase())
    .transform((value) => value.toLowerCase()),
  "dry-run": flag,
  exclude: repeatable,
};

/**
 * Translate a path glob the way fnmatch does, where `*` spans separators.
 *
 * Zed records whole directories, so an exclusion is written against the path as
 * a string, `*meterup*` and the like, rather than as a tree walk. Character
 * classes are left alone, since they mean the same thing in both syntaxes.
 */
const globToRegExp = (pattern: string): RegExp =>
  new RegExp(
    `^${pattern
      .replace(/[.+^${}()|\\]/g, "\\$&")
      .replaceAll("*", ".*")
      .replaceAll("?", ".")}$`,
  );

const excluded = (folders: readonly string[], patterns: readonly string[]): boolean =>
  patterns.some((pattern) => folders.some((folder) => globToRegExp(pattern).test(folder)));

interface Mapping {
  readonly old: string;
  readonly next: string;
}

const mapEntry = z
  .string()
  .regex(/^[^=]+=.+$/, "--map wants OLD=NEW")
  .transform((value): Mapping => {
    const index = value.indexOf("=");
    return {
      old: expandUser(value.slice(0, index)),
      next: expandUser(value.slice(index + 1)),
    };
  });

const applyMap = (
  paths: readonly string[],
  mapping: readonly Mapping[],
): readonly string[] =>
  paths.map((path) => {
    const hit = mapping.find(
      ({ old }) => path === old || path.startsWith(`${old.replace(/\/+$/, "")}/`),
    );
    return hit
      ? hit.next.replace(/\/+$/, "") + path.slice(hit.old.replace(/\/+$/, "").length)
      : path;
  });

const readThreads = (path: string): readonly Thread[] => {
  if (!existsSync(path)) return fail(`no Zed database at ${path}`);
  const readable = openReadable(path);
  try {
    return localThreads(readable.database);
  } finally {
    closeReadable(readable);
  }
};

const readColumns = (path: string): ReadonlySet<string> => {
  const readable = openReadable(path);
  try {
    return new Set(columnsOf(readable.database, "sidebar_threads"));
  } finally {
    closeReadable(readable);
  }
};

const refuseWhileRunning = (database: string, permitted: boolean): void => {
  if (permitted || !zedOwns(database) || !zedRunning()) return;
  fail(
    "Zed is running, and it rewrites this table as threads change, so a row " +
      "written underneath it\nstands to be lost. Quit it first, or pass --force " +
      "if it isn't holding this database.",
  );
};

const doExport = (argv: readonly string[]): number => {
  const args = parse({
    argv,
    usage: USAGE,
    options: { ...commonOptions, "keep-missing": { type: "boolean" } },
    schema: z.object({
      ...commonSchema,
      "keep-missing": flag,
      positionals: z.array(z.string()).max(0, "export takes no positionals"),
    }),
  });

  const counts = { excluded: 0, missing: 0, moved: 0 };
  const kept = readThreads(args.db).filter((thread) => {
    if (args.exclude.length && excluded(thread.folder_paths, args.exclude)) {
      counts.excluded += 1;
      return false;
    }
    const { found, elsewhere } = transcriptFor(thread.session_id, thread.folder_paths);
    // A transcript under some other project key is still worth exporting: it
    // syncs like any other, and the receiving machine can point at it with
    // --map. One that exists nowhere only gives that machine something to skip
    // in turn.
    if (!found && !elsewhere && !args["keep-missing"]) {
      counts.missing += 1;
      return false;
    }
    if (elsewhere) counts.moved += 1;
    return true;
  });

  const destination = join(EXPORT_DIR, `${args.host}.json`);
  console.log(`${kept.length} thread(s) to export as ${args.host}`);
  if (counts.moved) console.log(`  ${counts.moved} whose transcript sits under another project key`);
  if (counts.excluded) console.log(`  ${counts.excluded} excluded by pattern`);
  if (counts.missing) console.log(`  ${counts.missing} skipped, transcript no longer on disk`);
  if (args["dry-run"]) {
    console.log(`would write ${destination}`);
    return 0;
  }

  // Written in one move, since claude-sync may be reading the directory to
  // upload it and a half-written file would be pushed as the real thing.
  mkdirSync(EXPORT_DIR, { recursive: true });
  const partial = `${destination}.partial`;
  writeFileSync(
    partial,
    stableJson({ host: args.host, generated: new Date().toISOString(), threads: kept }),
  );
  renameSync(partial, destination);
  console.log(`wrote ${destination}`);
  return 0;
};

interface Pending {
  readonly host: string;
  readonly thread: Thread;
  readonly folders: readonly string[];
  readonly worktrees: readonly string[];
}

const doImport = (argv: readonly string[]): number => {
  const args = parse({
    argv,
    usage: USAGE,
    options: {
      ...commonOptions,
      map: { type: "string", multiple: true },
      verbose: { type: "boolean", short: "v" },
      force: { type: "boolean" },
    },
    schema: z.object({
      ...commonSchema,
      map: z.array(mapEntry).default([]),
      verbose: flag,
      force: flag,
      positionals: z.array(z.string()).max(0, "import takes no positionals"),
    }),
  });

  if (!existsSync(EXPORT_DIR)) return fail(`nothing to import from ${EXPORT_DIR}`);
  refuseWhileRunning(args.db, args["dry-run"] || args.force);

  const sources = readdirSync(EXPORT_DIR)
    .filter((name) => name.endsWith(".json") && name !== `${args.host}.json`)
    .sort()
    .map((name) => join(EXPORT_DIR, name));
  if (!sources.length) {
    console.log(`no exports from other machines in ${EXPORT_DIR}`);
    return 0;
  }

  const present = new Set(readThreads(args.db).map((thread) => thread.session_id));
  const available = readColumns(args.db);
  const pending: Pending[] = [];
  const gone = new Map<string, number>();
  const skipped = { present: 0, "no transcript": 0, moved: 0, excluded: 0, unreadable: 0 };

  sources.forEach((source) => {
    const payload = exportSchema.safeParse(
      ((): unknown => {
        try {
          return JSON.parse(readFileSync(source, "utf8"));
        } catch (error) {
          // One unreadable export, from a push that raced a write, shouldn't
          // cost the machines that did arrive intact.
          console.error(`skipping ${basename(source)}: ${(error as Error).message}`);
          return undefined;
        }
      })(),
    );
    if (!payload.success) return;

    payload.data.threads.forEach((entry) => {
      const parsed = threadSchema.safeParse(entry);
      if (!parsed.success) {
        skipped.unreadable += 1;
        return;
      }
      const thread = parsed.data;
      if (present.has(thread.session_id)) {
        skipped.present += 1;
        return;
      }
      const folders = applyMap(thread.folder_paths, args.map);
      const worktrees = applyMap(thread.main_worktree_paths, args.map);
      if (args.exclude.length && excluded(folders, args.exclude)) {
        skipped.excluded += 1;
        return;
      }
      const { found, elsewhere } = transcriptFor(thread.session_id, folders);
      if (!found) {
        skipped[elsewhere ? "moved" : "no transcript"] += 1;
        return;
      }
      if (folders.length && !folders.some((folder) => existsSync(folder))) {
        gone.set(folders[0]!, (gone.get(folders[0]!) ?? 0) + 1);
      }
      pending.push({ host: payload.data.host, thread, folders, worktrees });
      present.add(thread.session_id);
    });
  });

  console.log(`${pending.length} thread(s) to import from ${sources.length} machine(s)`);
  if (gone.size) {
    // Named rather than counted because these are mostly worktrees, whose paths
    // worktrunk derives from the branch: recreate the worktree and the thread
    // opens, so knowing which ones are missing is the actionable part.
    const total = [...gone.values()].reduce((sum, count) => sum + count, 0);
    console.log(
      `  ${total} in ${gone.size} folder(s) absent here, which import but stay ` +
        "unopenable until the folder is back:",
    );
    const ranked = [...gone.entries()].sort(([, left], [, right]) => right - left);
    const limit = args.verbose ? ranked.length : 8;
    ranked.slice(0, limit).forEach(([folder, count]) =>
      console.log(`    ${String(count).padStart(3)}  ${folder}`),
    );
    if (ranked.length > limit) {
      console.log(`    and ${ranked.length - limit} more folder(s), -v to list`);
    }
  }
  Object.entries(skipped)
    .filter(([, count]) => count)
    .forEach(([label, count]) => console.log(`  ${count} skipped, ${label}`));
  if (skipped.moved) {
    console.log(
      "  (their folder no longer matches where the transcript is keyed, usually a\n" +
        "   worktree Zed followed into the trash; --map can point one at a real path)",
    );
  }
  if (!pending.length) return 0;

  if (args.verbose || args["dry-run"]) {
    pending.forEach(({ host, thread, folders }) => {
      console.log(`  ${host}  ${(thread.title_override || thread.title || "(untitled)").slice(0, 58)}`);
      console.log(`        ${folders[0] ?? "?"}`);
    });
  }
  if (args["dry-run"]) return 0;

  const writable = new Database(args.db);
  try {
    writable.transaction(() =>
      pending.forEach(({ thread, folders, worktrees }) => {
        const values = new Map<string, unknown>(
          CARRIED.filter(
            (column) => available.has(column) && thread[column] !== undefined && thread[column] !== null,
          ).map((column) => [column, thread[column]]),
        );
        values.set("thread_id", threadIdFor(thread.session_id));
        // STRICT table with NOT NULL on both.
        values.set("title", thread.title ?? "");
        values.set("updated_at", thread.updated_at ?? new Date().toISOString());
        values.set("archived", Number(thread.archived ?? 0));
        if (available.has("folder_paths")) {
          values.set("folder_paths", folders.join("\n"));
          values.set("folder_paths_order", folders.map((_, index) => index).join(","));
        }
        if (available.has("main_worktree_paths")) {
          const paths = worktrees.length ? worktrees : folders;
          values.set("main_worktree_paths", paths.join("\n"));
          values.set("main_worktree_paths_order", paths.map((_, index) => index).join(","));
        }
        const columns = [...values.keys()].filter((column) => available.has(column));
        writable
          .prepare(
            `insert or ignore into sidebar_threads (${columns.join(", ")}) ` +
              `values (${columns.map(() => "?").join(", ")})`,
          )
          .run(...columns.map((column) => values.get(column) as never));
      }),
    )();
  } finally {
    writable.close();
  }

  console.log(`imported ${pending.length} thread(s); they appear next time Zed starts`);
  return 0;
};

const rootedAt = (thread: Thread, folder: string): boolean =>
  thread.folder_paths.some(
    (path) => path === folder || path.startsWith(`${folder.replace(/\/+$/, "")}/`),
  );

const doMove = (argv: readonly string[]): number => {
  const args = parse({
    argv,
    usage: USAGE,
    options: {
      ...commonOptions,
      session: { type: "string", multiple: true },
      all: { type: "boolean" },
      "no-transcripts": { type: "boolean" },
      force: { type: "boolean" },
    },
    schema: z.object({
      ...commonSchema,
      session: repeatable,
      all: flag,
      "no-transcripts": flag,
      force: flag,
      positionals: z
        .array(z.string())
        .length(2, "needs the directory the threads are at and the one they belong to"),
    }),
  });

  const [old, next] = args.positionals.map((path) => resolve(path)) as [string, string];
  if (old === next) return fail("old and new are the same directory");
  refuseWhileRunning(args.db, args["dry-run"] || args.force);

  const available = readColumns(args.db);
  const candidates = readThreads(args.db).filter((thread) => rootedAt(thread, old));
  if (!candidates.length) return fail(`no threads rooted at ${old}`);

  const selected = ((): readonly Thread[] => {
    if (args.session.length) {
      const matched = args.session.map((want) => ({
        want,
        matches: candidates.filter((thread) => thread.session_id.startsWith(want)),
      }));
      const unresolved = matched
        .filter(({ matches }) => matches.length !== 1)
        .map(({ want, matches }) =>
          matches.length ? `${want} matches ${matches.length} threads` : `no thread at ${old} for ${want}`,
        );
      if (unresolved.length) fail(unresolved.join("\n"));
      return matched.map(({ matches }) => matches[0]!);
    }
    if (args.all) return candidates;
    // Moving every thread of a long-lived checkout is rarely what someone
    // cutting a worktree means, so the bare form lists and stops.
    console.log(`${candidates.length} thread(s) rooted at ${old}:`);
    candidates.forEach((thread) => console.log(describe(thread)));
    console.log("\npass --session ID for the ones to move (repeatable), or --all");
    return process.exit(1);
  })();

  if (!existsSync(next)) {
    console.log(`note: ${next} does not exist here; the threads will not open until it does`);
  }

  const located = selected.map((thread) => ({
    thread,
    ...transcriptFor(thread.session_id, [old]),
  }));
  const here = located.filter(({ found }) => found);
  const elsewhere = located.filter(({ found, elsewhere: other }) => !found && other);
  const orphaned = located.filter(({ found, elsewhere: other }) => !found && !other);

  console.log(`${selected.length} thread(s) to re-root on ${next}`);
  selected.forEach((thread) => console.log(describe(thread)));
  if (elsewhere.length) {
    console.log(`  ${elsewhere.length} transcript(s) are keyed to another directory already and stay there`);
  }
  if (orphaned.length) {
    console.log(`  ${orphaned.length} have no transcript left, so the row is all that moves`);
  }

  // Transcripts first: if that fails, Zed is still pointing at a directory
  // where the threads do open.
  if (here.length && !args["no-transcripts"]) {
    const command = [
      "claude-mv-project",
      ...(args["dry-run"] ? ["-n"] : []),
      ...here.flatMap(({ thread }) => ["--session", thread.session_id]),
      old,
      next,
    ];
    console.log(`\n${command.join(" ")}`);
    const { exitCode } = Bun.spawnSync(command, { stdout: "inherit", stderr: "inherit" });
    if (exitCode !== 0) return exitCode ?? 1;
  }

  if (args["dry-run"]) {
    console.log(`\nwould re-root ${selected.length} thread(s) in ${args.db}`);
    return 0;
  }

  const writable = new Database(args.db);
  try {
    writable.transaction(() =>
      selected.forEach((thread) => {
        const folders = applyMap(thread.folder_paths, [{ old, next }]);
        const worktrees = applyMap(thread.main_worktree_paths, [{ old, next }]);
        const assignments: string[] = [];
        const values: unknown[] = [];
        if (available.has("folder_paths")) {
          assignments.push("folder_paths = ?", "folder_paths_order = ?");
          values.push(folders.join("\n"), folders.map((_, index) => index).join(","));
        }
        if (available.has("main_worktree_paths") && worktrees.length) {
          assignments.push("main_worktree_paths = ?", "main_worktree_paths_order = ?");
          values.push(worktrees.join("\n"), worktrees.map((_, index) => index).join(","));
        }
        writable
          .prepare(
            `update sidebar_threads set ${assignments.join(", ")} where session_id = ?`,
          )
          .run(...([...values, thread.session_id] as never[]));
      }),
    )();
  } finally {
    writable.close();
  }

  console.log(`\nre-rooted ${selected.length} thread(s); they appear next time Zed starts`);
  console.log(
    `open ${next} as its own Zed window before picking one up: a thread opened\n` +
      "from a window rooted somewhere else runs there instead, and Zed writes that " +
      "back over this.",
  );
  return 0;
};

const doStatus = (argv: readonly string[]): number => {
  const args = parse({
    argv,
    usage: USAGE,
    options: commonOptions,
    schema: z.object({
      ...commonSchema,
      positionals: z.array(z.string()).max(0, "status takes no positionals"),
    }),
  });

  const threads = readThreads(args.db);
  const located = threads.map((thread) =>
    transcriptFor(thread.session_id, thread.folder_paths),
  );
  const here = located.filter(({ found }) => found).length;
  const elsewhere = located.filter(({ found, elsewhere: other }) => !found && other).length;

  console.log(`${threads.length} Claude thread(s) in Zed's history on ${args.host}`);
  console.log(`${here} with a transcript under the folder Zed records`);
  if (elsewhere) console.log(`${elsewhere} with one under some other project key, needing --map`);
  console.log(
    `${here + elsewhere} exportable, ${threads.length - here - elsewhere} with no transcript left`,
  );

  if (!existsSync(EXPORT_DIR)) {
    console.log(`no exports yet (${EXPORT_DIR} does not exist)`);
    return 0;
  }
  readdirSync(EXPORT_DIR)
    .filter((name) => name.endsWith(".json"))
    .sort()
    .forEach((name) => {
      const payload = exportSchema.safeParse(
        JSON.parse(readFileSync(join(EXPORT_DIR, name), "utf8")),
      );
      if (!payload.success) return;
      const mine = name === `${args.host}.json` ? " (this machine)" : "";
      console.log(
        `  ${payload.data.host.padEnd(12)} ${String(payload.data.threads.length).padStart(4)} ` +
          `thread(s), exported ${payload.data.generated.slice(0, 19)}${mine}`,
      );
    });
  return 0;
};

const COMMANDS = { export: doExport, import: doImport, status: doStatus, move: doMove } as const;

const main = (): number => {
  const argv = process.argv.slice(2);
  if (argv[0] === "-h" || argv[0] === "--help" || argv[0] === "help") {
    console.log(USAGE);
    return 0;
  }
  // A bare invocation reports rather than doing anything, and so does one that
  // only carries flags.
  const named = argv[0] && !argv[0].startsWith("-") ? argv[0] : "status";
  if (!(named in COMMANDS)) return fail(`unknown command: ${named}\n${USAGE}`);
  return COMMANDS[named as keyof typeof COMMANDS](
    named === argv[0] ? argv.slice(1) : argv,
  );
};

process.exit(main());

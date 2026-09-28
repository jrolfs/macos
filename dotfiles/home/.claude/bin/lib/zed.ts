/**
 * Zed's side of a Claude Code thread: the sidebar_threads row that points at a
 * session, and the database it lives in.
 */
import { Database } from "bun:sqlite";
import { createHash } from "node:crypto";
import { copyFileSync, existsSync, mkdtempSync, realpathSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join, sep } from "node:path";
import * as z from "zod";

import { HOME } from "./store.ts";

export const ZED_SUPPORT = join(HOME, "Library/Application Support/Zed");
export const DEFAULT_DB = join(ZED_SUPPORT, "db/0-stable/db.sqlite");

/**
 * Columns carried between machines.
 *
 * thread_id is derived rather than copied, and remote_connection is left
 * behind: it names a connection this machine may not have.
 */
export const CARRIED = [
  "session_id",
  "agent_id",
  "title",
  "title_override",
  "created_at",
  "updated_at",
  "interacted_at",
  "archived",
] as const;

export const PATH_COLUMNS = ["folder_paths", "main_worktree_paths"] as const;

// Fixed namespace so both machines derive the same thread_id for a session,
// which is what keeps a re-import idempotent and stops one thread turning into
// two. It is also the namespace the Python helpers used, so a machine that
// hasn't switched yet still agrees on the id.
const NAMESPACE = "6f2a1d54-8f1b-5e2c-9a3d-1c7b0e4f8a62";

export const threadIdFor = (sessionId: string): Uint8Array => {
  const bytes = createHash("sha1")
    .update(Buffer.from(NAMESPACE.replaceAll("-", ""), "hex"))
    .update(Buffer.from(sessionId, "utf8"))
    .digest()
    .subarray(0, 16);
  bytes[6] = (bytes[6]! & 0x0f) | 0x50;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  return bytes;
};

export const zedRunning = (): boolean =>
  Bun.spawnSync(["pgrep", "-f", String.raw`Zed.*\.app/Contents/MacOS/zed`]).exitCode === 0;

/** Whether this database is one a running Zed would be holding. */
export const zedOwns = (database: string): boolean =>
  realpathSync(database).startsWith(realpathSync(ZED_SUPPORT) + sep);

export interface ReadableDatabase {
  readonly database: Database;
  /** Where a snapshot was taken, when one had to be. */
  readonly scratch?: string;
}

/**
 * Open the database for reading, snapshotting it if that isn't possible.
 *
 * Reading alongside a running Zed is normally fine, since a shared read lock is
 * all this needs. A read-only connection to a WAL database does still want to
 * write the shared memory file, though, so the fallback copies the three files
 * aside and reads those.
 */
export const openReadable = (path: string): ReadableDatabase => {
  try {
    const database = new Database(path, { readonly: true });
    database.query("select count(*) from sidebar_threads").get();
    return { database };
  } catch {
    const scratch = mkdtempSync(join(tmpdir(), "claude-zed-sync."));
    ["", "-wal", "-shm"]
      .filter((suffix) => existsSync(path + suffix))
      .forEach((suffix) =>
        copyFileSync(path + suffix, join(scratch, basename(path) + suffix)),
      );
    return { database: new Database(join(scratch, basename(path))), scratch };
  }
};

export const closeReadable = ({ database, scratch }: ReadableDatabase): void => {
  database.close();
  if (scratch) rmSync(scratch, { recursive: true, force: true });
};

/**
 * A thread as it travels between machines.
 *
 * Loose, and every field but the session id optional, because this is read
 * both from Zed's table and from another machine's export: the table is Zed's
 * to change, and an export may have been written by a different version of
 * this tool.
 */
export const threadSchema = z.looseObject({
  session_id: z.string().min(1),
  agent_id: z.string().nullish(),
  title: z.string().nullish(),
  title_override: z.string().nullish(),
  created_at: z.string().nullish(),
  updated_at: z.string().nullish(),
  interacted_at: z.string().nullish(),
  archived: z.number().nullish(),
  folder_paths: z.array(z.string()).default([]),
  main_worktree_paths: z.array(z.string()).default([]),
});

export type Thread = z.infer<typeof threadSchema>;

export const exportSchema = z.looseObject({
  host: z.string().default("?"),
  generated: z.string().default(""),
  // Unknown here and validated one at a time, so a single unreadable thread
  // doesn't cost the rest of the machine's history.
  threads: z.array(z.unknown()).default([]),
});

export const columnsOf = (database: Database, table: string): readonly string[] =>
  database
    .query(`pragma table_info(${table})`)
    .all()
    .map((row) => (row as { name: string }).name);

const splitPaths = (value: unknown): readonly string[] =>
  typeof value === "string" ? value.split("\n").filter(Boolean) : [];

/**
 * Rows Zed holds for Claude Code threads, newest first.
 *
 * A row needs both an agent and a session id to be worth carrying. What that
 * drops is titleless stubs, from a thread that was opened in the panel and
 * never used, which point at nothing in Claude's store.
 */
export const localThreads = (database: Database): readonly Thread[] => {
  const available = new Set(columnsOf(database, "sidebar_threads"));
  const wanted = [...CARRIED, ...PATH_COLUMNS].filter((column) =>
    available.has(column),
  );
  const rows = database
    .query(
      `select ${wanted.join(", ")} from sidebar_threads ` +
        "where agent_id is not null and coalesce(session_id, '') <> '' " +
        "order by updated_at desc",
    )
    .all() as readonly Record<string, unknown>[];

  const threads = new Map<string, Thread>();
  rows.forEach((row) => {
    const parsed = threadSchema.safeParse({
      ...row,
      folder_paths: splitPaths(row["folder_paths"]),
      main_worktree_paths: splitPaths(row["main_worktree_paths"]),
    });
    // Ordered newest first, so a duplicated session id keeps the live row.
    if (parsed.success && !threads.has(parsed.data.session_id)) {
      threads.set(parsed.data.session_id, parsed.data);
    }
  });
  return [...threads.values()];
};

export const titleOf = (thread: Thread): string =>
  thread.title_override || thread.title || "(untitled)";

export const describe = (thread: Thread): string =>
  `  ${thread.session_id.slice(0, 8)}  ${(thread.updated_at ?? "").slice(0, 10)}  ` +
  titleOf(thread).slice(0, 52);

/**
 * Serialise with sorted keys, so an export that didn't change in substance
 * doesn't churn in the bucket it syncs through.
 */
export const stableJson = (value: unknown): string =>
  `${JSON.stringify(
    value,
    (_key, nested) =>
      nested && typeof nested === "object" && !Array.isArray(nested)
        ? Object.fromEntries(
            Object.entries(nested).sort(([left], [right]) =>
              left < right ? -1 : left > right ? 1 : 0,
            ),
          )
        : nested,
    2,
  )}\n`;

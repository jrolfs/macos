/**
 * Claude Code's project store: where a thread's transcript lives, and how the
 * absolute working directory it is keyed by turns into a directory name.
 */
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

export const HOME = homedir();
export const PROJECTS_ROOT = join(HOME, ".claude/projects");

/**
 * Encode a working directory the way Claude Code names its project store.
 */
export const slugFor = (path: string): string =>
  resolve(path).replace(/[^a-zA-Z0-9]/g, "-");

export const storeFor = (path: string): string => join(PROJECTS_ROOT, slugFor(path));

export interface TranscriptLocation {
  /** Under the store for one of the folders asked about. */
  readonly found?: string;
  /** Under some other directory's store, when only that one has it. */
  readonly elsewhere?: string;
}

/**
 * Locate a session's transcript, preferring the store its folder would resume
 * from.
 *
 * A transcript turning up only under another key means the thread's directory
 * moved since, most often a worktree Zed followed into worktrunk's trash while
 * the store kept the original path.
 */
export const transcriptFor = (
  sessionId: string,
  folders: readonly string[],
): TranscriptLocation => {
  const keyed = folders
    .map((folder) => join(storeFor(folder), `${sessionId}.jsonl`))
    .find((candidate) => existsSync(candidate));
  if (keyed) return { found: keyed };

  if (!existsSync(PROJECTS_ROOT)) return {};
  const elsewhere = readdirSync(PROJECTS_ROOT, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => join(PROJECTS_ROOT, entry.name, `${sessionId}.jsonl`))
    .find((candidate) => existsSync(candidate));
  return elsewhere ? { elsewhere } : {};
};

/**
 * Re-encode a string as one code point per byte of its UTF-8 form.
 *
 * Stores hold whatever a session wrote, not only transcripts, so rewriting
 * them goes through latin1: every byte round-trips, where decoding as UTF-8
 * would turn anything malformed into U+FFFD and write that back.
 */
const toLatin1 = (value: string): string =>
  Buffer.from(value, "utf8").toString("latin1");

const escapeForRegExp = (value: string): string =>
  value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

export interface Replacement {
  readonly pattern: RegExp;
  readonly replacement: string;
}

/**
 * Match `needle` only where a path or slug plausibly ends.
 *
 * The next character may not be alphanumeric, `-` (slug continuation), or a
 * `.`/`_` that starts a longer basename (`repo.flake`, `repo_v2`).
 */
export const replacementFor = (needle: string, becomes: string): Replacement => ({
  pattern: new RegExp(`${escapeForRegExp(toLatin1(needle))}(?![a-zA-Z0-9._-])`, "g"),
  replacement: toLatin1(becomes),
});

const filesUnder = (path: string): readonly string[] => {
  if (!statSync(path).isDirectory()) return [path];
  return readdirSync(path, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => join(entry.parentPath, entry.name));
};

export interface RewriteOptions {
  /** Report what would change without writing it. */
  readonly dryRun?: boolean;
}

/**
 * Apply replacements to a file, or to every file below a directory.
 *
 * A store holds more than transcripts (`memory/` among others), so this walks
 * whatever it is handed.
 *
 * @returns how many files the replacements changed
 */
export const rewritePaths = (
  path: string,
  replacements: readonly Replacement[],
  { dryRun = false }: RewriteOptions = {},
): number =>
  filesUnder(path).filter((target) => {
    const original = readFileSync(target).toString("latin1");
    const rewritten = replacements.reduce(
      (data, { pattern, replacement }) => data.replaceAll(pattern, replacement),
      original,
    );
    if (rewritten === original) return false;
    if (!dryRun) writeFileSync(target, Buffer.from(rewritten, "latin1"));
    return true;
  }).length;

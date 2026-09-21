/**
 * Argument parsing for the helpers: node:util tokenises, zod decides what the
 * tokens have to be.
 */
import { parseArgs, type ParseArgsOptionsConfig } from "node:util";
import * as z from "zod";

export const fail = (message: string): never => {
  console.error(message);
  process.exit(1);
};

export interface ParseOptions<Schema extends z.ZodType> {
  readonly argv: readonly string[];
  readonly options: ParseArgsOptionsConfig;
  readonly schema: Schema;
  readonly usage: string;
}

/**
 * Parse argv against a schema, exiting with the usage line if it doesn't hold.
 *
 * parseArgs reports what was typed, which is booleans and strings and nothing
 * about how they combine. The schema is where a repeatable flag becomes an
 * array, a count becomes a number, and a command that needs two positionals
 * says so.
 */
export const parse = <Schema extends z.ZodType>({
  argv,
  options,
  schema,
  usage,
}: ParseOptions<Schema>): z.infer<Schema> => {
  try {
    const { values, positionals } = parseArgs({
      args: [...argv],
      options,
      allowPositionals: true,
    });
    const parsed = schema.safeParse({ ...values, positionals });
    return parsed.success
      ? parsed.data
      : fail(`${z.prettifyError(parsed.error)}\n${usage}`);
  } catch (error) {
    return fail(`${(error as Error).message}\n${usage}`);
  }
};

/** A repeatable flag, which parseArgs gives as an array or not at all. */
export const repeatable = z.array(z.string()).default([]);

export const flag = z.boolean().default(false);

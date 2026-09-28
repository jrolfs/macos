/**
 * Just enough SGR to colour printed output, with no dependency to carry.
 *
 * Gated on the stream being a terminal and on NO_COLOR, because this output
 * gets piped: the /resume-zed slash command reads it, and a shell function
 * parses it.
 */
import type { Tone } from "./table.ts";

const CODES = {
  reset: 0,
  bold: 1,
  dim: 2,
  black: 30,
  red: 31,
  green: 32,
  yellow: 33,
  blue: 34,
  magenta: 35,
  cyan: 36,
  white: 37,
  gray: 90,
} as const;

export type Paint = (text: string, tone?: Tone) => string;

export const paintFor = (stream: NodeJS.WriteStream): Paint => {
  const enabled = Boolean(stream.isTTY) && !process.env["NO_COLOR"];
  return (text, tone) => {
    if (!enabled || !tone) return text;
    const codes = [
      tone.bold ? CODES.bold : undefined,
      tone.dim ? CODES.dim : undefined,
      tone.color ? CODES[tone.color] : undefined,
    ].filter((code) => code !== undefined);
    return codes.length
      ? `\u001b[${codes.join(";")}m${text}\u001b[${CODES.reset}m`
      : text;
  };
};

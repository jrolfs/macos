/**
 * Parse a mapping argument like `ENV_VAR=cookie_name` into its parts.
 *
 * @returns A tuple of `[envVar, cookieName]`, or `null` if the format is invalid.
 */
const parseMapping = (mapping: string): readonly [string, string] | null => {
  const index = mapping.indexOf('=');

  if (index <= 0 || index === mapping.length - 1) return null;

  return [mapping.slice(0, index), mapping.slice(index + 1)] as const;
};

const cookieCopy = glide.excmds.create(
  {
    name: 'cookie_copy',
    description:
      'Copy cookie values from the current domain as a .env snippet (e.g. cookie_copy ENV_VAR=cookie_name,...)',
  },
  async ({ args_arr: args }) => {
    assert(args.length > 0, 'Usage: cookie_copy ENV_VAR=cookie_name[,ENV_VAR2=cookie_name2,...]');

    const mappings = args.join(' ').split(',').map((s) => s.trim()).filter(Boolean);

    const parsed = mappings.map((mapping) => {
      const result = parseMapping(mapping);

      assert(result, `Invalid mapping "${mapping}" — expected ENV_VAR=cookie_name`);

      return result;
    });

    const { url } = await glide.tabs.active();

    assert(url, 'No active tab URL');

    const cookies = await browser.cookies.getAll({ url });

    const lines = parsed.map(([envVar, cookieName]) => {
      const cookie = cookies.find((c) => c.name === cookieName);

      assert(cookie, `Cookie "${cookieName}" not found for ${url}`);

      return `${envVar}=${cookie.value}`;
    });

    await navigator.clipboard.writeText(lines.join('\n'));

    console.log(`Copied ${lines.length} cookie(s) to clipboard`);
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { cookie_copy: typeof cookieCopy; } }

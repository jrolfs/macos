/**
 * @typedef {{
 *   kae: string;
 *   kax: string;
 *   kbc: number;
 *   kay: string;
 *   kat: number;
 *   kav: number;
 *   k5: number;
 *   kaq: number;
 *   ko: number;
 *   kak: number;
 *   kao: number;
 *   km: string;
 *   kt: string;
 *   kj: string;
 *   k7: string;
 *   k9: string;
 *   kaa: string;
 *   kx: string;
 *   k8: string;
 * }} AllOptions
 */

/**
 * @type {Partial<AllOptions>}
 */
const defaultOptions = {
  kae: "d",
  kax: "v205-2",
  kbc: 1,
  kay: "b",
  kat: -1,
  kav: 1,
  k5: 1,
  kaq: -1,
  ko: 1,
  kak: -1,
  kao: -1,
  km: "m",
  kt: "Plex+Sans",
  kj: "313244",
  k7: "313244",
  k9: "89B4FA",
  kaa: "CBA6F7",
  kx: "89DCEB",
  k8: "BAC2DE",
};

const colorKeys = /** @type const */ (["kj", "k7", "k9", "kaa", "kx", "k8"]);

/**
 * @typedef {Pick<AllOptions, (typeof colorKeys)[number]>} Options
 */

// https://duckduckgo.com/?kae=d&kax=v205-2&kbc=1&kay=b&kat=-1&kav=1&k5=1&kaq=-1&ko=1&kak=-1&kao=-1&km=m&kt=Plex+Sans&kj=313244&k7=313244&k9=89B4FA&kaa=CBA6F7&kx=89DCEB&k8=BAC2DE

/**
 * Strip `#` from color values which are included in order to trigger the
 * colorizer plugin in editors so it's easier to visualize the theme colors
 *
 * @param {Options} options
 */
const normalizeColors = (options) =>
  Object.fromEntries(
    Object.entries(options).map(([key, value]) => [key, value.replace("#", "")])
  );


/**
 * Generate a Raycast theme URL from the provided options
 *
 * @example
 * ```js
 * generateThemeUrl({
 *   name: 'Chill Theme',
 *   version: '1',
 *   colors: [
 *    '#303446'
 *    // ...
 *   ]
 * });
 *
 * // output
 * // https://themes.ray.so/?version=1&name=Catppuccin%20Frappe&appearance=dark&colors=%23303446FF,...
 * ```
 *
 * @param {Options} options
 */
export const generateSettingsBookmarklet = (options) => {
  const base = "https://duckduckgo.com/settings";

  const params = new URLSearchParams({
    ...defaultOptions,
    ...normalizeColors(options),
  });

  return `${base}?${params.toString()}`;
};

/**
 * 
 * @param {Options} options 
 * @returns 
 */
export const generateCookie = (options) => {
  const allOptions = {
    ...defaultOptions,
    ...normalizeColors(options),
  }

  const values = [];

  for (const [key, value] of Object.entries(allOptions)) {
    const cookie = `${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
    values.push(cookie);
  }

  return values.join(';');
}

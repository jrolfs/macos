/**
 * 1Password autofill for Glide via the `op` CLI.
 *
 * This sidesteps 1Password's native Universal Autofill (which doesn't
 * recognise Glide's bundle id `app.glide-browser.glide`, so URL detection
 * never works) by doing everything ourselves:
 *
 *   1. `op item list` gives us every Login item *with its URLs*, so we match
 *      against the current page host locally — no dependency on 1Password's
 *      hardcoded browser list.
 *   2. A leader key (or the in-field badge) opens a Quick-Access-style menu
 *      built with `glide.commandline`.
 *   3. On selection, `op item get` fetches the credential and we inject it
 *      into the page via `glide.content.execute`.
 *   4. Login fields are decorated with a subtle "halo" + a clickable
 *      1Password badge, re-applied on every navigation.
 *
 * Secrets are only ever fetched lazily (at fill time) and passed straight
 * into the content process — never cached, never logged.
 */

// ---------------------------------------------------------------------------
// Decoration config — tweak the halo/badge appearance here.
//
// NOTE: `applyDecoration` runs in the content process (its body is stringified
// and cannot capture outer variables), so this object is passed in via `args`.
// It is the single source of truth for the visual constants.
// ---------------------------------------------------------------------------

/** Phosphor Icons `password` glyph (weight: fill), tinted at runtime. */
const icons = {
  password: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgZmlsbD0iIzAwMDAwMCIgdmlld0JveD0iMCAwIDI1NiAyNTYiPjxwYXRoIGQ9Ik0xMjgsMjRBMTA0LDEwNCwwLDEsMCwyMzIsMTI4LDEwNC4xMSwxMDQuMTEsMCwwLDAsMTI4LDI0Wm0yOS41MiwxNDYuMzlhNCw0LDAsMCwxLTMuNjYsNS42MUgxMDIuMTRhNCw0LDAsMCwxLTMuNjYtNS42MUwxMTIsMTM5LjcyYTMyLDMyLDAsMSwxLDMyLDBaIj48L3BhdGg+PC9zdmc+',
  vault: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgZmlsbD0iIzAwMDAwMCIgdmlld0JveD0iMCAwIDI1NiAyNTYiPjxwYXRoIGQ9Ik0yMTYsNDJINDBBMTQsMTQsMCwwLDAsMjYsNTZWMTkyYTE0LDE0LDAsMCwwLDE0LDE0SDU4djE4YTYsNiwwLDAsMCwxMiwwVjIwNkgxODZ2MThhNiw2LDAsMCwwLDEyLDBWMjA2aDE4YTE0LDE0LDAsMCwwLDE0LTE0VjU2QTE0LDE0LDAsMCwwLDIxNiw0MlptMCwxNTJINDBhMiwyLDAsMCwxLTItMlY1NmEyLDIsMCwwLDEsMi0ySDIxNmEyLDIsMCwwLDEsMiwydjY2SDE5Ny42YTQ2LDQ2LDAsMSwwLDAsMTJIMjE4djU4QTIsMiwwLDAsMSwyMTYsMTk0Wm0tNTEuMzctNzJhMTQsMTQsMCwxLDAsMCwxMmgyMC44M2EzNCwzNCwwLDEsMSwwLTEyWiI+PC9wYXRoPjwvc3ZnPg==',
  account: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgZmlsbD0iIzAwMDAwMCIgdmlld0JveD0iMCAwIDI1NiAyNTYiPjxwYXRoIGQ9Ik0xNzIsMTIwYTQ0LDQ0LDAsMSwxLTQ0LTQ0QTQ0LDQ0LDAsMCwxLDE3MiwxMjBabTYwLTY0VjIwMGExNiwxNiwwLDAsMS0xNiwxNkg0MGExNiwxNiwwLDAsMS0xNi0xNlY1NkExNiwxNiwwLDAsMSw0MCw0MEgyMTZBMTYsMTYsMCwwLDEsMjMyLDU2Wk0yMTYsMjAwVjU2SDQwVjIwMEg1NC42OGE4MCw4MCwwLDAsMSwyOS40MS0zNC44NCw0LDQsMCwwLDEsNC44My4zMSw1OS44Miw1OS44MiwwLDAsMCw3OC4xNiwwLDQsNCwwLDAsMSw0LjgzLS4zMUE4MCw4MCwwLDAsMSwyMDEuMzIsMjAwSDIxNloiPjwvcGF0aD48L3N2Zz4='
}

interface HaloConfig {
  /** Transparent gap (px) between the input's edge and the halo band. */
  readonly offset: number;
  /** Width (px) of the visible halo band. */
  readonly thickness: number;
  /** `backdrop-filter: blur()` radius (px) applied behind the halo. */
  readonly blurRadius: number;
  /** Halo fill opacity (0–1). */
  readonly opacity: number;
  /** Outer corner radius (px). Inner radius is derived as `outer - thickness`. */
  readonly outerRadius: number;
  /** Extra width (px) the band gains on the right to host the badge. */
  readonly buttonWidth: number;
  /** Halo fill colour (any CSS colour; opacity is applied separately). */
  readonly color: string;
  /** Badge icon tint colour. */
  readonly iconColor: string;
  /** Data URL for the badge icon. */
  readonly iconDataUrl: string;
}

const DECORATION: HaloConfig = {
  offset: 2,
  thickness: 2,
  blurRadius: 3,
  opacity: 0.9,
  outerRadius: 8,
  buttonWidth: 22,
  color: 'rgba(37, 99, 235, 0.14)',
  iconColor: 'rgba(37, 99, 235, 0.95)',
  iconDataUrl: icons.password,
};

// ---------------------------------------------------------------------------
// `op` CLI integration (main process)
// ---------------------------------------------------------------------------

interface OpAccount {
  readonly url: string;
  readonly email: string;
  readonly user_uuid: string;
  readonly account_uuid: string;
}

/**
 * Short human label for an account, derived from its email domain.
 *
 * Avoids hardcoding account shorthands (which can go stale — `op` account
 * shorthands aren't guaranteed to match the registered accounts).
 */
const accountLabel = (account: OpAccount): string =>
  account.email.toLowerCase().endsWith('@meter.com') ? 'Work' : 'Personal';

/**
 * Environment for spawned `op` processes.
 *
 * macOS GUI apps don't inherit the shell environment, so `PATH` and the
 * non-standard `OP_CONFIG_DIR` (this repo keeps it in the encrypted `private`
 * kingdom) must be set explicitly. `extend_env` keeps `HOME` etc. so the
 * desktop-app/Touch ID integration still resolves.
 */
const OP_ENV: Record<string, string> = {
  PATH: '/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin',
  OP_CONFIG_DIR: `${glide.path.home_dir}/.homesick/repos/private/home/.config/op`,
};

/**
 * Host permission needed to inject into pages (both the fill and the field
 * decoration go through `glide.content.execute`, which requires it).
 */
const HOST_PERMISSION: Browser.Permissions.Permissions = {
  origins: ['<all_urls>'],
};

/** True if we already hold the `<all_urls>` host permission. */
const hasHostPermission = (): Promise<boolean> =>
  browser.permissions.contains(HOST_PERMISSION);

/**
 * Ensure the `<all_urls>` host permission, requesting it if missing.
 *
 * `browser.permissions.request` needs a user gesture, so this must be called
 * synchronously off a keypress / click (e.g. from the fill excmds), not from a
 * background autocmd.
 */
const ensureHostPermission = async (): Promise<boolean> => {
  if (await hasHostPermission()) return true;

  try {
    return await browser.permissions.request(HOST_PERMISSION);
  } catch (error) {
    console.error('op-fill: could not request host permission', error);

    return false;
  }
};

interface OpUrl {
  readonly label?: string;
  readonly primary?: boolean;
  readonly href: string;
}

interface OpVaultRef {
  readonly id: string;
  readonly name: string;
}

interface OpListItem {
  readonly id: string;
  readonly title: string;
  readonly additional_information?: string;
  readonly urls?: readonly OpUrl[];
  readonly vault?: OpVaultRef;
}

interface OpField {
  readonly id: string;
  readonly label?: string;
  readonly type: string;
  readonly purpose?: string;
  readonly value?: string;
}

interface OpItemDetail {
  readonly id: string;
  readonly title: string;
  readonly fields?: readonly OpField[];
}

/** A list item enriched with its account and normalised hostnames. */
interface IndexedItem extends OpListItem {
  /** Stable account identifier (`user_uuid`) used as the `--account` filter. */
  readonly accountId: string;
  readonly accountLabel: string;
  readonly hosts: readonly string[];
}

/**
 * Candidate absolute paths for the `op` binary.
 *
 * Glide resolves a bare command name against its *own* (sparse, GUI-app)
 * `PATH` — not the `env` we pass to the child — so a bare `"op"` isn't found.
 * Using an absolute path skips that lookup entirely.
 */
const OP_BINARY_CANDIDATES = [
  '/opt/homebrew/bin/op',
  '/usr/local/bin/op',
  '/usr/bin/op',
] as const;

let opBinaryPromise: Promise<string> | null = null;

/** Resolve (and cache) the absolute path to `op`, falling back to `PATH`. */
const resolveOpBinary = (): Promise<string> => {
  opBinaryPromise ??= (async () => {
    const checks = await Promise.all(
      OP_BINARY_CANDIDATES.map(async path => ({
        path,
        exists: await glide.fs.exists(path),
      })),
    );

    return checks.find(check => check.exists)?.path ?? 'op';
  })();

  return opBinaryPromise;
};

/**
 * Run `op` with the given args and return its stdout.
 *
 * Throws (via `check_exit_code`) on a non-zero exit.
 */
const runOp = async (args: readonly string[]): Promise<string> => {
  const binary = await resolveOpBinary();
  // Use spawn + drain both pipes concurrently, then wait. `execute` waits for
  // exit up front, which can deadlock when a large stdout (1000+ items) fills
  // the pipe before anyone reads it. `check_exit_code: false` lets us read
  // stderr and throw op's real error instead of the opaque non-zero message.
  const proc = await glide.process.spawn(binary, [...args], {
    env: OP_ENV,
    extend_env: true,
    check_exit_code: false,
  });

  const [stdout, stderr] = await Promise.all([
    proc.stdout.text(),
    proc.stderr?.text() ?? Promise.resolve(''),
  ]);
  const { exit_code } = await proc.wait();

  if (exit_code !== 0) {
    throw new Error(
      `op ${args.join(' ')} exited ${exit_code}: ` +
        (stderr.trim() || stdout.trim() || 'no output'),
    );
  }

  return stdout;
};

/**
 * Extract the lowercased hostname from an `op` URL `href`, which may be a bare
 * host (`meterdown.com`) or a full URL.
 */
const hostFromHref = (href: string): string => {
  try {
    const withScheme = href.includes('://') ? href : `https://${href}`;

    return new URL(withScheme).hostname.toLowerCase();
  } catch {
    return '';
  }
};

/**
 * Common two-label public suffixes, so `example.co.uk` resolves to
 * `example.co.uk` rather than `co.uk`. Not the full Public Suffix List, but
 * covers the suffixes most likely to show up in saved logins.
 */
const MULTI_PART_TLDS = new Set([
  'co.uk',
  'org.uk',
  'me.uk',
  'ac.uk',
  'gov.uk',
  'co.jp',
  'co.nz',
  'co.in',
  'co.za',
  'com.au',
  'net.au',
  'org.au',
  'com.br',
  'com.mx',
  'com.sg',
]);

/**
 * Best-effort registrable ("base") domain — the scope 1Password matches by
 * default, collapsing all subdomains (so `mydoctor.kaiserpermanente.org` and
 * `www.kaiserpermanente.org` both match `kaiserpermanente.org`).
 */
const baseDomain = (host: string): string => {
  const parts = host.split('.').filter(part => part.length > 0);
  if (parts.length <= 2) return parts.join('.');

  const lastTwo = parts.slice(-2).join('.');

  return MULTI_PART_TLDS.has(lastTwo) ? parts.slice(-3).join('.') : lastTwo;
};

/** Match an item URL host to the page host by base domain (1Password default). */
const hostMatches = (itemHost: string, pageHost: string): boolean => {
  const pageBase = baseDomain(pageHost);

  return pageBase.length > 0 && baseDomain(itemHost) === pageBase;
};

/** Discover the configured `op` accounts. */
const listAccounts = async (): Promise<readonly OpAccount[]> => {
  try {
    return JSON.parse(
      await runOp(['account', 'list', '--format=json']),
    ) as readonly OpAccount[];
  } catch (error) {
    console.warn('op-fill: failed to list accounts', error);

    return [];
  }
};

/** `op item list` caps its output; a full count of this many is likely cut. */
const OP_LIST_CAP = 1000;

/** Max options rendered in the picker at once (protects the commandline). */
const MAX_MENU_ITEMS = 50;

/**
 * In-memory index of Login items across all accounts.
 *
 * Only non-secret metadata (id / title / urls / account) is cached; secrets
 * are fetched lazily at fill time. Cleared by the `op_reload` excmd.
 */
let indexCache: readonly IndexedItem[] | null = null;

/** Fetch and index one account's Login items. */
const loadAccountItems = async (
  account: OpAccount,
): Promise<readonly IndexedItem[]> => {
  try {
    const json = await runOp([
      'item',
      'list',
      '--account',
      account.user_uuid,
      '--categories',
      'Login',
      '--format=json',
    ]);
    const items = JSON.parse(json) as readonly OpListItem[];

    if (items.length >= OP_LIST_CAP) {
      console.warn(
        `op-fill: "${account.url}" returned ${items.length} items ` +
          `(op's list cap) — some logins may be missing from the index`,
      );
    }

    const label = accountLabel(account);

    return items.map(item => ({
      ...item,
      accountId: account.user_uuid,
      accountLabel: label,
      hosts: (item.urls ?? [])
        .map(url => hostFromHref(url.href))
        .filter(host => host.length > 0),
    }));
  } catch (error) {
    console.warn(`op-fill: failed to list items for "${account.url}"`, error);

    return [];
  }
};

const loadIndex = async (force = false): Promise<readonly IndexedItem[]> => {
  if (indexCache && !force) return indexCache;

  const accounts = await listAccounts();

  // Sequential, NOT Promise.all: concurrent `op` calls each raise their own
  // biometric prompt, and two simultaneous prompts deadlock the 1Password
  // desktop-app integration. The first call unlocks the session; the rest
  // reuse it without prompting.
  const collected: IndexedItem[] = [];
  for (const account of accounts) {
    collected.push(...(await loadAccountItems(account)));
  }

  indexCache = collected;

  return indexCache;
};

const fieldValue = (
  detail: OpItemDetail,
  purpose: 'USERNAME' | 'PASSWORD',
): string | null => {
  const field = (detail.fields ?? []).find(f => f.purpose === purpose);

  return field?.value ?? null;
};

// ---------------------------------------------------------------------------
// Content-process functions
//
// The bodies below are stringified and executed in the page, so they MUST be
// fully self-contained: no references to module-scope variables or helpers.
// Config/credentials arrive via `args`.
// ---------------------------------------------------------------------------

interface FillCredentials {
  readonly username: string | null;
  readonly password: string | null;
}

interface FillOptions {
  readonly submit: boolean;
}

/**
 * Fill the detected login fields on the page and optionally submit.
 *
 * Runs in the content process.
 */
const fillIntoPage = (
  credentials: FillCredentials,
  options: FillOptions,
): void => {
  const isVisible = (element: HTMLElement): boolean => {
    const rect = element.getBoundingClientRect();
    const style = getComputedStyle(element);

    return (
      rect.width > 0 &&
      rect.height > 0 &&
      style.visibility !== 'hidden' &&
      style.display !== 'none'
    );
  };

  const setNativeValue = (element: HTMLInputElement, value: string): void => {
    const descriptor = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      'value',
    );
    descriptor?.set?.call(element, value);
    element.dispatchEvent(new Event('input', { bubbles: true }));
    element.dispatchEvent(new Event('change', { bubbles: true }));
  };

  const inputs = Array.from(document.querySelectorAll('input')).filter(
    isVisible,
  );
  const passwordField = inputs.find(
    input => input.type.toLowerCase() === 'password',
  );

  const usernameField = (() => {
    const scope = passwordField?.form
      ? Array.from(passwordField.form.querySelectorAll('input')).filter(
          isVisible,
        )
      : inputs;
    const byAutocomplete = scope.find(input =>
      (input.getAttribute('autocomplete') ?? '')
        .toLowerCase()
        .split(/\s+/)
        .includes('username'),
    );
    if (byAutocomplete) return byAutocomplete;

    const byType = scope.find(input => {
      const type = input.type.toLowerCase();

      return type === 'email' || type === 'text' || type === 'tel';
    });

    return byType ?? null;
  })();

  let filledPassword = false;
  let filledUsername = false;

  if (usernameField && credentials.username) {
    setNativeValue(usernameField, credentials.username);
    filledUsername = true;
  }

  if (passwordField && credentials.password) {
    setNativeValue(passwordField, credentials.password);
    filledPassword = true;
  }

  const shouldSubmit =
    options.submit && (filledPassword || (filledUsername && !passwordField));

  if (!shouldSubmit) return;

  const anchor = passwordField ?? usernameField;
  if (!anchor) return;

  const form = anchor.closest('form');
  if (form) {
    const submitButton = form.querySelector<HTMLElement>(
      'button[type=submit], input[type=submit], button:not([type])',
    );
    if (submitButton) {
      submitButton.click();

      return;
    }
    if (typeof form.requestSubmit === 'function') {
      form.requestSubmit();

      return;
    }
    form.submit();

    return;
  }

  const keyInit: KeyboardEventInit = {
    key: 'Enter',
    code: 'Enter',
    keyCode: 13,
    which: 13,
    bubbles: true,
  };
  anchor.dispatchEvent(new KeyboardEvent('keydown', keyInit));
  anchor.dispatchEvent(new KeyboardEvent('keyup', keyInit));
};

/**
 * Install (idempotently) the field decorations: a masked "halo" band around
 * each login field that widens on the right into a clickable 1Password badge.
 *
 * Runs in the content process; re-invoked on every navigation. Config arrives
 * via `args` since the body cannot capture module scope.
 */
const applyDecoration = (config: HaloConfig): void => {
  const LAYER_ID = 'op-fill-layer';
  const innerRadius = Math.max(0, config.outerRadius - config.thickness);

  const stateWindow = window as unknown as {
    __opFillRescan?: () => void;
  };

  const isVisible = (element: HTMLElement): boolean => {
    const rect = element.getBoundingClientRect();
    const style = getComputedStyle(element);

    return (
      rect.width > 0 &&
      rect.height > 0 &&
      style.visibility !== 'hidden' &&
      style.display !== 'none'
    );
  };

  const findLoginInputs = (): HTMLInputElement[] => {
    const inputs = Array.from(document.querySelectorAll('input')).filter(
      isVisible,
    );
    const passwordForms = new Set(
      inputs
        .filter(input => input.type.toLowerCase() === 'password')
        .map(input => input.form)
        .filter((form): form is HTMLFormElement => form !== null),
    );

    return inputs.filter(input => {
      const type = input.type.toLowerCase();
      if (type === 'password') return true;

      const autocomplete = (input.getAttribute('autocomplete') ?? '')
        .toLowerCase()
        .split(/\s+/);
      if (autocomplete.includes('username')) return true;

      const isTextLike = type === 'email' || type === 'text';

      return isTextLike && input.form !== null && passwordForms.has(input.form);
    });
  };

  const holeMaskUrl = (holeWidth: number, holeHeight: number): string => {
    const svg =
      `<svg xmlns='http://www.w3.org/2000/svg' width='${holeWidth}' ` +
      `height='${holeHeight}'><rect x='0' y='0' width='${holeWidth}' ` +
      `height='${holeHeight}' rx='${innerRadius}' ry='${innerRadius}' ` +
      `fill='black'/></svg>`;

    return `data:image/svg+xml,${encodeURIComponent(svg)}`;
  };

  interface Decoration {
    readonly halo: HTMLDivElement;
    readonly frame: HTMLDivElement;
    readonly button: HTMLDivElement;
    lastKey: string;
  }

  const layer = (() => {
    const existing = document.getElementById(LAYER_ID);
    if (existing instanceof HTMLDivElement) return existing;

    const created = document.createElement('div');
    created.id = LAYER_ID;
    Object.assign(created.style, {
      position: 'fixed',
      inset: '0',
      pointerEvents: 'none',
      zIndex: '2147483646',
    } satisfies Partial<CSSStyleDeclaration>);
    (document.body ?? document.documentElement).appendChild(created);

    return created;
  })();

  const tracked = new Map<HTMLInputElement, Decoration>();

  const createDecoration = (): Decoration => {
    const halo = document.createElement('div');
    halo.setAttribute('data-op-fill-halo', '');
    Object.assign(halo.style, {
      position: 'absolute',
      pointerEvents: 'none',
    } satisfies Partial<CSSStyleDeclaration>);

    const frame = document.createElement('div');
    Object.assign(frame.style, {
      position: 'absolute',
      inset: '0',
      backgroundColor: config.color,
      opacity: String(config.opacity),
      backdropFilter: `blur(${config.blurRadius}px)`,
      borderRadius: `${config.outerRadius}px`,
      maskComposite: 'exclude',
      maskRepeat: 'no-repeat, no-repeat',
    } satisfies Partial<CSSStyleDeclaration>);

    const button = document.createElement('div');
    button.setAttribute('data-op-fill-button', '');
    button.setAttribute('role', 'button');
    button.setAttribute('aria-label', 'Fill with 1Password');
    Object.assign(button.style, {
      position: 'absolute',
      pointerEvents: 'auto',
      cursor: 'pointer',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
    } satisfies Partial<CSSStyleDeclaration>);

    const icon = document.createElement('div');
    Object.assign(icon.style, {
      width: '70%',
      height: '70%',
      backgroundColor: config.iconColor,
      maskImage: `url("${config.iconDataUrl}")`,
      maskRepeat: 'no-repeat',
      maskPosition: 'center',
      maskSize: 'contain',
    } satisfies Partial<CSSStyleDeclaration>);
    button.appendChild(icon);

    halo.appendChild(frame);
    halo.appendChild(button);

    return { halo, frame, button, lastKey: '' };
  };

  const syncOne = (input: HTMLInputElement, deco: Decoration): void => {
    const rect = input.getBoundingClientRect();
    const { offset, thickness, buttonWidth } = config;

    const holeWidth = rect.width + offset * 2;
    const holeHeight = rect.height + offset * 2;
    const outerWidth = holeWidth + thickness * 2 + buttonWidth;
    const outerHeight = holeHeight + thickness * 2;

    Object.assign(deco.halo.style, {
      left: `${rect.left - offset - thickness}px`,
      top: `${rect.top - offset - thickness}px`,
      width: `${outerWidth}px`,
      height: `${outerHeight}px`,
    } satisfies Partial<CSSStyleDeclaration>);

    const key = `${Math.round(holeWidth)}x${Math.round(holeHeight)}`;
    if (key !== deco.lastKey) {
      deco.lastKey = key;
      // First mask layer fills the whole frame; the second punches out the
      // input-shaped hole (composited with `exclude`), leaving the band + the
      // wider right region that hosts the badge.
      deco.frame.style.maskImage = `linear-gradient(black, black), url("${holeMaskUrl(holeWidth, holeHeight)}")`;
      deco.frame.style.maskPosition = `0 0, ${thickness}px ${thickness}px`;
      deco.frame.style.maskSize = `100% 100%, ${holeWidth}px ${holeHeight}px`;
    }

    Object.assign(deco.button.style, {
      left: `${thickness + holeWidth}px`,
      top: `${thickness}px`,
      width: `${thickness + buttonWidth}px`,
      height: `${holeHeight}px`,
    } satisfies Partial<CSSStyleDeclaration>);
  };

  const sync = (): void => {
    tracked.forEach((deco, input) => syncOne(input, deco));
  };

  const rescan = (): void => {
    const current = new Set(findLoginInputs());

    tracked.forEach((deco, input) => {
      if (!current.has(input) || !document.contains(input)) {
        deco.halo.remove();
        tracked.delete(input);
      }
    });

    current.forEach(input => {
      if (tracked.has(input)) return;

      const deco = createDecoration();
      layer.appendChild(deco.halo);
      tracked.set(input, deco);
    });

    sync();
  };

  // Already installed on this document — just re-scan for new/removed fields.
  if (stateWindow.__opFillRescan) {
    stateWindow.__opFillRescan();

    return;
  }

  let frame = 0;
  const schedule = (task: () => void): void => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(task);
  };

  window.addEventListener('scroll', () => schedule(sync), {
    capture: true,
    passive: true,
  });
  window.addEventListener('resize', () => schedule(sync), { passive: true });

  const resizeObserver = new ResizeObserver(() => schedule(sync));
  const mutationObserver = new MutationObserver(() => schedule(rescan));
  mutationObserver.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });

  const trackedRescan = (): void => {
    rescan();
    tracked.forEach((_deco, input) => resizeObserver.observe(input));
  };

  stateWindow.__opFillRescan = trackedRescan;
  trackedRescan();
};

// ---------------------------------------------------------------------------
// Menu (main process)
// ---------------------------------------------------------------------------

interface OpFillMessages {
  readonly op_fill_requested: null;
}

/** Deterministic hue (0–359) from a string, for tinting monograms. */
const hueFromString = (value: string): number => {
  const hash = [...value].reduce(
    (accumulator, character) =>
      (accumulator * 31 + character.charCodeAt(0)) >>> 0,
    0,
  );

  return hash % 360;
};

/**
 * A small rounded monogram tile for an item, tinted from its title.
 *
 * `op` exposes no favicons/icons, so this stands in for 1Password's item art.
 */
const monogram = (title: string): HTMLElement => {
  const hue = hueFromString(title);

  return DOM.create_element('div', {
    style: {
      flexShrink: '0',
      width: '32px',
      height: '32px',
      borderRadius: '7px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: '0.9em',
      fontWeight: '600',
      color: `hsl(${hue}, 70%, 85%)`,
      backgroundColor: `hsl(${hue}, 40%, 32%)`,
    },
    children: [(title.trim()[0] ?? '?').toUpperCase()],
  });
};

/**
 * Item icon: the monogram, with `faviconUrl` overlaid when provided.
 *
 * We use the *active tab's* favicon (the site the user is on) for host-matched
 * items — a real icon with no third-party request. If it fails to load, the
 * `error` handler removes the image and the monogram shows through.
 */
const itemIcon = (item: IndexedItem, faviconUrl?: string): HTMLElement => {
  const tile = monogram(item.title);

  if (!faviconUrl) return tile;

  tile.style.position = 'relative';

  const image = DOM.create_element('img', {
    src: faviconUrl,
    style: {
      position: 'absolute',
      inset: '0',
      width: '100%',
      height: '100%',
      borderRadius: '7px',
      objectFit: 'cover',
    },
  });
  image.addEventListener('error', () => image.remove());
  tile.appendChild(image);

  return tile;
};

/**
 * A small icon tinted to the current text colour via CSS mask.
 *
 * `backgroundColor: currentColor` makes the glyph follow the row's text colour,
 * so it reads correctly on both dark (unselected) and white (selected) rows.
 * Sized in `em` so it tracks the surrounding font size.
 */
const tintedIcon = (dataUrl: string): HTMLElement =>
  DOM.create_element('span', {
    style: {
      width: '1em',
      height: '1em',
      flexShrink: '0',
      backgroundColor: 'currentColor',
      maskImage: `url("${dataUrl}")`,
      maskRepeat: 'no-repeat',
      maskPosition: 'center',
      maskSize: 'contain',
    },
  });

/** Small, dimmed metadata label (vault / account) with a leading icon. */
const metaChip = (iconDataUrl: string, text: string): HTMLElement =>
  DOM.create_element('span', {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '4px',
      fontSize: '0.72em',
      opacity: '0.7',
      whiteSpace: 'nowrap',
    },
    children: [tintedIcon(iconDataUrl), text],
  });

const primaryHostOf = (item: IndexedItem): string => {
  const primary = item.urls?.find(url => url.primary) ?? item.urls?.[0];

  return primary ? hostFromHref(primary.href) : '';
};

const itemOption = (
  item: IndexedItem,
  tab: glide.TabWithID,
  options: FillOptions,
  faviconUrl?: string,
): glide.CommandLineCustomOption => {
  const username = item.additional_information ?? '';
  const host = primaryHostOf(item);
  const vaultName = item.vault?.name ?? '';
  const subtitle = [username, host]
    .filter(part => part.length > 0)
    .join('  ·  ');
  const haystack = [item.title, username, host, vaultName]
    .join(' ')
    .toLowerCase();

  return {
    label: item.title,
    description: username,
    render: () =>
      DOM.create_element('div', {
        style: {
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          width: '100%',
          boxSizing: 'border-box',
          padding: '4px 12px',
        },
        children: [
          itemIcon(item, faviconUrl),
          DOM.create_element('div', {
            style: {
              display: 'flex',
              flexDirection: 'column',
              gap: '1px',
              flex: '1',
              minWidth: '0',
            },
            children: [
              DOM.create_element('span', {
                style: {
                  lineHeight: '1.3',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                },
                children: [item.title],
              }),
              DOM.create_element('span', {
                style: {
                  fontSize: '0.82em',
                  lineHeight: '1.3',
                  opacity: '0.55',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                },
                children: [subtitle],
              }),
            ],
          }),
          DOM.create_element('div', {
            style: {
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'flex-end',
              gap: '2px',
              flexShrink: '0',
              marginLeft: '8px',
            },
            children: [
              ...(vaultName ? [metaChip(icons.vault, vaultName)] : []),
              metaChip(icons.account, item.accountLabel),
            ],
          }),
        ],
      }),
    matches: ({ input }) =>
      input ? haystack.includes(input.toLowerCase()) : true,
    execute: async () => {
      await fillFromItem(item, tab, options);
    },
  };
};

/** Fetch the selected item's credential and inject it into the page. */
const fillFromItem = async (
  item: IndexedItem,
  tab: glide.TabWithID,
  options: FillOptions,
): Promise<void> => {
  try {
    const detail = JSON.parse(
      await runOp([
        'item',
        'get',
        item.id,
        '--account',
        item.accountId,
        '--format=json',
      ]),
    ) as OpItemDetail;

    const password = fieldValue(detail, 'PASSWORD');
    const credentials: FillCredentials = {
      username: fieldValue(detail, 'USERNAME'),
      password,
    };

    // Passwordless (SSO) items can't be auto-submitted — fall back to filling
    // the username only, never submitting.
    const submit = options.submit && password !== null;

    await glide.content.execute(fillIntoPage, {
      tab_id: tab.id,
      args: [credentials, { submit }],
    });
  } catch (error) {
    console.error(
      'op-fill: failed to fill item (if this is a permission error, grant ' +
        'the host-access prompt on the next fill)',
      error,
    );
  }
};

/** Build and show the item picker for the active tab's host. */
const openMenu = async (
  tab: glide.TabWithID,
  options: FillOptions,
): Promise<void> => {
  // Request the host permission now, while we still hold the user gesture that
  // triggered the menu — the later fill (content injection) needs it.
  await ensureHostPermission();

  const pageHost = glide.ctx.url.hostname.toLowerCase();
  const index = await loadIndex();
  const matches = index.filter(item =>
    item.hosts.some(host => hostMatches(host, pageHost)),
  );
  const showAll = matches.length === 0;
  // Cap the option count — rendering the entire index (~1000s) into the
  // commandline at once can make it fail to open.
  const items = (showAll ? index : matches).slice(0, MAX_MENU_ITEMS);
  // Matched items are all the current site, so the active tab's already-loaded
  // favicon is their real icon (no third-party request). Arbitrary "show all"
  // items are different sites, so they fall back to monograms.
  const faviconUrl = showAll ? undefined : tab.favIconUrl;

  if (items.length === 0) {
    // Not awaited: `commandline.show` resolves on close, and awaiting it stalls
    // the excmd (and breaks re-opening from command mode). Fire and return.
    void glide.commandline.show({
      title: '1Password',
      options: [
        {
          label: 'No 1Password items found',
          description: 'Check the `op` CLI / Touch ID, then :op_reload',
          execute: () => {},
        },
      ],
    });

    return;
  }

  void glide.commandline.show({
    title: showAll
      ? `1Password — no match for ${pageHost} (${index.length} items)`
      : `1Password — ${pageHost}`,
    options: items.map(item => itemOption(item, tab, options, faviconUrl)),
  });
};

// ---------------------------------------------------------------------------
// Wiring: excmds, badge-click bridge, and per-navigation decoration
// ---------------------------------------------------------------------------

/** Content → main bridge for badge clicks (the only direction Glide allows). */
const fillMessenger = glide.messengers.create<OpFillMessages>(message => {
  if (message.name !== 'op_fill_requested') return;

  void (async () => {
    const tab = await glide.tabs.active();
    await openMenu(tab, { submit: true });
  })();
});

const opFill = glide.excmds.create(
  { name: 'op_fill', description: 'Autofill from 1Password (fill + submit)' },
  async () => {
    const tab = await glide.tabs.active();
    await openMenu(tab, { submit: true });
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { op_fill: typeof opFill; } }

const opFillNoSubmit = glide.excmds.create(
  {
    name: 'op_fill_no_submit',
    description: 'Autofill from 1Password (fill only, no submit)',
  },
  async () => {
    const tab = await glide.tabs.active();
    await openMenu(tab, { submit: false });
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { op_fill_no_submit: typeof opFillNoSubmit; } }

const opReload = glide.excmds.create(
  { name: 'op_reload', description: 'Reload the cached 1Password item index' },
  async () => {
    await loadIndex(true);
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { op_reload: typeof opReload; } }

// Re-apply decorations and (idempotently) wire badge clicks on every
// navigation. Skips non-web pages and no-ops until the host permission is
// granted (a background autocmd can't request it — that happens on first fill).
glide.autocmds.create('UrlEnter', /.*/, ({ tab_id, url }) => {
  if (!/^https?:/i.test(url)) return;

  void (async () => {
    if (!(await hasHostPermission())) return;

    try {
      await glide.content.execute(applyDecoration, {
        tab_id,
        args: [DECORATION],
      });

      fillMessenger.content.execute(
        messenger => {
          const wiredWindow = window as unknown as {
            __opFillClickWired?: boolean;
          };
          if (wiredWindow.__opFillClickWired) return;
          wiredWindow.__opFillClickWired = true;

          document.addEventListener(
            'click',
            event => {
              const target = event.target as Element | null;
              if (!target?.closest('[data-op-fill-button]')) return;

              event.preventDefault();
              event.stopPropagation();
              messenger.send('op_fill_requested');
            },
            true,
          );
        },
        { tab_id },
      );
    } catch {
      // Injection can still fail on privileged pages — ignore.
    }
  })();
});

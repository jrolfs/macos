const GOOGLE_SIGNIN_ALLOW = [
  'accounts.google.com',
  'mail.google.com',
  'claude.ai',
  'claude.com'
] as const satisfies string[];

const isGoogleSigninAllowed = (url: string): boolean => {
  try {
    const host = new URL(url).hostname.toLowerCase();

    return GOOGLE_SIGNIN_ALLOW.some(
      allowed => host === allowed || host.endsWith('.' + allowed),
    );
  } catch {
    return false;
  }
};

browser.webRequest.onBeforeRequest.addListener(
  async details => {
    // not in a tab, allow request
    if (details.tabId === -1) return {};

    try {
      const tab = await browser.tabs.get(details.tabId);

      if (isGoogleSigninAllowed(tab.url ?? '')) return {};

      return { cancel: true };
    } catch {
      return {};
    }
  },
  {
    urls: ['*://accounts.google.com/gsi/*'],
  },
  ['blocking'],
);

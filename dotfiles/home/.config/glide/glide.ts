/**
 * Documentation: https://glide-browser.app/config
 * Reference: https://glide-browser.app/api
 * Defaults configuration: https://github.com/glide-browser/glide/tree/main/src/glide/browser/base/content/plugins
 * Default keymappings: https://github.com/glide-browser/glide/blob/main/src/glide/browser/base/content/plugins/keymaps.mts
 */

glide.include('keymaps.ts');

// Commands

glide.include('settings.ts');
glide.include('toolbar.ts');
glide.include('tabs.ts');
glide.include('tab-activity.ts');
glide.include('tab-pip.ts');
glide.include('windows.ts');
glide.include('cookies.ts');
// Parked. Matching entries by scraping is too unreliable to leave on. Revisit
// with the 1Password SDK, which can recommend entries from the page URL.
// glide.include('one-password.ts');

glide.include('mode-indicator.ts');

// Miscellaneous

glide.include('google-signin.ts');

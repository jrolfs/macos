/**
 * Documentation: https://glide-browser.app/config
 * Reference: https://glide-browser.app/api
 * Defaults configuration: https://github.com/glide-browser/glide/tree/main/src/glide/browser/base/content/plugins
 * Default keymappings: https://github.com/glide-browser/glide/blob/main/src/glide/browser/base/content/plugins/keymaps.mts
 */

glide.include('keymaps.ts');

// Commands

glide.include('settings.ts');
glide.include('tabs.ts');
glide.include('tab-activity.ts');
glide.include('tab-pip.ts');
glide.include('windows.ts');
glide.include('cookies.ts');

// Miscellaneous

glide.include('google-signin.ts');

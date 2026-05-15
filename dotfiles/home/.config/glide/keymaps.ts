import type { SimpleKeymapTuple } from './types';

/**
 * Default keymappings: https://github.com/glide-browser/glide/blob/main/src/glide/browser/base/content/plugins/keymaps.mts
 */

(
  [
    //
    // Command

    ['command', '<C-n>', 'commandline_focus_next', 'Focus next command'],
    ['command', '<C-p>', 'commandline_focus_back', 'Focus previous command'],

    //
    // Normal

    // Tabs
    ['normal', 'q', 'tab_close', 'Close current tab'],
    ['normal', '<S-q>', 'tab_reopen', 'Reopen last closed tab'],
    ['normal', 't', 'tab_new', 'Open a new tab'],
    ['normal', '<leader>td', 'tab_duplicate', 'Duplicate the active tab'],
    ['normal', '<leader>tp', 'tab_pin_toggle', 'Toggle pinning the active tab'],
    ['normal', '<leader>tD', 'tab_move', 'Detach current tab into a new window'],
    ['normal', '<leader>tm', 'tab_move list', 'Move tab to another window'],
    // Groups
    ['normal', '<leader>tg', 'tab_group_move list', 'Move tab into a group'],
    ['normal', '<leader>tG', 'tab_group_move', 'Move tab into a new group'],
    ['normal', '<leader>tr', 'tab_group_rename', 'Rename the active tab group'],
    ['normal', '<leader>tc', 'tab_group_collapse_toggle', 'Toggle collapse of the active tab group'],
    // Activity
    ['normal', '<leader>ta', 'tab_activity toggle', 'Toggle activity capture on the active tab'],
    // PiP
    ['normal', '<leader>tf', 'tab_pip toggle', 'Toggle floating PiP window for the active tab'],

    ['normal', '<leader><leader>', 'tab_search_all', 'Fuzzy search tabs across all windows'],
    ['normal', '<leader>tQ', 'tab_recently_closed', 'List recently closed tabs'],
    ['normal', '<leader>t~', 'tab_close_other', 'Close all other tabs'],
    ['normal', '<leader>t>', 'tab_close_right', 'Close tabs to the right'],
    ['normal', '<leader>t<', 'tab_close_left', 'Close tabs to the left'],

    // Windows
    ['normal', '<leader>wl', 'window_list', 'List open windows with their IDs'],
    ['normal', '<leader>wq', 'window_close', 'Close window'],

    // Settings
    [
      'normal',
      '<leader>ss',
      'scale_toggle 1.8 2.0',
      'Toggle pixel density for all windows between 1.8 and 2.0',
    ],
    [
      'normal',
      '<leader>sS',
      'scale',
      'Scale pixel density to specified decimal value',
    ],

    // Cookies
    ['normal', '<leader>cc', 'cookie_copy COOKIE_DEV_DASHBOARD_FRONTEND_V3=dashboard.frontend.v3,COOKIE_DEV_DASHBOARD_V3=dashboard.v3', 'Copy Meter staging cookies to clipboard'],

    // Glide
    ['normal', '<leader><C-l>', 'clear', 'Clear alert notifications'],
    ['normal', '<leader><C-r>', 'config_reload', 'Reload configuration'],
  ] satisfies SimpleKeymapTuple[]
).map(([mode, map, command, description]) =>
  glide.keymaps.set(mode, map, command, { description }),
);

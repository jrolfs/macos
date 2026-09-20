/**
 * Toolbar layout: which buttons are where, spacers, pinned/removed items.
 *
 * Firefox Sync has never synced this. The layout lives in the
 * `browser.uiCustomization.state` pref, which sync excludes, so pinning it
 * here is what makes a fresh machine come up with the same chrome.
 *
 * Rearrange the toolbar in the UI (right-click, Customize Toolbar), then run
 * `:toolbar_export` to record the layout. Applies on startup, so a running
 * instance may need a restart to pick it up.
 */

const TOOLBAR_PREF = 'browser.uiCustomization.state';

// Resolved against the config directory, which is this file's own directory.
const TOOLBAR_CONFIG = 'toolbar.ts';

// Written by :toolbar_export, which replaces everything between the markers.
// Escaping the slashes keeps this pattern from matching its own source line.
const GENERATED_REGION =
  /^\/\/ #region generated$[\s\S]*?^\/\/ #endregion generated$/m;

// #region generated
// oxfmt-ignore
const toolbarState = {
  "placements": {
    "widget-overflow-fixed-list": [
      "downloads-button",
      "fxa-toolbar-menu-button",
      "firefox-view-button",
      "alltabs-button",
      "sidebar-button"
    ],
    "unified-extensions-area": [
      "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action",
      "neaturl_hugsmile_eu-browser-action",
      "gdpr_cavi_au_dk-browser-action",
      "_a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad_-browser-action",
      "_7599bb55-1e8e-445a-9e32-66da6e1d6749_-browser-action",
      "_8e8191f9-877a-45a0-b186-b5e83e98b7e9_-browser-action",
      "87677a2c52b84ad3a151a4a72f5bd3c4_jetpack-browser-action",
      "firefoxcolor_mozilla_com-browser-action"
    ],
    "nav-bar": [
      "back-button",
      "forward-button",
      "vertical-spacer",
      "urlbar-container",
      "reset-pbm-toolbar-button",
      "unified-extensions-button"
    ],
    "TabsToolbar": [
      "tabbrowser-tabs",
      "glide-toolbar-mode-button"
    ],
    "vertical-tabs": [],
    "PersonalToolbar": [
      "import-button",
      "personal-bookmarks"
    ]
  },
  "seen": [
    "reset-pbm-toolbar-button",
    "developer-button",
    "screenshot-button",
    "neaturl_hugsmile_eu-browser-action",
    "gdpr_cavi_au_dk-browser-action",
    "_a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad_-browser-action",
    "_7599bb55-1e8e-445a-9e32-66da6e1d6749_-browser-action",
    "_8e8191f9-877a-45a0-b186-b5e83e98b7e9_-browser-action",
    "87677a2c52b84ad3a151a4a72f5bd3c4_jetpack-browser-action",
    "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action",
    "firefoxcolor_mozilla_com-browser-action",
    "ipprotection-button"
  ],
  "dirtyAreaCache": [
    "nav-bar",
    "vertical-tabs",
    "PersonalToolbar",
    "TabsToolbar",
    "widget-overflow-fixed-list",
    "unified-extensions-area"
  ],
  "currentVersion": 24,
  "newElementCount": 8
};
// #endregion generated

glide.prefs.set(TOOLBAR_PREF, JSON.stringify(toolbarState));

// Reads the pref out of the running instance rather than scanning profile
// directories. The release and developer builds keep separate profiles under
// one Profiles/ root, so picking a profile by modification time snapshots
// whichever build was touched last instead of the one being customized. It also
// avoids reading a prefs.js that has not been flushed yet.
const toolbarExport = glide.excmds.create(
  {
    name: 'toolbar_export',
    description: 'Record the current toolbar layout into toolbar.ts',
  },
  async () => {
    const pref = glide.prefs.get(TOOLBAR_PREF);

    assert(
      typeof pref === 'string',
      `${TOOLBAR_PREF} is unset, customize the toolbar before exporting`,
    );

    const source = await glide.fs.read(TOOLBAR_CONFIG, 'utf8');

    assert(
      GENERATED_REGION.test(source),
      `No generated region found in ${TOOLBAR_CONFIG}`,
    );

    const region = [
      '// #region generated',
      '// oxfmt-ignore',
      `const toolbarState = ${JSON.stringify(JSON.parse(pref), null, 2)};`,
      '// #endregion generated',
    ].join('\n');

    // Replacing via a function keeps `$` sequences in the layout literal from
    // being read as replacement patterns.
    await glide.fs.write(
      TOOLBAR_CONFIG,
      source.replace(GENERATED_REGION, () => region),
    );

    console.log(`Wrote ${TOOLBAR_CONFIG} from ${glide.path.profile_dir}`);
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { toolbar_export: typeof toolbarExport; } }

//
// General

user_pref("general.warnOnAboutConfig", false);

//
// Developer

user_pref("devtools.theme", "dark");

//
// Extensions

user_pref("privacy.resistFingerprinting.block_mozAddonManager", true);
user_pref("extensions.webextensions.restrictedDomains", "");

//
// Interface

user_pref("browser.pageActions.persistedActions", `
  {
    "version": 1,
    "ids": [
      "bookmark",
      "bookmarkSeparator",
      "copyURL",
      "emailLink",
      "addSearchEngine",
      "sendToDevice",
      "shareURL",
      "pocket",
      "webcompat-reporter_mozilla_org",
      "screenshots_mozilla_org"
    ],
    "idsInUrlbar": []
  }
`);

//
// Security

user_pref("security.webauth.u2f", true);

type Action = 'toggle' | 'capture' | 'release';

const capturedTabs = new Set<number>();

/**
 * Spoofs visibility and focus state so the page always believes it is active.
 *
 * Runs in the MAIN world so overrides are visible to page scripts.
 */
const activitySpoofScript = () => {
  const tag = '[tab_activity]';

  // Visibility API
  Object.defineProperty(document, 'visibilityState', {
    get: () => 'visible',
    configurable: true,
  });

  Object.defineProperty(document, 'hidden', {
    get: () => false,
    configurable: true,
  });

  // Focus
  Document.prototype.hasFocus = () => true;

  // Swallow blur/focus/visibilitychange at capture phase
  const swallow = (event: Event) => {
    console.debug(tag, `swallowed ${event.type} on`, event.target);
    event.stopImmediatePropagation();
    event.preventDefault();
  };

  window.addEventListener('blur', swallow, true);
  window.addEventListener('focus', swallow, true);
  document.addEventListener('visibilitychange', swallow, true);

  // IntersectionObserver — make callbacks always see entries as intersecting
  const OriginalIntersectionObserver = window.IntersectionObserver;

  window.IntersectionObserver = class extends OriginalIntersectionObserver {
    constructor(
      callback: IntersectionObserverCallback,
      options?: IntersectionObserverInit,
    ) {
      super((entries, observer) => {
        const spoofed = entries.map((entry) => {
          if (entry.isIntersecting && entry.intersectionRatio >= 1) return entry;

          console.debug(tag, 'spoofing IntersectionObserver entry', entry.target);

          // IntersectionObserverEntry isn't constructable, so proxy the original
          return new Proxy(entry, {
            get(target, prop) {
              if (prop === 'isIntersecting') return true;
              if (prop === 'intersectionRatio') return 1;
              if (prop === 'intersectionRect') return target.boundingClientRect;

              const value = Reflect.get(target, prop);

              return typeof value === 'function' ? value.bind(target) : value;
            },
          });
        });

        callback(spoofed, observer);
      }, options);
    }
  } as unknown as typeof IntersectionObserver;

  console.info(tag, 'activity spoof injected');
};

const injectActivitySpoof = async (tabId: number): Promise<void> => {
  await browser.scripting.executeScript({
    target: { tabId, allFrames: true },
    world: 'MAIN',
    func: activitySpoofScript,
    injectImmediately: true,
  });
};

const onTabUpdated = (
  tabId: number,
  changeInfo: Browser.Tabs.OnUpdatedChangeInfoType,
): void => {
  if (changeInfo.status === 'loading' && capturedTabs.has(tabId)) {
    injectActivitySpoof(tabId);
  }
};

const onTabRemoved = (tabId: number): void => {
  capturedTabs.delete(tabId);
  removeListenersIfEmpty();
};

const addListenersIfNeeded = (): void => {
  if (capturedTabs.size === 1) {
    browser.tabs.onUpdated.addListener(onTabUpdated);
    browser.tabs.onRemoved.addListener(onTabRemoved);
  }
};

const removeListenersIfEmpty = (): void => {
  if (capturedTabs.size === 0) {
    browser.tabs.onUpdated.removeListener(onTabUpdated);
    browser.tabs.onRemoved.removeListener(onTabRemoved);
  }
};

const setMediaPrefs = (suspended: boolean): void => {
  glide.prefs.set('media.suspend-background-video.enabled', suspended);
  glide.prefs.set('media.suspend-background-video.delay-ms', suspended ? 10000 : 0);
  glide.prefs.set('media.block-autoplay-until-in-foreground', suspended);
  glide.prefs.set('dom.min_background_timeout_value', suspended ? 1000 : 0);
  glide.prefs.set('dom.timeout.enable_budget_timer_throttling', suspended);

  console.info('[tab_activity] media prefs set, suspended:', suspended);
};

const capture = async (tabId: number): Promise<void> => {
  capturedTabs.add(tabId);
  addListenersIfNeeded();
  setMediaPrefs(false);
  await injectActivitySpoof(tabId);

  console.info('[tab_activity] captured tab', tabId);
};

const release = (tabId: number): void => {
  capturedTabs.delete(tabId);
  removeListenersIfEmpty();

  if (capturedTabs.size === 0) {
    setMediaPrefs(true);
  }

  console.info('[tab_activity] released tab', tabId);

  glide.commandline.show({
    title: 'reload tab to restore normal activity events?',
    options: [
      {
        label: 'Reload',
        execute: async () => {
          await browser.tabs.reload(tabId);
        },
      },
      {
        label: 'Skip',
        execute: () => {},
      },
    ],
  });
};

const isValidAction = (value: string): value is Action =>
  value === 'toggle' || value === 'capture' || value === 'release';

const tabActivity = glide.excmds.create(
  {
    name: 'tab_activity',
    description:
      'Capture, release, or toggle activity spoofing on the active tab',
  },
  async ({ args_arr: [action = 'toggle'] }) => {
    if (!isValidAction(action)) {
      console.warn(`tab_activity: invalid action "${action}" — expected toggle, capture, or release`);

      return;
    }

    const { id } = await glide.tabs.active();

    switch (action) {
      case 'capture':
        await capture(id);
        break;

      case 'release':
        release(id);
        break;

      case 'toggle':
        if (capturedTabs.has(id)) {
          release(id);
        } else {
          await capture(id);
        }
        break;
    }
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_activity: typeof tabActivity; } }

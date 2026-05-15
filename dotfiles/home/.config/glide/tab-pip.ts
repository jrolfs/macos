/**
 * Pops the active tab into a small always-on-top "picture-in-picture" window,
 * or restores it back to its original window.
 */

interface PipState {
  readonly originalWindowId: number;
  readonly originalIndex: number;
  readonly pipWindowId: number;
}

const pipTabs = new Map<number, PipState>();

const PIP_WIDTH = 640;
const PIP_HEIGHT = 480;
const PIP_MARGIN = 20;

const pop = async (tabId: number): Promise<void> => {
  const tab = await browser.tabs.get(tabId);

  assert(tab.windowId);

  const pipWindow = await browser.windows.create({
    tabId,
    type: 'popup',
    width: PIP_WIDTH,
    height: PIP_HEIGHT,
    left: screen.availWidth - PIP_WIDTH - PIP_MARGIN,
    top: screen.availHeight - PIP_HEIGHT - PIP_MARGIN,
  });

  assert(pipWindow.id);

  await browser.windows.update(pipWindow.id, { alwaysOnTop: true });

  pipTabs.set(tabId, {
    originalWindowId: tab.windowId,
    originalIndex: tab.index,
    pipWindowId: pipWindow.id,
  });

  console.info('[tab_pip] popped tab', tabId, 'into window', pipWindow.id);
};

const restore = async (tabId: number): Promise<void> => {
  const state = pipTabs.get(tabId);

  if (!state) return;

  await browser.tabs.move(tabId, {
    windowId: state.originalWindowId,
    index: state.originalIndex,
  });

  await browser.tabs.update(tabId, { active: true });
  await browser.windows.update(state.originalWindowId, { focused: true });

  pipTabs.delete(tabId);

  console.info('[tab_pip] restored tab', tabId, 'to window', state.originalWindowId);
};

const onTabRemoved = (tabId: number): void => {
  pipTabs.delete(tabId);
};

browser.tabs.onRemoved.addListener(onTabRemoved);

type Action = 'toggle' | 'pop' | 'restore';

const isValidAction = (value: string): value is Action =>
  value === 'toggle' || value === 'pop' || value === 'restore';

const tabPip = glide.excmds.create(
  {
    name: 'tab_pip',
    description: 'Pop the active tab into an always-on-top PiP window, or restore it',
  },
  async ({ args_arr: [action = 'toggle'] }) => {
    if (!isValidAction(action)) {
      console.warn(`tab_pip: invalid action "${action}" — expected toggle, pop, or restore`);

      return;
    }

    const { id } = await glide.tabs.active();

    switch (action) {
      case 'pop':
        await pop(id);
        break;

      case 'restore':
        await restore(id);
        break;

      case 'toggle':
        if (pipTabs.has(id)) {
          await restore(id);
        } else {
          await pop(id);
        }
        break;
    }
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_pip: typeof tabPip; } }

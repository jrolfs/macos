const duckDuckGo = glide.excmds.create(
  {
    name: 'ddg',
    description: 'Search DuckDuckGo in a new tab',
  },
  async ({ args_arr: args }) => {
    const query = args.join(' ');
    const params = new URLSearchParams({ q: query, t: 'ffab', ia: 'web' });
    const url = `https://duckduckgo.com/?${params}`;

    await browser.tabs.create({ url });
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { ddg: typeof duckDuckGo; } }

const tabDuplicate = glide.excmds.create(
  {
    name: 'tab_duplicate',
    description: 'Duplicate the active tab',
  },
  async () => {
    const { id } = await glide.tabs.active();

    assert(id);

    await browser.tabs.duplicate(id);
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_duplicate: typeof tabDuplicate; } }

const tabPinToggle = glide.excmds.create(
  {
    name: 'tab_pin_toggle',
    description: 'Pin or unpin a tab depending on its current state',
  },
  async ({ args_arr: [arg] }) => {
    const active = await glide.tabs.active();

    const argId = arg && /\d+/.test(arg) ? parseInt(arg, 10) : null;
    const id = argId ?? active.id;

    const { pinned } = await browser.tabs.get(id);

    await glide.excmds.execute(pinned ? `tab_unpin ${id}` : `tab_pin ${id}`);
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_pin_toggle: typeof tabPinToggle; } }

type HasId<T> = T & { id: number };

const hasId = <T extends { id?: number }>(entity: T): entity is HasId<T> =>
  typeof entity.id !== 'undefined';

const truncate = (value: string, length: number) =>
  value.length > length ? `${value}…` : value;

const tabMove = glide.excmds.create(
  {
    name: 'tab_move',
    description: 'Move a ',
  },
  async ({ args_arr: [arg] }) => {
    const { id: tabId } = await glide.tabs.active();

    const move = async (windowId: number, index: number = -1) =>
      await browser.tabs.move(tabId, {
        windowId,
        index,
      });

    // Interactive list

    if (arg === 'list') {
      const windows = await browser.windows.getAll();

      glide.commandline.show({
        options: windows.filter(hasId).map(({ id, title, tabs }) => ({
          label: `${id}: ${title} ${tabs
            ?.map(t => t.title)
            .filter(Boolean)
            .map(title => `⎡${truncate(title, 15)}⎤`)
            .join('')}`,
          execute: async () => move(id),
        })),
      });

      return;
    }

    // Target window ID

    const argId = arg && /\d+/.test(arg) ? parseInt(arg, 10) : null;

    if (argId) {
      const { id } = await browser.windows.get(argId);

      assert(id);
      await move(id);

      return;
    }

    // New window

    const window = await browser.windows.create();
    const { id } = window;

    assert(id);
    await move(id, 1);

    // When opening a new window, it opens with an empty tab open to the new
    // tab page by default, but we only want the moved tab in that window
    const emptyId = window.tabs?.at(-1)?.id;

    if (typeof emptyId !== 'number') return;

    await browser.tabs.remove(emptyId);
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_move: typeof tabMove; } }

const formatGroup = (group: Browser.TabGroups.TabGroup): string => {
  const title = group.title || '(untitled)';
  const state = group.collapsed ? 'collapsed' : 'expanded';

  return `${group.id}: [${group.color}] ${title} (${state})`;
};

const tabGroupMove = glide.excmds.create(
  {
    name: 'tab_group_move',
    description: 'Move the active tab into a tab group',
  },
  async ({ args_arr: [arg] }) => {
    const { id: tabId } = await glide.tabs.active();

    const addToGroup = async (groupId: number) =>
      await browser.tabs.group({ tabIds: tabId, groupId });

    // Interactive list

    if (arg === 'list') {
      const groups = await browser.tabGroups.query({});

      glide.commandline.show({
        title: 'tab groups',
        options: [
          ...groups.map(group => ({
            label: formatGroup(group),
            execute: async () => addToGroup(group.id),
          })),
          {
            label: '+ New group',
            description: 'Create a new group with this tab',
            execute: async ({ input }) => {
              const groupId = await browser.tabs.group({ tabIds: tabId });

              if (input.trim()) {
                await browser.tabGroups.update(groupId, {
                  title: input.trim(),
                });
              }
            },
          },
        ],
      });

      return;
    }

    // Target group ID

    const argId = arg && /\d+/.test(arg) ? parseInt(arg, 10) : null;

    if (argId) {
      await addToGroup(argId);

      return;
    }

    // No argument — create a new group

    await browser.tabs.group({ tabIds: tabId });
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_group_move: typeof tabGroupMove; } }

const tabGroupRename = glide.excmds.create(
  {
    name: 'tab_group_rename',
    description: 'Rename the group the active tab belongs to',
  },
  async ({ args_arr: args }) => {
    const { groupId } = await glide.tabs.active();

    if (!groupId || groupId === browser.tabGroups.TAB_GROUP_ID_NONE) {
      console.warn('Active tab is not in a group');

      return;
    }

    const newTitle = args.join(' ');

    // Interactive — show commandline pre-filled with current title

    if (!newTitle) {
      const group = await browser.tabGroups.get(groupId);

      glide.commandline.show({
        input: group.title ?? '',
        title: 'rename group',
        options: [
          {
            label: `Current: ${group.title || '(untitled)'}`,
            matches: () => true,
            execute: async ({ input }) => {
              await browser.tabGroups.update(groupId, { title: input.trim() });
            },
          },
        ],
      });

      return;
    }

    await browser.tabGroups.update(groupId, { title: newTitle });
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_group_rename: typeof tabGroupRename; } }

const tabGroupCollapseToggle = glide.excmds.create(
  {
    name: 'tab_group_collapse_toggle',
    description: 'Toggle collapse/expand of the active tab group',
  },
  async () => {
    const { groupId } = await glide.tabs.active();

    if (!groupId || groupId === browser.tabGroups.TAB_GROUP_ID_NONE) {
      console.warn('Active tab is not in a group');

      return;
    }

    const { collapsed } = await browser.tabGroups.get(groupId);

    await browser.tabGroups.update(groupId, { collapsed: !collapsed });
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_group_collapse_toggle: typeof tabGroupCollapseToggle; } }

const tabOption = (
  tab: HasId<Browser.Tabs.Tab>,
  isOtherWindow: boolean,
): glide.CommandLineCustomOption => {
  const title = tab.title ?? '';
  const url = tab.url ?? '';
  const indicator = tab.active ? '*' : tab.pinned ? 'P' : '';

  return {
    label: title,
    description: url,
    render: () =>
      DOM.create_element('div', {
        style: {
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          width: '100%',
        },
        children: [
          DOM.create_element('span', {
            style: { width: '12px', flexShrink: '0', textAlign: 'center' },
            children: [indicator],
          }),
          ...(tab.favIconUrl
            ? [
                DOM.create_element('img', {
                  src: tab.favIconUrl,
                  style: { width: '16px', height: '16px', flexShrink: '0' },
                }),
              ]
            : [
                DOM.create_element('span', {
                  style: { width: '16px', flexShrink: '0' },
                }),
              ]),
          DOM.create_element('span', {
            style: {
              flexShrink: '1',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            },
            children: [title],
          }),
          DOM.create_element('span', {
            style: {
              marginLeft: 'auto',
              opacity: '0.5',
              flexShrink: '1',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            },
            children: [url],
          }),
        ],
      }),
    matches: ({ input }) => {
      if (!input) return true;

      const lower = input.toLowerCase();

      return (
        title.toLowerCase().includes(lower) || url.toLowerCase().includes(lower)
      );
    },
    execute: async () => {
      await browser.tabs.update(tab.id, { active: true });

      if (isOtherWindow && tab.windowId) {
        await browser.windows.update(tab.windowId, { focused: true });
      }
    },
  };
};

const windowDivider = (
  window: Browser.Windows.Window,
  isCurrent: boolean,
): glide.CommandLineCustomOption => ({
  label: '',
  matches: ({ input }) => !input,
  execute: () => {},
  render: () =>
    DOM.create_element('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        padding: '2px 0',
        opacity: '0.5',
        fontSize: '0.85em',
      },
      children: [
        DOM.create_element('span', {
          children: [`Window ${window.id}${isCurrent ? ' (current)' : ''}`],
        }),
        DOM.create_element('hr', {
          style: {
            flex: '1',
            border: 'none',
            borderTop: '1px solid currentColor',
            opacity: '0.3',
          },
        }),
      ],
    }),
});

const DEFAULT_RECENTLY_CLOSED_COUNT = 10;

const closedTabOption = (
  session: Browser.Sessions.Session & { tab: Browser.Tabs.Tab },
): glide.CommandLineCustomOption => {
  const { tab } = session;
  const title = tab.title ?? '';
  const url = tab.url ?? '';
  const closedAt = new Date(session.lastModified * 1000);
  const timeAgo = formatTimeAgo(closedAt);

  return {
    label: title,
    description: url,
    render: () =>
      DOM.create_element('div', {
        style: {
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          width: '100%',
        },
        children: [
          ...(tab.favIconUrl
            ? [
                DOM.create_element('img', {
                  src: tab.favIconUrl,
                  style: { width: '16px', height: '16px', flexShrink: '0' },
                }),
              ]
            : [
                DOM.create_element('span', {
                  style: { width: '16px', flexShrink: '0' },
                }),
              ]),
          DOM.create_element('span', {
            style: {
              flexShrink: '1',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            },
            children: [title],
          }),
          DOM.create_element('span', {
            style: {
              marginLeft: 'auto',
              opacity: '0.5',
              flexShrink: '0',
              fontSize: '0.85em',
            },
            children: [timeAgo],
          }),
          DOM.create_element('span', {
            style: {
              opacity: '0.5',
              flexShrink: '1',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            },
            children: [url],
          }),
        ],
      }),
    matches: ({ input }) => {
      if (!input) return true;

      const lower = input.toLowerCase();

      return (
        title.toLowerCase().includes(lower) || url.toLowerCase().includes(lower)
      );
    },
    execute: async () => {
      assert(tab.sessionId);
      await browser.sessions.restore(tab.sessionId);
    },
  };
};

const formatTimeAgo = (date: Date): string => {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);

  if (seconds < 60) return 'just now';

  const minutes = Math.floor(seconds / 60);

  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);

  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);

  return `${days}d ago`;
};

const hasTab = (
  session: Browser.Sessions.Session,
): session is Browser.Sessions.Session & { tab: Browser.Tabs.Tab } =>
  session.tab != null;

const tabRecentlyClosed = glide.excmds.create(
  {
    name: 'tab_recently_closed',
    description: 'Browse and restore recently closed tabs',
  },
  async ({ args_arr: [arg] }) => {
    const count =
      arg && /^\d+$/.test(arg)
        ? parseInt(arg, 10)
        : DEFAULT_RECENTLY_CLOSED_COUNT;

    const sessions = await browser.sessions.getRecentlyClosed({
      maxResults: count,
    });
    const tabSessions = sessions.filter(hasTab);

    glide.commandline.show({
      title: 'recently closed tabs',
      options: tabSessions.map(closedTabOption),
    });
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_recently_closed: typeof tabRecentlyClosed; } }

const closeTabsMatching = async (
  predicate: (
    tab: HasId<Browser.Tabs.Tab>,
    active: Browser.Tabs.Tab,
  ) => boolean,
): Promise<void> => {
  const active = await glide.tabs.active();
  const tabs = await browser.tabs.query({ currentWindow: true });

  await browser.tabs.remove(
    tabs
      .filter(hasId)
      .filter(tab => !tab.pinned && predicate(tab, active))
      .map(tab => tab.id),
  );
};

const tabCloseOther = glide.excmds.create(
  {
    name: 'tab_close_other',
    description: 'Close all tabs except the active tab',
  },
  async () => closeTabsMatching((tab, active) => tab.id !== active.id),
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_close_other: typeof tabCloseOther; } }

const tabCloseRight = glide.excmds.create(
  {
    name: 'tab_close_right',
    description: 'Close all tabs to the right of the active tab',
  },
  async () => closeTabsMatching((tab, active) => tab.index > active.index),
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_close_right: typeof tabCloseRight; } }

const tabCloseLeft = glide.excmds.create(
  {
    name: 'tab_close_left',
    description: 'Close all tabs to the left of the active tab',
  },
  async () => closeTabsMatching((tab, active) => tab.index < active.index),
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_close_left: typeof tabCloseLeft; } }

const tabSearchAll = glide.excmds.create(
  {
    name: 'tab_search_all',
    description: 'Fuzzy search across all tabs in all windows',
  },
  async () => {
    const [allTabs, currentWindow] = await Promise.all([
      browser.tabs.query({}),
      browser.windows.getCurrent(),
    ]);

    const tabsByWindow = Map.groupBy(
      allTabs.filter(hasId),
      tab => tab.windowId,
    );

    const options = [...tabsByWindow.entries()].flatMap(([windowId, tabs]) => {
      const isCurrent = windowId === currentWindow.id;
      const window = { id: windowId } as Browser.Windows.Window;

      return [
        windowDivider(window, isCurrent),
        ...tabs.map(tab => tabOption(tab, !isCurrent)),
      ];
    });

    glide.commandline.show({ title: 'tabs (all windows)', options });
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tab_search_all: typeof tabSearchAll; } }

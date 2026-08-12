const parseFloatArg = (value: string) => {
  const parsed = parseFloat(value);

  return Number.isNaN(parsed) ? null : parsed;
};

const scale = glide.excmds.create(
  {
    name: 'scale',
    description: 'Scale content and browser chrome by pixel density',
  },
  ({ args_arr: [arg] }) => {
    assert(arg, 'Scale is required (0.5 to 3.0)');

    const scale = parseFloatArg(arg);

    assert(
      scale && scale > 0.5 && scale <= 3.0,
      `Invalid scale, "${arg}" must be between 0.5 and 3`,
    );

    glide.prefs.set('layout.css.devPixelsPerPx', scale);
  },
);

// oxfmt-ignore
declare global { interface ExcmdRegistry { scale: typeof scale; } }

const scaleToggle = glide.excmds.create(
  {
    name: 'scale_toggle',
    description: 'Toggle scale between two values',
  },
  ({ args_arr: [arg1, arg2] }) => {
    assert(arg1 && arg2, 'Two scale values are required (0.5 to 3.0)');

    const scale1 = parseFloatArg(arg1);
    const scale2 = parseFloatArg(arg2);

    assert(
      scale1 &&
        scale1 > 0.5 &&
        scale1 <= 3.0 &&
        scale2 &&
        scale2 > 0.5 &&
        scale2 <= 3.0,
      `Invalid scale(s), "${arg1}-${arg2}" must be between 0.5 and 3`,
    );

    const current = glide.prefs.get('layout.css.devPixelsPerPx');

    const set = (value: number) =>
      glide.prefs.set('layout.css.devPixelsPerPx', value);

    switch (current) {
      case `${scale1}`:
        return set(scale2);
      case `${scale2}`:
        return set(scale1);
      default:
        set(scale1);
    }
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { scale_toggle: typeof scaleToggle; } }

const TOOLS_HOSTS = ['bottom', 'right', 'window'] as const;

type ToolsHost = (typeof TOOLS_HOSTS)[number];

const isToolsHost = (value: string): value is ToolsHost =>
  TOOLS_HOSTS.includes(value as ToolsHost);

const toolsPlace = glide.excmds.create(
  {
    name: 'tools_place',
    description: 'Dock devtools bottom/right, or detach into its own window',
  },
  ({ args_arr: [arg] }) => {
    assert(
      arg && isToolsHost(arg),
      `Placement must be one of: ${TOOLS_HOSTS.join(', ')}`,
    );

    // Applied the next time devtools is opened (Firefox reads this pref at
    // toolbox-open time, so it won't reposition an already-open toolbox).
    glide.prefs.set('devtools.toolbox.host', arg);
  },
);
// oxfmt-ignore
declare global { interface ExcmdRegistry { tools_place: typeof toolsPlace; } }

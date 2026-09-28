/**
 * Mode indicator drawn as a notch cut out of the content area.
 *
 * On a mode change a notch rises out of the bottom edge of the content,
 * exposing the darker surface behind it, and the mode is shown there in
 * monospace. After a pause it retracts, the label descends with it and is
 * clipped away, and the label's text colour crossfades into a solid strip in
 * the mode colour.
 *
 * The notch flares at its base so the content curves into it rather than
 * meeting it at a right angle. That flare sits at the bottom of the shape, so
 * it passes below the content edge early in the retraction and stops cutting
 * once the joint it was softening no longer exists.
 *
 * The label is anchored to `#tabbrowser-tabbox`, which is already
 * `position: relative` and is not clipped. The cutout is masked onto
 * `.browserSidebarContainer`, which paints the page.
 */

const STYLE_ID = 'enso-mode-indicator';

const CONTENT = '#tabbrowser-tabpanels .browserSidebarContainer.deck-selected';

const LABEL_ANCHOR = '#tabbrowser-tabbox';

/** Distance from the right edge, enough to clear the content corner radius. */
const INSET_RIGHT = 26;

/** Fixed so the notch keeps one shape across modes, as a hardware notch would. */
const NOTCH_WIDTH = 96;

const NOTCH_HEIGHT = 18;

/** Convex rounding on the two corners that face into the page. */
const NOTCH_RADIUS = 8;

/** Concave rounding where the notch meets the content edge. */
const FILLET = 6;

/**
 * What remains once the notch has closed. It rests below the content edge, in
 * the gutter, so it reads as a tinted section of the border rather than a nub
 * sitting on the page. Page content is often white, which left a nub on top of
 * it with no contrast.
 */
const STRIP_HEIGHT = 3;

const OPEN_MS = 260;

const HOLD_MS = 550;

const CLOSE_MS = 420;

const TOTAL_MS = OPEN_MS + HOLD_MS + CLOSE_MS;

const OPEN_AT = ((OPEN_MS / TOTAL_MS) * 100).toFixed(2);

const CLOSE_AT = (((OPEN_MS + HOLD_MS) / TOTAL_MS) * 100).toFixed(2);

/**
 * Taken from Glide's own palette rather than read from
 * `--glide-current-mode-color`, because Glide updates that variable three
 * animation frames after the mode change, which lands mid-animation. Literal
 * values also allow the crossfade below to vary only alpha.
 */
const MODE_COLORS: Readonly<Record<string, string>> = {
  normal: '#a89984',
  insert: '#83a598',
  visual: '#fe8019',
  hint: '#ff33aa',
  ignore: '#cc79a7',
  command: '#fb4934',
  'op-pending': '#b8bb26',
};

const FALLBACK_COLOR = '#ffffff';

/** Total mask width, including the flare on either side of the notch body. */
const MASK_WIDTH = NOTCH_WIDTH + FILLET * 2;

/**
 * The subtracted shape: a rounded-top rectangle that widens at its base into
 * two quarter-arcs, so the removed region meets the content edge tangentially.
 *
 * Kept at its natural size and moved with `mask-position` rather than scaled
 * with `mask-size`, so none of the radii distort.
 */
const notchMask = (): string => {
  const left = FILLET;
  const right = FILLET + NOTCH_WIDTH;

  const path = [
    `M0 ${NOTCH_HEIGHT}`,
    `A${FILLET} ${FILLET} 0 0 0 ${left} ${NOTCH_HEIGHT - FILLET}`,
    `V${NOTCH_RADIUS}`,
    `A${NOTCH_RADIUS} ${NOTCH_RADIUS} 0 0 1 ${left + NOTCH_RADIUS} 0`,
    `H${right - NOTCH_RADIUS}`,
    `A${NOTCH_RADIUS} ${NOTCH_RADIUS} 0 0 1 ${right} ${NOTCH_RADIUS}`,
    `V${NOTCH_HEIGHT - FILLET}`,
    `A${FILLET} ${FILLET} 0 0 0 ${MASK_WIDTH} ${NOTCH_HEIGHT}`,
    'Z',
  ].join(' ');

  const svg =
    `<svg xmlns='http://www.w3.org/2000/svg' width='${MASK_WIDTH}' height='${NOTCH_HEIGHT}'>`
    + `<path d='${path}' fill='black'/></svg>`;

  return `url("data:image/svg+xml;utf8,${svg}")`;
};

/**
 * `glide.styles.add` with `overwrite` removes and re-appends the style element
 * synchronously, so style resolution never sees a frame without the animation
 * and a same-named animation will not restart. Varying the name per render is
 * what forces it to run again.
 */
let renderCount = 0;

const render = (mode: string): void => {
  renderCount += 1;
  const slide = `enso-notch-slide-${renderCount}`;
  const settle = `enso-notch-settle-${renderCount}`;
  const color = MODE_COLORS[mode] ?? FALLBACK_COLOR;

  const closed = `0 0, right ${INSET_RIGHT}px bottom -${NOTCH_HEIGHT}px`;
  const open = `0 0, right ${INSET_RIGHT}px bottom 0px`;

  glide.styles.add(
    `
      @keyframes ${slide} {
        0%              { mask-position: ${closed}; }
        ${OPEN_AT}%     { mask-position: ${open}; }
        ${CLOSE_AT}%    { mask-position: ${open}; }
        100%            { mask-position: ${closed}; }
      }

      /* Offsetting the bottom edge by the strip height parks the resting
         state entirely below the content, inside the gutter. */
      @keyframes ${settle} {
        0% {
          bottom: -${STRIP_HEIGHT}px;
          height: ${STRIP_HEIGHT}px;
          border-radius: 2px;
          background-color: ${color}ff;
          color: ${color}00;
        }
        ${OPEN_AT}%, ${CLOSE_AT}% {
          bottom: 0;
          height: ${NOTCH_HEIGHT}px;
          border-radius: ${NOTCH_RADIUS}px ${NOTCH_RADIUS}px 0 0;
          background-color: ${color}00;
          color: ${color}ff;
        }
        100% {
          bottom: -${STRIP_HEIGHT}px;
          height: ${STRIP_HEIGHT}px;
          border-radius: 2px;
          background-color: ${color}ff;
          color: ${color}00;
        }
      }

      /* Glide's own indicator, superseded by the notch. Under Zen's vertical
         tabs it lands at the foot of the sidebar and renders its label text
         alongside the mode. */
      #glide-toolbar-mode-button,
      #glide-toolbar-keyseq-button {
        display: none !important;
      }

      /* Two mask layers composited with exclude: a full-bleed layer that keeps
         the page, minus the notch shape. */
      ${CONTENT} {
        mask-image: linear-gradient(#000, #000), ${notchMask()};
        mask-repeat: no-repeat, no-repeat;
        mask-size: 100% 100%, auto;
        mask-composite: exclude;
        animation: ${slide} ${TOTAL_MS}ms ease both;
      }

      ${LABEL_ANCHOR}::after {
        content: "${mode}";
        position: absolute;
        bottom: -${STRIP_HEIGHT}px;
        right: ${INSET_RIGHT + FILLET}px;
        width: ${NOTCH_WIDTH}px;
        z-index: 10;
        pointer-events: none;

        /* Descending the bottom edge while shrinking the height walks the
           label down into the gutter, clipping it against its own box. */
        overflow: hidden;
        box-sizing: border-box;
        height: ${STRIP_HEIGHT}px;
        border-radius: 2px;

        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        font-size: 10px;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-align: center;
        text-transform: uppercase;
        line-height: ${NOTCH_HEIGHT}px;

        animation: ${settle} ${TOTAL_MS}ms ease both;
      }
    `,
    { id: STYLE_ID, overwrite: true },
  );
};

glide.autocmds.create('ModeChanged', '*', ({ new_mode }) => {
  render(new_mode);
});

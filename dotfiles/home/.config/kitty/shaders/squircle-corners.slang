// Clips the panel to a superellipse. macOS rounds the corners of an ordinary
// window itself, but a panel is not an ordinary window and comes out square, and
// kitty has no option for this: window_border_radius draws kitty's own split
// borders inside the window and is documented as having no effect alongside
// draw_minimal_borders, which kitty.conf sets.
//
// A superellipse rather than a circle because that is the difference being
// matched. A circular corner meets the straight edge at a visible crease; a
// superellipse eases into it, and that easing is what reads as a squircle.
//
// RADIUS_PX is in device pixels, not points, because the only size a shader is
// handed is d.viewport_size_pixels. So on a 2x display this is half the figure
// you would reach for: 48 here is a 24pt corner.
//
// Which is a long way from the 10pt corner macOS used before Tahoe. Tahoe's own
// windows are much rounder than that, and 20 (the old value) read as barely
// rounded at all next to them.
//
// Both values are re-declared in squircle-corners.pipeline, which is the
// documented way to retune them without editing this file.

// Not implicit: without this slangc fails with `undefined identifier
// 'KittyTextures'` and kitty reports only the missing compiled module. The
// module file in its cache is spelled with dashes, Slang resolves it from the
// underscored name.
import kitty_custom_shader_types;

static const float RADIUS_PX = 48.0;
static const float EXPONENT = 5.0;

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float2 size = float2(d.viewport_size_pixels);
    float2 pixel = t.pos * size;

    // Distance to the nearer edge on each axis, which folds all four corners
    // into one case.
    float2 inset = min(pixel, size - pixel);

    // Nothing to clip outside the corner squares, and returning early keeps the
    // pow() calls away from the overwhelming majority of the window.
    if (inset.x >= RADIUS_PX || inset.y >= RADIUS_PX) { return color; }

    float2 q = (float2(RADIUS_PX) - inset) / RADIUS_PX;
    float curve = pow(pow(q.x, EXPONENT) + pow(q.y, EXPONENT), 1.0 / EXPONENT);

    // curve is 1 along the boundary and, multiplied back up by the radius,
    // grows at roughly a pixel per pixel. That is what makes a half-pixel band
    // the right width to antialias over instead of a hard cut.
    float coverage = 1.0 - clamp((curve - 1.0) * RADIUS_PX + 0.5, 0.0, 1.0);

    // Colour and alpha together, because kitty passes premultiplied alpha
    // through this stage. Scaling only .a would leave the clipped corner
    // carrying its colour at zero coverage, which shows up as a fringe wherever
    // the compositor rounds differently than this does.
    return color * coverage;
}

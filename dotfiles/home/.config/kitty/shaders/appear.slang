// Fades the panel in when it is shown.
//
// t.animation_progress runs 0 to 1 across the duration set in the pipeline, and
// is only ever delivered while the group is animating: kitty skips an idle
// group altogether rather than running it with a progress of zero. That is what
// makes this safe to write as a plain multiply — were it otherwise, a finished
// fade would leave the terminal permanently invisible. Verified by running a
// group that returns opaque red and watching the panel render normally once the
// animation had stopped.

import kitty_custom_shader_types;

// Where the fade begins. Zero fades up from nothing; raising it keeps the panel
// partly visible for the whole animation, which reads as quicker.
static const float FADE_FROM = 0.0;

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float amount = lerp(FADE_FROM, 1.0, t.animation_progress);

    // Colour with alpha, as in squircle-corners: this stage is premultiplied.
    return color * amount;
}

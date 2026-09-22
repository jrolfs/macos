local M = {}

-- hs.canvas reads colour components as Apple Generic RGB (gamma 1.8) rather
-- than sRGB, so a hex taken from a palette renders around fifteen levels too
-- light: #32302f reaches the display as #413f3e. Re-encode each channel so
-- the colour that lands on screen is the one named below.
local function canvasColor(hex, alpha)
  local function channel(value)
    local n = value / 255
    local linear = n <= 0.04045 and n / 12.92 or ((n + 0.055) / 1.055) ^ 2.4
    return math.floor(linear ^ (1 / 1.8) * 255 + 0.5)
  end

  local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
  return {
    hex = string.format(
      "#%02x%02x%02x",
      channel(tonumber(r, 16)),
      channel(tonumber(g, 16)),
      channel(tonumber(b, 16))
    ),
    alpha = alpha or 1.0,
  }
end

-- Gruvbox Material Dark, soft background
local palette = {
  backgroundTop = canvasColor("#3a3734", 0.97),
  background = canvasColor("#32302f", 0.97),
  border = canvasColor("#504945", 0.9),
  text = canvasColor("#d4be98"),
  shadow = { hex = "#000000", alpha = 0.5 },
}

-- Measured off Raycast's HUD at 2x, in points.
local layout = {
  height = 52,
  fontSize = 14,
  iconSize = 28,
  iconGap = 9,
  leadingWithIcon = 13,
  leadingPlain = 22,
  trailing = 22,
  minWidth = 120,
  maxWidth = 560,
  bottomMargin = 150,
  -- A canvas clips its own contents, so it needs slack around the capsule
  -- for the drop shadow to land inside it.
  shadowPad = 30,
}

local timing = {
  fadeIn = 0.1,
  fadeOut = 0.2,
  duration = 1.6,
}

local visible = nil
local dismissal = nil

local function systemFont()
  local fonts = hs.styledtext.defaultFonts
  return fonts and fonts.system and fonts.system.name or ".AppleSystemUIFont"
end

local function styleText(message)
  return hs.styledtext.new(tostring(message), {
    font = { name = systemFont(), size = layout.fontSize },
    color = palette.text,
    paragraphStyle = { alignment = "left", lineBreak = "truncateTail" },
  })
end

local function resolveIcon(icon)
  if icon == nil or type(icon) == "userdata" then return icon end
  if type(icon) ~= "string" then return nil end

  local first = icon:sub(1, 1)
  if first == "/" or first == "~" or first == "." then
    return hs.image.imageFromPath(icon)
  end

  return hs.image.imageFromAppBundle(icon) or hs.image.imageFromPath(icon)
end

function M.dismiss()
  if dismissal then
    dismissal:stop()
    dismissal = nil
  end

  if visible then
    local leaving = visible
    visible = nil
    leaving:hide(timing.fadeOut)
    hs.timer.doAfter(timing.fadeOut + 0.1, function() leaving:delete() end)
  end
end

function M.show(message, options)
  options = options or {}

  -- An icon and an emoji both fill the same slot; the image wins.
  local icon = resolveIcon(options.icon)
  local emoji = options.emoji
  local hasIcon = icon ~= nil or emoji ~= nil

  local text = styleText(message)
  local measured = hs.drawing.getTextDrawingSize(text) or { w = 120, h = 18 }
  -- getTextDrawingSize rounds short often enough to clip the final glyph
  local textWidth = math.ceil(measured.w) + 2
  local textHeight = math.ceil(measured.h)

  local leading = hasIcon and layout.leadingWithIcon or layout.leadingPlain
  local slot = hasIcon and (layout.iconSize + layout.iconGap) or 0
  local width = math.max(
    layout.minWidth,
    math.min(layout.maxWidth, leading + slot + textWidth + layout.trailing)
  )
  local height = layout.height
  local pad = layout.shadowPad

  local screen = options.screen or hs.screen.mainScreen()
  local frame = screen:frame()
  local canvas = hs.canvas.new({
    x = frame.x + (frame.w - width) / 2 - pad,
    y = frame.y + frame.h - layout.bottomMargin - height - pad,
    w = width + pad * 2,
    h = height + pad * 2,
  })

  if not canvas then return nil end

  canvas:appendElements({
    type = "rectangle",
    action = "strokeAndFill",
    fillGradient = "linear",
    fillGradientAngle = 90,
    fillGradientColors = { palette.backgroundTop, palette.background },
    strokeColor = palette.border,
    strokeWidth = 1,
    roundedRectRadii = { xRadius = height / 2, yRadius = height / 2 },
    withShadow = true,
    shadow = { blurRadius = 22, color = palette.shadow, offset = { h = -8, w = 0 } },
    frame = { x = pad, y = pad, w = width, h = height },
  })

  if hasIcon then
    local slotFrame = {
      x = pad + leading,
      y = pad + (height - layout.iconSize) / 2,
      w = layout.iconSize,
      h = layout.iconSize,
    }

    if icon then
      canvas:appendElements({
        type = "image",
        image = icon,
        imageScaling = "scaleProportionally",
        imageAlignment = "center",
        frame = slotFrame,
      })
    else
      local glyph = hs.styledtext.new(emoji, {
        font = { name = systemFont(), size = layout.iconSize * 0.74 },
        paragraphStyle = { alignment = "center" },
      })
      -- An emoji sits on the baseline, so it lands low unless the frame is
      -- shrunk to the measured line box and that box is centred in the slot.
      local glyphHeight = math.ceil((hs.drawing.getTextDrawingSize(glyph) or {}).h or layout.iconSize)

      canvas:appendElements({
        type = "text",
        text = glyph,
        frame = {
          x = slotFrame.x,
          y = slotFrame.y + (layout.iconSize - glyphHeight) / 2,
          w = slotFrame.w,
          h = glyphHeight,
        },
      })
    end
  end

  canvas:appendElements({
    type = "text",
    text = text,
    frame = {
      x = pad + leading + slot,
      y = pad + (height - textHeight) / 2,
      w = width - leading - slot - layout.trailing + 2,
      h = textHeight,
    },
  })

  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:behaviorAsLabels({ "canJoinAllSpaces", "stationary" })

  M.dismiss()
  visible = canvas
  canvas:show(timing.fadeIn)
  dismissal = hs.timer.doAfter(options.duration or timing.duration, M.dismiss)

  return canvas
end

return M

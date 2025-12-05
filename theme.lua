-- Theme configuration for Cybersafe Rogue
-- Vibrant cyberpunk color palette

local Theme = {}

-- Main colors
Theme.colors = {
  -- Background
  bgDark = {0.06, 0.04, 0.12},
  bgMid = {0.1, 0.06, 0.18},

  -- Primary accent (magenta/pink)
  primary = {0.95, 0.3, 0.6},
  primaryBright = {1, 0.4, 0.7},
  primaryDark = {0.7, 0.15, 0.4},

  -- Secondary accent (cyan)
  secondary = {0.2, 0.9, 0.95},
  secondaryBright = {0.4, 1, 1},
  secondaryDark = {0.1, 0.6, 0.7},

  -- Tertiary (lime/green)
  tertiary = {0.5, 1, 0.3},
  tertiaryBright = {0.6, 1, 0.5},

  -- UI elements
  panelBg = {0.12, 0.08, 0.2, 0.95},
  panelBorder = {0.95, 0.3, 0.6, 0.8},

  -- Text
  textBright = {1, 1, 1},
  textNormal = {0.9, 0.85, 0.95},
  textMuted = {0.6, 0.5, 0.7},

  -- Status
  health = {0.3, 1, 0.5},
  damage = {1, 0.4, 0.4},
  warning = {1, 0.8, 0.2},

  -- Hexagon grid
  hexLine = {0.95, 0.3, 0.6, 0.08},
  hexGlow = {0.95, 0.3, 0.6, 0.03},
}

-- Draw hexagonal background pattern
function Theme.drawHexBackground(w, h)
  local hexSize = 40
  local hexHeight = hexSize * math.sqrt(3)
  local hexWidth = hexSize * 2

  -- Background gradient
  love.graphics.setColor(Theme.colors.bgDark)
  love.graphics.rectangle('fill', 0, 0, w, h)

  -- Subtle radial gradient overlay
  local cx, cy = w/2, h/2
  local maxDist = math.sqrt(cx*cx + cy*cy)
  for i = 20, 1, -1 do
    local t = i / 20
    local radius = maxDist * t
    local alpha = 0.08 * (1 - t)
    love.graphics.setColor(0.95, 0.3, 0.6, alpha)
    love.graphics.circle('fill', cx, cy, radius)
  end

  -- Hexagon grid
  love.graphics.setLineWidth(1)
  love.graphics.setColor(Theme.colors.hexLine)

  local offsetX = -hexSize
  local offsetY = -hexHeight/2

  for row = -1, math.ceil(h / hexHeight) + 1 do
    for col = -1, math.ceil(w / (hexWidth * 0.75)) + 1 do
      local x = offsetX + col * hexWidth * 0.75
      local y = offsetY + row * hexHeight
      if col % 2 == 1 then
        y = y + hexHeight / 2
      end

      Theme.drawHexagon(x, y, hexSize * 0.95)
    end
  end
end

function Theme.drawHexagon(cx, cy, size)
  local points = {}
  for i = 0, 5 do
    local angle = math.pi / 3 * i + math.pi / 6
    table.insert(points, cx + size * math.cos(angle))
    table.insert(points, cy + size * math.sin(angle))
  end
  love.graphics.polygon('line', points)
end

-- Draw a styled panel/card
function Theme.drawPanel(x, y, w, h, options)
  options = options or {}
  local cornerRadius = options.cornerRadius or 16
  local glowColor = options.glowColor or Theme.colors.primary
  local bgColor = options.bgColor or Theme.colors.panelBg

  -- Outer glow
  love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.15)
  love.graphics.rectangle('fill', x - 4, y - 4, w + 8, h + 8, cornerRadius + 4, cornerRadius + 4)

  -- Background
  love.graphics.setColor(bgColor)
  love.graphics.rectangle('fill', x, y, w, h, cornerRadius, cornerRadius)

  -- Top highlight
  love.graphics.setColor(1, 1, 1, 0.05)
  love.graphics.rectangle('fill', x + 4, y + 4, w - 8, h * 0.3, cornerRadius - 2, cornerRadius - 2)

  -- Border
  love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.7)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', x, y, w, h, cornerRadius, cornerRadius)
end

-- Draw a styled button
function Theme.drawButton(x, y, w, h, text, font, options)
  options = options or {}
  local isHovered = options.hovered or false
  local accentColor = options.accent or Theme.colors.secondary

  -- Background
  if isHovered then
    love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.2)
  else
    love.graphics.setColor(0.15, 0.1, 0.25, 0.9)
  end
  love.graphics.rectangle('fill', x, y, w, h, 12, 12)

  -- Border
  love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.8)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', x, y, w, h, 12, 12)

  -- Text
  love.graphics.setFont(font)
  love.graphics.setColor(Theme.colors.textBright)
  local tw = font:getWidth(text)
  local th = font:getHeight()
  love.graphics.print(text, x + (w - tw)/2, y + (h - th)/2)
end

-- Draw upgrade card
function Theme.drawUpgradeCard(x, y, w, h, title, description, icon, font, titleFont)
  -- Glow effect
  love.graphics.setColor(Theme.colors.secondary[1], Theme.colors.secondary[2], Theme.colors.secondary[3], 0.1)
  love.graphics.rectangle('fill', x - 3, y - 3, w + 6, h + 6, 18, 18)

  -- Background with gradient feel
  love.graphics.setColor(0.1, 0.06, 0.2, 0.95)
  love.graphics.rectangle('fill', x, y, w, h, 14, 14)

  -- Top accent bar
  love.graphics.setColor(Theme.colors.secondary[1], Theme.colors.secondary[2], Theme.colors.secondary[3], 0.4)
  love.graphics.rectangle('fill', x, y, w, 4, 14, 14)
  love.graphics.rectangle('fill', x, y, w, 40, 14, 14)
  love.graphics.setColor(0.1, 0.06, 0.2, 0.7)
  love.graphics.rectangle('fill', x + 2, y + 6, w - 4, 32, 10, 10)

  -- Border
  love.graphics.setColor(Theme.colors.secondary[1], Theme.colors.secondary[2], Theme.colors.secondary[3], 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', x, y, w, h, 14, 14)

  -- Icon placeholder (colored circle)
  local iconX = x + 20
  local iconY = y + 20
  love.graphics.setColor(Theme.colors.secondary)
  love.graphics.circle('fill', iconX, iconY, 12)
  love.graphics.setColor(Theme.colors.bgDark)
  love.graphics.circle('fill', iconX, iconY, 6)

  -- Title
  love.graphics.setFont(titleFont or font)
  love.graphics.setColor(Theme.colors.textBright)
  love.graphics.print(title, iconX + 22, y + 12)

  -- Description
  love.graphics.setFont(font)
  love.graphics.setColor(Theme.colors.textNormal)
  love.graphics.printf(description, x + 16, y + 50, w - 32, 'left')
end

-- Draw HUD panel
function Theme.drawHUDPanel(x, y, w, h)
  -- Semi-transparent background
  love.graphics.setColor(0.08, 0.04, 0.15, 0.85)
  love.graphics.rectangle('fill', x, y, w, h, 12, 12)

  -- Accent border
  love.graphics.setColor(Theme.colors.primary[1], Theme.colors.primary[2], Theme.colors.primary[3], 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', x, y, w, h, 12, 12)

  -- Corner accents
  local cornerSize = 8
  love.graphics.setColor(Theme.colors.primary)
  love.graphics.rectangle('fill', x, y, cornerSize, 2)
  love.graphics.rectangle('fill', x, y, 2, cornerSize)
  love.graphics.rectangle('fill', x + w - cornerSize, y, cornerSize, 2)
  love.graphics.rectangle('fill', x + w - 2, y, 2, cornerSize)
end

-- Draw a progress bar (for HP, etc)
function Theme.drawProgressBar(x, y, w, h, value, maxValue, color)
  local pct = math.max(0, math.min(1, value / maxValue))
  color = color or Theme.colors.health

  -- Background
  love.graphics.setColor(0.1, 0.06, 0.15, 0.9)
  love.graphics.rectangle('fill', x, y, w, h, 4, 4)

  -- Fill
  if pct > 0 then
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.rectangle('fill', x + 2, y + 2, (w - 4) * pct, h - 4, 2, 2)

    -- Shine
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle('fill', x + 2, y + 2, (w - 4) * pct, (h - 4) * 0.4, 2, 2)
  end

  -- Border
  love.graphics.setColor(color[1], color[2], color[3], 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', x, y, w, h, 4, 4)
end

return Theme

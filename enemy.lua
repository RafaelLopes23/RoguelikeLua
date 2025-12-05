local Enemy = {}
Enemy.__index = Enemy

local function normalize(dx, dy)
  local len = math.sqrt(dx * dx + dy * dy)
  if len == 0 then
    return 1, 0
  end
  return dx / len, dy / len
end

local function randRange(min, max)
  return min + math.random() * (max - min)
end

function Enemy.new(x, y, hp, speed, kind)
  local self = setmetatable({}, Enemy)
  self.x, self.y = x, y
  self.hp = hp or 30
  self.maxHp = self.hp
  self.speed = speed or 80
  self.r = 12
  self.kind = kind or 'basic'

  if self.kind == 'charger' then
    self.speed = (speed or 80) * 0.85
    self.r = 14
    self.state = 'seek'
    self.chargeCooldownMin = 0.9
    self.chargeCooldownMax = 1.7
    self.timer = randRange(self.chargeCooldownMin, self.chargeCooldownMax)
    self.chargeDuration = 0.85
    self.dashDuration = 1.8  -- Aumentado de 1.1 para 1.8 (mais longe)
    self.dashSpeed = (speed or 80) * 4.2  -- Aumentado de 3.6 para 4.2
    self.dashDx, self.dashDy = 1, 0
    self.shakePhase = 0
  elseif self.kind == 'zigzag' then
    self.speed = (speed or 80) * 2.0  -- 100% mais rápido (dobro)
    self.hp = math.max(1, math.floor((hp or 30) * 0.6))  -- 40% menos vida
    self.maxHp = self.hp
    self.r = 10  -- Menor
    self.zigzagTimer = 0
    self.zigzagDir = 1
    self.zigzagInterval = 0.2 + math.random() * 0.15  -- Zigzag mais rápido
  end

  return self
end

function Enemy:update(dt, tx, ty)
  if self.kind == 'charger' then
    local dx, dy = tx - self.x, ty - self.y
    local ndx, ndy = normalize(dx, dy)

    if self.state == 'seek' then
      self.x = self.x + ndx * self.speed * dt
      self.y = self.y + ndy * self.speed * dt
      self.timer = self.timer - dt
      if self.timer <= 0 then
        self.state = 'charge'
        self.timer = self.chargeDuration
        self.dashDx, self.dashDy = ndx, ndy
        self.shakePhase = 0
      end
    elseif self.state == 'charge' then
      self.shakePhase = self.shakePhase + dt * 20
      self.timer = self.timer - dt
      if self.timer <= 0 then
        self.state = 'dash'
        self.timer = self.dashDuration
      end
    elseif self.state == 'dash' then
      local moveX = self.dashDx * self.dashSpeed * dt
      local moveY = self.dashDy * self.dashSpeed * dt
      self.x = self.x + moveX
      self.y = self.y + moveY
      self.timer = self.timer - dt
      if self.timer <= 0 then
        self.state = 'seek'
        self.timer = randRange(self.chargeCooldownMin, self.chargeCooldownMax)
      end
    end
  elseif self.kind == 'zigzag' then
    -- Movimento zigzag: vai em direção ao player mas oscila lateralmente
    local dx, dy = tx - self.x, ty - self.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
      dx, dy = dx / len, dy / len
    end

    -- Perpendicular para o zigzag
    local perpX, perpY = -dy, dx

    -- Timer para alternar direção
    self.zigzagTimer = self.zigzagTimer + dt
    if self.zigzagTimer >= self.zigzagInterval then
      self.zigzagTimer = 0
      self.zigzagDir = -self.zigzagDir
      self.zigzagInterval = 0.2 + math.random() * 0.15
    end

    -- Movimento: 70% em direção ao player, 60% zigzag lateral
    local moveX = dx * self.speed * 0.7 + perpX * self.speed * 0.6 * self.zigzagDir
    local moveY = dy * self.speed * 0.7 + perpY * self.speed * 0.6 * self.zigzagDir

    self.x = self.x + moveX * dt
    self.y = self.y + moveY * dt
  else
    local dx, dy = tx - self.x, ty - self.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
      dx, dy = dx / len, dy / len
    end
    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt
  end
end

function Enemy:hit(dmg)
  self.hp = self.hp - (dmg or 0)
  return self.hp <= 0
end

function Enemy:draw()
  local ox, oy = 0, 0
  if self.kind == 'charger' and self.state == 'charge' then
    ox = math.sin(self.shakePhase * 15) * 2.3
    oy = math.cos(self.shakePhase * 16) * 2.3
  end

  local x, y = self.x + ox, self.y + oy
  local r = self.r

  if self.kind == 'charger' then
    -- Trojan - visual cibernético (caixa de dados maliciosa)
    local baseColor
    if self.state == 'dash' then
      baseColor = {1, 0.25, 0.1}
    else
      baseColor = {0.7, 0.4, 0.15}
    end

    local time = love.timer.getTime()

    -- Corpo principal - hexágono metálico
    love.graphics.setColor(baseColor[1] * 0.6, baseColor[2] * 0.6, baseColor[3] * 0.6)
    local vertices = {}
    for i = 0, 5 do
      local angle = (i / 6) * math.pi * 2 - math.pi / 2
      table.insert(vertices, x + math.cos(angle) * r)
      table.insert(vertices, y + math.sin(angle) * r)
    end
    love.graphics.polygon('fill', vertices)

    -- Borda brilhante
    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3])
    love.graphics.setLineWidth(2)
    love.graphics.polygon('line', vertices)

    -- Circuito interno (linhas)
    love.graphics.setColor(1, 0.5, 0.2, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.line(x - r * 0.5, y, x + r * 0.5, y)
    love.graphics.line(x, y - r * 0.5, x, y + r * 0.5)
    love.graphics.line(x - r * 0.3, y - r * 0.3, x + r * 0.3, y + r * 0.3)

    -- Ícone de cavalo estilizado (cabeça)
    love.graphics.setColor(0.2, 0.1, 0.05)
    -- Cabeça do cavalo simplificada
    love.graphics.polygon('fill',
      x - 2, y - r * 0.4,
      x + 6, y - r * 0.6,
      x + 8, y - r * 0.3,
      x + 4, y + r * 0.1,
      x - 4, y + r * 0.1
    )
    -- Olho vermelho brilhante
    local eyePulse = math.sin(time * 6) * 0.3 + 0.7
    love.graphics.setColor(1, 0.2, 0.1, eyePulse)
    love.graphics.circle('fill', x + 4, y - r * 0.35, 3)
    love.graphics.setColor(1, 0.5, 0.3, eyePulse * 0.5)
    love.graphics.circle('fill', x + 4, y - r * 0.35, 5)

    -- Efeito de carga (aura elétrica)
    if self.state == 'charge' then
      love.graphics.setColor(1, 0.4, 0.1, 0.6)
      love.graphics.setLineWidth(2)
      -- Raios elétricos
      for i = 1, 6 do
        local angle = (i / 6) * math.pi * 2 + time * 8
        local rx = x + math.cos(angle) * (r + 5)
        local ry = y + math.sin(angle) * (r + 5)
        love.graphics.line(x + math.cos(angle) * r * 0.8, y + math.sin(angle) * r * 0.8, rx, ry)
      end
      love.graphics.setLineWidth(1)
    elseif self.state == 'dash' then
      -- Trilha de energia
      love.graphics.setColor(1, 0.3, 0.1, 0.6)
      love.graphics.circle('fill', x - self.dashDx * 12, y - self.dashDy * 12, 8)
      love.graphics.setColor(1, 0.5, 0.2, 0.3)
      love.graphics.circle('fill', x - self.dashDx * 22, y - self.dashDy * 22, 5)
      love.graphics.setColor(1, 0.6, 0.3, 0.15)
      love.graphics.circle('fill', x - self.dashDx * 30, y - self.dashDy * 30, 3)
    end
  elseif self.kind == 'zigzag' then
    -- Glitch/Bug - visual roxo elétrico, menor e ágil
    local time = love.timer.getTime()
    local glitch = math.sin(time * 15) * 0.2 + 0.8

    -- Cor base - roxo vibrante
    local baseColor = {0.7, 0.2, 0.9}

    -- Corpo triangular (mais aerodinâmico)
    love.graphics.setColor(baseColor[1] * 0.5, baseColor[2] * 0.5, baseColor[3] * 0.5)
    local triVerts = {}
    for i = 0, 2 do
      local angle = (i / 3) * math.pi * 2 - math.pi / 2
      table.insert(triVerts, x + math.cos(angle) * r)
      table.insert(triVerts, y + math.sin(angle) * r)
    end
    love.graphics.polygon('fill', triVerts)

    -- Borda elétrica pulsante
    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], glitch)
    love.graphics.setLineWidth(2)
    love.graphics.polygon('line', triVerts)

    -- Núcleo brilhante
    love.graphics.setColor(0.9, 0.5, 1, 0.9)
    love.graphics.circle('fill', x, y, r * 0.35)

    -- Símbolo de bug/erro
    love.graphics.setColor(0.2, 0.05, 0.3)
    love.graphics.setFont(love.graphics.newFont(7))
    love.graphics.print('!', x - 2, y - 4)

    -- Efeito de glitch (linhas que "falham")
    love.graphics.setColor(0.9, 0.4, 1, 0.6)
    love.graphics.setLineWidth(1)
    local glitchOffset = math.sin(time * 20) * 3
    love.graphics.line(x - r + glitchOffset, y, x + r + glitchOffset, y - 2)
    love.graphics.line(x - r - glitchOffset, y + 3, x + r - glitchOffset, y + 1)

    -- Partículas elétricas
    for i = 1, 3 do
      local pAngle = time * 8 + i * 2.1
      local px = x + math.cos(pAngle) * (r * 0.8 + math.sin(time * 12 + i) * 4)
      local py = y + math.sin(pAngle) * (r * 0.8 + math.cos(time * 10 + i) * 4)
      love.graphics.setColor(0.9, 0.6, 1, 0.7)
      love.graphics.circle('fill', px, py, 2)
    end

    -- Rastro de movimento zigzag
    local trailDir = self.zigzagDir or 1
    love.graphics.setColor(0.7, 0.3, 0.9, 0.4)
    love.graphics.circle('fill', x - trailDir * 8, y + 5, 4)
    love.graphics.setColor(0.6, 0.2, 0.8, 0.2)
    love.graphics.circle('fill', x + trailDir * 8, y + 10, 3)
  else
    -- Worm/Malware - visual cibernético (código malicioso)
    local time = love.timer.getTime()
    local pulse = math.sin(time * 5 + self.x * 0.05) * 0.15 + 0.85

    -- Cor base - verde matrix/cibernético
    local baseColor = {0.1, 0.8 * pulse, 0.3}

    -- Corpo hexagonal principal
    love.graphics.setColor(0.05, 0.15, 0.1)
    local hexVerts = {}
    for i = 0, 5 do
      local angle = (i / 6) * math.pi * 2
      table.insert(hexVerts, x + math.cos(angle) * r * 0.9)
      table.insert(hexVerts, y + math.sin(angle) * r * 0.9)
    end
    love.graphics.polygon('fill', hexVerts)

    -- Borda brilhante pulsante
    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], pulse)
    love.graphics.setLineWidth(2)
    love.graphics.polygon('line', hexVerts)

    -- Núcleo central (esfera de dados)
    love.graphics.setColor(0, 0.4, 0.15)
    love.graphics.circle('fill', x, y, r * 0.5)
    love.graphics.setColor(0.2, 0.9, 0.4, pulse)
    love.graphics.circle('line', x, y, r * 0.5)

    -- Símbolo de código/binário no centro
    love.graphics.setColor(0, 1, 0.4, 0.9)
    love.graphics.setFont(love.graphics.newFont(8))
    love.graphics.print('01', x - 6, y - 5)

    -- Tentáculos/conexões de dados (linhas que se movem)
    love.graphics.setColor(0.1, 0.9, 0.4, 0.7)
    love.graphics.setLineWidth(1)
    for i = 1, 4 do
      local angle = (i / 4) * math.pi * 2 + time * 2
      local len = r * 0.8 + math.sin(time * 4 + i) * 3
      local tx = x + math.cos(angle) * len
      local ty = y + math.sin(angle) * len
      love.graphics.line(x + math.cos(angle) * r * 0.5, y + math.sin(angle) * r * 0.5, tx, ty)
      -- Nó na ponta
      love.graphics.setColor(0.3, 1, 0.5, 0.8)
      love.graphics.circle('fill', tx, ty, 2)
    end

    -- Scanlines (efeito digital)
    love.graphics.setColor(0, 0, 0, 0.3)
    for i = -3, 3 do
      local ly = y + i * 4 + (time * 20) % 4
      if ly > y - r and ly < y + r then
        love.graphics.line(x - r, ly, x + r, ly)
      end
    end
  end

  -- HP bar (melhorada)
  local barW, barH = 28, 3
  local pct = math.max(0, self.hp / self.maxHp)
  local barX = x - barW / 2
  local barY = y - r - 12

  -- Background
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle('fill', barX - 1, barY - 1, barW + 2, barH + 2, 2, 2)

  -- HP fill com cor baseada na porcentagem
  if pct > 0.5 then
    love.graphics.setColor(0.3, 0.9, 0.4)
  elseif pct > 0.25 then
    love.graphics.setColor(1, 0.8, 0.2)
  else
    love.graphics.setColor(1, 0.3, 0.3)
  end
  love.graphics.rectangle('fill', barX, barY, barW * pct, barH, 2, 2)
end

return Enemy

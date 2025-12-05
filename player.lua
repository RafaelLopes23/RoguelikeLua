local Player = {}
Player.__index = Player

function Player.new(x, y)
  local self = setmetatable({}, Player)
  self.x, self.y = x, y
  self.r = 12
  self.speed = 160
  self.hp = 100
  self.maxHp = 100
  self.fireDelay = 0.35 -- segundos entre tiros
  self._fireTimer = 0
  self.bulletDamage = 3
  self.bulletSpeed = 420
  self.hasLaser = false
  return self
end

function Player:update(dt, vx, vy)
  -- movimento normalizado
  local len = math.sqrt(vx*vx + vy*vy)
  if len > 0 then
    vx, vy = vx/len, vy/len
  end
  self.x = self.x + vx * self.speed * dt
  self.y = self.y + vy * self.speed * dt

  -- limitar à tela
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  if self.x < self.r then self.x = self.r end
  if self.y < self.r then self.y = self.r end
  if self.x > w - self.r then self.x = w - self.r end
  if self.y > h - self.r then self.y = h - self.r end

  -- recarga do tiro
  if self._fireTimer > 0 then
    self._fireTimer = self._fireTimer - dt
  end
end

function Player:canShoot()
  return self._fireTimer <= 0
end

function Player:shotFired()
  self._fireTimer = self.fireDelay
end

function Player:draw()
  local time = love.timer.getTime()
  local x, y, r = self.x, self.y, self.r

  -- Aura de proteção (escudo digital)
  local auraPulse = math.sin(time * 3) * 0.15 + 0.85
  love.graphics.setColor(0.3, 0.8, 1, 0.1 * auraPulse)
  love.graphics.circle('fill', x, y, r + 8)
  love.graphics.setColor(0.4, 0.9, 1, 0.2 * auraPulse)
  love.graphics.circle('line', x, y, r + 6)

  -- Corpo principal - hexágono (representa defesa digital)
  love.graphics.setColor(0.15, 0.35, 0.45)
  local hexVerts = {}
  for i = 0, 5 do
    local angle = (i / 6) * math.pi * 2 - math.pi / 2
    table.insert(hexVerts, x + math.cos(angle) * r)
    table.insert(hexVerts, y + math.sin(angle) * r)
  end
  love.graphics.polygon('fill', hexVerts)

  -- Borda brilhante ciano
  love.graphics.setColor(0.4, 0.9, 1, 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.polygon('line', hexVerts)

  -- Núcleo interno (energia)
  local corePulse = math.sin(time * 5) * 0.2 + 0.8
  love.graphics.setColor(0.2, 0.5, 0.6)
  love.graphics.circle('fill', x, y, r * 0.6)
  love.graphics.setColor(0.5, 0.95, 1, corePulse)
  love.graphics.circle('fill', x, y, r * 0.35)

  -- Símbolo de escudo/cadeado no centro
  love.graphics.setColor(0.1, 0.3, 0.4)
  -- Escudo simplificado
  love.graphics.polygon('fill',
    x, y - 5,        -- topo
    x - 6, y - 2,    -- esquerda superior
    x - 5, y + 5,    -- esquerda inferior
    x, y + 8,        -- ponta inferior
    x + 5, y + 5,    -- direita inferior
    x + 6, y - 2     -- direita superior
  )
  -- Contorno do escudo
  love.graphics.setColor(0.6, 1, 1, 0.8)
  love.graphics.setLineWidth(1)
  love.graphics.polygon('line',
    x, y - 5, x - 6, y - 2, x - 5, y + 5, x, y + 8, x + 5, y + 5, x + 6, y - 2
  )
  -- Símbolo de check/lock dentro do escudo
  love.graphics.setColor(0.5, 1, 0.8, 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.line(x - 2, y + 1, x, y + 3, x + 4, y - 2)

  -- Circuitos decorativos (linhas de dados)
  love.graphics.setColor(0.4, 0.85, 1, 0.5)
  love.graphics.setLineWidth(1)
  for i = 1, 3 do
    local angle = (i / 3) * math.pi * 2 + time * 1.5
    local innerR = r * 0.7
    local outerR = r * 0.95
    local sx = x + math.cos(angle) * innerR
    local sy = y + math.sin(angle) * innerR
    local ex = x + math.cos(angle) * outerR
    local ey = y + math.sin(angle) * outerR
    love.graphics.line(sx, sy, ex, ey)
    -- Ponto na extremidade
    love.graphics.setColor(0.5, 1, 1, 0.7)
    love.graphics.circle('fill', ex, ey, 2)
  end

  -- Partículas orbitando (dados fluindo)
  for i = 1, 4 do
    local orbitAngle = time * 2 + i * (math.pi / 2)
    local orbitR = r + 3 + math.sin(time * 4 + i) * 2
    local px = x + math.cos(orbitAngle) * orbitR
    local py = y + math.sin(orbitAngle) * orbitR
    local alpha = math.sin(time * 6 + i) * 0.3 + 0.5
    love.graphics.setColor(0.4, 0.95, 1, alpha)
    love.graphics.circle('fill', px, py, 2)
  end

  -- HP bar (melhorada)
  local barW, barH = 60, 6
  local hpPct = math.max(0, self.hp / self.maxHp)
  local barX = x - barW/2
  local barY = y - r - 16

  -- Background
  love.graphics.setColor(0.1, 0.12, 0.2, 0.9)
  love.graphics.rectangle('fill', barX - 1, barY - 1, barW + 2, barH + 2, 4, 4)

  -- HP fill com cor baseada na porcentagem
  local hpColor
  if hpPct > 0.6 then
    hpColor = {0.3, 0.9, 0.5}  -- Verde
  elseif hpPct > 0.3 then
    hpColor = {0.9, 0.8, 0.2}  -- Amarelo
  else
    hpColor = {0.9, 0.3, 0.3}  -- Vermelho
  end
  love.graphics.setColor(hpColor[1], hpColor[2], hpColor[3])
  love.graphics.rectangle('fill', barX, barY, barW * hpPct, barH, 4, 4)

  -- Borda da barra
  love.graphics.setColor(0.4, 0.7, 0.8, 0.6)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', barX - 1, barY - 1, barW + 2, barH + 2, 4, 4)

  love.graphics.setLineWidth(1)
end

return Player

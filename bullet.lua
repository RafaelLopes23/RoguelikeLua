local Bullet = {}
Bullet.__index = Bullet

function Bullet.new(x, y, vx, vy, damage)
  local self = setmetatable({}, Bullet)
  self.x, self.y = x, y
  self.vx, self.vy = vx, vy
  self.damage = damage or 10
  self.r = 4
  self.dead = false
  return self
end

function Bullet:update(dt)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  if self.x < -20 or self.y < -20 or self.x > w + 20 or self.y > h + 20 then
    self.dead = true
  end
end

function Bullet:draw()
  love.graphics.setColor(0.95, 0.9, 0.2)
  love.graphics.circle('fill', self.x, self.y, self.r)
end

return Bullet

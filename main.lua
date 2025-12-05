-- Cybersafe Rogue - Roguelike MVP
-- Controles:
--  - Movimento: W/A/S/D
--  - Atirar: Mouse esquerdo (segurar) ou Espaço
--  - Reiniciar (quando game over): R

local Player = require('player')
local Enemy = require('enemy')
local Bullet = require('bullet')
local Questions = require('questions')
local Theme = require('theme')

local state = 'title' -- 'title' | 'play' | 'question' | 'upgrade' | 'gameover'
local player
local enemies = {}
local bullets = {}
local wave = 0
local completedWaves = 0
local waveActive = false
local toSpawn = 0
local spawnTimer = 0
local spawnInterval = 0.6
local difficulty = 1.0
local question
local lastAnswerCorrect = false
local baseEnemies = 5
local upgradeChoices = {
  { key = 'atk_speed', label = 'Velocidade de ataque' },
  { key = 'laser',     label = 'Laser perfurante' },
  { key = 'damage',    label = 'Dano aumentado' },
  { key = 'scatter',   label = 'Tiro espalhado' },
}
local currentUpgradeChoices = nil

local hudFont, titleFont, questionFont, optionFont, smallFont, bigTitleFont
local cheatBtn = { x = 0, y = 0, w = 170, h = 28 }
local laser = {
  active = false,
  interval = 0.4,
  timer = 0.4,
  width = 10,
  length = 900,
  dx = 1,
  dy = 0,
}
local feedback = { text = nil, timer = 0, color = {1, 1, 1} }
local laserHits = {}
local areaHits = {}
local showHowTo = false
local paused = false
local pausedFromState = nil  -- Guarda estado anterior ao pause

-- Músicas de fundo
local bgMusic = nil
local menuMusic = nil
local bossMusic = nil
local musicVolume = 0.075  -- Volume baixo
local menuMusicVolume = 0.10  -- Volume para menu
local bossMusicVolume = 0.075  -- Volume para boss

-- Sistema de Sons Procedurais (versão suave)
local sounds = {}
local soundEnabled = true
local masterVolume = 0.12  -- Volume bem baixo

-- Gerador de som mais suave com filtro
local function generateSoftTone(frequency, duration, waveType, envelope, options)
  options = options or {}
  local sampleRate = 44100
  local samples = math.floor(sampleRate * duration)
  local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
  local freqSlide = options.freqSlide or 0  -- Deslize de frequência
  local vibrato = options.vibrato or 0
  local softness = options.softness or 1  -- Quanto maior, mais suave

  local prevSample = 0  -- Para filtro passa-baixa

  for i = 0, samples - 1 do
    local t = i / sampleRate
    local progress = i / samples

    -- Frequência com slide e vibrato
    local freq = frequency + (freqSlide * progress) + math.sin(t * 30) * vibrato

    -- Envelope suave
    local env = 1
    if envelope == 'pluck' then
      env = math.exp(-progress * 6 * softness)
    elseif envelope == 'fade' then
      env = (1 - progress) ^ 1.5
    elseif envelope == 'pulse' then
      env = math.sin(progress * math.pi) ^ 0.7
    elseif envelope == 'smooth' then
      -- Attack + decay suave
      local attack = math.min(1, progress * 10)
      local decay = math.max(0, 1 - (progress - 0.1) * 1.2)
      env = attack * decay
    end

    -- Forma de onda
    local sample = 0
    if waveType == 'sine' then
      sample = math.sin(2 * math.pi * freq * t)
    elseif waveType == 'triangle' then
      -- Triângulo é mais suave que quadrada
      local phase = (freq * t) % 1
      sample = 4 * math.abs(phase - 0.5) - 1
    elseif waveType == 'softsaw' then
      -- Serra suavizada
      local phase = (freq * t) % 1
      sample = 2 * phase - 1
      sample = math.sin(sample * math.pi / 2)  -- Suaviza
    elseif waveType == 'noise' then
      -- Ruído filtrado (mais suave)
      local noise = math.random() * 2 - 1
      sample = prevSample * 0.7 + noise * 0.3  -- Filtro passa-baixa
    elseif waveType == 'laser' then
      -- Som de laser suave (frequência descendente)
      local laserFreq = freq * (1 - progress * 0.5)
      sample = math.sin(2 * math.pi * laserFreq * t) * 0.6
      sample = sample + math.sin(2 * math.pi * laserFreq * 2 * t) * 0.2
    end

    -- Filtro passa-baixa para suavizar
    sample = prevSample * 0.3 + sample * 0.7
    prevSample = sample

    sample = sample * env * masterVolume
    sample = math.max(-1, math.min(1, sample))
    soundData:setSample(i, sample)
  end

  return love.audio.newSource(soundData)
end

local function initSounds()
  -- Sons muito mais suaves
  -- Tiro: som curto e suave tipo "pew" abafado
  sounds.shoot = generateSoftTone(400, 0.06, 'triangle', 'pluck', {freqSlide = -200, softness = 2})

  -- Hit: som suave de impacto
  sounds.hit = generateSoftTone(150, 0.05, 'noise', 'pluck', {softness = 3})

  -- Inimigo morrendo: som descendente suave
  sounds.enemyDie = generateSoftTone(300, 0.12, 'triangle', 'fade', {freqSlide = -200})

  -- Laser: som de laser suave e contínuo
  sounds.laser = generateSoftTone(600, 0.08, 'laser', 'smooth', {freqSlide = -300})

  -- Upgrade: som agradável ascendente
  sounds.upgrade = generateSoftTone(400, 0.25, 'sine', 'pulse', {freqSlide = 300, vibrato = 5})

  -- Resposta correta: acorde suave
  sounds.correct = generateSoftTone(523, 0.2, 'sine', 'fade', {vibrato = 2})

  -- Resposta errada: som grave descendente
  sounds.wrong = generateSoftTone(200, 0.3, 'triangle', 'fade', {freqSlide = -100})

  -- Clique de botão: som muito curto
  sounds.buttonClick = generateSoftTone(350, 0.03, 'sine', 'pluck', {softness = 3})

  -- Início de wave: som suave de alerta
  sounds.waveStart = generateSoftTone(300, 0.35, 'sine', 'pulse', {freqSlide = 100})

  -- Boss levando dano
  sounds.bossHit = generateSoftTone(80, 0.1, 'softsaw', 'pluck', {softness = 2})

  -- Player levando dano
  sounds.playerHit = generateSoftTone(120, 0.12, 'noise', 'fade', {softness = 2})
end

local function playSound(name)
  if not soundEnabled or not sounds[name] then return end
  sounds[name]:stop()
  sounds[name]:play()
end

local function showQuestionScreen()
  Questions.setWave(wave)
  question = Questions.getForWave(wave)
  if not question then
    -- Todas as perguntas esgotadas, continua sem pergunta
    return false
  end
  state = 'question'
  laser.active = false
  laser.timer = laser.interval
  playSound('question')
  return true
end

local function clearBattlefield()
  enemies = {}
  bullets = {}
  waveActive = false
  toSpawn = 0
  spawnTimer = 0
  laser.active = false
  laserHits = {}
end

local function pushFeedback(text, color)
  feedback.text = text
  feedback.timer = 1.5
  feedback.color = color or {1, 1, 1}
end

local function cheatJumpToQuestion()
  if state == 'upgrade' then return end
  clearBattlefield()
  completedWaves = completedWaves + 2
  wave = wave + 1
  showQuestionScreen()
end

local function cheatJumpToBoss()
  if state == 'upgrade' then return end
  clearBattlefield()
  wave = 20  -- Próxima será 21 (boss) - startWave incrementa
  completedWaves = 40
  waveActive = false  -- Força iniciar nova wave no próximo update

  -- Dar upgrades equivalentes a jogar até wave 20
  -- 10 perguntas respondidas = 10 upgrades
  -- 2x laser, 2x scatter, resto em atk speed
  player.hasLaser = true
  player.laserLevel = 2
  player.hasScatter = true
  player.scatterLevel = 2
  -- 6 upgrades de atk speed (10 - 2 laser - 2 scatter = 6)
  for i = 1, 6 do
    player.fireDelay = math.max(0.05, player.fireDelay * 0.5)
    laser.interval = math.max(0.1, laser.interval * 0.5)
  end

  pushFeedback('Skip para Boss - Upgrades aplicados!', {1, 0.8, 0.2})
  state = 'play'  -- Garante que está no estado de jogo
end

local function updateFeedback(dt)
  if feedback.timer > 0 then
    feedback.timer = math.max(0, feedback.timer - dt)
  end
end

local function addLaserHit(x, y)
  table.insert(laserHits, { x = x, y = y, timer = 0.25, max = 0.25 })
end

local function updateLaserHits(dt)
  for i = #laserHits, 1, -1 do
    local hit = laserHits[i]
    hit.timer = hit.timer - dt
    if hit.timer <= 0 then
      table.remove(laserHits, i)
    end
  end
end

local function addAreaHit(x, y, radius)
  table.insert(areaHits, { x = x, y = y, radius = radius, timer = 0.3, max = 0.3 })
end

local function updateAreaHits(dt)
  for i = #areaHits, 1, -1 do
    local hit = areaHits[i]
    hit.timer = hit.timer - dt
    if hit.timer <= 0 then
      table.remove(areaHits, i)
    end
  end
end

local function getTitleButtons()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local btnW, btnH = 240, 56
  local playY = h * 0.55
  local gap = 16
  return {
    play = { x = (w - btnW)/2, y = playY, w = btnW, h = btnH },
    howto = { x = (w - btnW)/2, y = playY + btnH + gap, w = btnW, h = btnH },
  }
end

local function getHowToLayout()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local boxW, boxH = 560, 360
  local bx = (w - boxW)/2
  local by = (h - boxH)/2 - 40
  local closeW, closeH = 180, 46
  local closeX = bx + (boxW - closeW)/2
  local closeY = by + boxH - closeH - 24
  return {
    box = { x = bx, y = by, w = boxW, h = boxH },
    close = { x = closeX, y = closeY, w = closeW, h = closeH },
  }
end


-- Boss state
local boss = nil
local bossActive = false
local bossSpawnTimer = 0
local bossAttackTimer = 0
local bossPattern = 1
local bossProjectiles = {}

local function resetGame()
  player = Player.new(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  enemies = {}
  bullets = {}
  wave = 0
  completedWaves = 0
  waveActive = false
  toSpawn = 0
  spawnTimer = 0
  difficulty = 1.0
  question = nil
  lastAnswerCorrect = false
  currentUpgradeChoices = nil
  laser.active = false
  laser.interval = 0.4
  laser.timer = laser.interval
  player.hasLaser = false
  player.laserLevel = 0
  player.hasScatter = false
  player.scatterLevel = 0
  player.lastUpgrade = nil
  areaHits = {}
  boss = nil
  bossActive = false
  bossSpawnTimer = 0
  bossAttackTimer = 0
  bossPattern = 1
  bossProjectiles = {}
  Questions.reset()
  state = 'play'
end

function love.load()
  love.window.setTitle('Cybersafe Rogue - Roguelike MVP')
  love.graphics.setBackgroundColor(Theme.colors.bgDark)
  math.randomseed(os.time())
  smallFont = love.graphics.newFont(12)
  hudFont = love.graphics.newFont(14)
  optionFont = love.graphics.newFont(15)
  questionFont = love.graphics.newFont(17)
  titleFont = love.graphics.newFont(22)
  bigTitleFont = love.graphics.newFont(32)
  initSounds()  -- Inicializa sistema de sons

  -- Carrega músicas
  bgMusic = love.audio.newSource('main theme.mp3', 'stream')
  bgMusic:setLooping(true)
  bgMusic:setVolume(musicVolume)

  menuMusic = love.audio.newSource('menu pause.mp3', 'stream')
  menuMusic:setLooping(true)
  menuMusic:setVolume(menuMusicVolume)

  bossMusic = love.audio.newSource('boss.mp3', 'stream')
  bossMusic:setLooping(true)
  bossMusic:setVolume(bossMusicVolume)

  -- Inicia com música do menu
  menuMusic:play()

  resetGame()
  state = 'title'
  showHowTo = false
end

local function startWave()
  wave = wave + 1

  -- Não avança além da wave 21 (boss)
  if wave > 21 then
    wave = 21
  end

  waveActive = true
  playSound('waveStart')

  -- Wave 21 é a boss wave
  if wave == 21 then
    -- Troca para música do boss
    if bgMusic then bgMusic:stop() end
    if bossMusic then bossMusic:play() end

    -- Inicializa o boss (Trojan)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    boss = {
      x = w / 2,
      y = 80,
      hp = 5000,
      maxHp = 5000,
      r = 50,
      speed = 40,
      phase = 1,
      targetX = w / 2,
      moveTimer = 0,
      attackCooldown = 0,
    }
    bossActive = true
    bossSpawnTimer = 3  -- Espera 3 segundos antes de spawnar minions
    bossAttackTimer = 0
    bossPattern = 1
    bossProjectiles = {}
    toSpawn = 0
    spawnTimer = 0
    spawnInterval = 2.5  -- Minions aparecem mais devagar
    return
  end

  -- sempre +5 inimigos por wave (com multiplicador de dificuldade)
  local enemiesThisWave = baseEnemies + (wave - 1) * 5
  toSpawn = math.floor(enemiesThisWave * difficulty)
  spawnTimer = 0
  spawnInterval = math.max(0.25, 0.7 - wave * 0.03)
end

local function spawnBossMinion()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local side = math.random(4)
  local x, y
  if side == 1 then x, y = -20, math.random(0, h)
  elseif side == 2 then x, y = w + 20, math.random(0, h)
  elseif side == 3 then x, y = math.random(0, w), -20
  else x, y = math.random(0, w), h + 20 end
  -- Minions do boss são mais fracos mas constantes
  local hp = 8 + math.random(0, 4)
  local speed = 70 + math.random(0, 20)
  table.insert(enemies, Enemy.new(x, y, hp, speed, 'basic'))
end

local function fireBossProjectile(angle, speed, size)
  table.insert(bossProjectiles, {
    x = boss.x,
    y = boss.y,
    vx = math.cos(angle) * speed,
    vy = math.sin(angle) * speed,
    r = size or 8,
    damage = 10,
  })
end

local function bossAttackPattern1()
  -- Padrão circular: projéteis em círculo
  local numProjectiles = 12
  for i = 1, numProjectiles do
    local angle = (i / numProjectiles) * math.pi * 2
    fireBossProjectile(angle, 150, 8)
  end
end

local function bossAttackPattern2()
  -- Padrão direcionado: projéteis em direção ao player
  local dx, dy = player.x - boss.x, player.y - boss.y
  local len = math.sqrt(dx*dx + dy*dy)
  if len > 0 then
    dx, dy = dx/len, dy/len
  end
  local baseAngle = math.atan2(dy, dx)
  -- 5 projéteis em cone
  for i = -2, 2 do
    local angle = baseAngle + i * 0.2
    fireBossProjectile(angle, 200, 10)
  end
end

local function bossAttackPattern3()
  -- Padrão espiral: projéteis em espiral
  local baseAngle = love.timer.getTime() * 3
  for i = 0, 5 do
    local angle = baseAngle + i * (math.pi / 3)
    fireBossProjectile(angle, 120, 6)
  end
end

local function updateBoss(dt)
  if not boss then return end

  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  -- Inicializa variáveis de movimento avançado se não existirem
  if not boss.moveMode then
    boss.moveMode = 'wander'  -- wander, chase, zigzag, dash
    boss.dashTimer = 0
    boss.dashCooldown = 0
    boss.zigzagDir = 1
    boss.zigzagTimer = 0
    boss.targetY = boss.y
    boss.dashVx = 0
    boss.dashVy = 0
  end

  -- Movimento baseado na fase
  boss.moveTimer = boss.moveTimer - dt

  -- Fase 1: Movimento horizontal simples (como antes)
  if boss.phase == 1 then
    if boss.moveTimer <= 0 then
      boss.targetX = 100 + math.random() * (w - 200)
      boss.moveTimer = 2 + math.random() * 2
    end

    if boss.x < boss.targetX then
      boss.x = math.min(boss.x + boss.speed * dt, boss.targetX)
    else
      boss.x = math.max(boss.x - boss.speed * dt, boss.targetX)
    end

  -- Fase 2: Comportamento de Charger (dash attacks)
  elseif boss.phase == 2 then
    boss.dashCooldown = boss.dashCooldown - dt

    if boss.moveMode == 'wander' then
      -- Movimento normal até preparar dash
      if boss.moveTimer <= 0 then
        boss.targetX = 100 + math.random() * (w - 200)
        boss.targetY = 80 + math.random() * (h * 0.3)
        boss.moveTimer = 1.5 + math.random()
      end

      local dx = boss.targetX - boss.x
      local dy = boss.targetY - boss.y
      local len = math.sqrt(dx*dx + dy*dy)
      if len > 5 then
        boss.x = boss.x + (dx/len) * boss.speed * dt
        boss.y = boss.y + (dy/len) * boss.speed * dt
      end

      -- Preparar dash quando cooldown acabar
      if boss.dashCooldown <= 0 then
        boss.moveMode = 'charging'
        boss.dashTimer = 0.8  -- Tempo carregando
        -- Direção do dash: em direção ao player
        local toDx = player.x - boss.x
        local toDy = player.y - boss.y
        local toLen = math.sqrt(toDx*toDx + toDy*toDy)
        if toLen > 0 then
          boss.dashVx = (toDx/toLen) * boss.speed * 12  -- TRIPLO: 4 -> 12
          boss.dashVy = (toDy/toLen) * boss.speed * 12
        end
      end

    elseif boss.moveMode == 'charging' then
      -- Tremer enquanto carrega (visual)
      boss.dashTimer = boss.dashTimer - dt
      if boss.dashTimer <= 0 then
        boss.moveMode = 'dash'
        boss.dashTimer = 1.2  -- Duração do dash TRIPLA: 0.6 -> 1.8
      end

    elseif boss.moveMode == 'dash' then
      -- Dash rápido!
      boss.x = boss.x + boss.dashVx * dt
      boss.y = boss.y + boss.dashVy * dt

      -- Limita à tela
      boss.x = math.max(50, math.min(w - 50, boss.x))
      boss.y = math.max(50, math.min(h - 50, boss.y))

      boss.dashTimer = boss.dashTimer - dt
      if boss.dashTimer <= 0 then
        boss.moveMode = 'wander'
        boss.dashCooldown = 3 + math.random() * 2
        boss.moveTimer = 0.5
      end
    end

  -- Fase 3: Comportamento híbrido Charger + Zigzag
  else
    boss.dashCooldown = boss.dashCooldown - dt
    boss.zigzagTimer = boss.zigzagTimer - dt

    if boss.moveMode == 'wander' then
      -- Movimento zigzag MUITO mais intenso (glitch)
      if boss.zigzagTimer <= 0 then
        boss.zigzagDir = -boss.zigzagDir
        boss.zigzagTimer = 0.08 + math.random() * 0.05  -- Muito mais rápido
      end

      if boss.moveTimer <= 0 then
        boss.targetX = 50 + math.random() * (w - 100)  -- Range maior
        boss.targetY = 50 + math.random() * (h * 0.6)  -- Desce mais
        boss.moveTimer = 0.5 + math.random() * 0.5  -- Muda alvo mais rápido
      end

      -- Movimento em direção ao alvo + zigzag lateral MUITO MAIOR
      local dx = boss.targetX - boss.x
      local dy = boss.targetY - boss.y
      local len = math.sqrt(dx*dx + dy*dy)
      if len > 5 then
        local ndx, ndy = dx/len, dy/len
        -- Perpendicular
        local perpX, perpY = -ndy, ndx
        local moveSpeed = boss.speed * 2.5  -- MUITO mais rápido na fase 3

        boss.x = boss.x + (ndx * 0.5 + perpX * 1.5 * boss.zigzagDir) * moveSpeed * dt  -- Zigzag 3x maior
        boss.y = boss.y + (ndy * 0.5 + perpY * 1.5 * boss.zigzagDir) * moveSpeed * dt
      end

      -- Dash mais frequente
      if boss.dashCooldown <= 0 then
        boss.moveMode = 'charging'
        boss.dashTimer = 0.3  -- Carga MUITO mais rápida
        local toDx = player.x - boss.x
        local toDy = player.y - boss.y
        local toLen = math.sqrt(toDx*toDx + toDy*toDy)
        if toLen > 0 then
          boss.dashVx = (toDx/toLen) * boss.speed * 15  -- Dash MUITO mais forte
          boss.dashVy = (toDy/toLen) * boss.speed * 15
        end
      end

    elseif boss.moveMode == 'charging' then
      boss.dashTimer = boss.dashTimer - dt
      if boss.dashTimer <= 0 then
        boss.moveMode = 'dash'
        boss.dashTimer = 0.5
      end

    elseif boss.moveMode == 'dash' then
      boss.x = boss.x + boss.dashVx * dt
      boss.y = boss.y + boss.dashVy * dt
      boss.x = math.max(50, math.min(w - 50, boss.x))
      boss.y = math.max(50, math.min(h - 50, boss.y))

      boss.dashTimer = boss.dashTimer - dt
      if boss.dashTimer <= 0 then
        boss.moveMode = 'wander'
        boss.dashCooldown = 2 + math.random()
        boss.moveTimer = 0.3
      end
    end
  end

  -- Determina fase baseada no HP
  if boss.hp <= boss.maxHp * 0.3 then
    boss.phase = 3
  elseif boss.hp <= boss.maxHp * 0.6 then
    boss.phase = 2
  end

  -- Ataque baseado na fase
  bossAttackTimer = bossAttackTimer - dt
  if bossAttackTimer <= 0 then
    if boss.phase == 1 then
      bossAttackPattern1()
      bossAttackTimer = 2.0
    elseif boss.phase == 2 then
      if bossPattern == 1 then
        bossAttackPattern1()
        bossPattern = 2
      else
        bossAttackPattern2()
        bossPattern = 1
      end
      bossAttackTimer = 1.5
    else
      -- Fase 3: todos os padrões mais rápido
      local pattern = math.random(1, 3)
      if pattern == 1 then bossAttackPattern1()
      elseif pattern == 2 then bossAttackPattern2()
      else bossAttackPattern3() end
      bossAttackTimer = 1.0
    end
  end

  -- Update projectiles
  for i = #bossProjectiles, 1, -1 do
    local p = bossProjectiles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt

    -- Colisão com player
    local dx, dy = p.x - player.x, p.y - player.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist <= p.r + player.r then
      player.hp = player.hp - p.damage
      playSound('playerHit')
      table.remove(bossProjectiles, i)
      if player.hp <= 0 then
        player.hp = 0
        state = 'gameover'
      end
    -- Remove se fora da tela
    elseif p.x < -50 or p.x > w + 50 or p.y < -50 or p.y > love.graphics.getHeight() + 50 then
      table.remove(bossProjectiles, i)
    end
  end

  -- Spawn minions periodicamente
  bossSpawnTimer = bossSpawnTimer - dt
  if bossSpawnTimer <= 0 then
    spawnBossMinion()
    bossSpawnTimer = math.max(1.5, 3.0 - boss.phase * 0.5)  -- Mais rápido nas fases finais
  end
end

local function hitBoss(damage)
  if not boss then return false end
  boss.hp = boss.hp - damage
  if boss.hp <= 0 then
    boss = nil
    bossActive = false
    bossProjectiles = {}
    return true  -- Boss morreu
  end
  return false
end

local function spawnEnemy()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  -- spawn nas bordas
  local side = math.random(4)
  local x, y
  if side == 1 then x, y = -20, math.random(0, h)
  elseif side == 2 then x, y = w + 20, math.random(0, h)
  elseif side == 3 then x, y = math.random(0, w), -20
  else x, y = math.random(0, w), h + 20 end
  -- Escalonamento: vida inicial 3, +6 HP por wave (3x mais)
  local hp = 3 + (wave - 1) * 6
  local speed = 60 + (wave - 1) * 1

  -- Determinar tipo de inimigo
  local enemyKind = 'basic'

  -- Charger aparece a partir da wave 2
  local chargerChance = 0
  if wave >= 2 then
    chargerChance = math.min(0.12 + wave * 0.025, 0.55)
  end

  -- Zigzag aparece a partir da wave 3
  local zigzagChance = 0
  if wave >= 3 then
    zigzagChance = math.min(0.10 + wave * 0.02, 0.40)
  end

  -- Rolar para determinar tipo
  local roll = math.random()
  if roll < zigzagChance then
    enemyKind = 'zigzag'
    -- Zigzag tem menos HP base (aplicado no Enemy.new)
  elseif roll < zigzagChance + chargerChance then
    enemyKind = 'charger'
    hp = hp + 1  -- Charger tem +1 HP
  end

  table.insert(enemies, Enemy.new(x, y, hp, speed, enemyKind))
end

local function allEnemiesDefeated()
  -- Na boss wave, verifica se o boss foi derrotado
  if wave == 21 then
    return waveActive and not bossActive and #enemies == 0
  end
  return waveActive and toSpawn <= 0 and #enemies == 0
end

local function endWave()
  waveActive = false

  -- Se derrotou o boss, mostra vitória
  if wave == 21 then
    -- Para música do boss, volta para música do menu (vitória)
    if bossMusic then bossMusic:stop() end
    if menuMusic then menuMusic:play() end
    state = 'victory'
    return
  end

  completedWaves = completedWaves + 1
  if completedWaves % 2 == 0 then
    local hasQuestion = showQuestionScreen()
    if not hasQuestion then
      -- Sem mais perguntas, vai direto pro boss
      startWave()
    end
  end
end

local function fireTowardsMouse()
  local mx, my = love.mouse.getPosition()
  local dx, dy = mx - player.x, my - player.y
  local len = math.sqrt(dx*dx + dy*dy)
  if len == 0 then return end
  dx, dy = dx/len, dy/len

  if player.hasScatter then
    -- Fire bullets in a cone: 3 at level 1, 6 at level 2
    local spreadAngle = 0.26 -- ~15 degrees in radians
    local baseAngle = math.atan2(dy, dx)
    local angles
    if (player.scatterLevel or 1) >= 2 then
      -- Level 2: 6 projectiles with tighter spread
      local halfSpread = spreadAngle * 1.2
      angles = {
        baseAngle - halfSpread,
        baseAngle - halfSpread * 0.6,
        baseAngle - halfSpread * 0.2,
        baseAngle + halfSpread * 0.2,
        baseAngle + halfSpread * 0.6,
        baseAngle + halfSpread,
      }
    else
      -- Level 1: 3 projectiles
      angles = { baseAngle - spreadAngle, baseAngle, baseAngle + spreadAngle }
    end
    for _, angle in ipairs(angles) do
      local adx = math.cos(angle)
      local ady = math.sin(angle)
      local b = Bullet.new(player.x, player.y, adx * player.bulletSpeed, ady * player.bulletSpeed, player.bulletDamage)
      table.insert(bullets, b)
    end
  else
    local b = Bullet.new(player.x, player.y, dx * player.bulletSpeed, dy * player.bulletSpeed, player.bulletDamage)
    table.insert(bullets, b)
  end
  playSound('shoot')
end

local function distancePointToSegment(px, py, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  local len2 = dx*dx + dy*dy
  if len2 == 0 then
    local ddx, ddy = px - x1, py - y1
    return math.sqrt(ddx*ddx + ddy*ddy)
  end
  local t = ((px - x1) * dx + (py - y1) * dy) / len2
  t = math.max(0, math.min(1, t))
  local projx = x1 + t * dx
  local projy = y1 + t * dy
  local ddx, ddy = px - projx, py - projy
  return math.sqrt(ddx*ddx + ddy*ddy)
end

local function getLaserDirections()
  -- Returns array of {dx, dy} for each laser beam
  local baseAngle = math.atan2(laser.dy, laser.dx)
  if player.hasScatter then
    local spreadAngle = 0.26 -- ~15 degrees
    if (player.scatterLevel or 1) >= 2 then
      -- Level 2: 6 lasers
      local halfSpread = spreadAngle * 1.2
      return {
        { dx = math.cos(baseAngle - halfSpread), dy = math.sin(baseAngle - halfSpread) },
        { dx = math.cos(baseAngle - halfSpread * 0.6), dy = math.sin(baseAngle - halfSpread * 0.6) },
        { dx = math.cos(baseAngle - halfSpread * 0.2), dy = math.sin(baseAngle - halfSpread * 0.2) },
        { dx = math.cos(baseAngle + halfSpread * 0.2), dy = math.sin(baseAngle + halfSpread * 0.2) },
        { dx = math.cos(baseAngle + halfSpread * 0.6), dy = math.sin(baseAngle + halfSpread * 0.6) },
        { dx = math.cos(baseAngle + halfSpread), dy = math.sin(baseAngle + halfSpread) },
      }
    else
      -- Level 1: 3 lasers
      return {
        { dx = math.cos(baseAngle - spreadAngle), dy = math.sin(baseAngle - spreadAngle) },
        { dx = math.cos(baseAngle), dy = math.sin(baseAngle) },
        { dx = math.cos(baseAngle + spreadAngle), dy = math.sin(baseAngle + spreadAngle) },
      }
    end
  else
    return { { dx = laser.dx, dy = laser.dy } }
  end
end

local function applyAreaDamage(centerX, centerY, radius)
  -- Deal damage to all enemies within radius of the center point
  local areaHitCount = 0
  for i = #enemies, 1, -1 do
    local e = enemies[i]
    local ddx, ddy = e.x - centerX, e.y - centerY
    local dist = math.sqrt(ddx*ddx + ddy*ddy)
    if dist <= radius + e.r then
      local dead = e:hit(player.bulletDamage * 0.5) -- Area damage is 50% of normal
      if dead then
        table.remove(enemies, i)
        playSound('enemyDie')
      end
      areaHitCount = areaHitCount + 1
    end
  end
  return areaHitCount
end

local function applyLaserDamage()
  local directions = getLaserDirections()
  local anyHit = false
  local hitPositions = {} -- Store positions for area damage (laser level 2)
  local totalHits = 0  -- Contador de hits para lifesteal

  for _, dir in ipairs(directions) do
    local x1, y1 = player.x, player.y
    local x2 = player.x + dir.dx * laser.length
    local y2 = player.y + dir.dy * laser.length

    -- Dano no boss (verificação dupla para evitar nil)
    if boss and bossActive and boss.x and boss.y then
      local dist = distancePointToSegment(boss.x, boss.y, x1, y1, x2, y2)
      if dist <= boss.r + laser.width * 0.5 then
        local bossDied = hitBoss(player.bulletDamage)
        if boss then  -- Verificar novamente após hit
          addLaserHit(boss.x, boss.y)
        end
        anyHit = true
        totalHits = totalHits + 1
        if bossDied then
          pushFeedback('BOSS DERROTADO!', {1, 0.8, 0.2})
        elseif boss and player.laserLevel >= 2 then
          table.insert(hitPositions, { x = boss.x, y = boss.y })
        end
      end
    end

    for i = #enemies, 1, -1 do
      local e = enemies[i]
      local dist = distancePointToSegment(e.x, e.y, x1, y1, x2, y2)
      if dist <= e.r + laser.width * 0.5 then
        local dead = e:hit(player.bulletDamage)
        addLaserHit(e.x, e.y)
        anyHit = true
        totalHits = totalHits + 1

        -- Store hit position for area damage if laser level 2
        if player.laserLevel >= 2 then
          table.insert(hitPositions, { x = e.x, y = e.y })
        end

        if dead then
          table.remove(enemies, i)
          playSound('enemyDie')
        end
      end
    end
  end

  -- Apply area damage for laser level 2
  if player.laserLevel >= 2 then
    local areaRadius = 60
    for _, pos in ipairs(hitPositions) do
      applyAreaDamage(pos.x, pos.y, areaRadius)
      addAreaHit(pos.x, pos.y, areaRadius)
    end
  end

  -- Aplicar lifesteal (roubo de vida)
  if anyHit and player.laserLifesteal and player.laserLifesteal > 0 then
    local healAmount = totalHits * player.laserLifesteal
    player.hp = math.min(player.maxHp, player.hp + healAmount)
  end

  if anyHit then
    playSound('laser')
  end
end

local function updateLaser(dt, shooting)
  if not player.hasLaser then
    laser.active = false
    return
  end

  if shooting then
    local mx, my = love.mouse.getPosition()
    local dx, dy = mx - player.x, my - player.y
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then
      dx, dy = 1, 0
    else
      dx, dy = dx/len, dy/len
    end
    laser.dx, laser.dy = dx, dy
    if not laser.active then
      laser.timer = 0
    end
    laser.active = true
    laser.timer = laser.timer - dt
    if laser.timer <= 0 then
      laser.timer = laser.interval
      applyLaserDamage()
      playSound('laser')
    end
  else
    if laser.active then
      laser.timer = laser.interval
    end
    laser.active = false
  end
end

local function handleInput(dt)
  local vx, vy = 0, 0
  if love.keyboard.isDown('w') then vy = vy - 1 end
  if love.keyboard.isDown('s') then vy = vy + 1 end
  if love.keyboard.isDown('a') then vx = vx - 1 end
  if love.keyboard.isDown('d') then vx = vx + 1 end
  player:update(dt, vx, vy)

  local shooting = love.keyboard.isDown('space') or love.mouse.isDown(1)
  updateLaser(dt, shooting)

  if not player.hasLaser and shooting then
    if player:canShoot() then
      fireTowardsMouse()
      player:shotFired()
      playSound('shoot')
    end
  end
end

local function circleRectCollision(cx, cy, cr, rx, ry, rw, rh)
  local closestX = math.max(rx, math.min(cx, rx + rw))
  local closestY = math.max(ry, math.min(cy, ry + rh))
  local dx, dy = cx - closestX, cy - closestY
  return (dx*dx + dy*dy) <= cr*cr
end

local function drawButton(x, y, w, h, text)
  love.graphics.setColor(0.08, 0.1, 0.18, 0.95)
  love.graphics.rectangle('fill', x, y, w, h, 12, 12)
  love.graphics.setColor(0.25, 0.45, 0.65)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', x, y, w, h, 12, 12)
  love.graphics.setColor(0.85, 0.9, 0.95)
  local tw = hudFont:getWidth(text)
  local th = hudFont:getHeight()
  love.graphics.print(text, x + (w - tw)/2, y + (h - th)/2)
end

local function generateUpgradeChoices()
  -- Build list of available upgrades with weights
  local available = {}

  -- atk_speed and damage are always available
  table.insert(available, { key = 'atk_speed', label = 'Velocidade de ataque', weight = 1 })
  table.insert(available, { key = 'damage', label = 'Dano aumentado', weight = 1 })

  -- laser available until level 2
  if (player.laserLevel or 0) < 2 then
    table.insert(available, { key = 'laser', label = 'Laser perfurante', weight = 1 })
  end

  -- scatter available until level 2
  if (player.scatterLevel or 0) < 2 then
    table.insert(available, { key = 'scatter', label = 'Tiro espalhado', weight = 1 })
  end

  -- Reduce weight of last chosen upgrade
  if player.lastUpgrade then
    for _, upg in ipairs(available) do
      if upg.key == player.lastUpgrade then
        upg.weight = 0.3
      end
    end
  end

  -- Select 3 random upgrades (or less if not enough available)
  local selected = {}
  local numToSelect = math.min(3, #available)

  for _ = 1, numToSelect do
    -- Calculate total weight
    local totalWeight = 0
    for _, upg in ipairs(available) do
      totalWeight = totalWeight + upg.weight
    end

    if totalWeight <= 0 then break end

    -- Weighted random selection
    local roll = math.random() * totalWeight
    local cumulative = 0
    local chosenIdx = 1

    for idx, upg in ipairs(available) do
      cumulative = cumulative + upg.weight
      if roll <= cumulative then
        chosenIdx = idx
        break
      end
    end

    table.insert(selected, available[chosenIdx])
    table.remove(available, chosenIdx)
  end

  return selected
end

local function applyUpgrade(key)
  if key == 'atk_speed' then
    player.fireDelay = math.max(0.05, player.fireDelay * 0.5)
    laser.interval = math.max(0.1, laser.interval * 0.5)
    pushFeedback('Upgrade: velocidade dobrada', {0.4, 0.9, 1})
  elseif key == 'laser' then
    player.laserLevel = (player.laserLevel or 0) + 1
    player.laserLifesteal = (player.laserLifesteal or 0) + 0.5  -- +0.5 lifesteal por nível
    if player.laserLevel == 1 then
      player.hasLaser = true
      laser.active = false
      laser.timer = laser.interval
      pushFeedback('Laser ativo! +0.5 roubo de vida', {0.8, 0.95, 1})
    elseif player.laserLevel >= 2 then
      pushFeedback('Laser Nv.2: área + 1.0 roubo de vida!', {1, 0.6, 0.9})
    end
  elseif key == 'damage' then
    player.bulletDamage = player.bulletDamage + 10
    pushFeedback('Upgrade: +10 de dano por acerto', {1, 0.8, 0.4})
  elseif key == 'scatter' then
    player.scatterLevel = (player.scatterLevel or 0) + 1
    player.hasScatter = true
    if player.scatterLevel == 1 then
      pushFeedback('Upgrade: tiro espalhado ativo!', {0.9, 1, 0.5})
    elseif player.scatterLevel >= 2 then
      pushFeedback('Scatter Nv.2: 6 projéteis!', {0.7, 1, 0.3})
    end
  end
  player.lastUpgrade = key
  playSound('upgrade')
end

function love.update(dt)
  -- Não atualiza nada se pausado
  if paused then return end

  updateFeedback(dt)
  updateLaserHits(dt)
  updateAreaHits(dt)
  if state == 'title' then return end
  if state == 'gameover' then return end
  if state == 'victory' then return end

  if state == 'play' then
    if not waveActive then startWave() end

    -- Update boss se ativo
    if bossActive then
      updateBoss(dt)
    end

    -- spawns cronometrados (não na boss wave)
    if wave ~= 21 and toSpawn > 0 then
      spawnTimer = spawnTimer - dt
      if spawnTimer <= 0 then
        spawnEnemy()
        toSpawn = toSpawn - 1
        spawnTimer = spawnInterval
      end
    end

    handleInput(dt)

    -- atualizar balas
    for i = #bullets, 1, -1 do
      local b = bullets[i]
      b:update(dt)
      if b.dead then table.remove(bullets, i) end
    end

    -- Colisão balas com boss
    if boss then
      for bi = #bullets, 1, -1 do
        local b = bullets[bi]
        local dx, dy = boss.x - b.x, boss.y - b.y
        local dist2 = dx*dx + dy*dy
        local rr = (boss.r + b.r)
        if dist2 <= rr*rr then
          local bossDied = hitBoss(b.damage)
          playSound('bossHit')
          addLaserHit(boss.x, boss.y)
          b.dead = true
          if bossDied then
            pushFeedback('BOSS DERROTADO!', {1, 0.8, 0.2})
          end
        end
      end
    end

    -- atualizar inimigos e colisões
    for ei = #enemies, 1, -1 do
      local e = enemies[ei]
      local prevState = e.state
      e:update(dt, player.x, player.y)
      if e.kind == 'charger' and prevState ~= 'dash' and e.state == 'dash' then
        playSound('charger_dash')
      end
      -- colisão com player
      local dx, dy = e.x - player.x, e.y - player.y
      local dist2 = dx*dx + dy*dy
      local rr = (e.r + player.r)
      if dist2 <= rr*rr then
        player.hp = player.hp - 15 * dt
        if player.hp <= 0 then
          player.hp = 0
          state = 'gameover'
        end
      end
      -- colisões com balas
      for bi = #bullets, 1, -1 do
        local b = bullets[bi]
        local dx2, dy2 = e.x - b.x, e.y - b.y
        local dist2b = dx2*dx2 + dy2*dy2
        local rr2 = (e.r + b.r)
        if dist2b <= rr2*rr2 then
          local died = e:hit(b.damage)
          playSound('hit')
          if died then
            playSound('enemyDie')
            b.dead = true
            table.remove(enemies, ei)
            break
          end
          addLaserHit(e.x, e.y)
          b.dead = true
        end
      end
    end

    if allEnemiesDefeated() then
      endWave()
    end

  elseif state == 'question' then
    -- lógica de resposta ocorre no mousepressed
  elseif state == 'upgrade' then
    -- escolha no mousepressed
  end
end

function love.keypressed(key)
  -- Pause com Enter (exceto no menu e telas finais)
  if key == 'return' or key == 'escape' then
    if paused then
      -- Despausar: volta música apropriada, para música do menu
      paused = false
      if menuMusic then menuMusic:stop() end
      -- Retoma música correta (boss ou normal)
      if wave == 21 and bossActive then
        if bossMusic then bossMusic:play() end
      else
        if bgMusic then bgMusic:play() end
      end
      return
    elseif state == 'play' or state == 'question' then
      -- Pausar: para todas as músicas, toca música do menu
      paused = true
      pausedFromState = state
      if bgMusic then bgMusic:pause() end
      if bossMusic then bossMusic:pause() end
      if menuMusic then menuMusic:play() end
      return
    end
  end

  -- Se estiver pausado, ignora outras teclas
  if paused then return end

  if state == 'title' then
    if key == 'escape' and showHowTo then
      showHowTo = false
      return
    elseif key == 'space' then
      showHowTo = false
      -- Para música do menu, inicia música do jogo
      if menuMusic then menuMusic:stop() end
      if bgMusic then bgMusic:play() end
      resetGame()
      return
    end
  end
  if key == 'r' and (state == 'gameover' or state == 'victory') then
    resetGame()
  elseif key == 'c' and state ~= 'title' and state ~= 'upgrade' then
    cheatJumpToQuestion()
  elseif key == 'b' and state == 'play' then
    cheatJumpToBoss()
  end
end

function love.mousepressed(mx, my, button)
  if button ~= 1 then return end
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  if state == 'title' then
    if showHowTo then
      local layout = getHowToLayout()
      local box = layout.box
      local close = layout.close
      if circleRectCollision(mx, my, 1, close.x, close.y, close.w, close.h) then
        showHowTo = false
        return
      end
      if not circleRectCollision(mx, my, 1, box.x, box.y, box.w, box.h) then
        showHowTo = false
      end
      return
    else
      local buttons = getTitleButtons()
      if circleRectCollision(mx, my, 1, buttons.play.x, buttons.play.y, buttons.play.w, buttons.play.h) then
        showHowTo = false
        -- Para música do menu, inicia música do jogo
        if menuMusic then menuMusic:stop() end
        if bgMusic then bgMusic:play() end
        resetGame()
        return
      elseif circleRectCollision(mx, my, 1, buttons.howto.x, buttons.howto.y, buttons.howto.w, buttons.howto.h) then
        showHowTo = true
        return
      end
    end
  end
  -- clique no botão de cheat (disponível fora do estado 'upgrade')
  cheatBtn.x, cheatBtn.y = w - cheatBtn.w - 12, 10
  if state ~= 'upgrade' then
    if circleRectCollision(mx, my, 1, cheatBtn.x, cheatBtn.y, cheatBtn.w, cheatBtn.h) then
      cheatJumpToQuestion()
      return
    end
  end
  if state == 'question' and question then
    -- Match the new question screen layout
    local boxW, boxH = 720, 480
    local bx, by = (w - boxW) / 2, (h - boxH) / 2
    local questionY = by + 80
    local questionPadding = 50
    local _, wrappedText = questionFont:getWrap(question.text, boxW - questionPadding * 2)
    local questionTextHeight = #wrappedText * questionFont:getHeight() * 1.2

    local optW, optH = 620, 60
    local optX = (w - optW) / 2
    local optStartY = questionY + math.max(questionTextHeight + 25, 60)
    local optGap = 10

    for i = 1, 3 do
      local optY = optStartY + (i - 1) * (optH + optGap)
      if circleRectCollision(mx, my, 1, optX, optY, optW, optH) then
        local correct = (i == question.correct)
        lastAnswerCorrect = correct
        if correct then
          -- prepara 3 escolhas de upgrade aleatórias
          currentUpgradeChoices = generateUpgradeChoices()
          state = 'upgrade'
          pushFeedback('Acertou! Escolha um upgrade', {0.4, 0.95, 0.6})
          playSound('correct')
        else
          -- penalidade de dificuldade
          difficulty = difficulty * 1.2
          pushFeedback('Errou! Dificuldade aumentou', {0.95, 0.5, 0.4})
          playSound('wrong')
          state = 'play'
        end
        question = nil
        return
      end
    end
  elseif state == 'upgrade' then
    local cardW, cardH = 200, 140
    local gap = 24
    local opts = currentUpgradeChoices or upgradeChoices
    local numCards = #opts
    local totalW = cardW * numCards + gap * (numCards - 1)
    local x0 = (w - totalW) / 2
    local y0 = h/2 - cardH/2 + 20
    for i, choice in ipairs(opts) do
      local cx = x0 + (i-1) * (cardW + gap)
      if circleRectCollision(mx, my, 1, cx, y0, cardW, cardH) then
        applyUpgrade(choice.key)
        playSound('upgrade')
        state = 'play'
        currentUpgradeChoices = nil
        return
      end
    end
  end
end

local function drawHowToOverlay()
  local layout = getHowToLayout()
  local box = layout.box
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setColor(0.08, 0.12, 0.2, 0.97)
  love.graphics.rectangle('fill', box.x, box.y, box.w, box.h, 18, 18)
  love.graphics.setColor(0.25, 0.55, 0.85)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', box.x, box.y, box.w, box.h, 18, 18)
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.9, 0.95, 1)
  love.graphics.printf('Como jogar', box.x, box.y + 18, box.w, 'center')

  local instructions = {
    'Movimente-se com W/A/S/D e mantenha distância.',
    'Atire segurando botão esquerdo do mouse ou Espaço.',
    'A cada 2 waves surge uma pergunta: acerte = upgrade!',
    'Desbloqueie laser, scatter e aumente dano/velocidade.',
    'Objetivo: sobreviver e aprender cibersegurança.'
  }
  love.graphics.setFont(hudFont)
  love.graphics.setColor(0.85, 0.92, 1)
  local startY = box.y + 60
  local lineHeight = 32
  for i, text in ipairs(instructions) do
    love.graphics.printf('• ' .. text, box.x + 24, startY + (i-1) * lineHeight, box.w - 48, 'left')
  end

  local close = layout.close
  drawButton(close.x, close.y, close.w, close.h, 'Entendi (Esc)')
end

local function drawTitle()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local time = love.timer.getTime()

  -- Background com gradiente cyberpunk
  love.graphics.setColor(0.02, 0.03, 0.08)
  love.graphics.rectangle('fill', 0, 0, w, h)

  -- Grid hexagonal de fundo (sutil)
  love.graphics.setColor(0.1, 0.15, 0.25, 0.15)
  local hexSize = 40
  for row = -1, math.ceil(h / (hexSize * 1.5)) + 1 do
    for col = -1, math.ceil(w / (hexSize * 2)) + 1 do
      local offsetX = (row % 2) * hexSize
      local cx = col * hexSize * 2 + offsetX
      local cy = row * hexSize * 1.5
      love.graphics.setLineWidth(1)
      local hexVerts = {}
      for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 2
        table.insert(hexVerts, cx + math.cos(angle) * hexSize * 0.5)
        table.insert(hexVerts, cy + math.sin(angle) * hexSize * 0.5)
      end
      love.graphics.polygon('line', hexVerts)
    end
  end

  -- Scanlines (efeito retro)
  love.graphics.setColor(0, 0, 0, 0.03)
  for i = 0, h, 3 do
    love.graphics.line(0, i, w, i)
  end

  -- Partículas flutuantes (dados digitais)
  love.graphics.setFont(love.graphics.newFont(10))
  for i = 1, 30 do
    local px = (math.sin(time * 0.3 + i * 0.7) * 0.5 + 0.5) * w
    local py = ((time * 15 + i * 40) % (h + 100)) - 50
    local alpha = math.sin(time * 2 + i) * 0.2 + 0.3

    if i % 3 == 0 then
      love.graphics.setColor(0.2, 0.8, 0.4, alpha)  -- Verde
    elseif i % 3 == 1 then
      love.graphics.setColor(0.4, 0.6, 1, alpha)  -- Azul
    else
      love.graphics.setColor(0.8, 0.4, 1, alpha)  -- Roxo
    end
    love.graphics.print(i % 2 == 0 and '1' or '0', px, py)
  end

  -- Logo principal com efeito de brilho
  local titleY = h * 0.18

  -- Glow do título
  love.graphics.setFont(bigTitleFont)
  local titleText = 'CYBERSAFE ROGUE'
  local titleW = bigTitleFont:getWidth(titleText)
  local titleX = (w - titleW) / 2

  -- Múltiplas camadas de glow
  love.graphics.setColor(0.3, 0.8, 1, 0.15)
  love.graphics.printf(titleText, -4, titleY - 2, w, 'center')
  love.graphics.printf(titleText, 4, titleY + 2, w, 'center')
  love.graphics.setColor(0.5, 0.3, 0.9, 0.2)
  love.graphics.printf(titleText, -2, titleY, w, 'center')
  love.graphics.printf(titleText, 2, titleY, w, 'center')

  -- Título principal com gradiente simulado (ciano para roxo)
  local pulse = math.sin(time * 2) * 0.1 + 0.9
  love.graphics.setColor(0.4 * pulse, 0.9 * pulse, 1 * pulse)
  love.graphics.printf(titleText, 0, titleY, w, 'center')

  -- Linha decorativa abaixo do título
  local lineY = titleY + 50
  local lineW = 300
  love.graphics.setColor(0.4, 0.8, 1, 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.line(w/2 - lineW/2, lineY, w/2 + lineW/2, lineY)
  -- Pontos nas extremidades
  love.graphics.setColor(0.5, 0.9, 1)
  love.graphics.circle('fill', w/2 - lineW/2, lineY, 4)
  love.graphics.circle('fill', w/2 + lineW/2, lineY, 4)
  -- Ponto central pulsante
  local centerPulse = math.sin(time * 4) * 3 + 6
  love.graphics.setColor(0.8, 0.4, 1, 0.8)
  love.graphics.circle('fill', w/2, lineY, centerPulse)

  -- Subtítulo
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.6, 0.8, 1, 0.9)
  love.graphics.printf('Roguelike educativo com perguntas de cibersegurança', 0, lineY + 20, w, 'center')

  -- Ícones decorativos (escudo, cadeado, etc)
  local iconsY = lineY + 55
  love.graphics.setColor(0.3, 0.7, 0.5, 0.6)
  -- Escudo esquerdo
  love.graphics.polygon('fill', w/2 - 120, iconsY, w/2 - 110, iconsY - 10, w/2 - 100, iconsY, w/2 - 110, iconsY + 15)
  -- Cadeado direito
  love.graphics.setColor(0.7, 0.5, 0.3, 0.6)
  love.graphics.rectangle('fill', w/2 + 100, iconsY - 5, 20, 15, 2, 2)
  love.graphics.arc('line', w/2 + 110, iconsY - 5, 7, math.pi, 0)

  -- Dica de controles
  love.graphics.setFont(hudFont)
  love.graphics.setColor(0.5, 0.6, 0.8, 0.7)
  love.graphics.printf('Clique em "Como jogar" para ver os controles antes de iniciar', 0, lineY + 85, w, 'center')

  -- Botões estilizados
  local buttons = getTitleButtons()

  -- Botão Começar (destaque especial)
  local playBtn = buttons.play

  -- Glow do botão play
  love.graphics.setColor(0.2, 0.6, 0.4, 0.3)
  love.graphics.rectangle('fill', playBtn.x - 5, playBtn.y - 5, playBtn.w + 10, playBtn.h + 10, 12, 12)

  -- Botão play com borda animada
  love.graphics.setColor(0.05, 0.15, 0.1, 0.95)
  love.graphics.rectangle('fill', playBtn.x, playBtn.y, playBtn.w, playBtn.h, 8, 8)
  local borderPulse = math.sin(time * 3) * 0.3 + 0.7
  love.graphics.setColor(0.3, 0.9, 0.5, borderPulse)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', playBtn.x, playBtn.y, playBtn.w, playBtn.h, 8, 8)
  love.graphics.setColor(0.4, 1, 0.6)
  love.graphics.setFont(titleFont)
  love.graphics.printf('▶ Começar partida', playBtn.x, playBtn.y + (playBtn.h - titleFont:getHeight()) / 2, playBtn.w, 'center')

  -- Botão Como Jogar
  local howBtn = buttons.howto
  love.graphics.setColor(0.08, 0.1, 0.18, 0.95)
  love.graphics.rectangle('fill', howBtn.x, howBtn.y, howBtn.w, howBtn.h, 8, 8)
  love.graphics.setColor(0.4, 0.6, 0.9, 0.7)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', howBtn.x, howBtn.y, howBtn.w, howBtn.h, 8, 8)
  love.graphics.setColor(0.6, 0.8, 1)
  love.graphics.setFont(hudFont)
  love.graphics.printf('? Como jogar', howBtn.x, howBtn.y + (howBtn.h - hudFont:getHeight()) / 2, howBtn.w, 'center')

  -- Versão/créditos no canto
  love.graphics.setFont(smallFont)
  love.graphics.setColor(0.4, 0.5, 0.6, 0.5)
  love.graphics.print('v1.0 - Projeto Educativo', 10, h - 25)

  if showHowTo then
    drawHowToOverlay()
  end
end

local function drawHUD()
  local w = love.graphics.getWidth()

  -- Left panel - Stats
  Theme.drawHUDPanel(10, 10, 220, 105)

  -- Wave indicator (grande e destacado)
  love.graphics.setFont(smallFont)
  love.graphics.setColor(0.6, 0.5, 0.8)
  love.graphics.print('WAVE', 20, 16)
  love.graphics.setFont(bigTitleFont)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(tostring(wave), 65, 6)

  -- HP Bar com coração
  local hpBarX, hpBarY = 20, 48
  local hpBarW, hpBarH = 190, 16

  -- Desenha coração (ícone)
  local heartX, heartY = hpBarX + 6, hpBarY + hpBarH/2
  love.graphics.setColor(1, 0.3, 0.4)
  love.graphics.circle('fill', heartX - 3, heartY - 2, 5)
  love.graphics.circle('fill', heartX + 3, heartY - 2, 5)
  love.graphics.polygon('fill', heartX - 7, heartY, heartX + 7, heartY, heartX, heartY + 8)

  -- Barra de HP
  local barStartX = hpBarX + 22
  local barW = hpBarW - 22
  love.graphics.setColor(0.15, 0.1, 0.2, 0.9)
  love.graphics.rectangle('fill', barStartX, hpBarY, barW, hpBarH, 4, 4)

  -- HP fill com gradiente de cor
  local hpPct = player.hp / player.maxHp
  local hpColor
  if hpPct > 0.6 then
    hpColor = {0.3, 0.9, 0.5}
  elseif hpPct > 0.3 then
    hpColor = {1, 0.8, 0.2}
  else
    hpColor = {1, 0.3, 0.3}
  end
  love.graphics.setColor(hpColor[1], hpColor[2], hpColor[3])
  love.graphics.rectangle('fill', barStartX + 2, hpBarY + 2, (barW - 4) * hpPct, hpBarH - 4, 3, 3)

  -- Stats row (ATK e DMG)
  local statsY = 72

  -- Attack Speed com ícone de raio
  love.graphics.setColor(0.4, 0.8, 1)
  love.graphics.polygon('fill', 24, statsY, 30, statsY, 26, statsY + 6, 32, statsY + 6, 22, statsY + 14, 26, statsY + 8, 20, statsY + 8)
  love.graphics.setFont(smallFont)
  love.graphics.setColor(0.7, 0.85, 1)
  love.graphics.print(string.format('%.2fs', player.fireDelay), 36, statsY + 2)

  -- Damage com ícone de espada diagonal
  local dmgX = 95
  local swordY = statsY + 7
  -- Lâmina diagonal
  love.graphics.setColor(0.85, 0.85, 0.9)
  love.graphics.setLineWidth(3)
  love.graphics.line(dmgX - 6, swordY + 6, dmgX + 6, swordY - 6)
  -- Ponta da espada
  love.graphics.setColor(1, 1, 1)
  love.graphics.polygon('fill', dmgX + 5, swordY - 5, dmgX + 8, swordY - 4, dmgX + 6, swordY - 8)
  -- Guarda (crossguard)
  love.graphics.setColor(0.7, 0.5, 0.2)
  love.graphics.setLineWidth(2)
  love.graphics.line(dmgX - 3, swordY, dmgX + 1, swordY + 4)
  -- Punho
  love.graphics.setColor(0.5, 0.35, 0.15)
  love.graphics.setLineWidth(3)
  love.graphics.line(dmgX - 6, swordY + 6, dmgX - 9, swordY + 9)
  love.graphics.setLineWidth(1)
  -- Número de dano
  love.graphics.setFont(smallFont)
  love.graphics.setColor(1, 0.8, 0.5)
  love.graphics.print(string.format('%.0f', player.bulletDamage), dmgX + 12, statsY + 2)

  -- Upgrades section (mais claro e visível)
  local upgradesY = 90
  love.graphics.setFont(smallFont)

  local upX = 20

  -- Laser upgrade box
  if player.hasLaser then
    local lvl = player.laserLevel or 1
    -- Background box
    love.graphics.setColor(0.15, 0.25, 0.4, 0.9)
    love.graphics.rectangle('fill', upX, upgradesY - 2, 58, 18, 4, 4)
    -- Border
    love.graphics.setColor(0.3, 0.7, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', upX, upgradesY - 2, 58, 18, 4, 4)
    -- Laser beam icon
    love.graphics.setColor(0.4, 0.85, 1)
    love.graphics.rectangle('fill', upX + 4, upgradesY + 5, 18, 3)
    love.graphics.setColor(0.7, 0.95, 1, 0.7)
    love.graphics.rectangle('fill', upX + 2, upgradesY + 4, 22, 5)
    -- Text
    love.graphics.setColor(1, 1, 1)
    local laserTxt = lvl >= 2 and 'LV2' or 'LV1'
    love.graphics.print(laserTxt, upX + 28, upgradesY)
    upX = upX + 64
  end

  -- Scatter upgrade box
  if player.hasScatter then
    local lvl = player.scatterLevel or 1
    -- Background box
    love.graphics.setColor(0.3, 0.15, 0.35, 0.9)
    love.graphics.rectangle('fill', upX, upgradesY - 2, 58, 18, 4, 4)
    -- Border
    love.graphics.setColor(0.9, 0.5, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', upX, upgradesY - 2, 58, 18, 4, 4)
    -- Scatter icon (3 bullets spreading)
    love.graphics.setColor(1, 0.6, 0.9)
    love.graphics.circle('fill', upX + 6, upgradesY + 7, 3)
    love.graphics.circle('fill', upX + 14, upgradesY + 3, 3)
    love.graphics.circle('fill', upX + 14, upgradesY + 11, 3)
    -- Text
    love.graphics.setColor(1, 1, 1)
    local scatterTxt = lvl >= 2 and 'LV2' or 'LV1'
    love.graphics.print(scatterTxt, upX + 22, upgradesY)
    upX = upX + 64
  end

  -- Cheat button (top-right) - mais discreto
  cheatBtn.x, cheatBtn.y = w - cheatBtn.w - 12, 10
  love.graphics.setColor(0.08, 0.05, 0.12, 0.7)
  love.graphics.rectangle('fill', cheatBtn.x, cheatBtn.y, cheatBtn.w, cheatBtn.h, 6, 6)
  love.graphics.setColor(0.4, 0.3, 0.5, 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', cheatBtn.x, cheatBtn.y, cheatBtn.w, cheatBtn.h, 6, 6)
  love.graphics.setFont(smallFont)
  love.graphics.setColor(0.5, 0.4, 0.6)
  local label = 'Skip [C/B]'
  local tw = smallFont:getWidth(label)
  local th = smallFont:getHeight()
  love.graphics.print(label, cheatBtn.x + (cheatBtn.w - tw)/2, cheatBtn.y + (cheatBtn.h - th)/2)
end

local function drawLaserHits()
  for _, hit in ipairs(laserHits) do
    local alpha = math.max(0, hit.timer / hit.max)
    love.graphics.setColor(1, 0.8, 0.4, alpha)
    love.graphics.circle('fill', hit.x, hit.y, 8 * alpha)
    love.graphics.setColor(1, 1, 1, alpha * 0.6)
    love.graphics.circle('line', hit.x, hit.y, 12 * alpha)
  end
end

local function drawFeedback()
  if feedback.timer <= 0 or not feedback.text then return end
  love.graphics.setFont(titleFont)
  local alpha = math.min(1, feedback.timer / 1.5)
  love.graphics.setColor(feedback.color[1], feedback.color[2], feedback.color[3], alpha)
  love.graphics.printf(feedback.text, 0, 60, love.graphics.getWidth(), 'center')
  love.graphics.setFont(hudFont)
end

local function drawLaser()
  if not (laser.active and player.hasLaser) then return end

  local directions = getLaserDirections()
  local time = love.timer.getTime()

  -- Different color for laser level 2 (area damage)
  local coreColor, glowColor, particleColor
  if player.laserLevel >= 2 then
    coreColor = {1, 0.5, 0.8, 0.6}  -- Pink/magenta for area laser
    glowColor = {1, 0.7, 0.9, 0.25}
    particleColor = {1, 0.6, 0.9}
  else
    coreColor = {0.4, 0.9, 1, 0.5}  -- Cyan for normal laser
    glowColor = {0.8, 0.95, 1, 0.2}
    particleColor = {0.5, 1, 1}
  end

  for _, dir in ipairs(directions) do
    local x2 = player.x + dir.dx * laser.length
    local y2 = player.y + dir.dy * laser.length

    -- Efeito de pulsação no laser
    local pulse = math.sin(time * 20) * 0.15 + 1
    local laserWidth = laser.width * pulse

    -- Outer glow (mais amplo)
    love.graphics.setLineWidth(laserWidth * 2.5)
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * 0.3)
    love.graphics.line(player.x, player.y, x2, y2)

    -- Mid glow
    love.graphics.setLineWidth(laserWidth * 1.8)
    love.graphics.setColor(glowColor)
    love.graphics.line(player.x, player.y, x2, y2)

    -- Core beam
    love.graphics.setLineWidth(laserWidth)
    love.graphics.setColor(coreColor)
    love.graphics.line(player.x, player.y, x2, y2)

    -- Inner bright core
    love.graphics.setLineWidth(laserWidth * 0.4)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.line(player.x, player.y, x2, y2)

    -- Partículas ao longo do laser (energia fluindo)
    for i = 1, 12 do
      local t = ((i / 12) + time * 3) % 1  -- Movimento constante ao longo do laser
      local px = player.x + (x2 - player.x) * t
      local py = player.y + (y2 - player.y) * t

      -- Variação perpendicular ao laser
      local perpX = -dir.dy
      local perpY = dir.dx
      local offset = math.sin(time * 15 + i * 2) * 6
      px = px + perpX * offset
      py = py + perpY * offset

      local size = 2 + math.sin(time * 10 + i) * 1.5
      local alpha = 0.5 + math.sin(time * 8 + i * 0.5) * 0.3

      love.graphics.setColor(particleColor[1], particleColor[2], particleColor[3], alpha)
      love.graphics.circle('fill', px, py, size)
    end

    -- Efeito de impacto na origem (player)
    local originPulse = math.sin(time * 25) * 0.3 + 0.7
    love.graphics.setColor(particleColor[1], particleColor[2], particleColor[3], originPulse * 0.6)
    love.graphics.circle('fill', player.x + dir.dx * 15, player.y + dir.dy * 15, 8 * pulse)

    -- Círculos de energia na ponta
    local tipPulse = (time * 5) % 1
    for j = 0, 2 do
      local ringProgress = (tipPulse + j * 0.33) % 1
      local ringSize = 5 + ringProgress * 15
      local ringAlpha = (1 - ringProgress) * 0.4
      love.graphics.setColor(particleColor[1], particleColor[2], particleColor[3], ringAlpha)
      love.graphics.circle('line', x2, y2, ringSize)
    end
  end
  love.graphics.setLineWidth(1)
end

local function drawAreaHits()
  for _, hit in ipairs(areaHits) do
    local alpha = math.max(0, hit.timer / hit.max)
    -- Expanding ring effect
    local expandFactor = 1 + (1 - alpha) * 0.5
    love.graphics.setColor(1, 0.4, 0.7, alpha * 0.4)
    love.graphics.circle('fill', hit.x, hit.y, hit.radius * expandFactor)
    love.graphics.setColor(1, 0.6, 0.85, alpha * 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle('line', hit.x, hit.y, hit.radius * expandFactor)
  end
  love.graphics.setLineWidth(1)
end

local function drawBoss()
  if not boss then return end

  local w = love.graphics.getWidth()
  local time = love.timer.getTime()

  -- Desenha símbolo do Trojan com transformações baseadas na fase
  local bx, by = boss.x, boss.y
  local r = boss.r

  -- Shake durante charging (fase 2+)
  if boss.moveMode == 'charging' then
    bx = bx + math.sin(time * 50) * 5
    by = by + math.cos(time * 55) * 5
  end

  -- Aura pulsante - cor varia por fase
  local pulse = math.sin(time * 3) * 0.2 + 0.8
  local auraColor
  if boss.phase == 1 then
    auraColor = {0.8, 0.2, 0.3}
  elseif boss.phase == 2 then
    auraColor = {0.9, 0.4, 0.15}  -- Laranja (charger)
  else
    auraColor = {0.7, 0.2, 0.9}  -- Roxo (zigzag)
  end

  love.graphics.setColor(auraColor[1], auraColor[2], auraColor[3], 0.15 * pulse)
  love.graphics.circle('fill', bx, by, r + 20)
  love.graphics.setColor(auraColor[1], auraColor[2], auraColor[3], 0.1 * pulse)
  love.graphics.circle('fill', bx, by, r + 35)

  -- Corpo principal - muda forma por fase
  local vertices = {}
  if boss.phase == 1 then
    -- Fase 1: Hexágono (Trojan original)
    for i = 0, 5 do
      local angle = (i / 6) * math.pi * 2 - math.pi / 2
      table.insert(vertices, bx + math.cos(angle) * r)
      table.insert(vertices, by + math.sin(angle) * r)
    end
  elseif boss.phase == 2 then
    -- Fase 2: Hexágono mais agressivo (tipo charger)
    for i = 0, 5 do
      local angle = (i / 6) * math.pi * 2 - math.pi / 2
      local spiky = (i % 2 == 0) and 1.15 or 0.85  -- Pontas alternadas
      table.insert(vertices, bx + math.cos(angle) * r * spiky)
      table.insert(vertices, by + math.sin(angle) * r * spiky)
    end
  else
    -- Fase 3: Triângulos sobrepostos (tipo zigzag + charger)
    for i = 0, 5 do
      local angle = (i / 6) * math.pi * 2 - math.pi / 2 + time * 0.5
      local pulse3 = 1 + math.sin(time * 8 + i) * 0.1
      table.insert(vertices, bx + math.cos(angle) * r * pulse3)
      table.insert(vertices, by + math.sin(angle) * r * pulse3)
    end
  end

  -- Preenchimento com gradiente de cor baseado na fase
  local phaseColor
  if boss.phase == 1 then
    phaseColor = {0.6, 0.15, 0.2}  -- Vermelho escuro
  elseif boss.phase == 2 then
    phaseColor = {0.7, 0.35, 0.1}   -- Laranja (charger)
  else
    phaseColor = {0.55, 0.15, 0.7}   -- Roxo (zigzag)
  end
  love.graphics.setColor(phaseColor[1], phaseColor[2], phaseColor[3], 0.9)
  love.graphics.polygon('fill', vertices)

  -- Borda brilhante
  love.graphics.setColor(auraColor[1], auraColor[2], auraColor[3], 0.8)
  love.graphics.setLineWidth(3)
  love.graphics.polygon('line', vertices)

  -- Símbolo interno - muda por fase
  if boss.phase == 1 then
    -- Olhos normais
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.circle('fill', bx - 12, by - 8, 8)
    love.graphics.circle('fill', bx + 12, by - 8, 8)
    love.graphics.setColor(1, 0.3, 0.3, 0.9)
    love.graphics.circle('fill', bx - 12, by - 8, 4)
    love.graphics.circle('fill', bx + 12, by - 8, 4)
  elseif boss.phase == 2 then
    -- Olhos de charger (mais agressivos, brilho laranja)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.circle('fill', bx - 14, by - 8, 10)
    love.graphics.circle('fill', bx + 14, by - 8, 10)
    local eyePulse = math.sin(time * 8) * 0.3 + 0.7
    love.graphics.setColor(1, 0.5, 0.1, eyePulse)
    love.graphics.circle('fill', bx - 14, by - 8, 6)
    love.graphics.circle('fill', bx + 14, by - 8, 6)
    -- Trilha de fogo durante dash
    if boss.moveMode == 'dash' then
      for i = 1, 5 do
        local trailAlpha = (5 - i) / 5 * 0.6
        local trailX = bx - boss.dashVx * 0.02 * i
        local trailY = by - boss.dashVy * 0.02 * i
        love.graphics.setColor(1, 0.4, 0.1, trailAlpha)
        love.graphics.circle('fill', trailX, trailY, r * 0.8 - i * 3)
      end
    end
  else
    -- Fase 3: Olhos de glitch (roxo, piscando)
    local glitch = math.sin(time * 20) > 0 and 1 or 0.5
    love.graphics.setColor(0.1, 0, 0.15, 0.8)
    love.graphics.circle('fill', bx - 12, by - 6, 9)
    love.graphics.circle('fill', bx + 12, by - 6, 9)
    love.graphics.setColor(0.9, 0.4, 1, glitch)
    love.graphics.circle('fill', bx - 12, by - 6, 5)
    love.graphics.circle('fill', bx + 12, by - 6, 5)
    -- Efeito de glitch
    love.graphics.setColor(0.7, 0.3, 0.9, 0.4)
    local gOffset = math.sin(time * 30) * 6
    love.graphics.line(bx - r + gOffset, by, bx + r + gOffset, by - 3)
    love.graphics.line(bx - r - gOffset, by + 5, bx + r - gOffset, by + 2)
  end

  -- Boca estilizada
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle('fill', bx - 15, by + 10, 30, 8, 2, 2)
  local mouthColor = boss.phase == 3 and {0.8, 0.4, 1} or (boss.phase == 2 and {1, 0.5, 0.2} or {1, 0.3, 0.3})
  love.graphics.setColor(mouthColor[1], mouthColor[2], mouthColor[3], 0.5)
  for i = 0, 4 do
    love.graphics.rectangle('fill', bx - 12 + i * 6, by + 10, 4, 8)
  end

  -- Efeito de carga (fase 2+)
  if boss.moveMode == 'charging' then
    love.graphics.setColor(1, 0.6, 0.2, 0.7)
    love.graphics.setLineWidth(2)
    for i = 1, 8 do
      local angle = (i / 8) * math.pi * 2 + time * 10
      local rx = bx + math.cos(angle) * (r + 15)
      local ry = by + math.sin(angle) * (r + 15)
      love.graphics.line(bx + math.cos(angle) * r, by + math.sin(angle) * r, rx, ry)
    end
  end

  -- Desenha projéteis do boss
  for _, p in ipairs(bossProjectiles) do
    love.graphics.setColor(1, 0.3, 0.2, 0.9)
    love.graphics.circle('fill', p.x, p.y, p.r)
    love.graphics.setColor(1, 0.6, 0.4, 0.5)
    love.graphics.circle('fill', p.x, p.y, p.r * 0.6)
  end

  -- Barra de vida do boss no topo da tela
  local barW, barH = 400, 20
  local barX = (w - barW) / 2
  local barY = 15

  -- Background da barra
  love.graphics.setColor(0.1, 0.05, 0.1, 0.9)
  love.graphics.rectangle('fill', barX - 2, barY - 2, barW + 4, barH + 4, 6, 6)

  -- Borda - cor muda por fase
  love.graphics.setColor(auraColor[1], auraColor[2], auraColor[3])
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', barX - 2, barY - 2, barW + 4, barH + 4, 6, 6)

  -- Vida atual
  local hpRatio = boss.hp / boss.maxHp
  local hpColor = {phaseColor[1], phaseColor[2] + 0.2, phaseColor[3]}
  love.graphics.setColor(hpColor[1], hpColor[2], hpColor[3], 0.9)
  love.graphics.rectangle('fill', barX, barY, barW * hpRatio, barH, 4, 4)

  -- Nome do boss - muda por fase
  love.graphics.setFont(titleFont)
  love.graphics.setColor(auraColor[1], auraColor[2], auraColor[3])
  local bossName = 'TROJAN'
  if boss.phase == 2 then
    bossName = 'TROJAN CHARGER'
  elseif boss.phase == 3 then
    bossName = 'TROJAN GLITCH'
  end
  love.graphics.printf(bossName, 0, barY + barH + 5, w, 'center')

  -- Indicador de fase
  love.graphics.setFont(smallFont)
  love.graphics.setColor(1, 0.8, 0.7)
  love.graphics.printf('Fase ' .. boss.phase .. '/3', 0, barY + barH + 28, w, 'center')

  love.graphics.setLineWidth(1)
end

local function drawVictory()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  -- Background escuro
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.rectangle('fill', 0, 0, w, h)

  -- Confetti effect (partículas douradas)
  local time = love.timer.getTime()
  love.graphics.setColor(1, 0.85, 0.2, 0.6)
  for i = 1, 50 do
    local px = (math.sin(time * 0.5 + i * 0.7) + 1) * w / 2
    local py = (time * 30 + i * 50) % (h + 20) - 10
    local size = 3 + math.sin(i) * 2
    love.graphics.circle('fill', px, py, size)
  end

  -- Título de vitória
  love.graphics.setFont(bigTitleFont)
  love.graphics.setColor(1, 0.85, 0.2)
  love.graphics.printf('VITÓRIA!', 0, h * 0.25, w, 'center')

  -- Subtítulo
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.4, 1, 0.5)
  love.graphics.printf('Trojan Derrotado!', 0, h * 0.35, w, 'center')

  -- Mensagem educacional
  love.graphics.setFont(questionFont)
  love.graphics.setColor(0.9, 0.95, 1)
  love.graphics.printf(
    'Parabéns! Você demonstrou conhecimento em cibersegurança\ne derrotou a ameaça digital!',
    0, h * 0.45, w, 'center'
  )

  -- Estatísticas
  love.graphics.setFont(hudFont)
  love.graphics.setColor(0.7, 0.8, 0.9)
  love.graphics.printf('Waves completadas: 21', 0, h * 0.6, w, 'center')

  -- Instrução de reinício
  love.graphics.setColor(0.6, 0.7, 0.8)
  love.graphics.printf('Pressione R para jogar novamente', 0, h * 0.75, w, 'center')
end

local function drawPlay()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  -- Hexagonal background
  Theme.drawHexBackground(w, h)

  -- player
  player:draw()
  drawLaser()
  drawLaserHits()
  drawAreaHits()
  -- boss
  if bossActive then
    drawBoss()
  end
  -- enemies
  for _, e in ipairs(enemies) do e:draw() end
  -- bullets
  for _, b in ipairs(bullets) do b:draw() end
  drawHUD()
  drawFeedback()
end

local function drawQuestionOption(x, y, w, h, text, index)
  local time = love.timer.getTime()
  local hoverPulse = math.sin(time * 4 + index) * 0.1 + 0.9

  -- Glow de fundo cyberpunk
  love.graphics.setColor(0.4, 0.1, 0.6, 0.15 * hoverPulse)
  love.graphics.rectangle('fill', x - 4, y - 4, w + 8, h + 8, 16, 16)

  -- Background com gradiente escuro
  love.graphics.setColor(0.05, 0.02, 0.1, 0.95)
  love.graphics.rectangle('fill', x, y, w, h, 12, 12)

  -- Scanlines sutis
  love.graphics.setColor(0, 0, 0, 0.1)
  for i = 0, h, 4 do
    love.graphics.line(x + 5, y + i, x + w - 5, y + i)
  end

  -- Brilho no topo
  love.graphics.setColor(0.6, 0.3, 0.9, 0.08)
  love.graphics.rectangle('fill', x + 2, y + 2, w - 4, h * 0.35, 10, 10)

  -- Borda com gradiente neon
  love.graphics.setColor(0.5, 0.2, 0.8, 0.7 * hoverPulse)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', x, y, w, h, 12, 12)

  -- Cantos decorativos (estilo terminal)
  love.graphics.setColor(0.6, 0.4, 1, 0.6)
  love.graphics.setLineWidth(2)
  -- Canto superior esquerdo
  love.graphics.line(x + 2, y + 12, x + 2, y + 2)
  love.graphics.line(x + 2, y + 2, x + 12, y + 2)
  -- Canto inferior direito
  love.graphics.line(x + w - 2, y + h - 12, x + w - 2, y + h - 2)
  love.graphics.line(x + w - 2, y + h - 2, x + w - 12, y + h - 2)

  -- Badge hexagonal do número
  local badgeSize = 32
  local badgeX = x + 16
  local badgeY = y + (h - badgeSize) / 2

  -- Hexágono de fundo
  local hexVerts = {}
  local cx, cy = badgeX + badgeSize/2, badgeY + badgeSize/2
  for i = 0, 5 do
    local angle = (i / 6) * math.pi * 2 - math.pi / 2
    table.insert(hexVerts, cx + math.cos(angle) * badgeSize * 0.5)
    table.insert(hexVerts, cy + math.sin(angle) * badgeSize * 0.5)
  end
  love.graphics.setColor(0.3, 0.1, 0.5, 0.6)
  love.graphics.polygon('fill', hexVerts)
  love.graphics.setColor(0.6, 0.4, 1, 0.8)
  love.graphics.setLineWidth(1.5)
  love.graphics.polygon('line', hexVerts)

  -- Número
  love.graphics.setColor(0.9, 0.8, 1)
  love.graphics.setFont(questionFont)
  local numW = questionFont:getWidth(tostring(index))
  love.graphics.print(tostring(index), cx - numW/2, cy - 10)

  -- Texto da opção
  love.graphics.setFont(optionFont)
  love.graphics.setColor(0.85, 0.9, 1)
  local textX = badgeX + badgeSize + 18
  local textW = w - (textX - x) - 20
  local _, wrappedLines = optionFont:getWrap(text, textW)
  local lineHeight = optionFont:getHeight()
  local totalTextHeight = #wrappedLines * lineHeight
  local textY = y + (h - totalTextHeight) / 2
  love.graphics.printf(text, textX, textY, textW, 'left')

  -- Indicador lateral (barra de seleção)
  love.graphics.setColor(0.5, 0.3, 0.9, 0.4 + math.sin(time * 3 + index * 2) * 0.2)
  love.graphics.rectangle('fill', x + 3, y + 8, 3, h - 16, 2, 2)
end

local function drawQuestion()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local time = love.timer.getTime()

  -- Overlay escuro com efeito de vinheta
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle('fill', 0, 0, w, h)

  -- Container principal
  local boxW, boxH = 740, 500
  local bx, by = (w - boxW) / 2, (h - boxH) / 2

  -- Glow externo pulsante
  local glowPulse = math.sin(time * 2) * 0.1 + 0.9
  love.graphics.setColor(0.4, 0.2, 0.7, 0.2 * glowPulse)
  love.graphics.rectangle('fill', bx - 10, by - 10, boxW + 20, boxH + 20, 20, 20)
  love.graphics.setColor(0.5, 0.3, 0.8, 0.15 * glowPulse)
  love.graphics.rectangle('fill', bx - 5, by - 5, boxW + 10, boxH + 10, 18, 18)

  -- Fundo principal
  love.graphics.setColor(0.03, 0.02, 0.08, 0.98)
  love.graphics.rectangle('fill', bx, by, boxW, boxH, 16, 16)

  -- Grid de fundo (efeito matrix/tech)
  love.graphics.setColor(0.2, 0.1, 0.4, 0.05)
  for gx = bx, bx + boxW, 30 do
    love.graphics.line(gx, by, gx, by + boxH)
  end
  for gy = by, by + boxH, 30 do
    love.graphics.line(bx, gy, bx + boxW, gy)
  end

  -- Borda neon
  love.graphics.setColor(0.5, 0.3, 0.9, 0.8)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle('line', bx, by, boxW, boxH, 16, 16)

  -- Cantos decorativos estilo tech
  love.graphics.setColor(0.6, 0.4, 1, 0.9)
  love.graphics.setLineWidth(3)
  local cornerLen = 25
  -- Superior esquerdo
  love.graphics.line(bx, by + cornerLen, bx, by)
  love.graphics.line(bx, by, bx + cornerLen, by)
  -- Superior direito
  love.graphics.line(bx + boxW - cornerLen, by, bx + boxW, by)
  love.graphics.line(bx + boxW, by, bx + boxW, by + cornerLen)
  -- Inferior esquerdo
  love.graphics.line(bx, by + boxH - cornerLen, bx, by + boxH)
  love.graphics.line(bx, by + boxH, bx + cornerLen, by + boxH)
  -- Inferior direito
  love.graphics.line(bx + boxW - cornerLen, by + boxH, bx + boxW, by + boxH)
  love.graphics.line(bx + boxW, by + boxH, bx + boxW, by + boxH - cornerLen)

  -- Header bar com gradiente
  love.graphics.setColor(0.3, 0.15, 0.5, 0.4)
  love.graphics.rectangle('fill', bx + 4, by + 4, boxW - 8, 55, 14, 14)

  -- Ícone de escudo/segurança
  local iconX = bx + 25
  local iconY = by + 18
  love.graphics.setColor(0.5, 0.8, 1, 0.8)
  love.graphics.polygon('fill',
    iconX, iconY,
    iconX - 12, iconY + 8,
    iconX - 10, iconY + 22,
    iconX, iconY + 28,
    iconX + 10, iconY + 22,
    iconX + 12, iconY + 8
  )
  love.graphics.setColor(0.2, 0.4, 0.6, 0.9)
  love.graphics.polygon('fill',
    iconX, iconY + 5,
    iconX - 7, iconY + 10,
    iconX - 6, iconY + 18,
    iconX, iconY + 22,
    iconX + 6, iconY + 18,
    iconX + 7, iconY + 10
  )

  -- Título
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.7, 0.85, 1)
  love.graphics.printf('PERGUNTA DE CIBERSEGURANÇA', bx + 45, by + 18, boxW - 90, 'center')

  -- Linha divisória animada
  local lineY = by + 65
  love.graphics.setColor(0.4, 0.3, 0.8, 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.line(bx + 30, lineY, bx + boxW - 30, lineY)
  -- Ponto animado na linha
  local dotX = bx + 30 + ((time * 50) % (boxW - 60))
  love.graphics.setColor(0.6, 0.5, 1, 0.8)
  love.graphics.circle('fill', dotX, lineY, 3)

  -- Área da pergunta
  love.graphics.setFont(questionFont)
  love.graphics.setColor(0.9, 0.95, 1)
  local questionY = by + 85
  local questionPadding = 45
  love.graphics.printf(question.text, bx + questionPadding, questionY, boxW - questionPadding * 2, 'left')

  -- Calcula altura do texto para posicionar opções
  local _, wrappedText = questionFont:getWrap(question.text, boxW - questionPadding * 2)
  local questionTextHeight = #wrappedText * questionFont:getHeight() * 1.2

  -- Opções
  local optW, optH = 640, 65
  local optX = (w - optW) / 2
  local optStartY = questionY + math.max(questionTextHeight + 30, 70)
  local optGap = 12

  for i = 1, 3 do
    local optY = optStartY + (i - 1) * (optH + optGap)
    drawQuestionOption(optX, optY, optW, optH, question.options[i], i)
  end

  -- Dica no rodapé
  love.graphics.setFont(smallFont)
  love.graphics.setColor(0.5, 0.6, 0.8, 0.7)
  love.graphics.printf('[ Clique na alternativa correta ]', bx, by + boxH - 28, boxW, 'center')

  love.graphics.setLineWidth(1)
end

local function drawUpgrade()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  -- Overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle('fill', 0, 0, w, h)

  -- Title with glow effect
  love.graphics.setFont(bigTitleFont)
  love.graphics.setColor(Theme.colors.tertiary[1], Theme.colors.tertiary[2], Theme.colors.tertiary[3], 0.3)
  love.graphics.printf('Acertou!', 2, 52, w, 'center')
  love.graphics.setColor(Theme.colors.tertiary)
  love.graphics.printf('Acertou!', 0, 50, w, 'center')

  love.graphics.setFont(titleFont)
  love.graphics.setColor(Theme.colors.textNormal)
  love.graphics.printf('Escolha um upgrade', 0, 95, w, 'center')

  local cardW, cardH = 200, 140
  local gap = 24
  local opts = currentUpgradeChoices or upgradeChoices
  local numCards = #opts

  -- Calculate centered position based on number of cards
  local totalW = cardW * numCards + gap * (numCards - 1)
  local x0 = (w - totalW) / 2
  local y0 = h/2 - cardH/2 + 20

  for i, choice in ipairs(opts) do
    local cardX = x0 + (i-1) * (cardW + gap)

    -- Card glow
    local glowColor = Theme.colors.secondary
    if choice.key == 'laser' then
      glowColor = Theme.colors.secondary
    elseif choice.key == 'scatter' then
      glowColor = Theme.colors.tertiary
    elseif choice.key == 'damage' then
      glowColor = Theme.colors.primary
    elseif choice.key == 'atk_speed' then
      glowColor = {1, 0.8, 0.2}
    end

    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.15)
    love.graphics.rectangle('fill', cardX - 4, y0 - 4, cardW + 8, cardH + 8, 18, 18)

    -- Card background
    love.graphics.setColor(0.08, 0.04, 0.15, 0.95)
    love.graphics.rectangle('fill', cardX, y0, cardW, cardH, 14, 14)

    -- Top accent
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.25)
    love.graphics.rectangle('fill', cardX, y0, cardW, 40, 14, 14)
    love.graphics.setColor(0.08, 0.04, 0.15, 0.6)
    love.graphics.rectangle('fill', cardX + 3, y0 + 6, cardW - 6, 28, 10, 10)

    -- Border
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', cardX, y0, cardW, cardH, 14, 14)

    -- Icon circle
    local iconX = cardX + 18
    local iconY = y0 + 20
    love.graphics.setColor(glowColor)
    love.graphics.circle('fill', iconX, iconY, 10)
    love.graphics.setColor(0.08, 0.04, 0.15)
    love.graphics.circle('fill', iconX, iconY, 5)

    -- Title
    love.graphics.setFont(hudFont)
    love.graphics.setColor(Theme.colors.textBright)
    love.graphics.print(choice.label, iconX + 18, y0 + 12)

    -- Description
    local text
    if choice.key == 'atk_speed' then
      text = 'Dobra a frequência dos disparos'
    elseif choice.key == 'laser' then
      if player.laserLevel >= 1 then
        text = 'Nv.2: Acertos causam explosão em área!'
      else
        text = 'Feixe contínuo que atravessa inimigos'
      end
    elseif choice.key == 'scatter' then
      if (player.scatterLevel or 0) >= 1 then
        text = 'Nv.2: Dispara 6 projéteis em cone!'
      else
        text = 'Dispara 3 projéteis em cone'
      end
    else
      text = '+3 de dano por acerto'
    end

    love.graphics.setFont(smallFont)
    love.graphics.setColor(Theme.colors.textNormal)
    love.graphics.printf(text, cardX + 14, y0 + 50, cardW - 28, 'left')
  end
end

local function drawGameOver()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle('fill', 0, 0, w, h)

  -- Game Over text with glow
  love.graphics.setFont(bigTitleFont)
  love.graphics.setColor(Theme.colors.damage[1], Theme.colors.damage[2], Theme.colors.damage[3], 0.3)
  love.graphics.printf('Game Over', 2, h/2 - 58, w, 'center')
  love.graphics.setColor(Theme.colors.damage)
  love.graphics.printf('Game Over', 0, h/2 - 60, w, 'center')

  love.graphics.setFont(hudFont)
  love.graphics.setColor(Theme.colors.textNormal)
  love.graphics.printf('Você chegou até a Wave ' .. wave, 0, h/2 - 10, w, 'center')

  love.graphics.setColor(Theme.colors.textMuted)
  love.graphics.printf('Pressione R para reiniciar', 0, h/2 + 20, w, 'center')
end

function love.draw()
  if state == 'title' then
    drawTitle()
  elseif state == 'play' then
    drawPlay()
  elseif state == 'question' then
    drawPlay()
    drawQuestion()
  elseif state == 'upgrade' then
    drawPlay()
    drawUpgrade()
  elseif state == 'gameover' then
    drawPlay()
    drawGameOver()
  elseif state == 'victory' then
    drawPlay()
    drawVictory()
  end

  -- Overlay de pause
  if paused then
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    -- Fundo escurecido
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Caixa central
    local boxW, boxH = 300, 180
    local boxX, boxY = (w - boxW) / 2, (h - boxH) / 2

    love.graphics.setColor(0.08, 0.1, 0.18, 0.95)
    love.graphics.rectangle('fill', boxX, boxY, boxW, boxH, 12, 12)
    love.graphics.setColor(0.4, 0.6, 0.9, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', boxX, boxY, boxW, boxH, 12, 12)

    -- Texto PAUSADO
    love.graphics.setFont(bigTitleFont)
    love.graphics.setColor(0.5, 0.8, 1)
    love.graphics.printf('PAUSADO', boxX, boxY + 40, boxW, 'center')

    -- Instruções
    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.7, 0.8, 0.9)
    love.graphics.printf('Pressione ENTER ou ESC\npara continuar', boxX, boxY + 100, boxW, 'center')

    love.graphics.setLineWidth(1)
  end
end
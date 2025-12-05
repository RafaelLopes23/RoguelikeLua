# Cybersafe Rogue - Roguelike Educativo

Roguelike 2D educativo desenvolvido em LÖVE (Lua) com foco em cibersegurança. A cada 2 waves, responda perguntas sobre segurança digital para ganhar upgrades. Sobreviva às 20 waves e derrote o boss final: o Trojan!

## 🎮 Como Rodar

```bash
love .
```

### Instalação do LÖVE (Ubuntu/Debian):

```bash
sudo add-apt-repository -y ppa:love2d/love-stable
sudo apt update
sudo apt install -y love
```

## 🕹️ Controles

| Ação | Tecla |
|------|-------|
| Movimento | W, A, S, D |
| Atirar | Mouse esquerdo (segurar) ou Espaço |
| Pausar | Enter ou ESC |
| Reiniciar (Game Over/Vitória) | R |
| Cheat: Pular para pergunta | C |
| Cheat: Pular para Boss | B |

## ⚔️ Mecânica de Jogo

### Inimigos
- **Worm (Verde)**: Inimigo básico que persegue o jogador
- **Charger/Trojan (Laranja)**: Treme e dá dash em alta velocidade (aparece na wave 2+)
- **Glitch (Roxo)**: Movimento em zigzag, mais rápido mas com menos vida (aparece na wave 3+)

### Sistema de Perguntas
- A cada 2 waves surge uma pergunta de cibersegurança (3 opções)
- **20 perguntas** organizadas por dificuldade:
  - Waves 1-6: Perguntas fáceis (conceitos básicos)
  - Waves 7-14: Perguntas médias (conhecimento intermediário)
  - Waves 15-20: Perguntas difíceis (conceitos avançados)
- **Acerto**: Escolha um upgrade
- **Erro**: Dificuldade aumenta (mais inimigos, mais fortes)

### Upgrades Disponíveis
| Upgrade | Efeito |
|---------|--------|
| Velocidade de Ataque | Dobra a frequência de disparo |
| Laser Perfurante | Feixe contínuo que atravessa inimigos + 0.1 roubo de vida por hit |
| Laser Nv.2 | Dano em área ao acertar + 0.3 roubo de vida total |
| Dano Aumentado | +10 de dano por acerto |
| Tiro Espalhado | Dispara múltiplos projéteis (3 no Nv.1, 6 no Nv.2) |

### Boss: Trojan (Wave 21)
O boss final possui 5000 HP e 3 fases distintas:
- **Fase 1** (100%-60% HP): Movimento horizontal, projéteis causam 20 de dano
- **Fase 2** (60%-30% HP): Modo Charger com dash attacks, projéteis causam 30 de dano
- **Fase 3** (30%-0% HP): Modo Glitch com zigzag intenso, projéteis causam 40 de dano

**Cuidado com o Charge Attack!** Se o boss acertar você durante o dash, causa 50% da sua vida máxima!

O boss também invoca minions durante a luta!

## 🎵 Áudio

O jogo possui trilha sonora, e efeitos sonoros procedurais para tiros, hits, upgrades e ações.

## 🎨 Visual

- Tema cyberpunk com cores neon (ciano, roxo, magenta)
- Sprites procedurais para todos os personagens
- Efeitos visuais: partículas, glow, scanlines
- Interface estilizada com elementos hexagonais

## 📁 Estrutura do Projeto

```
├── main.lua        # Lógica principal do jogo
├── player.lua      # Classe do jogador com sprite cybernético
├── enemy.lua       # Inimigos (Worm, Charger, Zigzag)
├── bullet.lua      # Sistema de projéteis
├── questions.lua   # Pool de 20 perguntas de cibersegurança
├── theme.lua       # Paleta de cores e helpers visuais
├── main theme.mp3  # Música principal
├── menu pause.mp3  # Música do menu/pause
├── boss.mp3        # Música do boss
└── conf.lua        # Configurações da janela
```

## 📝 Créditos

Projeto educativo desenvolvido para ensinar conceitos de cibersegurança de forma interativa e divertida.

## 🔄 Versão

**v1.0** - Release completa com:
- 20 waves + boss fight
- 20 perguntas de cibersegurança
- 4 tipos de upgrade
- 3 tipos de inimigos
- Sistema de música e efeitos sonoros
- Interface cyberpunk completa

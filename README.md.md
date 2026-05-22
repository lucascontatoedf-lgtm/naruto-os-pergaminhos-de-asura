# Naruto: Os Pergaminhos de Asura

MVP Vertical Slice de um jogo 2D de plataforma/ação inspirado no universo Naruto, desenvolvido em **Godot 4** (GDScript). Projeto pessoal de portfólio explorando *game feel* apurado em platformers 2D.

> **Status atual**: Core Gameplay da Semana 1 finalizado — movimentação, máquina de estados, double jump, chakra, HUD de debug e kill zone. Próxima etapa: Level Design (Semana 2).

---

## Demo

Vídeos de gameplay, screenshots e GIFs em [`documentation/`](documentation/).

---

## O que entra no MVP

Escopo fixo de **3 semanas**:

| Semana | Tema | Status |
|---|---|---|
| 1 | Core Gameplay — movimentação, câmera, colisão, chakra, HUD | finalizando |
| 2 | Level Design — Vila da Folha + Floresta da Névoa, NPCs, segredos | a iniciar |
| 3 | Boss (Zabuza, 2 fases) + Polish — áudio, partículas, otimização | a iniciar |

Sem multiplayer, sem segundo personagem jogável, sem mapas extras. Vertical slice curto e focado.

---

## Features da Semana 1

### Movimentação responsiva
- Aceleração e fricção separadas para chão e ar
- Sem deslizamento perceptível, resposta imediata ao input
- Análogo + DPad + teclado simultâneos via Godot Input Map (zero hardcode de tecla)

### Pulo com 4 camadas de *game feel*
- **Coyote Time** (0.12s) — permite pular logo após sair de uma plataforma
- **Input Buffer** (0.15s) — registra o pulo pressionado antes de tocar o chão
- **Variable Jump Height** — soltar o botão cedo corta a velocidade ascendente
- **Double Jump** — segundo pulo no ar (`max_jumps` configurável, default 2; signal `jumped(jump_number)` permite VFX diferenciado por crédito)

### Máquina de estados embutida
FSM enum-based com 8 estados:

```
IDLE → MOVE → JUMP → FALL → CROUCH → ATTACK → SPECIAL → CHAKRA_CHARGE
```

Cada estado tem `_enter_state`, `_exit_state` e tick próprio. Signals plugáveis em UI, VFX e áudio: `state_changed`, `chakra_changed`, `jumped`, `landed`, `attack_started/ended`, `special_started/ended`, `facing_flipped`, `respawned`.

### Sistema de Chakra
- Barra 0–100, custo do Rasengan: 40
- Regen passiva 6/s · Recarga ativa segurando `chakra_charge`: 35/s
- Estado dedicado `CHAKRA_CHARGE` que trava `velocity.x` e libera interrupções via pulo

### Kill Zone + Respawn
- Verificação por frame: se `position.y > kill_zone_y` (default 1000), reset completo
- Reseta posição, velocidade, contador de pulos, timers (coyote/buffer/state), chakra
- Signal `respawned(at_position)` pra hooks de VFX/áudio
- `_spawn_position` capturado em `_ready` a partir da posição inicial na cena (level designer-friendly)

### Debug HUD
`CanvasLayer` no canto superior esquerdo mostrando, em tempo real:
- Estado atual da FSM (atualiza via `state_changed`)
- Chakra (valor + porcentagem, atualiza via `chakra_changed`)

Plugado por signals — zero polling, zero overhead.

---

## Controles oficiais

| Ação | Teclado | Gamepad (Xbox / PlayStation) |
|---|---|---|
| Mover | ← / → | Analógico esq. + DPad |
| Pular | ↑ | A / X |
| Agachar | ↓ | DPad ↓ |
| Ataque curto | H | X / □ |
| Ataque longo | J | Y / △ |
| Rasengan (Special) | L | B / ○ |
| Concentrar chakra | Shift Esq. | RT |

Tudo definido via Godot Input Map — rebinding suportado nativamente.

---

## Como rodar localmente

1. Baixe **Godot 4.6+** em [godotengine.org](https://godotengine.org)
2. Clone este repositório
3. No Godot: **Import** → selecione `project.godot`
4. **F5** — abre na `test_stage.tscn` (3 plataformas de altura progressiva para testar pulo simples vs. double jump)

---

## Stack

- **Engine**: Godot 4.6 (Forward Plus + Jolt Physics)
- **Linguagem**: GDScript com tipagem estática
- **Plataforma de dev**: Windows 11
- **Idioma**: Português Brasileiro (pt-BR)

---

## Estrutura do projeto

```
naruto-os-pergaminhos-de-asura/
├── project.godot                       # config + Input Map oficial
├── icon.svg
├── README.md                           # este arquivo
├── documentation/                      # portfólio (vídeos, screenshots, GIFs)
│   └── README.md
├── scenes/
│   ├── player/player.tscn              # CharacterBody2D + colisão + Camera2D
│   └── test_stage.tscn                 # chão + 3 plataformas + Player + Debug HUD
└── scripts/
    ├── player/player_controller.gd     # FSM + pulo + chakra + respawn
    └── ui/debug_hud.gd                 # HUD plugado via signals
```

---

## Parâmetros tunáveis (Inspector do Godot)

Todos os valores de *game feel* são `@export` no `PlayerController` — calibre sem tocar em código:

| Grupo | Parâmetros | Defaults |
|---|---|---|
| Movimento | `move_speed`, `ground_acceleration`, `ground_friction`, `air_acceleration`, `air_friction` | 320, 2800, 3200, 1600, 900 |
| Pulo | `gravity`, `jump_velocity`, `jump_cut_multiplier`, `coyote_time`, `jump_buffer_time`, `max_jumps` | 1200, -650, 0.45, 0.12, 0.15, 2 |
| Chakra | `max_chakra`, `chakra_regen_rate`, `chakra_charge_rate`, `rasengan_chakra_cost` | 100, 6, 35, 40 |
| Combate | `light_attack_duration`, `heavy_attack_duration`, `special_duration` | 0.30, 0.50, 0.65 |
| Respawn | `kill_zone_y` | 1000 |

---

## Roadmap

- [x] **Semana 1 — Core Gameplay**
  - [x] Movimentação responsiva (chão/ar separados)
  - [x] Pulo: coyote + input buffer + variable height + double jump
  - [x] Máquina de estados (8 estados, signals plugáveis)
  - [x] Sistema de chakra (passiva, ativa, gasto pelo Rasengan)
  - [x] Câmera 2D com position smoothing
  - [x] Debug HUD em tempo real
  - [x] Kill zone + respawn
  - [ ] Hitboxes reais, knockback, hitstop *(FSM pronta; falta wirar Area2Ds)*
  - [ ] 3 tipos de inimigos básicos *(ninja melee · ninja shuriken · cachorro ninja)*
- [ ] **Semana 2 — Level Design**: Vila da Folha (hub + loja de lamen), Floresta da Névoa (fase principal 10–20 min com segredos e pergaminhos), NPCs, checkpoints
- [ ] **Semana 3 — Boss + Polish**: Zabuza (2 fases, névoa, espada, camera shake, hitstop), áudio, partículas, otimização final

---

## Licença

Projeto pessoal de portfólio, sem fins comerciais. **Naruto** é propriedade de Masashi Kishimoto / Shueisha / TV Tokyo / Pierrot. Este projeto é uma homenagem fan-made.

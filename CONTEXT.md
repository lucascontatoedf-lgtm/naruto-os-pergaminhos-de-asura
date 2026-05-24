# Naruto: Os Pergaminhos de Asura — Context

**Engine**: Godot 4.6 | **Branch**: main | **Repo**: lucascontatoedf-lgtm/naruto-os-pergaminhos-de-asura

---

## Stack
- GDScript, 2D platformer, uso pessoal (máquina única, sem distribuição)
- Input: Teclado (WASD/Setas + J/K/O/Shift) — sem suporte a controle

---

## Estrutura de pastas
- `levels/` → zonas do jogo
- `scenes/` → player, entidades, test_stage
- `scripts/player/` → player_controller.gd (~707 linhas, FSM 12 estados)
- `scripts/entities/` → zabuza, melee_ninja, shuriken, dummy
- `scripts/components/` → hitbox, hurtbox
- `scripts/systems/` → level_manager.gd (autoload)
- `scripts/ui/` → debug_hud.gd
- `assets/audio/` → Zabuza_laugh.wav
- `documentation/` → prints de validação

---

## Input Map atual
| Action | Teclado |
|---|---|
| move_left/right | ← → + A D |
| jump | ↑ + W |
| crouch | ↓ + S |
| attack_light | J |
| attack_heavy (shuriken) | K |
| special (rasengan) | O |
| chakra_charge | Shift Esq |

---

## Sistemas implementados
| Sistema | Arquivo | Status |
|---|---|---|
| PlayerController | player_controller.gd | ✅ FSM 12 estados (inclui WALL_SLIDE) |
| CombatSystem | hitbox.gd, hurtbox.gd | ✅ |
| ChakraSystem | embarcado no player | ✅ |
| BossController | zabuza.gd | ✅ FSM 9 estados |
| EnemyController | melee_ninja.gd | ✅ FSM 6 estados |
| LevelManager | level_manager.gd | ✅ autoload, RESPAWN_ZONE = zona_2 |
| DialogueSystem | — | ❌ próximo bloco |
| CollectibleSystem | — | ❌ pendente |
| SaveSystem | — | ❌ pendente |

---

## Decisões de design fechadas
- Morte → respawn sempre na Zona 2, independente da zona atual
- Zona 1 = tutorial com Jiraiya — jogado só uma vez
- Wall slide = segurar direção contra a parede. Solta → cai. Pulo → wall jump
- Wall jump recarrega double jump (_jumps_made = 0)
- Shuriken durante WALL_SLIDE sai oposta à parede
- Sem checkpoint — morreu recomeça da Zona 2
- Galho fatal na Zona 3 = único elemento propositalmente injusto (sem telegraf)
- Fighting game style (KOF/MK) — sem mira livre com mouse

---

## Estrutura do jogo (5 zonas lineares)
| Zona | Cena | Status |
|---|---|---|
| 1 | zona_1_floresta_morte.tscn | ❌ não criada |
| 2 | zona_2_casa_central.tscn | 🟡 placeholder mínimo |
| 3 | zona_3_arvores_gigantes.tscn | ❌ não criada |
| 4 | zona_4_aldeia_corredor.tscn | ❌ não criada |
| 5 | zona_5_lago.tscn | 🟡 floresta_da_nevoa.tscn (renomear) |

---

## Commits desta sessão
| SHA | Descrição |
|---|---|
| 8a90c75 | Feat: Wall Jump + Remapeamento de Controles |
| f3fe0bf | Refactor: estrutura assets/audio + Floresta Fase 1 |
| d51f415 | Feat: LevelManager autoload |
| 424e06c | Feat: zona_2_casa_central.tscn placeholder |

---

## Próximo bloco
**Bloco 3 — DialogueSystem** (balões de diálogo para Jiraiya/NPCs/easter eggs)

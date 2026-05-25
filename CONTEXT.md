# Naruto: Os Pergaminhos de Asura — Context

**Engine**: Godot 4.6 | **Branch**: main | **Repo**: lucascontatoedf-lgtm/naruto-os-pergaminhos-de-asura

---

## Como usar este arquivo
- Cole o conteúdo deste arquivo no início de cada nova sessão de chat
- Peça "Atualiza o CONTEXT.md" ao final de cada sessão antes do último commit

---

## Stack
- GDScript, 2D platformer, uso pessoal (máquina única, sem distribuição)
- Input: Teclado (WASD/Setas + J/K/O/Shift) — sem suporte a controle

---

## Estrutura de pastas
- `levels/` → zonas do jogo (zona_2 placeholder, floresta_da_nevoa)
- `scenes/` → player, entidades, test_stage
- `scenes/cutscenes/` → ichiraku, akatsuki_hideout
- `scenes/components/` → dialogue_trigger, rasengan_balloon
- `scenes/ui/` → dialogue_box
- `scripts/player/` → player_controller.gd (~799 linhas, FSM 12 estados)
- `scripts/entities/` → zabuza, melee_ninja, shuriken, dummy
- `scripts/components/` → hitbox, hurtbox, dialogue_trigger, kamui_trigger, rasengan_balloon
- `scripts/systems/` → level_manager.gd, dialogue_manager.gd (autoloads)
- `scripts/cutscenes/` → ichiraku, akatsuki_hideout
- `scripts/ui/` → debug_hud, dialogue_box
- `assets/audio/` → Zabuza_laugh.wav
- `assets/backgrounds/ichiraku/` → 3 frames teuchi_naruto_jiraya
- `assets/backgrounds/akatsuki/` → 2 frames guedomazo (frame1 removido, swap via signal)
- `assets/backgrounds/` → Vila_da_folha.png
- `assets/sprites/` → Naruto_chakra_charge.png (aguarda integração no Player)
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
| DialogueSystem | dialogue_manager.gd + dialogue_box.gd | ✅ autoload + UI manga-style + signal line_advanced |
| DialogueTrigger | dialogue_trigger.gd | ✅ Area2D, modos AUTO e INTERACTION |
| RasengaBalloon | rasengan_balloon.gd | ✅ world-space, filho do Player, await 1.5s |
| CutsceneSystem | ichiraku.gd, akatsuki_hideout.gd | ✅ scenes prontas (aguarda DialogueTrigger filho) |
| KamuiTrigger | kamui_trigger.gd | ✅ implementado, dormente (aguarda cena Akatsuki integrar) |
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
- Diálogos pausam o jogo (get_tree().paused = true); DialogueBox tem process_mode = ALWAYS
- DialogueBox estilo manga: fundo branco + borda colorida por personagem
- SPEAKER_COLORS: Naruto=laranja, Jiraiya=verde, Pain=roxo, Konan=azul, Tobi=laranja escuro
- Speakers desconhecidos → fallback DEFAULT_COLOR (preto)
- "Tô certo" é marca verbal exclusiva do Naruto (removida das falas do Jiraiya)
- RasengaBalloon é world-space (filho do Player), não UI screen-space — segue camera
- Cutscenes reagem a `DialogueManager.line_advanced(index)` pra trocar texturas (padrão Akatsuki frame swap)
- Akatsuki cutscene: abre com frame_a (Pain mão na cabeça), troca para frame_b na linha 2 ("Pain: Inesperado.")

---

## Estrutura do jogo (5 zonas lineares)
| Zona | Cena | Status |
|---|---|---|
| 1 | zona_1_floresta_morte.tscn | ❌ não criada |
| 2 | zona_2_casa_central.tscn | 🟡 placeholder + JiraiyaTrigger AUTO |
| 3 | zona_3_arvores_gigantes.tscn | ❌ não criada |
| 4 | zona_4_aldeia_corredor.tscn | ❌ não criada (cutscene Ichiraku pronta pra encaixar) |
| 5 | zona_5_lago.tscn | 🟡 floresta_da_nevoa.tscn (renomear, cutscene Akatsuki pronta pra encaixar) |

---

## Commits desta sessão (Bloco 3 + refinamentos)
| SHA | Descrição |
|---|---|
| 2327c33 | Docs: PROMPT.md — instrução de sessão para o Tech Lead |
| ab8e2e1 | Docs: atualiza SUGESTOES.md com design fechado sessão 2 |
| 4e64af8 | Feat: DialogueSystem — DialogueManager + DialogueBox + DialogueTrigger + diálogos Jiraiya e Akatsuki |
| 90248be | Feat: assets Ichiraku/Akatsuki + diálogos ichiraku_encontro e ichiraku_saida |
| dac7503 | Feat: assets cutscenes + scenes/cutscenes Ichiraku e Akatsuki |
| d55ddd1 | Feat: Akatsuki cutscene — swap de textura via signal line_advanced |
| 6236313 | Feat: DialogueBox manga-style + RasengaBalloon world-space + fix diálogo Jiraiya |

---

## Pendências de integração (não-bloqueantes)
- `ichiraku.tscn` precisa de DialogueTrigger filho com `dialogue_id="ichiraku_encontro"`
- `akatsuki_hideout.tscn` precisa de DialogueTrigger + KamuiTrigger instanciados (exit_position, entrance_collider, player no inspector)
- `assets/sprites/Naruto_chakra_charge.png` aguarda integração no Player (sem AnimatedSprite2D/Sprite2D ainda)
- Renomear `floresta_da_nevoa.tscn` → `zona_5_lago.tscn` quando definir a Zona 5 final

---

## Próximo bloco
A definir. Opções na mesa:
- **Integração das cutscenes**: cabear DialogueTrigger + KamuiTrigger nas cenas Ichiraku/Akatsuki
- **SaveSystem**: autoload pra persistir HP/chakra/pergaminhos cross-zona
- **CollectibleSystem**: pergaminhos coletáveis (#02 Espadas, #03 Ramen, #04 Cobra, #05 Akatsuki, #06 Jiraiya — ver SUGESTOES.md)
- **Chakra charge sprite**: integrar Naruto_chakra_charge.png ao Player (precisa AnimatedSprite2D ou TextureRect)
- **Zona 5**: renomear/finalizar floresta_da_nevoa.tscn

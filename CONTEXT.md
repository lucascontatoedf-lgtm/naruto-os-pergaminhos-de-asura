# Naruto: Os Pergaminhos de Asura — Context

**Engine**: Godot 4.6 | **Branch**: main | **Repo**: lucascontatoedf-lgtm/naruto-os-pergaminhos-de-asura

---

## Como usar este arquivo
- Cole o conteúdo deste arquivo no início de cada nova sessão de chat
- Peça "Atualiza o CONTEXT.md" ao final de cada sessão antes do último commit

---

## Regra permanente — zero commits sem teste
**Fluxo obrigatório:** coworker implementa → usuário testa no Godot Editor → traz feedback → aprovado → commit.
Nunca commitar antes da confirmação do usuário.

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
| CutsceneSystem | ichiraku.gd, akatsuki_hideout.gd | ✅ Ichiraku 100% integrado e testado (encontro + saída + fade); akatsuki integrado |
| KamuiTrigger | kamui_trigger.gd | ✅ ativo em akatsuki_hideout, player via grupo, fallback get_nodes_in_group |
| FadeTransition | fade_transition.gd | ✅ componente genérico, `fade(callback)` + signal `fade_completed`, duration=0.5s default |
| CollectibleSystem | — | ❌ pendente |
| SaveSystem | save_system.gd | ✅ autoload, snapshot em memória de hp/chakra/scrolls; `load_into()` emite signals |
| DebugHUD | debug_hud.gd + debug_hud.tscn | ✅ autoload, reconecta ao Player via `node_added` + grupo "Player" |

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
- Ichiraku é sub-scene da Zona 4 (não `change_scene_to_file`) — Player permanece na árvore
- `exit_position` do KamuiTrigger = `Vector2(500, 0)` placeholder — ajustar quando Zona 2 for construída

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

## Commits desta sessão (Sessão 7)
- `9ea1b21` — Feat: SaveSystem — persistência de hp/chakra/scrolls entre zonas
- `1cdfa3b` — Docs: CLAUDE.md — lições aprendidas sessão 7
- (este commit) — Docs: SUGESTOES.md #07 + CONTEXT.md sessão 7

### Sistemas entregues
- `SaveSystem` — autoload novo registrado em `project.godot` (`SaveSystem="*res://scripts/systems/save_system.gd"`). Snapshot em memória de `_hp`, `_chakra`, `_scrolls`. API: `save(player)`, `load_into(player)`, `reset()`, `has_data()`. `load_into()` emite `health_changed` e `chakra_changed` no Player após restore — sincroniza HUD sem esperar próxima emissão natural. ✅
- `DebugHUD` — refatorado para autoload (`DebugHUD="*res://scenes/ui/debug_hud.tscn"`). `@export var player_path` removido; agora resolve o Player via `get_tree().get_first_node_in_group("Player")` e reconecta automaticamente em troca de zona via `get_tree().node_added`. Disconnect-before-reconnect evita signals duplicados. Instâncias locais de DebugHUD removidas de `test_stage.tscn` e `floresta_da_nevoa.tscn`. ✅
- `zona_2_casa_central.tscn` — `ZoneLabel` corrigido: tipo `Label2D` (classe inexistente no Godot 4.6) → `Label`; propriedade `font_size = 28` → `theme_override_font_sizes/font_size = 28`. Corrige crash com `ERROR: Cannot get class 'Label2D'` em respawn/change_scene. ✅
- `debug_zone_switch.gd` — novo autoload de debug em `scripts/debug/`. F1 = `SaveSystem.save(player)` + `LevelManager.change_scene("zona_2")`; F2 = `SaveSystem.load_into(player)`; F3 = `SaveSystem.reset()`. Usado para validar persistência cross-zona. ✅
- `CLAUDE.md` — adicionada seção "Lições aprendidas — Sessão 7": direcionamento de tarefas (coworker vs Claude Code), alucinação/verificação contra disco, specs sem valores numéricos duplicados, prompts sem ambiguidade de escopo. ✅
- `SUGESTOES.md` — `#07 Tutorial interativo — Zona 2 (JiraiyaTrigger)` adicionado: sistema independente do DialogueSystem que aguarda input correto antes de avançar instrução. ✅

## Commits da sessão 6
- `Feat: ChakraSprite — Naruto sentado durante CHAKRA_CHARGE (#01)` (cb037d2)
- `Fix: Ichiraku background — sizing e posicionamento` (cb037d2)
- `Docs: atualiza CONTEXT.md sessão 6` (a355897)

## Commits da sessão 5
| SHA | Descrição |
|---|---|
| 65c4d44 | Docs: reformula papéis — CLAUDE.md + CLAUDE_CODE.md |
| 093af3b | Docs: atualiza CONTEXT.md sessão 5 |
| 88179a5 | Feat: FadeTransition genérico + ichiraku_saida trigger e fluxo de saída |
| 6530e3a | Feat: Bloco 3 completo — player grupo Player, KamuiTrigger fallback, akatsuki_hideout integrado |
| 933aea0 | Feat: ichiraku.tscn — DialogueTrigger AUTO ichiraku_encontro |

## Commits anteriores (Bloco 3 + refinamentos)
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
- `assets/sprites/Naruto_chakra_charge.png` aguarda integração no Player (sem AnimatedSprite2D/Sprite2D ainda)
- Renomear `floresta_da_nevoa.tscn` → `zona_5_lago.tscn` quando definir a Zona 5 final
- Warning: signal `respawned` declarado em `player_controller.gd` mas nunca conectado (cleanup futura, não-bloqueante)
- `exit_position` do KamuiTrigger (`Vector2(500, 0)`) é placeholder — revisar quando Zona 2 for construída
- Refactor `kamui_trigger.gd` para usar `FadeTransition` (eliminar duplicação de fade)
- Quando Zona 4 for construída, mover fala `Jiraiya: "Entra aí, garoto."` para trigger no corredor antes da entrada do Ichiraku

---

## Próximo bloco
A definir. Opções na mesa:
- **TutorialTrigger Zona 2** (#07 — ver SUGESTOES.md): substituir JiraiyaTrigger AUTO por sistema que aguarda input correto antes de avançar instrução
- **CollectibleSystem**: pergaminhos coletáveis (#02 Espadas, #03 Ramen, #04 Cobra, #05 Akatsuki, #06 Jiraiya — ver SUGESTOES.md)
- **Chakra charge sprite**: integrar Naruto_chakra_charge.png ao Player (precisa AnimatedSprite2D ou TextureRect)
- **Zona 5**: renomear/finalizar floresta_da_nevoa.tscn

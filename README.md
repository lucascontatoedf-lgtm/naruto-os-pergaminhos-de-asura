# Pergaminho de Asura — MVP de Combate & IA (Godot Engine 4.x)

> **Vertical Slice** focado em mecânicas estritas de combate 2D e Inteligência Artificial preditiva.
> Engine: **Godot 4.6** (Forward Plus + Jolt Physics) — GDScript tipado, código modular, signals-first.

![Visão geral do MVP em execução — Player, Dummy e MeleeNinja na cena de teste](documentation/prints/Captura%20de%20tela%202026-05-22%20051859.png)

---

## 1. Apresentação Geral

**Pergaminho de Asura** é um protótipo de plataforma/ação 2D inspirado no universo Naruto. O escopo é deliberadamente apertado: um único personagem jogável, um único tipo de inimigo melee, um único cenário de teste — todos servindo a um único objetivo: **investigar profundidade em sistemas de combate e IA reativa antes de escalar conteúdo**.

A meta do MVP não é quantidade de fases ou personagens. É:

- **Game feel** apurado — pulo, combo, chakra e respawn impecáveis ao toque.
- **IA preditiva** — inimigo que detecta, persegue, **escala plataformas verticalmente** e responde a impactos com knockback direcional e stun.
- **Arquitetura limpa** — componentes reaproveitáveis (`Hitbox` / `Hurtbox`), FSMs explícitas, signals plugáveis em zero-polling.

Este repositório consolida a fase de **Core Gameplay** completa: movimentação fluida do jogador, FSM de 8 estados, sistema de combate de 3 frentes (combo melee + projétil + special com custo de chakra), HUD de debug em tempo real, kill zone com respawn, e a IA reativa do inimigo melee com gatilho de pulo preditivo.

---

## 2. Arquitetura & Árvore de Cenas (Scene Tree)

A modularidade do projeto se apoia em **três pilares de isolamento**:

1. **Entidades físicas** — `CharacterBody2D` para corpos com movimento próprio (Player, MeleeNinja) e `StaticBody2D` para geometria estática (Floor, Plataformas, Dummy de teste). Nenhum desses interage com a camada de combate diretamente.
2. **Áreas reativas** — `Area2D` para todo o pipeline de detecção de impacto (`Hitbox` ofensiva, `Hurtbox` defensiva, `DetectionArea` de percepção). Vivem em layers próprias e não influenciam fisicamente o `CharacterBody2D` pai.
3. **Camada de apresentação** — `CanvasLayer` independente para o HUD de debug, plugado diretamente nos signals do `PlayerController` (`state_changed`, `chakra_changed`) sem nenhum polling por frame.

![Scene Tree expandida no Godot Editor — TestStage com Player, Dummy, MeleeNinja e DebugHUD](documentation/prints/Captura%20de%20tela%202026-05-22%20052151.png)

### Árvore de cenas resumida

```
TestStage (Node2D)
├── Floor / PlatformA / PlatformB / PlatformC   (StaticBody2D + Polygon2D + CollisionShape2D)
├── Dummy (StaticBody2D)                        — alvo passivo, vida 3, respawn 1s
│   ├── Visual / BodyShape / HPBar
│   └── Hurtbox (Area2D, layer enemy_hurtbox)
├── MeleeNinja (CharacterBody2D)                — IA completa
│   ├── Visual / BodyShape / HPBar
│   ├── Hurtbox      (Area2D, layer enemy_hurtbox)
│   ├── Hitbox       (Area2D, layer enemy_hitbox)  — golpe melee
│   └── DetectionArea (Area2D, CircleShape2D r=280) — percepção
├── Player (CharacterBody2D)                    — Naruto
│   ├── Visual / FaceMarker / CollisionShape2D / Camera2D
│   ├── HitboxLight    (Area2D, dmg 1)
│   └── HitboxSpecial  (Area2D, dmg 3)
└── DebugHUD (CanvasLayer)                      — overlay
    └── Root → Background + VBox → StateLabel + ChakraLabel
```

### Separação física × reativa × apresentação

| Camada | Tipo de nó | Layer física | Responsabilidade |
|---|---|---|---|
| Player body | `CharacterBody2D` | 1 (world) | Movimento, gravidade, colisão com floor |
| MeleeNinja body | `CharacterBody2D` | 1 (world) | Mesmo do Player, isolado de combate |
| Hitbox ofensiva | `Area2D` + `Hitbox.gd` | 2 (player_hitbox) ou 5 (enemy_hitbox) | Causa dano ao tocar Hurtbox |
| Hurtbox defensiva | `Area2D` + `Hurtbox.gd` | 3 (enemy_hurtbox) | Recebe e repassa o hit via signal |
| DetectionArea | `Area2D` | mask=1 + filtro por classe | Percepção do Player |
| DebugHUD | `CanvasLayer` + `Control` | — (sem física) | UI em screen-space, signals-driven |

### Responsabilidades por script

| Script | Responsabilidade |
|---|---|
| `player_controller.gd` | FSM do jogador (8 estados), física, input, chakra, kill zone. |
| `melee_ninja.gd` | FSM do inimigo (6 estados), percepção, pulo AI preditivo. |
| `hitbox.gd` | Componente Area2D ofensivo reusável (`damage`, signal `hit_landed`). |
| `hurtbox.gd` | Componente Area2D defensivo reusável (`take_hit` → signal `hit_taken`). |
| `shuriken.gd` | Projétil que **estende** `Hitbox` — movimento próprio + auto-destruct. |
| `dummy.gd` | Alvo passivo de testes — recebe hits, flasha, respawna. |
| `debug_hud.gd` | Plugado em `state_changed` + `chakra_changed`, zero polling. |

---

## 3. Sistemas de Combate e Recursos

![Combate em ação — combo conectando no MeleeNinja com knockback visível](documentation/prints/Captura%20de%20tela%202026-05-22%20052216.png)

### Combo Leve (Tecla **H**) — 3 hits encadeados com micro-dash automático

O combo opera dentro de uma **cancel window** definida pelo último 25% da duração de cada ataque (`attack_cancel_window_ratio = 0.25`). Apertar **H** novamente dentro dessa janela reentra o estado `ATTACK` aplicando um **micro-impulso de `velocity.x = 250 px/s * facing_direction`** (decai pela friction natural em ~5 frames), dando ao Naruto um leve "tranco" pra frente a cada hit conectado.

| Hit | Custo de chakra | Damage | Ganho de terreno por dash |
|---|---|---|---|
| H1 (entrada) | 0 | 1 | — |
| H2 (cancel window) | 0 | 1 | ~10 px |
| H3 (cancel window) | 0 | 1 | ~10 px |
| **Total do combo** | **0** | **3** | **~30 px** |

A FSM faz `_exit_state(State.ATTACK)` + `_enter_state(State.ATTACK)` manualmente, **sem** passar pelo `_change_state` (que bloqueia transições mesmo→mesmo), reciclando hitbox, signals `attack_started`/`attack_ended` e o `_state_timer`.

### Shuriken (Tecla **J**) — projétil físico com alcance limitado

`Shuriken` estende `Hitbox` e é spawnada como sibling do Player no momento do arremesso. Auto-destrói após **600 px** de distância percorrida OU ao atingir uma `Hurtbox` válida.

| Parâmetro | Valor |
|---|---|
| Damage | 1 |
| Custo de chakra | **40** |
| Alcance máximo | **600 px** |
| Velocidade de voo | 800 px/s |
| Spin visual | 12 rad/s |

A direção é setada por `direction = Vector2(facing_direction, 0)` no spawn, **antes** de adicionar à árvore — garantindo que o `_physics_process` do projétil já comece com o vetor correto.

### Rasengan (Tecla **L**) — special com dash melee

O `State.SPECIAL` aplica um impulso `velocity.x = 1300 * facing_direction` no momento do `_enter_state`, fazendo o Naruto **avançar cerca de 264 px** em direção ao alvo antes de descarregar a `HitboxSpecial` (raio 45 px, damage 3). A friction natural do chão decai o dash em ~0.41s.

| Parâmetro | Valor |
|---|---|
| Damage | 3 (one-shot no Dummy de 3 HP) |
| Custo de chakra | **70** |
| Dash inicial | 1300 px/s |
| Alcance total efetivo | ~360 px |

### Gerenciamento dinâmico de Chakra

A barra de 0–100 é o recurso central do combate. Os custos altos (40 / 70) impõem uma **decisão tática contínua**: stockar pra Rasengan ou gastar em shurikens?

![Chakra em consumo durante combate — barra parcial visível na HUD](documentation/prints/Captura%20de%20tela%202026-05-22%20052329.png)

| Fonte | Variação |
|---|---|
| Regen passiva (sempre que não estiver em `CHAKRA_CHARGE`) | **+8/s** |
| `chakra_charge` (segurar Shift Esq.) | +35/s (full bar em ~12.5s, 70 chakra em ~2s) |
| Shuriken (J) | **−40** |
| Rasengan (L) | **−70** |

Com max 100, a barra cheia comporta **1 Rasengan + 0.75 shuriken**, OU **2 shurikens com 20 sobrando**, OU 1 Rasengan + breve `chakra_charge` pra outro recurso. **Sempre tem que escolher**.

---

## 4. Máquina de Estados Finitas (FSM) do Inimigo

![MeleeNinja em combate — chase e attack contra o Player](documentation/prints/Captura%20de%20tela%202026-05-22%20052700.png)

O `MeleeNinja.gd` implementa uma FSM enum-based com **6 estados** e signal `state_changed(previous, new)` plugável em UI, áudio e VFX futuros.

### Diagrama de transições

```
        ┌──────────┐
        │   IDLE   │
        └────┬─────┘
             │ (timer 0.5–1.5s aleatório expira)
        ┌────▼─────┐
        │  PATROL  │   movimentação a patrol_speed=80 px/s
        └────┬─────┘   dentro de patrol_distance=220 px do spawn
             │
             │ (player entra na DetectionArea)
        ┌────▼─────┐
        │  CHASE   │   movimentação a chase_speed=160 px/s, facing dinâmico
        └────┬─────┘
             │ (|distância horizontal| < attack_range=60 + cooldown ok)
        ┌────▼─────┐
        │  ATTACK  │   windup(0.30s) → active(0.15s) → recovery(0.35s)
        └────┬─────┘   + cooldown(0.8s)
             │
             └──→ CHASE (se player ainda detectado) OU PATROL

  EM QUALQUER ESTADO (Hurtbox.hit_taken):
    │
┌───▼──────┐
│   HURT   │   stun 0.25s + knockback 280 px/s na direção oposta ao golpe
└───┬──────┘
    │ (HP > 0)        │ (HP ≤ 0)
    ▼                  ▼
  CHASE ou PATROL  ┌──────────┐
                   │   DEAD   │ → invisível por 2s → renasce no spawn
                   └──────────┘
```

### IDLE — pausa orgânica entre pernas de patrol

Velocidade horizontal decai por friction (`move_toward(velocity.x, 0.0, ground_friction * delta)`). Um timer aleatório no intervalo `[patrol_pause_min, patrol_pause_max]` segura o inimigo no lugar, dando personalidade de "olhar pros lados antes de andar de novo".

### PATROL — vai-e-vem em torno do spawn

Caminha a **80 px/s** em `facing_direction`. Quando `position.x - _spawn_position.x` ultrapassa `patrol_distance=220` em módulo, OU quando `is_on_wall()` retorna true (esbarrou em geometria), o inimigo **vira o nariz** e transiciona pra `IDLE`. Esse ciclo `PATROL → IDLE → PATROL` repete indefinidamente até o jogador aparecer.

### CHASE — perseguição reativa por frame

Recalcula `horizontal_distance = _player.global_position.x - global_position.x` a cada `_physics_process`, atualiza `facing_direction` para apontar pro jogador, e aplica `velocity.x = chase_speed * facing_direction`. Se a distância horizontal cai abaixo de `attack_range=60 px` E `_attack_cooldown_timer` está zerado, transiciona pra `ATTACK`.

### ATTACK — três fases internas + cooldown externo

A FSM do ataque é, na prática, **uma sub-FSM** dentro do estado:

```gdscript
match _attack_phase:
    "windup":   if _state_timer <= 0: → active   + _enable_attack_hitbox()
    "active":   if _state_timer <= 0: → recovery + hitbox.disable()
    "recovery": if _state_timer <= 0: → set cooldown + back to CHASE/PATROL
```

A telegrafia de **0.30s no windup** dá ao jogador uma janela clara para reagir — esquivar, contra-atacar com Rasengan ou disparar uma shuriken na cara antes do impacto. Esse design escolhe **legibilidade** acima de "pegadinhas de timing".

### Sistema de Percepção — Area2D circular

A `DetectionArea` é uma `Area2D` com `CircleShape2D` (raio 280 px) e `collision_mask = 1` (layer world). Captura qualquer body em layer 1 e filtra por classe no script:

```gdscript
func _on_body_entered_detection(body: Node2D) -> void:
    if body is PlayerController:
        _player = body
        if current_state == State.PATROL or current_state == State.IDLE:
            _change_state(State.CHASE)
```

Filtrar via `is PlayerController` em vez de criar uma layer `player_body` dedicada mantém o `collision_layer` do Player intacto (já validado em vários ciclos de combate). Trade-off favorável: zero refactor para um overhead irrelevante de descartar o floor e o dummy no callback.

---

## 5. IA de Movimentação Vertical — Pulo Preditivo no CHASE

![Naruto em pulo com chakra baixo — escalada vertical de plataformas](documentation/prints/Captura%20de%20tela%202026-05-22%20053018.png)

A IA do `MeleeNinja` ganhou um **gatilho de pulo dentro do estado CHASE** para impedir que o jogador escape verticalmente subindo em plataformas flutuantes.

### Condição de gatilho — três checks em AND lógico

Avaliados a cada frame em `_state_chase`:

```gdscript
if is_on_floor() and is_on_wall() and _player.global_position.y < global_position.y - 50.0:
    velocity.y = enemy_jump_velocity   # -650.0
```

| Verificação | Significado |
|---|---|
| `is_on_floor()` | Inimigo está grounded — só pula a partir de superfície sólida. |
| `is_on_wall()` | Há **barreira física à frente** — está esbarrando lateralmente na quina de uma plataforma ou em uma parede. |
| `_player.global_position.y < global_position.y - 50.0` | Player está **significativamente acima** (margem de 50 px) — vale a pena gastar o pulo. |

A condição só dispara quando as três são `true` **simultaneamente**. Após o pulo, `is_on_floor()` retorna `false` (inimigo no ar) e a condição falha automaticamente — **sem necessidade de cooldown explícito ou flag anti-spam**.

### Verificação de barreira física via `is_on_wall()`

A leitura é feita pelo próprio motor do Godot — `CharacterBody2D` mantém o flag interno após cada `move_and_slide()`. Quando o ninja em PATROL ou CHASE encosta lateralmente em uma plataforma flutuante (a parte de baixo é tratada como "wall" pelo solver porque a normal da colisão é vertical), o flag fica `true` por aquele frame.

Combinado com a leitura de `_player.global_position.y`, o inimigo só pula quando **há uma plataforma física a sua frente E o jogador está em cima dela** — comportamento que parece intencional e proposital, não aleatório.

### Matemática da subida — calibrado com a gravidade

Com `enemy_jump_velocity = -650` e `GRAVITY = 1400`:

- **Pico vertical**: 650² / (2 · 1400) ≈ **151 px** acima da posição inicial.
- **Duração total do arco** (subida + descida): 2 · 650 / 1400 ≈ **0.93 s**.
- **Cobertura horizontal durante o pulo**: `chase_speed (160 px/s) × 0.93 s` ≈ **149 px**.

### Escalada progressiva entre plataformas

O ninja **não tem pathfinding global** — apenas reage às condições locais. Mesmo assim, isso é suficiente para escalar todas as plataformas do `test_stage` em sequência:

| De | Para | Altura (px) | Cabe num pulo? |
|---|---|---|---|
| Chão (y=368) | PlatformA top (y=268) | 100 | Sim — sobra 51 px |
| PlatformA | PlatformB top (y=168) | 100 | Sim — mesma margem |
| PlatformB | PlatformC top (y=88) | 80 | Sim — confortável |

### Compatibilidade com a trava de gravidade

A ordem das operações em `_physics_process` é o que faz o pulo funcionar **mesmo com `velocity.y = 0.0` sendo aplicado por `_apply_gravity` em todo frame on-floor**:

```
1. _apply_gravity(delta)         ← zera velocity.y se on_floor
2. _tick_timers(delta)
3. _process_current_state(delta) ← _state_chase SETA velocity.y = -650 depois do zero
4. _update_visual_facing()
5. move_and_slide()              ← move o corpo com o impulso intacto
```

O estado roda **depois** da gravidade, então a atribuição `velocity.y = enemy_jump_velocity` no `_state_chase` **sobrescreve** o zero. Sem conflito de prioridade.

---

## 6. Post-Mortem de Bugs Críticos

A integração da IA passou por dois bugs de física **não-triviais** durante o desenvolvimento. Ambos foram diagnosticados e resolvidos com correções cirúrgicas. Documentação detalhada da raiz e da solução abaixo.

### Bug 1 — *Jittering* (micro-quiques verticais no chão)

**Sintoma**: o `MeleeNinja` em estados `IDLE` e `PATROL` vibrava verticalmente (~1–2 px) cada frame, **mesmo parado em superfície totalmente plana**. O Player, usando `CharacterBody2D` idêntico, não sofria do mesmo problema.

**Diagnóstico**: o método `_apply_gravity` original retornava cedo quando `is_on_floor()` era `true`, **sem zerar `velocity.y`**:

```gdscript
func _apply_gravity(delta: float) -> void:
    if is_on_floor():
        return  # ← velocity.y mantinha o valor positivo da última queda
    velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
```

Quando o inimigo aterrissava após o spawn — mesmo uma queda mínima conta — `velocity.y` ficava com um valor pequeno, mas positivo. Em frames de borda, quando `is_on_floor()` oscila entre `true` e `false` por **imprecisão numérica do solver**, a gravidade voltava a somar em cima desse valor. O `move_and_slide` então gerava o quique micro-vertical.

**Por que o Player não sofria**: por hábito de movimento. O jogador raramente fica parado em borda — ele pula, anda, cai de plataformas — e o `velocity.y` reseta naturalmente como efeito colateral. O inimigo em `PATROL` **fica exatamente em cima do chão por longos períodos**, expondo o bug em sua forma mais pura.

**Correção** — trava ativa de `velocity.y` em `_apply_gravity`:

```gdscript
func _apply_gravity(delta: float) -> void:
    if is_on_floor():
        velocity.y = 0.0   # ← zera ATIVAMENTE no on_floor
        return
    velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
```

Cada frame `on_floor` reseta o eixo Y antes de qualquer física rolar. O loop de feedback `gravity acumula → move_and_slide empurra → is_on_floor flicker → gravity acumula` é cortado na raiz.

### Bug 2 — *Sanduíche de Colisão* (overlap geométrico no spawn)

**Sintoma**: depois da correção do Jittering, o `MeleeNinja` **ainda vibrava** — mas agora estava travado embaixo da quina esquerda da `PlatformA`, sem conseguir andar pra lugar nenhum.

**Diagnóstico geométrico**: o spawn original do inimigo estava em `Vector2(-300, 368)`, **exatamente sob o volume da `PlatformA` flutuante**. As caixas de colisão se sobrepunham fisicamente desde o frame 0:

| Volume | x range | y range |
|---|---|---|
| MeleeNinja shape (em spawn) | `[-324, -276]` | `[272, 368]` |
| PlatformA shape | `[-520, -280]` | `[268, 300]` |
| **Overlap real** | **`[-324, -280]` (44 px)** | **`[272, 300]` (28 px)** |

O ninja literalmente **nascia com a cabeça enfiada dentro do tijolo da plataforma flutuante**. O engine tentava resolver o overlap pelo menor caminho (28 px vertical para baixo), mas o chão sólido abaixo bloqueava — então tentava o segundo menor caminho (44 px horizontal para a direita), gerando um empurrão constante que conflitava com o `velocity.x` que a IA tentava aplicar.

**Correção dupla**:

**1. Reposicionamento de spawn** em `test_stage.tscn`:

```diff
- position = Vector2(-300, 368)
+ position = Vector2(-150, 368)
```

No novo spawn, o shape do inimigo `[-174, -126]` fica a **106 px de clearance** da borda direita da `PlatformA` `[-520, -280]`. **Zero overlap** inicial.

**2. `floor_snap_length = 12.0`** no `_ready()`:

```gdscript
func _ready() -> void:
    floor_snap_length = 12.0   # snap ativo no chão em todas as transições
    current_health = max_health
    _spawn_position = position
    ...
```

Essa propriedade nativa do `CharacterBody2D` força o engine a buscar ativamente o chão em um raio de **12 px abaixo do corpo** após cada `move_and_slide()`. Mesmo se a IA mais tarde caminhar para baixo da `PlatformA` durante o PATROL (e o head do inimigo tocar a parte de baixo da plataforma), o snap empurra o corpo de volta pro chão — sem permitir que o engine resolva o overlap empurrando o ninja pra cima.

A combinação das duas correções — **geometria limpa no spawn** + **snap defensivo contínuo** — eliminou completamente o sanduíche.

---

## Como rodar localmente

1. Baixe **Godot 4.6+** em [godotengine.org](https://godotengine.org).
2. Clone este repositório.
3. No Godot: **Import** → selecione `project.godot`.
4. **F5** — abre na `scenes/test_stage.tscn` por padrão.

### Controles

| Ação | Teclado | Gamepad (Xbox / PS) |
|---|---|---|
| Mover | ← / → | Analógico esq. / DPad |
| Pular | ↑ | A / X |
| Agachar | ↓ | DPad ↓ |
| Combo leve | **H** | X (Xbox) / □ (PS) |
| Shuriken | **J** | Y / △ |
| Rasengan | **L** | B / ○ |
| Concentrar chakra | Shift Esq. | RT / R2 |

---

## Estrutura de pastas

```
naruto-game/
├── project.godot                      # config Godot + Input Map + layers
├── README.md                          # este arquivo
├── .gitignore                         # blindagem de artefatos locais
├── documentation/
│   └── prints/                        # capturas usadas neste README
├── scenes/
│   ├── test_stage.tscn                # cena principal de teste
│   ├── player/player.tscn             # CharacterBody2D + hitboxes + camera
│   └── entities/
│       ├── dummy.tscn                 # alvo passivo
│       ├── melee_ninja.tscn           # inimigo com IA
│       └── shuriken.tscn              # projétil
└── scripts/
    ├── player/player_controller.gd
    ├── components/
    │   ├── hitbox.gd                  # Area2D ofensivo reusável
    │   └── hurtbox.gd                 # Area2D defensivo reusável
    ├── entities/
    │   ├── dummy.gd
    │   ├── melee_ninja.gd
    │   └── shuriken.gd
    └── ui/debug_hud.gd
```

---

## Licença

Projeto pessoal de portfólio, sem fins comerciais. **Naruto** é propriedade de Masashi Kishimoto / Shueisha / TV Tokyo / Pierrot. Este projeto é uma homenagem fan-made.

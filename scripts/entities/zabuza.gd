class_name Zabuza
extends CharacterBody2D

## Zabuza — Boss único do MVP (Floresta da Névoa, fim de Semana 3).
##
## Pipeline de IA:
##   PATROL → CHASE → {MELEE_ATTACK (combo guilhotina, curto), WATER_DRAGON (jutsu, médio)}
##                  └→ HIDDEN_MIST (invisível/imune, reposiciona) → AMBUSH (ataque surpresa)
##                  └→ HURT (compartilhado com pipeline de combate do MeleeNinja)
##                  └→ DEAD (sem respawn no MVP — boss morre uma vez, fim da demo)
##
## Reutiliza o padrão de FSM, Hitstop e _on_hit_taken do MeleeNinja, mas em arquivo
## separado pra permitir tuning independente sem mexer no balanço do inimigo básico.
## O esqueleto está aqui — Hurt/Dead/Hitstop/Percepção já funcionais, demais estados
## são stubs com TODOs específicos da mecânica de cada um.

# ---------------------------------------------------------------------------
# CONSTANTES DE FÍSICA (mesmas do MeleeNinja pra consistência)
# ---------------------------------------------------------------------------
const GRAVITY: float = 1400.0
const MAX_FALL_SPEED: float = 900.0

# preload() força carregamento em tempo de PARSE (antes do _ready), garantindo que o
# stream já está em memória quando _enter_state(HIDDEN_MIST) chamar play(). Zero latência
# vs. load() em runtime. FLAC é compressed lossless — descomprime no play, mas o decode
# do header acontece aqui, então o primeiro play() não tem hitch.
const LAUGH_STREAM: AudioStream = preload("res://assets/audio/Zabuza_laugh.wav")

# ---------------------------------------------------------------------------
# PARÂMETROS
# ---------------------------------------------------------------------------
@export_group("Vida e Dano")
@export var max_health: int = 15                  ## Boss tem ~3x o HP do ninja básico.
@export var melee_damage: int = 2                 ## Cada swing da guilhotina (combo de N hits).
@export var water_dragon_damage: int = 3          ## Jutsu de longo alcance.
## OBS: AMBUSH transiciona pra MELEE_ATTACK por design (spec), então o "golpe surpresa"
## usa melee_damage também. Pra dano diferenciado no futuro, adicionar ambush_damage e
## checar contexto (came_from_ambush flag) em _enter_state(MELEE_ATTACK).

@export_group("Movimento")
@export var patrol_speed: float = 60.0
@export var chase_speed: float = 384.0   ## 1.2× player.move_speed (320) — caçador implacável, sempre ganhando terreno em corrida pura. Não é coincidência: forçar player a usar JUMP/DASH pra criar distância em vez de só correr.
@export var ground_friction: float = 2000.0
@export var enemy_jump_velocity: float = -700.0   ## Pulo um pouco mais forte que o MeleeNinja (boss = mais traversal vertical). Pico ~175px.
@export var chase_jump_y_threshold: float = 40.0  ## Player ≥ esse valor acima → pulo no CHASE. Threshold mais agressivo (40) pro boss reagir antes que o ninja básico.

@export_group("Percepção e Alcance")
@export var detection_radius: float = 500.0       ## Boss enxerga mais longe que o ninja básico.
@export var melee_attack_range: float = 85.0      ## Combo da guilhotina (curto alcance).
@export var water_dragon_range: float = 350.0     ## Jutsu Dragão de Água (alcance médio).

@export_group("Combate Melee (Guilhotina)")
@export var melee_combo_count: int = 3            ## Sequência de swings antes de recuperar.
@export var melee_windup: float = 0.40            ## Telegrafia maior — boss = leitura de ataques.
@export var melee_active: float = 0.20
@export var melee_recovery: float = 0.50
@export var melee_cooldown: float = 1.2

@export_group("Combate Jutsu (Dragão de Água)")
@export var water_dragon_windup: float = 0.80     ## Jutsu = telegrafia bem maior (esquivável).
@export var water_dragon_active: float = 0.30
@export var water_dragon_recovery: float = 0.60
@export var water_dragon_cooldown: float = 4.0

@export_group("Stealth (HIDDEN_MIST / AMBUSH)")
@export var mist_duration: float = 2.5            ## Tempo invisível enquanto reposiciona (spec do MVP).
@export var ambush_offset_x: float = 50.0         ## Distância horizontal atrás do player onde o boss surge (spec: 50px).
@export var ambush_offset_y: float = 0.0          ## Offset vertical em relação ao Y do player (0 = mesma altura/chão). _snap_to_floor() força ele pro piso após o teleporte, evitando spawn flutuando.
@export var mist_cooldown: float = 8.0            ## Tempo mínimo entre entradas em HIDDEN_MIST.
@export var mist_health_threshold: float = 0.3    ## HIDDEN_MIST dispara quando HP cai abaixo desse ratio (30% por default — gatilho de fuga).
@export var mist_hard_stop_ratio: float = 0.10    ## HARD STOP: abaixo desse ratio (10% por default), HIDDEN_MIST é PERMANENTEMENTE desativada. Boss entra em "modo desespero" — só luta com a espada até morrer.

@export_group("Audio")
@export var laugh_stream: AudioStream             ## Risada do Zabuza ao sair da névoa (AMBUSH). Arraste o Zabuza_Laugh.wav aqui no inspetor. Toca via AudioStreamPlayer2D (espacializado).

@export_group("Hit Feel")
@export var hit_flash_duration: float = 0.12
@export var hit_knockback_speed: float = 220.0    ## Knockback menor que ninja básico (boss = peso).
@export var stun_duration: float = 0.30
@export var heavy_hit_threshold: int = 3
@export var heavy_hit_knockback_multiplier: float = 1.6
@export var heavy_hit_stun_multiplier: float = 1.5
@export var heavy_hit_hitstop_duration: float = 0.12
@export var stun_extension_cap: float = 1.2
@export var hurt_gravity_multiplier: float = 0.6  ## Mesmo conceito do MeleeNinja — juggle aéreo cadenciado.

@export_group("Respawn")
@export var kill_zone_y: float = 1000.0
# Sem respawn_delay — boss não renasce no MVP. Death = fim da demo.

# ---------------------------------------------------------------------------
# FSM — 9 estados, dos quais 4 são únicos do Zabuza (MELEE_ATTACK, WATER_DRAGON, HIDDEN_MIST, AMBUSH)
# ---------------------------------------------------------------------------
enum State {
	IDLE,
	PATROL,
	CHASE,
	MELEE_ATTACK,    ## combo guilhotina (close-range)
	WATER_DRAGON,    ## jutsu mid-range
	HIDDEN_MIST,     ## invisível, imune, reposicionando
	AMBUSH,          ## reaparece próximo ao player + ataque surpresa
	HURT,
	DEAD,
}

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal damaged(amount: int, remaining: int)
signal died
signal state_changed(previous_state: State, new_state: State)
signal phase_changed(phase_name: String)   ## Gancho pra UI futura de boss (life bar, name plate, fase)

# ---------------------------------------------------------------------------
# ESTADO INTERNO
# ---------------------------------------------------------------------------
var current_state: State = State.IDLE
var current_health: int = 0
var facing_direction: int = 1

var _spawn_position: Vector2 = Vector2.ZERO
var _state_timer: float = 0.0
var _melee_cooldown_timer: float = 0.0
var _water_dragon_cooldown_timer: float = 0.0
var _mist_cooldown_timer: float = 0.0
var _attack_phase: String = ""
var _melee_combo_index: int = 0     ## qual swing do combo da guilhotina (0..melee_combo_count-1)
var _player: Node2D = null
var _hit_flash_tween: Tween = null

# ---------------------------------------------------------------------------
# NÓS — esperam estrutura no zabuza.tscn (criar quando for instanciar)
# ---------------------------------------------------------------------------
@onready var visual: Node2D = $Visual
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox_melee: Hitbox = $HitboxMelee                ## Hitbox curta da guilhotina
@onready var hitbox_water_dragon: Hitbox = $HitboxWaterDragon   ## Hitbox/area do jutsu
@onready var detection_area: Area2D = $DetectionArea
@onready var hp_fill: Polygon2D = $HPBar/Fill
@onready var laugh_player: AudioStreamPlayer2D = $LaughSFX   ## Player espacializado da risada de AMBUSH

# ===========================================================================
# CICLO DE VIDA
# ===========================================================================
func _ready() -> void:
	floor_snap_length = 12.0
	current_health = max_health
	_spawn_position = position

	hurtbox.hit_taken.connect(_on_hit_taken)
	detection_area.body_entered.connect(_on_body_entered_detection)
	detection_area.body_exited.connect(_on_body_exited_detection)

	# Resolve stream da risada: export do inspector (laugh_stream) tem precedência sobre o
	# preload. Preload da const LAUGH_STREAM garante que o asset está em memória DESDE O
	# PARSE (antes mesmo de _ready), eliminando latência no primeiro play().
	# Sequência: parse-time preload → _ready assign → _enter_state(HIDDEN_MIST) play().
	laugh_player.stream = laugh_stream if laugh_stream != null else LAUGH_STREAM

	_update_hp_visual()
	_change_state(State.PATROL)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	_apply_gravity(delta)
	_tick_timers(delta)
	_process_current_state(delta)
	_update_visual_facing()

	move_and_slide()
	_check_kill_zone()

# ===========================================================================
# FÍSICA & TIMERS
# ===========================================================================
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		return
	var effective_gravity: float = GRAVITY
	if current_state == State.HURT:
		effective_gravity *= hurt_gravity_multiplier
	velocity.y = minf(velocity.y + effective_gravity * delta, MAX_FALL_SPEED)

func _tick_timers(delta: float) -> void:
	_state_timer = maxf(_state_timer - delta, 0.0)
	_melee_cooldown_timer = maxf(_melee_cooldown_timer - delta, 0.0)
	_water_dragon_cooldown_timer = maxf(_water_dragon_cooldown_timer - delta, 0.0)
	_mist_cooldown_timer = maxf(_mist_cooldown_timer - delta, 0.0)

# ===========================================================================
# FSM — DISPATCH
# ===========================================================================
func _process_current_state(delta: float) -> void:
	match current_state:
		State.IDLE:          _state_idle(delta)
		State.PATROL:        _state_patrol(delta)
		State.CHASE:         _state_chase(delta)
		State.MELEE_ATTACK:  _state_melee_attack(delta)
		State.WATER_DRAGON:  _state_water_dragon(delta)
		State.HIDDEN_MIST:   _state_hidden_mist(delta)
		State.AMBUSH:        _state_ambush(delta)
		State.HURT:          _state_hurt(delta)
		# DEAD não tem tick (early return em _physics_process)

func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var previous: State = current_state
	_exit_state(previous)
	current_state = new_state
	_enter_state(new_state)
	state_changed.emit(previous, new_state)

func _enter_state(state: State) -> void:
	match state:
		State.MELEE_ATTACK:
			# Pipeline phased: windup → active (hitbox_melee ON) → recovery. Pro MVP a guilhotina
			# é golpe único; combo de melee_combo_count entra como polish futuro encadeando reentries.
			_state_timer = melee_windup
			_attack_phase = "windup"
			velocity.x = 0.0
			hitbox_melee.disable()  # safety: garante que entra com hitbox desligada
			_melee_cooldown_timer = melee_cooldown
			phase_changed.emit("melee_attack")
		State.WATER_DRAGON:
			# Pipeline phased: windup (esquivável — 0.80s telegrafia) → active (hitbox_water_dragon
			# como Area2D persistente wide na frente do boss) → recovery. Sem viagem de projétil —
			# refatorar pra projétil viajante é polish Semana 3 se precisar.
			_state_timer = water_dragon_windup
			_attack_phase = "windup"
			velocity.x = 0.0
			hitbox_water_dragon.disable()
			_water_dragon_cooldown_timer = water_dragon_cooldown
			phase_changed.emit("water_dragon")
		State.HIDDEN_MIST:
			# Ativa a névoa: invisível + imune + parado. Seta cooldown imediato pra não re-disparar mist em loop.
			if visual != null:
				visual.modulate.a = 0.0
			hurtbox.monitorable = false
			velocity.x = 0.0
			_state_timer = mist_duration
			_mist_cooldown_timer = mist_cooldown
			# Risada do Zabuza — AVISO SONORO de que a caçada começou (boss sumiu, prepare-se).
			# Toca AGORA (entrada na névoa), não no AMBUSH: dá ao player ~2.5s (mist_duration)
			# pra processar audio cue + se preparar pra reagir com Dash quando ele reaparecer.
			# AudioStreamPlayer2D é espacializado: posição da risada = última pos do boss
			# antes de sumir (já está na global_position do node Zabuza). Stream pré-carregado
			# via LAUGH_STREAM const + atribuído em _ready, então play() é instantâneo.
			# Garantia de "exatamente uma vez": _change_state guarda re-entrada (linha 193).
			if laugh_player != null and laugh_player.stream != null:
				laugh_player.play()
			phase_changed.emit("hidden_mist")
		State.AMBUSH:
			# Reaparece: teleporta pra ATRÁS do player, NO CHÃO, restaura opacidade e hurtbox.
			if _player != null and is_instance_valid(_player):
				# "Atrás" = lado oposto ao que o player está em relação ao boss.
				var dir_to_player: int = 1 if _player.global_position.x > global_position.x else -1
				# X: ambush_offset_x atrás do player. Y: alinhado ao Y do player + offset (default 0).
				global_position = Vector2(
					_player.global_position.x - ambush_offset_x * dir_to_player,
					_player.global_position.y + ambush_offset_y
				)
				facing_direction = dir_to_player  # vira pra encarar o player
				# Snap pro chão via raycast vertical — evita spawn flutuando ou caindo do céu
				# se o player estiver pulando ou em altura diferente.
				_snap_to_floor()
				velocity = Vector2.ZERO  # zera momentum residual da névoa pra não "voar"
			if visual != null:
				visual.modulate.a = 1.0
			hurtbox.monitorable = true
			# OBS: risada NÃO toca aqui — foi movida pra _enter_state(HIDDEN_MIST). O AMBUSH
			# é o GOLPE da caçada; a risada é o AVISO de que a caçada começou (entrada na névoa).
			phase_changed.emit("ambush")
			# Transição imediata pra MELEE_ATTACK acontece no _state_ambush (1 frame depois).
		# Outros estados (IDLE, PATROL, CHASE, MELEE_ATTACK, WATER_DRAGON, HURT, DEAD)
		# ainda não preencheram setup próprio — preencher conforme implementar cada um.

func _exit_state(state: State) -> void:
	# Cleanup defensivo: desliga hitboxes ao sair de qualquer estado de ataque. Garante que um
	# HURT/DEAD interrompendo o ataque não deixe um swing órfão ativo no mundo.
	match state:
		State.MELEE_ATTACK:
			hitbox_melee.disable()
			_attack_phase = ""
		State.WATER_DRAGON:
			hitbox_water_dragon.disable()
			_attack_phase = ""

# ===========================================================================
# ESTADOS — esqueletos a preencher
# ===========================================================================
func _state_idle(_delta: float) -> void:
	# TODO: friction decay + transição pra PATROL ou CHASE conforme detecção (similar MeleeNinja).
	pass

func _state_patrol(_delta: float) -> void:
	# TODO: patrulha simples em torno do spawn — futuro: waypoints por designer.
	pass

func _state_chase(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_change_state(State.PATROL)
		return

	var horizontal_distance: float = _player.global_position.x - global_position.x
	var abs_horizontal: float = absf(horizontal_distance)

	if abs_horizontal > 1.0:
		facing_direction = 1 if horizontal_distance > 0.0 else -1

	# Árvore de decisão por GATILHOS de prioridade decrescente:
	# GATILHO 1 (Desespero/Fuga): HP entre 30% (mist_health_threshold) e 10% (mist_hard_stop_ratio).
	#   - Acima de 30%: ainda não está em apuros, boss luta normal.
	#   - Entre 30% e 10%: vanish-and-reposition (override que ignora ranges).
	#   - Abaixo de 10%: HARD STOP — modo desespero, mist desativada, só espada até morrer.
	var hp_threshold_mist: float = float(max_health) * mist_hard_stop_ratio
	if float(current_health) > hp_threshold_mist \
			and float(current_health) <= float(max_health) * mist_health_threshold \
			and _mist_cooldown_timer <= 0.0:
		_change_state(State.HIDDEN_MIST)
		return
	# GATILHO 2 (Combate Curto): em alcance melee → MELEE_ATTACK (combo da guilhotina).
	if abs_horizontal <= melee_attack_range:
		_change_state(State.MELEE_ATTACK)
		return
	# GATILHO 3 (Combate Longo): fora do melee, em alcance jutsu + cooldown pronto → WATER_DRAGON.
	if abs_horizontal <= water_dragon_range and _water_dragon_cooldown_timer <= 0.0:
		_change_state(State.WATER_DRAGON)
		return

	# Pulo no CHASE — mesma lógica do MeleeNinja. Cobre side-bump (is_on_wall) E
	# head-bump no fundo de plataforma baixa (is_on_ceiling). Sem o ceiling check,
	# Zabuza ficaria preso embaixo de plataformas estreitas exatamente como o ninja básico.
	if is_on_floor() and (is_on_wall() or is_on_ceiling()) and _player.global_position.y < global_position.y - chase_jump_y_threshold:
		velocity.y = enemy_jump_velocity

	velocity.x = chase_speed * facing_direction

func _state_melee_attack(delta: float) -> void:
	# Trava o movimento horizontal com friction decay (parada suave em vez de slam-to-zero).
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	match _attack_phase:
		"windup":
			if _state_timer <= 0.0:
				_attack_phase = "active"
				_state_timer = melee_active
				# Espelha posição da hitbox pro lado do facing antes de ligar.
				hitbox_melee.position.x = absf(hitbox_melee.position.x) * facing_direction
				hitbox_melee.enable()
		"active":
			if _state_timer <= 0.0:
				_attack_phase = "recovery"
				_state_timer = melee_recovery
				hitbox_melee.disable()
		"recovery":
			if _state_timer <= 0.0:
				if _player != null and is_instance_valid(_player):
					_change_state(State.CHASE)
				else:
					_change_state(State.PATROL)

func _state_water_dragon(delta: float) -> void:
	# Mesmo pipeline phased do MELEE_ATTACK, mas com hitbox_water_dragon (área 200×100, dano 3,
	# wider que o melee 80×80). Persistente: a "onda" fica plantada na frente do boss durante
	# a fase active, sem viajar — esquivável pelo lado oposto ou pulando por cima.
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	match _attack_phase:
		"windup":
			if _state_timer <= 0.0:
				_attack_phase = "active"
				_state_timer = water_dragon_active
				hitbox_water_dragon.position.x = absf(hitbox_water_dragon.position.x) * facing_direction
				hitbox_water_dragon.enable()
		"active":
			if _state_timer <= 0.0:
				_attack_phase = "recovery"
				_state_timer = water_dragon_recovery
				hitbox_water_dragon.disable()
		"recovery":
			if _state_timer <= 0.0:
				if _player != null and is_instance_valid(_player):
					_change_state(State.CHASE)
				else:
					_change_state(State.PATROL)

func _state_hidden_mist(_delta: float) -> void:
	# Setup (modulate, hurtbox, timer) foi feito em _enter_state(HIDDEN_MIST).
	# Aqui só esperamos o timer expirar. Movimento de reposicionamento gradual
	# (ex: tween em direção ao player durante a névoa) é polish da Semana 3.
	velocity.x = 0.0
	if _state_timer <= 0.0:
		_change_state(State.AMBUSH)

func _state_ambush(_delta: float) -> void:
	# Setup (teleport, restaurar opacidade, reativar hurtbox) feito em _enter_state(AMBUSH).
	# AMBUSH é um estado de transição de 1 frame: imediatamente parte pro golpe surpresa
	# usando MELEE_ATTACK (conforme spec — golpe surpresa reusa a guilhotina, sem hitbox dedicada).
	_change_state(State.MELEE_ATTACK)

func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	if _state_timer <= 0.0:
		if _player != null and is_instance_valid(_player):
			_change_state(State.CHASE)
		else:
			_change_state(State.PATROL)

# ===========================================================================
# VISUAL & FEEDBACK
# ===========================================================================
func _update_visual_facing() -> void:
	if visual != null:
		visual.scale.x = float(facing_direction)

func _flash_hit() -> void:
	if visual == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	visual.modulate = Color(2.5, 0.55, 0.55, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(visual, "modulate", Color(1, 1, 1, 1), hit_flash_duration)

func _update_hp_visual() -> void:
	if hp_fill == null or max_health == 0:
		return
	var ratio: float = float(current_health) / float(max_health)
	hp_fill.scale.x = maxf(ratio, 0.001)

# ===========================================================================
# DANO E DEATH (reusando o padrão escalado do MeleeNinja)
# ===========================================================================
func _on_hit_taken(incoming_hitbox: Hitbox) -> void:
	if current_state == State.DEAD:
		return
	# Boss é IMUNE durante HIDDEN_MIST — hits passam sem efeito.
	if current_state == State.HIDDEN_MIST:
		return

	current_health = maxi(current_health - incoming_hitbox.damage, 0)
	damaged.emit(incoming_hitbox.damage, current_health)
	_update_hp_visual()
	_flash_hit()

	if current_health <= 0:
		_die()
		return

	# Tier de peso (mesmo padrão do MeleeNinja).
	var is_heavy: bool = incoming_hitbox.damage >= heavy_hit_threshold
	var knockback_mult: float = heavy_hit_knockback_multiplier if is_heavy else 1.0
	var stun_mult: float = heavy_hit_stun_multiplier if is_heavy else 1.0
	var scaled_stun: float = stun_duration * stun_mult

	if is_heavy:
		_apply_hitstop(heavy_hit_hitstop_duration)

	var attack_dir: float = _resolve_attack_direction(incoming_hitbox)
	velocity.x = hit_knockback_speed * knockback_mult * attack_dir

	# Fix bouncing: estende stun se já em HURT (mesmo padrão do MeleeNinja).
	if current_state == State.HURT:
		_state_timer = minf(_state_timer + scaled_stun, stun_extension_cap)
	else:
		_change_state(State.HURT)
		_state_timer = scaled_stun

func _resolve_attack_direction(hb: Hitbox) -> float:
	if hb is Shuriken:
		var sx: float = signf((hb as Shuriken).direction.x)
		return sx if sx != 0.0 else 1.0
	var local_sign: float = signf(hb.position.x)
	if local_sign == 0.0:
		return 1.0 if global_position.x >= hb.global_position.x else -1.0
	return local_sign

func _die() -> void:
	_change_state(State.DEAD)
	visible = false
	hurtbox.monitorable = false
	velocity = Vector2.ZERO
	# KILL SWITCH do áudio: a risada do HIDDEN_MIST tem ~4s de duração; se o boss morre
	# durante esse clip, sem stop() ele continua tocando 2-3s após a morte (não é loop —
	# loop_mode=0 no .import — só é o clip longo). stop() corta instantaneamente.
	# stream = null garante que nenhuma chamada acidental de play() futura toque algo
	# (defensivo: boss não re-entra HIDDEN_MIST após DEAD por causa do early return em
	# _physics_process, mas explicita a intenção "áudio dele acabou de vez").
	if laugh_player != null:
		laugh_player.stop()
		laugh_player.stream = null
	died.emit()
	phase_changed.emit("death")
	# TODO Semana 3: trigger END_OF_DEMO — entrega do pergaminho, frase exclusiva, cinemática.
	# Sem respawn no MVP — boss morre uma vez só.

# ===========================================================================
# KILL ZONE — mesmo padrão do MeleeNinja (knockback pra fora do mapa = morte limpa)
# ===========================================================================
func _check_kill_zone() -> void:
	if position.y > kill_zone_y:
		_die()

# ===========================================================================
# SNAP TO FLOOR — usado após teleportes (AMBUSH) pra garantir que o boss apareça
# colado no chão, não flutuando ou caindo do céu. Raycast vertical pra baixo
# contra o mundo (collision_mask = 1), e cola a y na superfície encontrada.
# ===========================================================================
func _snap_to_floor() -> void:
	var space_state := get_world_2d().direct_space_state
	# Começa um pouco acima da posição atual pra cobrir o caso de já estar
	# tangenciando o piso (sem isso, o ray pode "começar dentro" e falhar).
	var from: Vector2 = global_position + Vector2(0, -8.0)
	var to: Vector2 = global_position + Vector2(0, 400.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		global_position.y = result["position"].y

# ===========================================================================
# HITSTOP — duplicado do MeleeNinja (tuning independente; considerar autoload futuro)
# ===========================================================================
func _apply_hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	if Engine.time_scale == 0.0:
		return
	Engine.time_scale = 0.0
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hitstop)

func _end_hitstop() -> void:
	Engine.time_scale = 1.0

# ===========================================================================
# PERCEPÇÃO
# ===========================================================================
func _on_body_entered_detection(body: Node2D) -> void:
	# DEBUG: imprime SEMPRE que body_entered dispara — tracking de detecção.
	# Se vê esta print no console, mask+layer estão certas e o Player ENTROU na CircleShape2D.
	# Se NÃO vê, ou (a) Player nunca entrou no radius, ou (b) mask/layer não batem.
	print("[ZABUZA DETECT] body_entered fired | body=", body, " | is_player=", body is PlayerController, " | current_state=", State.keys()[current_state])
	if body is PlayerController:
		_player = body
		if current_state == State.PATROL or current_state == State.IDLE:
			print("[ZABUZA DETECT] → transição pra CHASE")
			_change_state(State.CHASE)

func _on_body_exited_detection(body: Node2D) -> void:
	if body == _player:
		_player = null
		# Se estava CHASE, volta a PATROL. Outros estados (MELEE_ATTACK, WATER_DRAGON, etc.)
		# completam naturalmente e tomam decisão própria no fim.
		if current_state == State.CHASE:
			_change_state(State.PATROL)

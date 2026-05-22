class_name MeleeNinja
extends CharacterBody2D

## Inimigo básico melee — FSM com IDLE / PATROL / CHASE / ATTACK / HURT / DEAD.
## - Patrulha em torno do spawn point dentro de uma janela horizontal.
## - Detecta Player via Area2D circular e parte pro CHASE.
## - Em alcance de attack_range, executa ataque em 3 fases (windup → active → recovery) + cooldown.
## - Ao tomar dano: flash vermelho, knockback horizontal pra longe do atacante, stun curto, depois retoma.
## - Ao morrer: invisível por respawn_delay, depois renasce no spawn cheio de vida.

# ---------------------------------------------------------------------------
# CONSTANTES DE FÍSICA
# ---------------------------------------------------------------------------
const GRAVITY: float = 1400.0
const MAX_FALL_SPEED: float = 900.0

# ---------------------------------------------------------------------------
# PARÂMETROS (ajustáveis no editor)
# ---------------------------------------------------------------------------
@export_group("Vida e Dano")
@export var max_health: int = 5
@export var attack_damage: int = 1                  ## Usado pelo Hitbox melee quando o player tiver hurtbox.

@export_group("Movimento")
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 160.0
@export var ground_friction: float = 2000.0
@export var enemy_jump_velocity: float = -650.0   ## Impulso Y inicial do pulo em CHASE. Negativo = pra cima. Calibrado pra GRAVITY=1400 (pico ~151px).
@export var recoil_speed: float = 120.0           ## Velocidade horizontal do recuo quando o player gruda no ponto cego (< 8px). Cria espaço pra atacar de novo.

@export_group("Patrol")
@export var patrol_distance: float = 220.0          ## Distância máxima do spawn antes de virar.
@export var patrol_pause_min: float = 0.5           ## IDLE entre pernas de patrol (mínimo).
@export var patrol_pause_max: float = 1.5           ## IDLE entre pernas de patrol (máximo).

@export_group("Percepção")
@export var detection_radius: float = 280.0         ## Sincronizado com o CircleShape2D em _ready.
@export var attack_range: float = 60.0              ## Distância horizontal pra entrar em ATTACK.

@export_group("Combate")
@export var attack_windup: float = 0.30             ## Telegrafia antes da hitbox ligar.
@export var attack_active: float = 0.15             ## Tempo de hitbox ativa.
@export var attack_recovery: float = 0.35           ## Recuperação após hitbox.
@export var attack_cooldown: float = 0.8            ## Tempo mínimo entre ataques.

@export_group("Hit Feel")
@export var hit_flash_duration: float = 0.12        ## Duração do flash vermelho.
@export var hit_knockback_speed: float = 280.0      ## Velocidade horizontal do tranco ao tomar dano.
@export var stun_duration: float = 0.25             ## Tempo travado em HURT antes de retomar.

@export_group("Respawn")
@export var respawn_delay: float = 2.0
@export var kill_zone_y: float = 1000.0           ## Limite vertical inferior. Se y ultrapassar → _die() → respawn em _spawn_position após respawn_delay. Mesmo flow da morte por HP.

# ---------------------------------------------------------------------------
# MÁQUINA DE ESTADOS
# ---------------------------------------------------------------------------
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	HURT,
	DEAD,
}

# ---------------------------------------------------------------------------
# SIGNALS (ganchos para UI, áudio, VFX)
# ---------------------------------------------------------------------------
signal damaged(amount: int, remaining: int)
signal died
signal respawned
signal state_changed(previous_state: State, new_state: State)

# ---------------------------------------------------------------------------
# ESTADO INTERNO
# ---------------------------------------------------------------------------
var current_state: State = State.IDLE
var current_health: int = 0
var facing_direction: int = 1

var _spawn_position: Vector2 = Vector2.ZERO
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _attack_phase: String = ""              ## "windup" / "active" / "recovery"
var _player: Node2D = null
var _hit_flash_tween: Tween = null

# ---------------------------------------------------------------------------
# NÓS DA CENA
# ---------------------------------------------------------------------------
@onready var visual: Node2D = $Visual
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var detection_area: Area2D = $DetectionArea
@onready var hp_fill: Polygon2D = $HPBar/Fill

# ===========================================================================
# CICLO DE VIDA
# ===========================================================================
func _ready() -> void:
	# Força o motor a manter o corpo grudado no chão mesmo em transições de superfície
	# ou quando o head do ninja toca a parte de baixo de plataformas flutuantes — sem isso
	# o engine pode empurrar o corpo pra cima na tentativa de resolver overlap vertical.
	floor_snap_length = 12.0

	current_health = max_health
	_spawn_position = position
	_sync_detection_shape()

	hurtbox.hit_taken.connect(_on_hit_taken)
	detection_area.body_entered.connect(_on_body_entered_detection)
	detection_area.body_exited.connect(_on_body_exited_detection)

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
		# Trava no chão: zera velocity.y pra eliminar o jitter por acúmulo após landing.
		# Sem isso, frames de borda em que is_on_floor() oscila deixam velocity.y crescer e o move_and_slide bate/quica.
		velocity.y = 0.0
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

func _tick_timers(delta: float) -> void:
	_state_timer = maxf(_state_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)

func _sync_detection_shape() -> void:
	## Aplica detection_radius no CircleShape2D filho da DetectionArea, garantindo
	## que cada instância tenha seu shape próprio (duplicate evita compartilhamento).
	var det_shape_node: CollisionShape2D = detection_area.get_node("DetectionShape") as CollisionShape2D
	if det_shape_node == null:
		return
	if not (det_shape_node.shape is CircleShape2D):
		return
	var unique_shape: CircleShape2D = det_shape_node.shape.duplicate() as CircleShape2D
	unique_shape.radius = detection_radius
	det_shape_node.shape = unique_shape

# ===========================================================================
# FSM — DISPATCH
# ===========================================================================
func _process_current_state(delta: float) -> void:
	match current_state:
		State.IDLE:   _state_idle(delta)
		State.PATROL: _state_patrol(delta)
		State.CHASE:  _state_chase(delta)
		State.ATTACK: _state_attack(delta)
		State.HURT:   _state_hurt(delta)
		# DEAD não tem tick (return early em _physics_process).

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
		State.IDLE:
			_state_timer = randf_range(patrol_pause_min, patrol_pause_max)
			velocity.x = 0.0
		State.PATROL:
			_state_timer = 0.0
			# Vira o nariz pro lado em que ainda há espaço de patrulha.
			var offset: float = position.x - _spawn_position.x
			if offset > 0.0:
				facing_direction = -1
			elif offset < 0.0:
				facing_direction = 1
		State.CHASE:
			pass  # Tick gerencia movimento e transição pra ATTACK.
		State.ATTACK:
			_state_timer = attack_windup
			_attack_phase = "windup"
			velocity.x = 0.0
			hitbox.disable()
		State.HURT:
			_state_timer = stun_duration
			hitbox.disable()
			# velocity.x foi setado em _on_hit_taken ANTES desta transição (knockback).
		State.DEAD:
			visible = false
			hurtbox.monitorable = false
			velocity = Vector2.ZERO
			died.emit()
			_respawn_after_delay()

func _exit_state(state: State) -> void:
	match state:
		State.ATTACK:
			hitbox.disable()
			_attack_phase = ""

# ===========================================================================
# ESTADOS INDIVIDUAIS
# ===========================================================================
func _state_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	if _player != null and is_instance_valid(_player):
		_change_state(State.CHASE)
		return

	if _state_timer <= 0.0:
		_change_state(State.PATROL)

func _state_patrol(_delta: float) -> void:
	velocity.x = patrol_speed * facing_direction

	if _player != null and is_instance_valid(_player):
		_change_state(State.CHASE)
		return

	# Limites de patrulha relativos ao spawn.
	var offset: float = position.x - _spawn_position.x
	if facing_direction > 0 and offset >= patrol_distance:
		facing_direction = -1
		_change_state(State.IDLE)
		return
	if facing_direction < 0 and offset <= -patrol_distance:
		facing_direction = 1
		_change_state(State.IDLE)
		return

	# Vira ao bater em parede (mesma reação que limite de patrol).
	if is_on_wall():
		facing_direction = -facing_direction
		_change_state(State.IDLE)

func _state_chase(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_change_state(State.PATROL)
		return

	var horizontal_distance: float = _player.global_position.x - global_position.x
	var abs_horizontal: float = absf(horizontal_distance)

	# Atualiza o facing pra apontar pro player.
	if abs_horizontal > 1.0:
		facing_direction = 1 if horizontal_distance > 0.0 else -1

	# Ponto cego: player gruda em cima do ninja (< 8px). A Hitbox melee fica em +40 de offset,
	# então um ATTACK aqui whiff. Recua pra criar espaço e re-engajar no próximo frame.
	if abs_horizontal < 8.0:
		velocity.x = -recoil_speed * facing_direction
		return

	# Em alcance e fora de cooldown → ATTACK.
	if abs_horizontal < attack_range and _attack_cooldown_timer <= 0.0:
		_change_state(State.ATTACK)
		return

	# Pulo: no chão + esbarrando em parede/plataforma + player ≥ 50px acima.
	# Mantém o ninja em CHASE durante todo o arco — _apply_gravity já cuida do down naturalmente.
	if is_on_floor() and is_on_wall() and _player.global_position.y < global_position.y - 50.0:
		velocity.y = enemy_jump_velocity

	velocity.x = chase_speed * facing_direction

func _state_attack(delta: float) -> void:
	# Decai velocidade horizontal durante o ataque (fica "ancorado" mas suave).
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	match _attack_phase:
		"windup":
			if _state_timer <= 0.0:
				_attack_phase = "active"
				_state_timer = attack_active
				_enable_attack_hitbox()
		"active":
			if _state_timer <= 0.0:
				_attack_phase = "recovery"
				_state_timer = attack_recovery
				hitbox.disable()
		"recovery":
			if _state_timer <= 0.0:
				_attack_cooldown_timer = attack_cooldown
				if _player != null and is_instance_valid(_player):
					_change_state(State.CHASE)
				else:
					_change_state(State.PATROL)

func _state_hurt(delta: float) -> void:
	# Friction decai o knockback ao longo do stun.
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	if _state_timer <= 0.0:
		if _player != null and is_instance_valid(_player):
			_change_state(State.CHASE)
		else:
			_change_state(State.PATROL)

# ===========================================================================
# HELPERS DE COMBATE
# ===========================================================================
func _enable_attack_hitbox() -> void:
	hitbox.position.x = absf(hitbox.position.x) * facing_direction
	hitbox.enable()

# ===========================================================================
# VISUAL
# ===========================================================================
func _update_visual_facing() -> void:
	if visual != null:
		visual.scale.x = float(facing_direction)

func _flash_hit() -> void:
	if visual == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	visual.modulate = Color(2.5, 0.55, 0.55, 1.0)  # bright red
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(visual, "modulate", Color(1, 1, 1, 1), hit_flash_duration)

func _update_hp_visual() -> void:
	if hp_fill == null or max_health == 0:
		return
	var ratio: float = float(current_health) / float(max_health)
	hp_fill.scale.x = maxf(ratio, 0.001)

# ===========================================================================
# DANO E RESPAWN
# ===========================================================================
func _on_hit_taken(incoming_hitbox: Hitbox) -> void:
	if current_state == State.DEAD:
		return

	current_health = maxi(current_health - incoming_hitbox.damage, 0)
	damaged.emit(incoming_hitbox.damage, current_health)
	_update_hp_visual()
	_flash_hit()

	if current_health <= 0:
		_die()
		return

	# Knockback pra longe da direção do ataque.
	var attack_dir: float = _resolve_attack_direction(incoming_hitbox)
	velocity.x = hit_knockback_speed * attack_dir
	_change_state(State.HURT)

func _resolve_attack_direction(hb: Hitbox) -> float:
	## Retorna o sinal (+1 ou -1) da direção em que o golpe empurra o alvo.
	## Shuriken usa o vetor direction da própria projétil;
	## hitboxes melee usam signf(hb.position.x), que já reflete o facing do atacante
	## (PlayerController seta hitbox.position.x = abs * facing_direction antes de enable()).
	if hb is Shuriken:
		var sx: float = signf((hb as Shuriken).direction.x)
		return sx if sx != 0.0 else 1.0
	var local_sign: float = signf(hb.position.x)
	if local_sign == 0.0:
		# Fallback defensivo se a hitbox estiver exatamente em cima do parent.
		return 1.0 if global_position.x >= hb.global_position.x else -1.0
	return local_sign

func _check_kill_zone() -> void:
	## Knockback do Rasengan ou queda de plataforma pode empurrar o ninja pra fora do mapa.
	## Sem esta checagem, o engine segue simulando gravidade infinitamente e o ninja
	## "assombra o limbo" — vivo no Y=10000+, ainda gastando frames de física.
	## Reusa o flow de morte por HP: _die() → DEAD → invisível por respawn_delay → renasce no _spawn_position com HP cheio.
	if position.y > kill_zone_y:
		_die()

func _die() -> void:
	_change_state(State.DEAD)

func _respawn_after_delay() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return

	current_health = max_health
	position = _spawn_position
	velocity = Vector2.ZERO
	facing_direction = 1
	_attack_cooldown_timer = 0.0
	_attack_phase = ""
	visible = true
	hurtbox.monitorable = true

	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	if visual != null:
		visual.modulate = Color(1, 1, 1, 1)

	_update_hp_visual()
	_change_state(State.PATROL)
	respawned.emit()

# ===========================================================================
# PERCEPÇÃO — DetectionArea (Area2D circular)
# ===========================================================================
## A detection_area tem mask = 1 (world layer). Captura qualquer body em layer 1
## (player, floor, dummy, plataformas) e filtra por classe aqui — evita acrescentar
## uma layer dedicada de player_body só pra isso e mantém o setup existente intacto.
func _on_body_entered_detection(body: Node2D) -> void:
	if body is PlayerController:
		_player = body
		# Interrompe patrol/idle e parte pro chase imediatamente.
		if current_state == State.PATROL or current_state == State.IDLE:
			_change_state(State.CHASE)

func _on_body_exited_detection(body: Node2D) -> void:
	if body == _player:
		_player = null
		# Se estava chase, volta a patrulhar. ATTACK e HURT seguem até naturalmente expirarem.
		if current_state == State.CHASE:
			_change_state(State.PATROL)

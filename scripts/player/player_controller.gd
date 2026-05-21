class_name PlayerController
extends CharacterBody2D

## PlayerController — Naruto: Os Pergaminhos de Asura
## Semana 1 — Core Gameplay: movimento, pulo (coyote + buffer) e máquina de estados.

# ---------------------------------------------------------------------------
# CONSTANTES DE FÍSICA
# ---------------------------------------------------------------------------
const MAX_FALL_SPEED: float = 900.0

# ---------------------------------------------------------------------------
# PARÂMETROS DE MOVIMENTO (ajustáveis no editor)
# ---------------------------------------------------------------------------
@export_group("Movimento")
@export var move_speed: float = 320.0
@export var ground_acceleration: float = 2800.0
@export var ground_friction: float = 3200.0
@export var air_acceleration: float = 1600.0
@export var air_friction: float = 900.0

@export_group("Pulo")
@export var gravity: float = 1200.0            ## Aceleração para baixo em px/s². Menor = pulo "flutuante" (estilo ninja), maior = "punchy".
@export var jump_velocity: float = -650.0
@export var jump_cut_multiplier: float = 0.45  ## Variable jump height: ao soltar pulo, corta velocidade ascendente.
@export var coyote_time: float = 0.12          ## Janela em segundos para pular após sair de uma plataforma.
@export var jump_buffer_time: float = 0.15     ## Janela em segundos para registrar pulo antes de tocar o chão.
@export var max_jumps: int = 2                 ## Total de pulos consumíveis desde o último contato com o chão. 1 = sem double jump; 2 = pulo + double; 3+ = multi-air-jump.

@export_group("Chakra")
@export var max_chakra: float = 100.0
@export var chakra_regen_rate: float = 6.0          ## Regen passiva por segundo.
@export var chakra_charge_rate: float = 35.0        ## Regen ativa ao segurar `chakra_charge`.
@export var rasengan_chakra_cost: float = 40.0

@export_group("Combate")
@export var light_attack_duration: float = 0.30
@export var heavy_attack_duration: float = 0.50
@export var special_duration: float = 0.65

@export_group("Respawn")
@export var kill_zone_y: float = 1000.0    ## Limite vertical inferior. Se position.y passar disso, o player respawna em _spawn_position.

# ---------------------------------------------------------------------------
# MÁQUINA DE ESTADOS
# ---------------------------------------------------------------------------
enum State {
	IDLE,
	MOVE,
	JUMP,
	FALL,
	CROUCH,
	ATTACK,
	SPECIAL,
	CHAKRA_CHARGE,
}

# ---------------------------------------------------------------------------
# SIGNALS (ganchos para UI, animação, VFX, áudio etc.)
# ---------------------------------------------------------------------------
signal state_changed(previous_state: State, new_state: State)
signal chakra_changed(current: float, maximum: float)
signal jumped(jump_number: int) ## 1 = pulo de chão/coyote, 2+ = pulos aéreos (double jump e além).
signal landed
signal attack_started(kind: String)   ## "light" | "heavy"
signal attack_ended(kind: String)
signal special_started
signal special_ended
signal facing_flipped(direction: int) ## 1 = direita, -1 = esquerda
signal respawned(at_position: Vector2) ## Disparado quando o player cruza a kill zone e é reposicionado.

# ---------------------------------------------------------------------------
# ESTADO INTERNO
# ---------------------------------------------------------------------------
var current_state: State = State.IDLE
var current_chakra: float = 0.0
var facing_direction: int = 1

# Timers (em segundos, contagem regressiva)
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _state_timer: float = 0.0

# Contador de pulos desde o último contato com o chão (reseta em is_on_floor()).
var _jumps_made: int = 0

# Flags auxiliares
var _current_attack_kind: String = ""

# Posição capturada em _ready; alvo do respawn quando o player cruza a kill zone.
var _spawn_position: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# NÓS (placeholders — serão ligados quando a cena Player.tscn for criada)
# ---------------------------------------------------------------------------
# @onready var animation_player: AnimationPlayer = $AnimationPlayer
# @onready var sprite: Sprite2D = $Sprite2D
# @onready var hitbox_light: Area2D = $Hitboxes/Light
# @onready var hitbox_heavy: Area2D = $Hitboxes/Heavy
# @onready var hitbox_special: Area2D = $Hitboxes/Special

# ===========================================================================
# CICLO DE VIDA
# ===========================================================================
func _ready() -> void:
	current_chakra = max_chakra
	chakra_changed.emit(current_chakra, max_chakra)
	_spawn_position = position
	_enter_state(State.IDLE)

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_buffer_jump_input()
	_apply_gravity(delta)

	var was_on_floor: bool = is_on_floor()
	_process_current_state(delta)
	_update_facing()
	_regenerate_chakra(delta)

	move_and_slide()

	if is_on_floor() and not was_on_floor:
		landed.emit()

	_check_kill_zone()

# ===========================================================================
# TIMERS & BUFFERS
# ===========================================================================
func _tick_timers(delta: float) -> void:
	# No chão: coyote fica cheio e o contador de pulos zera (libera double jump após pousar).
	# No ar: coyote decai; quando chega a 0, só o contador de pulos governa novos saltos.
	if is_on_floor():
		_coyote_timer = coyote_time
		_jumps_made = 0
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_state_timer = maxf(_state_timer - delta, 0.0)

func _buffer_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

# ===========================================================================
# FÍSICA BASE
# ===========================================================================
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

func _get_move_input() -> float:
	return Input.get_axis("move_left", "move_right")

func _apply_horizontal_movement(delta: float, axis: float) -> void:
	var target_speed: float = axis * move_speed
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration
	var fric: float = ground_friction if is_on_floor() else air_friction

	if absf(axis) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

func _update_facing() -> void:
	var new_dir: int = facing_direction
	if velocity.x > 5.0:
		new_dir = 1
	elif velocity.x < -5.0:
		new_dir = -1
	if new_dir != facing_direction:
		facing_direction = new_dir
		facing_flipped.emit(facing_direction)

# ===========================================================================
# JUMP LOGIC (coyote + buffer)
# ===========================================================================
func _has_buffered_jump() -> bool:
	if _jump_buffer_timer <= 0.0:
		return false
	# Pulo do chão / coyote: ainda dentro da janela após sair de uma plataforma.
	if _coyote_timer > 0.0:
		return true
	# Pulo aéreo (double jump em diante): tem créditos sobrando no contador.
	return _jumps_made < max_jumps

func _consume_jump() -> void:
	velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_jumps_made += 1
	jumped.emit(_jumps_made)

# ===========================================================================
# CHAKRA
# ===========================================================================
func _regenerate_chakra(delta: float) -> void:
	if current_state == State.CHAKRA_CHARGE:
		return # Recarga ativa cuidada no próprio estado.
	if current_chakra >= max_chakra:
		return
	current_chakra = minf(current_chakra + chakra_regen_rate * delta, max_chakra)
	chakra_changed.emit(current_chakra, max_chakra)

func _spend_chakra(amount: float) -> bool:
	if current_chakra < amount:
		return false
	current_chakra -= amount
	chakra_changed.emit(current_chakra, max_chakra)
	return true

func has_chakra_for_special() -> bool:
	return current_chakra >= rasengan_chakra_cost

# ===========================================================================
# KILL ZONE / RESPAWN
# ===========================================================================
func _check_kill_zone() -> void:
	if position.y > kill_zone_y:
		_respawn()

func _respawn() -> void:
	position = _spawn_position
	velocity = Vector2.ZERO
	_jumps_made = 0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_state_timer = 0.0
	current_chakra = max_chakra
	chakra_changed.emit(current_chakra, max_chakra)
	_change_state(State.IDLE)
	respawned.emit(_spawn_position)

# ===========================================================================
# MÁQUINA DE ESTADOS — DISPATCH
# ===========================================================================
func _process_current_state(delta: float) -> void:
	match current_state:
		State.IDLE:          _state_idle(delta)
		State.MOVE:          _state_move(delta)
		State.JUMP:          _state_jump(delta)
		State.FALL:          _state_fall(delta)
		State.CROUCH:        _state_crouch(delta)
		State.ATTACK:        _state_attack(delta)
		State.SPECIAL:       _state_special(delta)
		State.CHAKRA_CHARGE: _state_chakra_charge(delta)

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
		State.JUMP:
			_consume_jump()
			_play_animation("jump")
		State.FALL:
			_play_animation("fall")
		State.IDLE:
			_play_animation("idle")
		State.MOVE:
			_play_animation("run")
		State.CROUCH:
			velocity.x = 0.0
			_play_animation("crouch")
		State.ATTACK:
			_state_timer = light_attack_duration if _current_attack_kind == "light" else heavy_attack_duration
			attack_started.emit(_current_attack_kind)
			_enable_attack_hitbox(_current_attack_kind)
			_play_animation("attack_" + _current_attack_kind)
		State.SPECIAL:
			_state_timer = special_duration
			_spend_chakra(rasengan_chakra_cost)
			special_started.emit()
			_enable_attack_hitbox("special")
			_play_animation("rasengan")
		State.CHAKRA_CHARGE:
			velocity.x = 0.0
			_play_animation("chakra_charge")

func _exit_state(state: State) -> void:
	match state:
		State.ATTACK:
			_disable_attack_hitbox(_current_attack_kind)
			attack_ended.emit(_current_attack_kind)
			_current_attack_kind = ""
		State.SPECIAL:
			_disable_attack_hitbox("special")
			special_ended.emit()

# ===========================================================================
# ESTADOS INDIVIDUAIS
# ===========================================================================
func _state_idle(delta: float) -> void:
	_apply_horizontal_movement(delta, 0.0)

	if _try_start_attack():        return
	if _try_start_special():       return
	if _try_start_chakra_charge(): return
	if _has_buffered_jump():       _change_state(State.JUMP); return
	if not is_on_floor():          _change_state(State.FALL); return
	if Input.is_action_pressed("crouch"): _change_state(State.CROUCH); return

	if absf(_get_move_input()) > 0.01:
		_change_state(State.MOVE)

func _state_move(delta: float) -> void:
	var axis: float = _get_move_input()
	_apply_horizontal_movement(delta, axis)

	if _try_start_attack():        return
	if _try_start_special():       return
	if _has_buffered_jump():       _change_state(State.JUMP); return
	if not is_on_floor():          _change_state(State.FALL); return
	if Input.is_action_pressed("crouch"): _change_state(State.CROUCH); return

	if absf(axis) < 0.01:
		_change_state(State.IDLE)

func _state_jump(delta: float) -> void:
	_apply_horizontal_movement(delta, _get_move_input())

	# Variable jump height: solta cedo = pulo curto.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	# Double jump durante a subida: consome um crédito e relança sem trocar de estado.
	if _has_buffered_jump():
		_consume_jump()
		_play_animation("jump")
		return

	if _try_start_attack():
		return

	if velocity.y >= 0.0:
		_change_state(State.FALL)

func _state_fall(delta: float) -> void:
	_apply_horizontal_movement(delta, _get_move_input())

	# Permite jump bufferizado durante coyote time (pulo após sair de plataforma).
	if _has_buffered_jump():
		_change_state(State.JUMP)
		return

	if _try_start_attack():
		return

	if is_on_floor():
		if absf(_get_move_input()) > 0.01:
			_change_state(State.MOVE)
		else:
			_change_state(State.IDLE)

func _state_crouch(delta: float) -> void:
	_apply_horizontal_movement(delta, 0.0)

	if not is_on_floor():
		_change_state(State.FALL)
		return

	if not Input.is_action_pressed("crouch"):
		_change_state(State.IDLE)
		return

	# Permite atacar agachado — fica como gancho para attack_crouch futuramente.
	if _try_start_attack():
		return

func _state_attack(delta: float) -> void:
	_apply_horizontal_movement(delta, 0.0) # ataque "trava" o personagem; será revisitado em combate aéreo.

	if _state_timer <= 0.0:
		_change_state(State.FALL if not is_on_floor() else State.IDLE)

func _state_special(delta: float) -> void:
	_apply_horizontal_movement(delta, 0.0)

	if _state_timer <= 0.0:
		_change_state(State.FALL if not is_on_floor() else State.IDLE)

func _state_chakra_charge(delta: float) -> void:
	velocity.x = 0.0
	current_chakra = minf(current_chakra + chakra_charge_rate * delta, max_chakra)
	chakra_changed.emit(current_chakra, max_chakra)

	if not Input.is_action_pressed("chakra_charge"):
		_change_state(State.IDLE)
		return

	# Interrupções permitidas durante a recarga:
	if _has_buffered_jump():
		_change_state(State.JUMP); return
	if not is_on_floor():
		_change_state(State.FALL); return

# ===========================================================================
# HELPERS DE TRANSIÇÃO (reduzem duplicação entre IDLE/MOVE/CROUCH)
# ===========================================================================
func _try_start_attack() -> bool:
	if Input.is_action_just_pressed("attack_light"):
		_current_attack_kind = "light"
		_change_state(State.ATTACK)
		return true
	if Input.is_action_just_pressed("attack_heavy"):
		_current_attack_kind = "heavy"
		_change_state(State.ATTACK)
		return true
	return false

func _try_start_special() -> bool:
	if Input.is_action_just_pressed("special") and has_chakra_for_special():
		_change_state(State.SPECIAL)
		return true
	return false

func _try_start_chakra_charge() -> bool:
	if Input.is_action_pressed("chakra_charge") and is_on_floor():
		_change_state(State.CHAKRA_CHARGE)
		return true
	return false

# ===========================================================================
# GANCHOS — ANIMAÇÃO (preencher quando AnimationPlayer existir)
# ===========================================================================
func _play_animation(_anim_name: String) -> void:
	# TODO Semana 2: conectar a AnimationPlayer / AnimatedSprite2D.
	# Ex.: if animation_player and animation_player.has_animation(_anim_name):
	#          animation_player.play(_anim_name)
	pass

# ===========================================================================
# GANCHOS — HITBOXES DE ATAQUE (preencher quando Player.tscn tiver Area2Ds)
# ===========================================================================
func _enable_attack_hitbox(_kind: String) -> void:
	# TODO Semana 2: ativar Area2D correspondente (light / heavy / special),
	# orientando-o conforme `facing_direction`.
	pass

func _disable_attack_hitbox(_kind: String) -> void:
	# TODO Semana 2: desativar Area2D correspondente.
	pass

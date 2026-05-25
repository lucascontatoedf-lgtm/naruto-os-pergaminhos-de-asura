class_name PlayerController
extends CharacterBody2D

## PlayerController — Naruto: Os Pergaminhos de Asura
## Semana 1 — Core Gameplay: movimento, pulo (coyote + buffer) e máquina de estados.

# ---------------------------------------------------------------------------
# CONSTANTES DE FÍSICA
# ---------------------------------------------------------------------------
const MAX_FALL_SPEED: float = 900.0
const SHURIKEN_SCENE: PackedScene = preload("res://scenes/entities/shuriken.tscn")

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
@export var chakra_regen_rate: float = 8.0          ## Regen passiva por segundo (bumpado pra acompanhar a economia 40/70 dos golpes).
@export var chakra_charge_rate: float = 35.0        ## Regen ativa ao segurar `chakra_charge`.
@export var rasengan_chakra_cost: float = 70.0      ## Custo do Rasengan (L). Balanceado contra regen 8/s + chakra_charge ativo.
@export var shuriken_chakra_cost: float = 40.0      ## Custo por arremesso (J). Economia tight — força escolha entre stockar pra Rasengan ou gastar em shurikens.

@export_group("Combate")
@export var light_attack_duration: float = 0.30
@export var heavy_attack_duration: float = 0.50
@export var special_duration: float = 0.65
@export var rasengan_dash_speed: float = 1300.0      ## Impulso inicial de velocity.x no Rasengan; decai pela friction natural do chão. Calibrado pro ritmo dinâmico atual.
@export var attack_cancel_window_ratio: float = 0.25 ## Fração FINAL da duração em que a trava de movimento abre e o player aceita input de novo.
@export var combo_dash_speed: float = 250.0          ## Micro-impulso de velocity.x a cada hit conectado no combo. Decai pela friction em poucos frames — dá um "tranco" sutil de ganho de terreno.

@export_group("Dash")
@export var dash_distance: float = 200.0              ## Distância percorrida em pixels (não velocidade). Speed é calculado em runtime: dash_distance / dash_duration. Spec do jogador: dash = 200px.
@export var dash_duration: float = 0.20               ## Duração do dash em segundos. Spec do jogador: timer rígido de 0.2s. Speed efetivo = dash_distance / dash_duration (default 200 / 0.20 = 1000 px/s — visível mas rápido).
@export var dash_double_tap_window: float = 0.20      ## Janela em segundos entre o 1º e o 2º tap na MESMA direção. Acima disso, considera-se tap solo (cancelado).
@export var dash_cooldown: float = 0.40               ## Tempo mínimo entre dashes. Impede spam de double-tap encadeado.
@export var dash_iframe_buffer: float = 0.05          ## Margem de i-frames APÓS o dash terminar — janela pra perdoar reação atrasada do player vs. AMBUSH do Zabuza.

@export_group("Wall Jump")
@export var wall_slide_gravity_multiplier: float = 0.15   ## Multiplicador da gravidade durante WALL_SLIDE. 0.15 = cai a 15% da velocidade normal — slide bem lento, estilo Hollow Knight. Valor anterior (0.30) ficou rápido demais no playtest.
@export var wall_jump_velocity: Vector2 = Vector2(450, -550)  ## Impulso do wall jump. X = força lateral pra LONGE da parede (mirrorado por -_wall_normal). Y = pulo vertical (negativo = up). Override pós-_consume_jump.
@export var wall_jump_lock_duration: float = 0.15         ## Janela após wall jump em que NÃO pode reentrar em WALL_SLIDE. Impede grudar na mesma parede instantaneamente.

@export_group("Vida")
@export var max_health: int = 5                        ## Vida total. Quando current_health chega a 0 → DEATH → respawn.
@export var hurt_stun_duration: float = 0.4            ## Tempo travado em HURT (frames de hitstun) antes de retomar IDLE/FALL.
@export var hurt_knockback_speed: float = 350.0        ## Velocidade horizontal do tranco ao tomar dano.
@export var invulnerability_duration: float = 0.8      ## I-frames pós-HURT — hits adicionais são ignorados durante esse tempo.
@export var death_respawn_delay: float = 1.5           ## Tempo travado em DEATH antes do respawn automático.

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
	DASH,           ## Disparado por double-tap em move_left/right. Override horizontal + i-frames + sem gravidade.
	WALL_SLIDE,     ## Tocando parede no ar + segurando direção contra ela. Gravidade reduzida, recarga de double jump, pode lançar wall jump.
	ATTACK,
	SPECIAL,
	CHAKRA_CHARGE,
	HURT,
	DEATH,
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
signal health_changed(current: int, maximum: int)        ## Para HUD de vida — emitido sempre que current_health muda.
signal player_hurt(damage: int, source_position: Vector2) ## Emitido ao entrar em HURT (não em DEATH).
signal player_died                                        ## Emitido ao entrar em DEATH (vida chegou a 0).

# ---------------------------------------------------------------------------
# ESTADO INTERNO
# ---------------------------------------------------------------------------
var current_state: State = State.IDLE
var current_chakra: float = 0.0
var current_health: int = 0
var facing_direction: int = 1

# Timers (em segundos, contagem regressiva)
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _state_timer: float = 0.0
var _invulnerability_timer: float = 0.0     ## I-frames pós-HURT: enquanto > 0, hits são ignorados em _on_hit_taken.

# Contador de pulos desde o último contato com o chão (reseta em is_on_floor()).
var _jumps_made: int = 0

# Flags auxiliares
var _current_attack_kind: String = ""
## Snapshot: o ataque atual começou no estado CROUCH? Setado em _try_start_attack
## antes da troca pra State.ATTACK (que apaga o contexto original). Lido em
## _throw_shuriken pra escolher entre marker stand (peito) ou crouch (joelho).
var _attack_started_from_crouch: bool = false

# Dash — double-tap detection
var _last_tap_dir: int = 0                ## -1 = esquerda, +1 = direita, 0 = nenhum (janela expirada).
var _last_tap_window_timer: float = 0.0   ## Contagem regressiva da janela de double-tap (dash_double_tap_window).
var _dash_cooldown_timer: float = 0.0     ## Contagem regressiva do cooldown entre dashes.

# Wall Jump
var _wall_jump_lock_timer: float = 0.0    ## Cooldown anti-reentrada em WALL_SLIDE pós-wall-jump.
var _wall_normal: int = 0                 ## +1 = parede à DIREITA do player, -1 = parede à ESQUERDA, 0 = sem parede. Aponta PRA parede (inward).

# Posição capturada em _ready; alvo do respawn quando o player cruza a kill zone.
var _spawn_position: Vector2 = Vector2.ZERO

# Mapeia "light" / "heavy" / "special" → instância de Hitbox correspondente. Populado em _ready.
var _hitbox_by_kind: Dictionary = {}

# ---------------------------------------------------------------------------
# NÓS — referências da cena Player.tscn
# ---------------------------------------------------------------------------
@onready var hitbox_light: Hitbox = $HitboxLight
@onready var hitbox_special: Hitbox = $HitboxSpecial
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var shuriken_spawn_stand: Marker2D = $ShurikenSpawnStand     ## Origem da shuriken em pé (altura do peito/ombro).
@onready var shuriken_spawn_crouch: Marker2D = $ShurikenSpawnCrouch   ## Origem da shuriken agachado (altura do joelho/cintura).
# @onready var animation_player: AnimationPlayer = $AnimationPlayer
# Heavy não tem mais Area2D no Player — virou projétil (Shuriken) instanciado em _throw_shuriken().

# ===========================================================================
# CICLO DE VIDA
# ===========================================================================
func _ready() -> void:
	current_chakra = max_chakra
	current_health = max_health
	chakra_changed.emit(current_chakra, max_chakra)
	health_changed.emit(current_health, max_health)
	_spawn_position = position
	_hitbox_by_kind = {
		"light": hitbox_light,
		"special": hitbox_special,
	} # "heavy" não entra: vira projétil via _throw_shuriken()
	hurtbox.hit_taken.connect(_on_hit_taken)
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
	_invulnerability_timer = maxf(_invulnerability_timer - delta, 0.0)
	# Dash: janela de double-tap (zera _last_tap_dir ao expirar pra evitar match falso depois)
	# e cooldown entre dashes.
	_last_tap_window_timer = maxf(_last_tap_window_timer - delta, 0.0)
	if _last_tap_window_timer <= 0.0:
		_last_tap_dir = 0
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_wall_jump_lock_timer = maxf(_wall_jump_lock_timer - delta, 0.0)

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

func spend_chakra(amount: float) -> bool:
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
	## Reload completo da cena: substitui o reset local de posição/HP/chakra/timers.
	## Disparado tanto pela kill zone (y > kill_zone_y em _check_kill_zone) quanto pelo
	## fim do timer de State.DEATH em _state_death. Garante que TODOS os nós da fase
	## (MeleeNinja, Dummy, plataformas, futuros inimigos) ressurjam limpos, e que os
	## signals do DebugHUD reconectem do zero no _ready() do novo Player — sem acúmulo
	## de estado entre vidas. O engine processa o reload no fim do frame atual,
	## então qualquer linha após esta no callstack ainda roda em segurança.
	## SALVAGUARDA: força Engine.time_scale = 1.0 ANTES do reload pra eliminar o risco
	## de congelamento permanente. Cenário coberto: reload coincide com hitstop ativo do
	## MeleeNinja → o callback _end_hitstop pertenceria a um nó que será freed pelo reload,
	## então nunca dispara, e o jogo ficaria preso em time_scale = 0.0 pra sempre.
	Engine.time_scale = 1.0
	LevelManager.restart_zone()

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
		State.DASH:          _state_dash(delta)
		State.WALL_SLIDE:    _state_wall_slide(delta)
		State.ATTACK:        _state_attack(delta)
		State.SPECIAL:       _state_special(delta)
		State.CHAKRA_CHARGE: _state_chakra_charge(delta)
		State.HURT:          _state_hurt(delta)
		State.DEATH:         _state_death(delta)

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
		State.DASH:
			# Trava de movimento e gravidade: velocity.x fica fixa em (dash_distance/dash_duration)
			# pelo _state_dash, velocity.y é zerada pra dash horizontal puro.
			# Speed derivado da distância garante que tunar dash_distance = 200 sempre dá 200px,
			# independente da duração escolhida (game design pensa em distância, não em px/s).
			# I-frames cobrem dash_duration + dash_iframe_buffer (margem pós-dash) pra
			# perdoar a janela de reação no AMBUSH do Zabuza.
			_state_timer = dash_duration
			_invulnerability_timer = dash_duration + dash_iframe_buffer
			_dash_cooldown_timer = dash_cooldown
			velocity.x = (dash_distance / dash_duration) * facing_direction
			velocity.y = 0.0
			# Reseta tap tracker pra impedir triple-tap-chain dash → dash → dash.
			_last_tap_dir = 0
			_last_tap_window_timer = 0.0
			_play_animation("dash")
		State.WALL_SLIDE:
			# Decisão de game design: parede "recarrega" o double jump igual ao chão.
			# Permite encadear wall_jump → air_jump pra extensão vertical (estilo Hollow Knight).
			# Sem isso, double-jumpar antes da parede travaria o player ali sem opção de pulo.
			_jumps_made = 0
			_play_animation("wall_slide")
		State.ATTACK:
			_state_timer = light_attack_duration if _current_attack_kind == "light" else heavy_attack_duration
			attack_started.emit(_current_attack_kind)
			_enable_attack_hitbox(_current_attack_kind)
			_play_animation("attack_" + _current_attack_kind)
		State.SPECIAL:
			_state_timer = special_duration
			spend_chakra(rasengan_chakra_cost)
			velocity.x = rasengan_dash_speed * facing_direction # dash curto pra frente; friction decai naturalmente
			special_started.emit()
			_enable_attack_hitbox("special")
			_play_animation("rasengan")
			$RasengaBalloon.show_balloon()
		State.CHAKRA_CHARGE:
			velocity.x = 0.0
			_play_animation("chakra_charge")
		State.HURT:
			_state_timer = hurt_stun_duration
			_invulnerability_timer = invulnerability_duration
			# Desliga qualquer hitbox que estivesse ativa (em caso de hit mid-attack).
			_disable_attack_hitbox("light")
			_disable_attack_hitbox("special")
			_play_animation("hurt")
			# velocity.x foi setado por _take_damage ANTES desta transição (knockback).
		State.DEATH:
			velocity = Vector2.ZERO
			_state_timer = death_respawn_delay
			_disable_attack_hitbox("light")
			_disable_attack_hitbox("special")
			player_died.emit()
			_play_animation("death")

func _exit_state(state: State) -> void:
	match state:
		State.ATTACK:
			_disable_attack_hitbox(_current_attack_kind)
			attack_ended.emit(_current_attack_kind)
			_current_attack_kind = ""
		State.SPECIAL:
			_disable_attack_hitbox("special")
		State.DASH:
			# BUG-FIX crítico: ao sair do dash, velocity.x ainda está em ~1000-2000 px/s.
			# Sem clamp, a friction natural leva ~0.25s pra zerar — o player desliza MUITO além
			# dos 200px nominais ("atravessa o mapa"). Clamp pra move_speed garante saída suave:
			# se player segura direção, continua correndo nessa velocidade; se solta, friction
			# do _state_idle/move decai de 320 → 0 em poucos frames.
			velocity.x = clampf(velocity.x, -move_speed, move_speed)
			special_ended.emit()

# ===========================================================================
# ESTADOS INDIVIDUAIS
# ===========================================================================
func _state_idle(delta: float) -> void:
	_apply_horizontal_movement(delta, 0.0)

	if _try_start_dash():          return
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

	if _try_start_dash():          return
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

	if _try_start_dash():
		return
	if _try_start_attack():
		return

	if velocity.y >= 0.0:
		_change_state(State.FALL)

func _state_fall(delta: float) -> void:
	_apply_horizontal_movement(delta, _get_move_input())

	if _try_start_dash():
		return

	# Wall slide trigger: tocando parede no ar + segurando contra ela + lock timer expirado.
	# Detectado apenas em FALL (não em JUMP) — entrar em WALL_SLIDE durante a subida ficaria estranho.
	# _is_holding_against_wall() atualiza _wall_normal como side effect documentado.
	if is_on_wall_only() and _wall_jump_lock_timer <= 0.0 and _is_holding_against_wall():
		_change_state(State.WALL_SLIDE)
		return

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

func _state_dash(_delta: float) -> void:
	# Override total: ignora input do player, gravidade zerada, velocity.x travada.
	# _apply_gravity já rodou em _physics_process; aqui anulamos pra dash horizontal puro.
	# Speed = dash_distance / dash_duration, recalculado por frame pra refletir tuning live no inspector.
	velocity.y = 0.0
	velocity.x = (dash_distance / dash_duration) * facing_direction

	if _state_timer <= 0.0:
		# Saída: FALL se ainda no ar, senão IDLE. Velocity residual é decaída pela friction natural.
		_change_state(State.FALL if not is_on_floor() else State.IDLE)

func _state_wall_slide(delta: float) -> void:
	## WALL_SLIDE: tocando parede no ar, gravidade reduzida, recarga de double jump.
	## Entradas: via _state_fall quando is_on_wall_only + holding contra parede + lock timer 0.
	## Saídas: wall jump (→ JUMP), solta direcional/perde parede (→ FALL), toca chão (→ IDLE/MOVE).
	## HURT/DEATH interrompem normalmente via _take_damage (sem filtro de estado).

	# Wall jump PRIMEIRO — antes da gravidade reduzida, pra que o pulo cancele o slide.
	# _has_buffered_jump retorna true porque _enter_state(WALL_SLIDE) zerou _jumps_made.
	if _has_buffered_jump():
		_wall_jump_lock_timer = wall_jump_lock_duration
		_change_state(State.JUMP)   # _consume_jump zera jump_buffer + _jumps_made++ + velocity.y = jump_velocity
		# Override pós-_change_state: wall_jump_velocity é distinto do jump_velocity normal.
		# velocity.x usa -_wall_normal pra apontar PRA LONGE da parede (away from wall).
		velocity.x = wall_jump_velocity.x * -float(_wall_normal)
		velocity.y = wall_jump_velocity.y
		return

	# Shuriken durante WALL_SLIDE: spawn inline COM wall_normal, permanece em WALL_SLIDE.
	# NÃO passa por _try_start_attack — esse transicionaria pra ATTACK state.
	if Input.is_action_just_pressed("attack_heavy") and current_chakra >= shuriken_chakra_cost:
		_throw_shuriken_from_wall()

	# Gravidade reduzida — desce devagar (efeito "deslizar pela parede").
	velocity.y = minf(velocity.y + gravity * wall_slide_gravity_multiplier * delta, MAX_FALL_SPEED * wall_slide_gravity_multiplier)
	# Player fica "pinado" lateralmente — sem velocity.x. Movimento horizontal só via wall jump.
	velocity.x = 0.0

	# Saída prioritária: tocou chão → IDLE/MOVE conforme input.
	if is_on_floor():
		_change_state(State.MOVE if absf(_get_move_input()) > 0.01 else State.IDLE)
		return

	# Saída secundária: perdeu contato com parede OU soltou direcional → FALL.
	# _is_holding_against_wall() atualiza _wall_normal como side effect documentado.
	if not _is_holding_against_wall():
		_change_state(State.FALL)
		return

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
	var duration: float = light_attack_duration if _current_attack_kind == "light" else heavy_attack_duration
	_tick_attack_lock(delta, duration)

	# Combo cancel: dentro da janela final, apertar attack_light/heavy emenda no próximo golpe.
	var lock_threshold: float = duration * attack_cancel_window_ratio
	if _state_timer <= lock_threshold and _try_chain_attack():
		return

	if _state_timer <= 0.0:
		_change_state(State.FALL if not is_on_floor() else State.IDLE)

func _state_special(delta: float) -> void:
	# Dash inicial setado em _enter_state(SPECIAL); aqui o impulso decai via friction enquanto travado.
	_tick_attack_lock(delta, special_duration)

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

func _state_hurt(delta: float) -> void:
	# Hitstun: nenhum input é lido, friction decai o knockback aplicado em _take_damage.
	_apply_horizontal_movement(delta, 0.0)

	if _state_timer <= 0.0:
		# Saída pra IDLE/FALL conforme estado físico. I-frames seguem ativos até _invulnerability_timer expirar.
		_change_state(State.FALL if not is_on_floor() else State.IDLE)

func _state_death(delta: float) -> void:
	# Trava total: zero input, velocidade decai naturalmente. Respawn automático ao fim do timer.
	_apply_horizontal_movement(delta, 0.0)

	if _state_timer <= 0.0:
		_respawn() # _respawn já transiciona pra IDLE e reseta vida/chakra/timers

# ===========================================================================
# HELPERS DE TRANSIÇÃO (reduzem duplicação entre IDLE/MOVE/CROUCH)
# ===========================================================================
func _try_start_attack() -> bool:
	if Input.is_action_just_pressed("attack_light"):
		_current_attack_kind = "light"
		# Captura origem ANTES do _change_state (que sobrescreve current_state).
		_attack_started_from_crouch = (current_state == State.CROUCH)
		_change_state(State.ATTACK)
		return true
	if Input.is_action_just_pressed("attack_heavy") and current_chakra >= shuriken_chakra_cost:
		_current_attack_kind = "heavy"
		_attack_started_from_crouch = (current_state == State.CROUCH)
		_change_state(State.ATTACK)
		return true
	return false

func _try_start_special() -> bool:
	if Input.is_action_just_pressed("special") and has_chakra_for_special():
		_change_state(State.SPECIAL)
		return true
	return false

func _try_start_dash() -> bool:
	## Double-tap detection em move_left / move_right.
	## Fluxo: 1º tap arma janela (_last_tap_dir + _last_tap_window_timer). 2º tap na MESMA
	## direção, com janela ainda viva → dispara DASH. Janela expirada zera tap dir em _tick_timers.
	## Cooldown trava no portão: se _dash_cooldown_timer > 0, ignora qualquer tap.
	if _dash_cooldown_timer > 0.0:
		return false
	var tap_dir: int = 0
	if Input.is_action_just_pressed("move_right"):
		tap_dir = 1
	elif Input.is_action_just_pressed("move_left"):
		tap_dir = -1
	if tap_dir == 0:
		return false   # nenhum tap neste frame
	# 2º tap na MESMA direção dentro da janela → dash. Força facing pra direção do tap
	# (cobre caso do player estar virado pra um lado e dar double-tap pro outro).
	if tap_dir == _last_tap_dir and _last_tap_window_timer > 0.0:
		facing_direction = tap_dir
		_change_state(State.DASH)
		return true
	# 1º tap (ou direção diferente do anterior): arma janela pra próximo tap.
	_last_tap_dir = tap_dir
	_last_tap_window_timer = dash_double_tap_window
	return false

func _is_holding_against_wall() -> bool:
	## Atualiza _wall_normal (SIDE EFFECT) lendo get_wall_normal() e checa se input aponta
	## NA direção da parede ("segurar contra a parede"). Convenção do _wall_normal:
	##   +1 = parede à DIREITA do player; -1 = parede à ESQUERDA; 0 = sem parede.
	## (Godot retorna outward; invertemos pra inward via -signf(wall_n.x) — consistente
	## com shuriken.gd que aplica `wall_normal * -1` pra recuperar a direção outward.)
	if not is_on_wall_only():
		_wall_normal = 0
		return false
	var wall_n: Vector2 = get_wall_normal()
	if wall_n == Vector2.ZERO:
		_wall_normal = 0
		return false
	_wall_normal = -int(signf(wall_n.x))
	var axis: float = _get_move_input()
	return absf(axis) > 0.01 and signf(axis) == float(_wall_normal)

func _throw_shuriken_from_wall() -> void:
	## Spawn de shuriken durante WALL_SLIDE — ignora facing (player encara parede), usa
	## _wall_normal pra direcionar oposto. NÃO troca pra ATTACK state — player permanece
	## em WALL_SLIDE. Spawn position é espelhado por -_wall_normal pro shuriken nascer no
	## lado de SAÍDA (oposto à parede) em vez de "dentro" da parede.
	spend_chakra(shuriken_chakra_cost)
	var shuriken: Shuriken = SHURIKEN_SCENE.instantiate() as Shuriken
	shuriken.wall_normal = _wall_normal
	var local: Vector2 = shuriken_spawn_stand.position
	shuriken.global_position = global_position + Vector2(local.x * -float(_wall_normal), local.y)
	get_parent().add_child(shuriken)

func _try_start_chakra_charge() -> bool:
	if Input.is_action_pressed("chakra_charge") and is_on_floor():
		_change_state(State.CHAKRA_CHARGE)
		return true
	return false

func _try_chain_attack() -> bool:
	## Combo: chamado dentro do cancel_window do _state_attack.
	## Apertar attack_light ou attack_heavy reentra ATTACK com novo kind sem passar
	## por _change_state (que bloqueia transição mesmo→mesmo).
	## Faz exit + enter manualmente pra reciclar hitbox, signals attack_started/ended e _state_timer.
	var new_kind: String = ""
	if Input.is_action_just_pressed("attack_light"):
		new_kind = "light"
	elif Input.is_action_just_pressed("attack_heavy") and current_chakra >= shuriken_chakra_cost:
		new_kind = "heavy"
	else:
		return false

	_exit_state(State.ATTACK)   # desliga hitbox atual + emite attack_ended (+ zera _current_attack_kind)
	_current_attack_kind = new_kind
	_enter_state(State.ATTACK)  # liga novo hitbox + emite attack_started + reseta _state_timer
	# Micro-dash: cada hit conectado ganha um "tranco" sutil pra frente; friction decai em ~5 frames.
	velocity.x = combo_dash_speed * facing_direction
	return true

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
func _enable_attack_hitbox(kind: String) -> void:
	if kind == "heavy":
		_throw_shuriken()
		return
	var hitbox: Hitbox = _hitbox_by_kind.get(kind) as Hitbox
	if hitbox == null:
		return
	# Espelha a posição X conforme a direção atual do personagem.
	hitbox.position.x = absf(hitbox.position.x) * facing_direction
	hitbox.enable()

func _disable_attack_hitbox(kind: String) -> void:
	if kind == "heavy":
		return # shuriken se autodestrói (max_travel_distance ou hit) — nada pra desligar aqui
	var hitbox: Hitbox = _hitbox_by_kind.get(kind) as Hitbox
	if hitbox == null:
		return
	hitbox.disable()

# ===========================================================================
# COMBATE — HELPERS E PROJÉTEIS
# ===========================================================================
func _tick_attack_lock(delta: float, duration: float) -> void:
	## Trava velocity.x durante a fração inicial do ataque; libera input de movimento no final
	## (último `attack_cancel_window_ratio` da duração) pra permitir cancel leve.
	var lock_threshold: float = duration * attack_cancel_window_ratio
	if _state_timer > lock_threshold:
		_apply_horizontal_movement(delta, 0.0)
	else:
		_apply_horizontal_movement(delta, _get_move_input())

func _throw_shuriken() -> void:
	spend_chakra(shuriken_chakra_cost)
	var shuriken: Shuriken = SHURIKEN_SCENE.instantiate() as Shuriken
	shuriken.direction = Vector2(facing_direction, 0)
	# Origem dinâmica: marker do CROUCH (joelho) se o ataque começou agachado;
	# senão marker do STAND (peito/ombro). Snapshot capturado em _try_start_attack
	# porque current_state já é ATTACK aqui.
	# OBS: marker.position é LOCAL e fica no lado canônico +X. Espelhamos X via
	# facing_direction porque o visual do Player ainda não flipa (não tem scale.x = -1
	# nem AnimatedSprite2D.flip_h). Quando virar sprite com flip, dá pra simplificar
	# pra `shuriken.global_position = marker.global_position` direto.
	var marker: Marker2D = shuriken_spawn_crouch if _attack_started_from_crouch else shuriken_spawn_stand
	var local: Vector2 = marker.position
	shuriken.global_position = global_position + Vector2(local.x * facing_direction, local.y)
	get_parent().add_child(shuriken)

# ===========================================================================
# SISTEMA DE DANO — Hurtbox → HURT / DEATH
# ===========================================================================
func _on_hit_taken(incoming_hitbox: Hitbox) -> void:
	## Entry point: chamado quando uma Hitbox inimiga colide com a Hurtbox do Player.
	## Filtra DEATH e i-frames antes de delegar pra _take_damage.
	if current_state == State.DEATH:
		return
	if _invulnerability_timer > 0.0:
		return # i-frames pós-HURT — ignora hits em cascata
	_take_damage(incoming_hitbox.damage, incoming_hitbox.global_position)

func _take_damage(amount: int, source_position: Vector2) -> void:
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_change_state(State.DEATH)
		return

	# Knockback horizontal pra longe do atacante: signf(player.x - source.x).
	var knockback_dir: float = signf(global_position.x - source_position.x)
	if knockback_dir == 0.0:
		knockback_dir = -float(facing_direction) # fallback raro: empurra pra trás do facing atual
	velocity.x = hurt_knockback_speed * knockback_dir

	player_hurt.emit(amount, source_position)
	_change_state(State.HURT)

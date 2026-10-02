extends CharacterBody3D

enum State { GROUND, CLIMBING }

# --- Movimiento en suelo ---
@export var move_speed: float = 4.0
@export var acceleration: float = 12.0
@export var rotation_speed: float = 10.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.0

# --- Salto: breve "agache" de impulso antes de despegar, solo para que se
# note el golpe de la animación; el impulso horizontal ya NO se frena
# durante esta fase (antes se anulaba, por eso el salto se sentía pegajoso). ---
@export var jump_anticipation_time: float = 0.12

# --- Salto grande (estilo BOTW): saltar mientras se corre da más distancia
# y altura, a cambio de un mordisco extra de resistencia. ---
@export var big_jump_velocity_multiplier: float = 1.25
@export var big_jump_speed_multiplier: float = 1.4
@export var big_jump_stamina_cost: float = 1.5

# --- La animación de salto (Hop_with_Arms_Raised) dura ~2.4s pero el salto
# físico dura menos de 1s; se acelera su reproducción para que se vea
# completa (agache, impulso y caída) en el tiempo real que dura el salto,
# en vez de cortarla a un tercio de camino. ---
@export var jump_anim_speed: float = 2.5

# --- Sprint (Shift) ---
@export var sprint_multiplier: float = 1.7

# --- Inactividad: tiempo sin ningún input antes de que Kael se acueste ---
@export var idle_timeout: float = 60.0

# --- La animación de acostarse deja al modelo con las caderas/pies varios
# centímetros por debajo del piso (pose importada así, no es root motion);
# se compensa levantando el modelo mientras dura la pose. ---
@export var lie_down_y_offset: float = 0.36

# --- Cámara orbital ---
@export var mouse_sensitivity: float = 0.008
@export var min_pitch: float = -60.0  # grados
@export var max_pitch: float = 30.0   # grados

# --- Trepar ---
@export var climb_speed: float = 2.5
@export var max_stamina: float = 5.0       # segundos de resistencia
@export var stamina_regen_rate: float = 1.0 # regeneración por segundo (quieto o caminando)
@export var climb_detect_distance: float = 0.8

# --- Resistencia (estilo BOTW): correr y escalar la consumen; se regenera
# al estar quieto o caminando a paso normal, tras una breve pausa. ---
@export var sprint_stamina_drain_rate: float = 1.0
@export var climb_stamina_drain_rate: float = 1.0
@export var stamina_regen_delay: float = 0.5 # segundos de gracia antes de regenerar

@onready var model: Node3D = $PenguinModel
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var climb_ray: RayCast3D = $ClimbRayCast3D

var state: State = State.GROUND
var stamina: float = max_stamina
var stamina_regen_timer: float = 0.0

var idle_anim: String = ""
var run_anim: String = ""
var climb_anim: String = ""
var jump_anim: String = ""
var lie_down_anim: String = ""

var is_jump_anticipating: bool = false
var jump_anticipation_timer: float = 0.0
var is_big_jump: bool = false

var climb_wall_normal: Vector3 = Vector3.ZERO

var idle_timer: float = 0.0
var is_lying_down: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# El animator del modelo fusiona sus animaciones en su propio _ready();
	# esperamos un frame para que ya estén disponibles.
	await get_tree().process_frame

	if model == null or not model.has_method("get_best_animation"):
		push_warning("Player: el modelo no tiene el script de animación esperado.")
		return

	idle_anim = model.get_best_animation("Idle")
	run_anim = model.get_best_animation("Run")
	climb_anim = model.get_best_animation("Climb")
	jump_anim = model.get_best_animation("Hop")
	lie_down_anim = model.get_best_animation("Lie")
	print("Player: idle='%s'  run='%s'  climb='%s'  jump='%s'  lie_down='%s'" % [idle_anim, run_anim, climb_anim, jump_anim, lie_down_anim])

	if idle_anim != "":
		model.play_animation(idle_anim)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spring_arm.rotate_y(-event.relative.x * mouse_sensitivity)
		var new_pitch: float = spring_arm.rotation.x - event.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clamp(new_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		idle_timer = 0.0
		_wake_up()

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	match state:
		State.GROUND:
			_process_ground(delta)
		State.CLIMBING:
			_process_climbing(delta)

	move_and_slide()

func _get_input_dir() -> Vector2:
	return Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_back", "move_forward")
	)

func _process_ground(delta: float) -> void:
	var input_dir := _get_input_dir()
	var jump_pressed := Input.is_action_just_pressed("jump")

	# Cualquier input de movimiento o salto despierta a Kael si estaba acostado.
	if is_lying_down and (input_dir.length() > 0.1 or jump_pressed):
		_wake_up()
		idle_timer = 0.0

	# --- Fase de anticipación del salto: brevísimo "agache" que solo frena
	# la caída; el impulso horizontal se conserva tal cual (antes se
	# frenaba a 0, por eso un salto en carrera perdía toda su velocidad). ---
	if is_jump_anticipating:
		velocity.y = 0.0
		jump_anticipation_timer += delta
		if jump_anticipation_timer >= jump_anticipation_time:
			is_jump_anticipating = false
			velocity.y = jump_velocity * (big_jump_velocity_multiplier if is_big_jump else 1.0)
		return

	# Movimiento relativo a la orientación horizontal de la cámara (SpringArm3D)
	var cam_basis: Basis = spring_arm.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction := (right * input_dir.x + forward * input_dir.y)
	var is_moving := direction.length() > 0.1

	# El sprint solo acelera mientras quede resistencia; al agotarse, Kael
	# vuelve al paso normal aunque se siga presionando Shift (como en BOTW).
	var is_sprinting := is_moving and Input.is_action_pressed("sprint") and stamina > 0.0

	if is_moving:
		direction = direction.normalized()
		var current_speed := move_speed
		if is_sprinting:
			current_speed *= sprint_multiplier
		# Mientras dura el arco de un salto grande, el objetivo de velocidad
		# horizontal queda más alto: así el control en el aire sostiene el
		# impulso extra en vez de que el "move_toward" normal lo frene enseguida.
		if is_big_jump:
			current_speed *= big_jump_speed_multiplier
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)

		if model:
			var target_angle := atan2(direction.x, direction.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	var was_on_floor := is_on_floor()
	var jump_started := false

	if not was_on_floor:
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
		is_big_jump = false
		if is_sprinting:
			stamina = max(stamina - sprint_stamina_drain_rate * delta, 0.0)
			stamina_regen_timer = 0.0
		else:
			stamina_regen_timer += delta
			if stamina_regen_timer >= stamina_regen_delay:
				stamina = min(stamina + stamina_regen_rate * delta, max_stamina)
		if jump_pressed and not is_lying_down:
			_start_jump_anticipation(is_sprinting)
			jump_started = true

	if jump_started:
		idle_timer = 0.0
		return

	# --- Inactividad: sin movimiento durante idle_timeout segundos → se acuesta ---
	if is_moving:
		idle_timer = 0.0
	elif not is_lying_down:
		idle_timer += delta
		if idle_timer >= idle_timeout:
			is_lying_down = true
			if model:
				model.position.y = lie_down_y_offset

	# Prioridad de animación: acostado > saltar (mientras dure, en el aire) > correr > idle
	if model:
		if is_lying_down and lie_down_anim != "":
			if not model.is_playing_animation(lie_down_anim):
				model.play_animation(lie_down_anim)
		elif not was_on_floor and jump_anim != "" and model.is_playing_animation(jump_anim):
			pass  # dejar que el salto termine su curso sin interrumpirlo
		elif is_moving and run_anim != "":
			if not model.is_playing_animation(run_anim):
				model.play_animation(run_anim)
		elif not is_moving and idle_anim != "":
			if not model.is_playing_animation(idle_anim):
				model.play_animation(idle_anim)

	# El Player no rota (solo el modelo visual), así que el raycast de trepar
	# se orienta dinámicamente hacia la dirección de movimiento actual.
	if is_moving:
		climb_ray.target_position = direction * climb_detect_distance
		climb_ray.force_raycast_update()

	# Entrar a trepar: pared detectada al frente + input hacia ella + stamina disponible
	if is_moving and stamina > 0.0 and _is_facing_climbable(direction):
		_enter_climb()

func _start_jump_anticipation(big: bool) -> void:
	is_jump_anticipating = true
	jump_anticipation_timer = 0.0
	is_big_jump = big
	if big:
		stamina = max(stamina - big_jump_stamina_cost, 0.0)
		stamina_regen_timer = 0.0
	if model and jump_anim != "":
		model.play_animation(jump_anim, false, 0.1, jump_anim_speed)

func _process_climbing(delta: float) -> void:
	var vertical_input := Input.get_axis("move_back", "move_forward")
	var horizontal_input := Input.get_axis("move_left", "move_right")
	var is_climbing_moving := absf(vertical_input) > 0.1 or absf(horizontal_input) > 0.1

	# Solo se gasta resistencia mientras trepa activamente; quieto y aferrado
	# a la pared no se cansa (como en Zelda).
	if is_climbing_moving:
		stamina = max(stamina - climb_stamina_drain_rate * delta, 0.0)
		stamina_regen_timer = 0.0

	if stamina <= 0.0 or not climb_ray.is_colliding():
		_exit_climb()
		return

	# Movimiento tangente a la pared: "right" se calcula a partir de la normal
	# de la superficie capturada al enganchar, así se puede escalar en horizontal.
	# (orden del cruz invertido respecto a la versión anterior: A/D salían intercambiados)
	var wall_right := Vector3.UP.cross(climb_wall_normal).normalized()
	if wall_right.length_squared() < 0.01:
		wall_right = Vector3.RIGHT

	velocity = wall_right * horizontal_input * climb_speed + Vector3.UP * vertical_input * climb_speed

	# Reapunta el raycast contra la pared (dirección opuesta a su normal) para
	# seguir detectando colisión mientras nos deslizamos lateralmente.
	climb_ray.target_position = -climb_wall_normal * climb_detect_distance
	climb_ray.force_raycast_update()

	if model and climb_anim != "":
		if not model.is_playing_animation(climb_anim):
			model.play_animation(climb_anim)
		model.set_animation_paused(not is_climbing_moving)
	elif model and idle_anim != "":
		if not model.is_playing_animation(idle_anim):
			model.play_animation(idle_anim)

func _is_facing_climbable(direction: Vector3) -> bool:
	if not climb_ray.is_colliding():
		return false
	var collider := climb_ray.get_collider()
	return collider is Node and collider.is_in_group("climbable")

func _enter_climb() -> void:
	state = State.CLIMBING
	velocity = Vector3.ZERO
	climb_wall_normal = climb_ray.get_collision_normal()
	if model and climb_anim != "":
		model.play_animation(climb_anim)

func _exit_climb() -> void:
	state = State.GROUND
	stamina_regen_timer = 0.0
	if model:
		model.set_animation_paused(false)

## Fracción de resistencia restante (0.0 a 1.0), usada por el HUD.
func get_stamina_ratio() -> float:
	if max_stamina <= 0.0:
		return 0.0
	return clamp(stamina / max_stamina, 0.0, 1.0)

func _wake_up() -> void:
	is_lying_down = false
	if model:
		model.position.y = 0.0

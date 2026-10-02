extends CharacterBody3D

enum State { GROUND, CLIMBING, SWIMMING, DROWNING }

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
# Una superficie es trepable si es casi vertical: |normal.y| menor a este valor
# (0 = pared perfecta, 1 = suelo). Las marcadas con el grupo "no_climb" no se trepan.
@export var climb_max_normal_y: float = 0.35
# Al llegar al borde superior de una pared, impulso hacia arriba y adelante
# para subirse a la cornisa en vez de caer de vuelta.
@export var ledge_boost_up: float = 4.0
@export var ledge_boost_forward: float = 3.0

# --- Caída fuera del mapa: sin castigo, reaparece en el último tótem ---
@export var fall_limit_y: float = -12.0

# --- Resistencia (estilo BOTW): correr y escalar la consumen; se regenera
# al estar quieto o caminando a paso normal, tras una breve pausa. ---
@export var sprint_stamina_drain_rate: float = 1.0
@export var climb_stamina_drain_rate: float = 1.0
@export var stamina_regen_delay: float = 0.5 # segundos de gracia antes de regenerar

# --- Nadar (estilo Zelda): Kael es torpe nadando, así que es lento y cansa;
# no regenera resistencia en el agua y, si se agota, se ahoga y reaparece en
# tierra firme. Con 5 s de resistencia alcanza ~17 m. ---
@export var swim_speed: float = 2.5
@export var swim_sprint_multiplier: float = 1.4
@export var swim_acceleration: float = 6.0
@export var swim_stamina_drain_rate: float = 0.7
@export var swim_sprint_extra_drain: float = 0.7
@export var swim_float_depth: float = 0.9      # cuánto bajan los pies de la superficie (agua a la altura del pecho)
@export var swim_enter_depth: float = 0.35     # cuánto deben bajar los pies para empezar a nadar
@export var water_jump_velocity: float = 7.0   # salto desde el agua para subirse a una orilla
@export var water_jump_cost: float = 0.5
@export var swim_anim_speed: float = 0.6       # velocidad de la animación provisional (correr)
@export var drown_sink_time: float = 1.1       # segundos hundiéndose antes de reaparecer
@export var safe_trail_interval: float = 0.75  # cada cuánto se guarda un punto seguro

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
var swim_anim: String = ""

var current_water: Node = null
var swim_cooldown: float = 0.0
var safe_trail: Array[Vector3] = []
var safe_timer: float = 0.0
var ripple: MeshInstance3D = null

var is_jump_anticipating: bool = false
var jump_anticipation_timer: float = 0.0
var is_big_jump: bool = false

var climb_wall_normal: Vector3 = Vector3.ZERO

var idle_timer: float = 0.0
var is_lying_down: bool = false

var respawn_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	respawn_position = global_position
	_create_ripple()

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
	# Si aún no hay animación de nadar, se usa la de correr más lenta.
	swim_anim = model.get_best_animation("Swim")
	print("Player: idle='%s'  run='%s'  climb='%s'  jump='%s'  lie_down='%s'  swim='%s'" % [idle_anim, run_anim, climb_anim, jump_anim, lie_down_anim, swim_anim])

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
		State.SWIMMING:
			_process_swimming(delta)
		State.DROWNING:
			_process_drowning(delta)

	move_and_slide()

	if state == State.GROUND and is_on_floor():
		_update_safe_trail(delta)

	if global_position.y < fall_limit_y and state != State.DROWNING:
		_respawn()

## Lo llaman los tótems de punto de control al tocarlos.
func set_respawn_point(pos: Vector3) -> void:
	respawn_position = pos

func _respawn() -> void:
	global_position = respawn_position
	velocity = Vector3.ZERO
	state = State.GROUND
	is_jump_anticipating = false
	is_big_jump = false
	_leave_swim()

# --- Agua: la avisa el WaterVolume al entrar y salir ---
func enter_water(water: Node) -> void:
	current_water = water

func exit_water(water: Node) -> void:
	if current_water == water:
		current_water = null

func _is_in_water() -> bool:
	return current_water != null and global_position.y < current_water.get_surface_y() - swim_enter_depth

func _enter_swim() -> void:
	state = State.SWIMMING
	is_jump_anticipating = false
	is_big_jump = false
	velocity.y *= 0.3   # el agua amortigua la caída
	_wake_up()
	idle_timer = 0.0
	if ripple:
		ripple.visible = true

## Restablece lo que nadar cambia: ondas ocultas y velocidad de animación normal.
func _leave_swim() -> void:
	if ripple:
		ripple.visible = false
	if model:
		model.set_animation_paused(false)

func _create_ripple() -> void:
	ripple = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.9
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 1
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.35)
	disc.material = mat
	ripple.mesh = disc
	ripple.top_level = true
	ripple.visible = false
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ripple)

func _process_swimming(delta: float) -> void:
	if current_water == null:
		_leave_swim()
		state = State.GROUND
		return

	var surface: float = current_water.get_surface_y()
	var input_dir := _get_input_dir()
	var cam_basis: Basis = spring_arm.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var direction := right * input_dir.x + forward * input_dir.y
	var is_moving := direction.length() > 0.1
	var is_sprinting := is_moving and Input.is_action_pressed("sprint")

	if is_moving:
		direction = direction.normalized()
		var speed := swim_speed * (swim_sprint_multiplier if is_sprinting else 1.0)
		velocity.x = move_toward(velocity.x, direction.x * speed, swim_acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, swim_acceleration * delta)
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, swim_acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, swim_acceleration * delta)

	# Flotar: un resorte lleva los pies a la profundidad de nado.
	var target_y := surface - swim_float_depth
	velocity.y = clampf((target_y - global_position.y) * 6.0, -4.0, 4.0)

	# Nadar cansa y no regenera; sin resistencia, se ahoga.
	var drain := swim_stamina_drain_rate + (swim_sprint_extra_drain if is_sprinting else 0.0)
	stamina = maxf(stamina - drain * delta, 0.0)
	stamina_regen_timer = 0.0
	idle_timer = 0.0
	if stamina <= 0.0:
		_start_drowning()
		return

	# Salto desde el agua para alcanzar una orilla.
	if Input.is_action_just_pressed("jump") and stamina > water_jump_cost:
		stamina -= water_jump_cost
		velocity.y = water_jump_velocity
		swim_cooldown = 0.5
		_leave_swim()
		state = State.GROUND
		return

	# Contra una pared de la orilla se sale trepando (reusa el trepado).
	if is_moving:
		climb_ray.target_position = direction * climb_detect_distance
		climb_ray.force_raycast_update()
		if _is_facing_climbable(direction):
			_leave_swim()
			_enter_climb()
			return

	# Animación provisional: la de correr, más lenta, hasta tener 'swim'.
	if model:
		var anim := swim_anim if swim_anim != "" else run_anim
		if is_moving and anim != "":
			if not model.is_playing_animation(anim):
				model.play_animation(anim, true, 0.2, 1.0 if swim_anim != "" else swim_anim_speed)
		elif idle_anim != "" and not model.is_playing_animation(idle_anim):
			model.play_animation(idle_anim)

	if ripple:
		var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.005)
		ripple.global_position = Vector3(global_position.x, surface + 0.03, global_position.z)
		ripple.scale = Vector3(pulse, 1.0, pulse)

func _start_drowning() -> void:
	state = State.DROWNING
	_leave_swim()
	var fade := get_tree().get_first_node_in_group("screen_fade")
	if fade:
		fade.fade_to(1.0, drown_sink_time * 0.8)
	await get_tree().create_timer(drown_sink_time).timeout

	# Reaparece en el punto seguro de hace ~1.5 s (o en el último tótem).
	var target := respawn_position
	if safe_trail.size() > 0:
		target = safe_trail[maxi(0, safe_trail.size() - 3)]
	global_position = target + Vector3.UP * 0.2
	velocity = Vector3.ZERO
	stamina = max_stamina
	stamina_regen_timer = 0.0
	swim_cooldown = 0.3
	state = State.GROUND
	if fade:
		fade.fade_to(0.0, 0.7)

func _process_drowning(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, swim_acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, swim_acceleration * delta)
	velocity.y = -0.8

func _update_safe_trail(delta: float) -> void:
	safe_timer += delta
	if safe_timer < safe_trail_interval:
		return
	safe_timer = 0.0
	if _is_safe_spot():
		safe_trail.append(global_position)
		if safe_trail.size() > 8:
			safe_trail.remove_at(0)

## Punto seguro = hay suelo firme alrededor, o sea, no es el borde de una orilla.
func _is_safe_spot() -> bool:
	var space := get_world_3d().direct_space_state
	for off in [Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0), Vector3(0, 0, 1.3), Vector3(0, 0, -1.3)]:
		var from: Vector3 = global_position + off + Vector3.UP
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.5)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.7:
			return false
	return true

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

	# Al bajar de la superficie del agua, empieza a nadar.
	if swim_cooldown > 0.0:
		swim_cooldown -= delta
	elif _is_in_water():
		_enter_swim()
		return

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

	if stamina <= 0.0:
		_exit_climb()
		return

	# Sin pared al frente: si se subía, es el borde superior y se da un
	# impulso para trepar a la cornisa; si no, simplemente se suelta.
	if not climb_ray.is_colliding():
		if vertical_input > 0.1:
			velocity = -climb_wall_normal * ledge_boost_forward + Vector3.UP * ledge_boost_up
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
	if not (collider is Node) or collider.is_in_group("no_climb"):
		return false
	return absf(climb_ray.get_collision_normal().y) < climb_max_normal_y

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

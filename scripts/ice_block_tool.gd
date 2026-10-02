extends Node3D

## Herramienta de bloques de hielo (Cryonis de BotW + controles de Ultramano
## de TotK). Hijo del Player. Q activa el modo hielo.
##
## Colocación:
## - Apuntar al suelo, al agua o a una pared: la vista previa se pega ahí.
## - Apuntar a un bloque (cualquier cara): la vista previa va ENCIMA de su pila
##   (apilar sin tener que ver la cara de arriba).
## - Rueda: acercar / alejar la vista previa (cae sobre lo que haya debajo).
## - R / F: subir / bajar la vista previa un bloque de altura.
## - Shift + rueda: girar.
## - Clic izquierdo crea, clic derecho rompe el bloque apuntado.
##
## Reglas: un bloque tiene que apoyarse en algo (suelo, agua u otro bloque, o
## tocar una pared); no flota en el aire. El hielo pulido (grupo "no_climb")
## no sirve de apoyo y lo rechaza. Hay un límite de bloques activos: al
## llegar a él hay que romper uno para crear otro (no se reciclan solos).

@export var block_scene: PackedScene
@export var max_blocks: int = 3   # límite duro: obliga a romper y reusar (base de los puzzles)
@export var create_cost: float = 0.8
@export var place_range: float = 12.0
@export var block_size: float = 2.0
@export var yaw_step_deg: float = 15.0
@export var cooldown: float = 0.25
@export var water_float_offset: float = 0.2   # centro del bloque sobre la superficie del agua
@export var distance_step: float = 1.0        # cuánto acerca/aleja cada paso de la rueda (m)
@export var max_distance_steps: int = 8
@export var max_level: int = 4                # cuántos bloques de altura se puede subir la vista previa
@export var support_margin: float = 0.15      # holgura para detectar apoyo alrededor del bloque
@export var shoulder_offset: float = 1.1      # cámara al hombro en modo hielo, para que Kael no tape la mira
@export var shoulder_blend_speed: float = 8.0

var mode_active: bool = false
var aim_valid: bool = false
var invalid_reason: String = ""   # por qué no se puede crear (lo muestra el HUD)
var level_offset: int = 0         # R / F
var distance_offset: int = 0      # rueda
var snapped_to_block: bool = false

var blocks: Array[Node3D] = []

var _yaw_offset_deg: float = 0.0
var _cooldown_timer: float = 0.0
var _ghost: MeshInstance3D = null
var _ghost_ok: StandardMaterial3D = null
var _ghost_bad: StandardMaterial3D = null
var _aim_found: bool = false
var _aim_collider: Object = null
var _aim_transform: Transform3D = Transform3D.IDENTITY

@onready var player: CharacterBody3D = get_parent()

func _ready() -> void:
	_ghost_ok = _make_ghost_material(Color(0.4, 0.8, 1.0, 0.35))
	_ghost_bad = _make_ghost_material(Color(1.0, 0.3, 0.3, 0.35))
	_ghost = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * block_size
	_ghost.mesh = box
	_ghost.top_level = true
	_ghost.visible = false
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)

func _make_ghost_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		set_mode(not mode_active)
		return
	if not mode_active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				level_offset = mini(level_offset + 1, max_level)
			KEY_F:
				level_offset = maxi(level_offset - 1, -max_level)
	if event is InputEventMouseButton and event.pressed:
		var rotating: bool = event.shift_pressed
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				try_create()
			MOUSE_BUTTON_RIGHT:
				try_break()
			MOUSE_BUTTON_WHEEL_UP:
				if rotating:
					_yaw_offset_deg += yaw_step_deg
				else:
					distance_offset = mini(distance_offset + 1, max_distance_steps)
			MOUSE_BUTTON_WHEEL_DOWN:
				if rotating:
					_yaw_offset_deg -= yaw_step_deg
				else:
					distance_offset = maxi(distance_offset - 1, -max_distance_steps)

func set_mode(active: bool) -> void:
	if active and (player.state == player.State.CLIMBING or player.state == player.State.DROWNING):
		return
	mode_active = active
	reset_offsets()
	if not active:
		_ghost.visible = false
		aim_valid = false

func reset_offsets() -> void:
	level_offset = 0
	distance_offset = 0

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var target := shoulder_offset if mode_active else 0.0
		cam.h_offset = lerpf(cam.h_offset, target, minf(shoulder_blend_speed * delta, 1.0))

func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	if not mode_active:
		return
	if player.state == player.State.CLIMBING or player.state == player.State.DROWNING:
		set_mode(false)
		return
	_compute_aim()
	_update_ghost()

## Apunta con un rayo desde el centro de la cámara; el agua cuenta como suelo.
func _compute_aim() -> void:
	_aim_found = false
	_aim_collider = null
	snapped_to_block = false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var hit := _ray(from, from + dir * 80.0)
	var point := Vector3.ZERO
	var normal := Vector3.UP
	var on_water := false
	var best := INF
	if not hit.is_empty():
		point = hit.position
		normal = hit.normal
		_aim_collider = hit.collider
		_aim_found = true
		best = from.distance_to(point)
	var water_y := _water_y()
	if not is_nan(water_y) and dir.y < -0.001:
		var t: float = (water_y - from.y) / dir.y
		if t > 0.0 and t < best:
			point = from + dir * t
			normal = Vector3.UP
			_aim_collider = null
			on_water = true
			_aim_found = true
	if not _aim_found:
		aim_valid = false
		invalid_reason = "Apunta al suelo, al agua o a una pared"
		return

	var yaw := snappedf(rad_to_deg(cam.global_rotation.y), yaw_step_deg) + _yaw_offset_deg
	var xform: Transform3D
	if absf(normal.y) < 0.5:
		# Contra una pared el bloque se alinea con ella, para que no la atraviese con una esquina.
		yaw = rad_to_deg(atan2(normal.x, normal.z)) + _yaw_offset_deg
	var smooth: bool = _aim_collider is Node and (_aim_collider as Node).is_in_group("no_climb")
	if smooth and absf(normal.y) > 0.5:
		# Encima o debajo de hielo pulido: no hay donde dejarlo.
		_aim_transform = _transform_for(point, normal, false, yaw)
		aim_valid = false
		invalid_reason = "El hielo pulido rechaza los bloques"
		return
	if smooth:
		# Pared de hielo pulido: el bloque no se pega, resbala hasta el pie.
		xform = _transform_for(point, normal, false, yaw)
		xform.origin = _drop(xform.origin, xform.origin.y)
	elif _aim_collider is Node and (_aim_collider as Node).is_in_group("ice_block"):
		xform = _stack_on(_aim_collider as Node3D)
		snapped_to_block = true
	else:
		xform = _transform_for(point, normal, on_water, yaw)
	xform = _apply_offsets(xform, dir)
	if _overlaps_player(xform):
		xform.origin = _nudge_from_player(xform.origin, dir)
	_aim_transform = xform
	if distance_offset != 0:
		snapped_to_block = false
	invalid_reason = _check(_aim_transform)
	aim_valid = invalid_reason == ""

## Encima del bloque más alto de la pila a la que pertenece `block`.
func _stack_on(block: Node3D) -> Transform3D:
	var top := block
	var climbing := true
	while climbing:
		climbing = false
		for b in blocks:
			if b == top or not is_instance_valid(b):
				continue
			var d := b.global_position - top.global_position
			if Vector2(d.x, d.z).length() < block_size * 0.3 and absf(d.y - block_size) < block_size * 0.3:
				top = b
				climbing = true
				break
	var xform := top.global_transform
	xform.origin += Vector3.UP * block_size
	return xform

## Rueda: mueve la vista previa en horizontal hacia/desde la cámara y la deja
## caer sobre lo que haya debajo. R / F: la sube o baja de a un bloque.
func _apply_offsets(xform: Transform3D, cam_dir: Vector3) -> Transform3D:
	var out := xform
	if distance_offset != 0:
		var flat := Vector3(cam_dir.x, 0.0, cam_dir.z).normalized()
		var target := out.origin + flat * (distance_offset * distance_step)
		out.origin = _drop(target, out.origin.y)
	out.origin.y += level_offset * block_size
	return out

## Centro de un bloque apoyado en lo que haya bajo `pos` (o en el agua),
## buscando desde la altura `from_y` hacia abajo.
func _drop(pos: Vector3, from_y: float) -> Vector3:
	var top := Vector3(pos.x, from_y + block_size * 0.45, pos.z)
	var hit := _ray(top, top + Vector3.DOWN * 60.0)
	var floor_y := -INF
	if not hit.is_empty():
		floor_y = hit.position.y
	var water_y := _water_y()
	if not is_nan(water_y) and water_y > floor_y and water_y < top.y:
		return Vector3(pos.x, water_y + water_float_offset, pos.z)
	if floor_y == -INF:
		return Vector3(pos.x, from_y, pos.z)
	return Vector3(pos.x, floor_y + block_size * 0.5, pos.z)

## ¿El bloque en `xform` se metería dentro de Kael? (aprox. con su cápsula)
func _overlaps_player(xform: Transform3D) -> bool:
	var d := xform.origin - player.global_position
	var half := block_size * 0.5
	var horizontal := Vector2(d.x, d.z).length() < half + 0.5
	var vertical := xform.origin.y - half < player.global_position.y + 1.8 and xform.origin.y + half > player.global_position.y
	return horizontal and vertical

## Saca la vista previa de encima de Kael: la aleja en horizontal (en la
## dirección en la que ya estaba, o hacia donde mira la cámara) y la deja caer.
func _nudge_from_player(pos: Vector3, cam_dir: Vector3) -> Vector3:
	var away := Vector3(pos.x - player.global_position.x, 0.0, pos.z - player.global_position.z)
	if away.length() < 0.2:
		away = Vector3(cam_dir.x, 0.0, cam_dir.z)
	var target := player.global_position + away.normalized() * (block_size * 0.5 + 0.6)
	return _drop(Vector3(target.x, pos.y, target.z), pos.y)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)

func _water_y() -> float:
	var water := get_tree().get_first_node_in_group("water_volume")
	return water.get_surface_y() if water else NAN

func _transform_for(point: Vector3, normal: Vector3, on_water: bool, yaw_deg: float) -> Transform3D:
	var center := point + normal * (block_size * 0.5)
	if on_water:
		center = Vector3(point.x, point.y + water_float_offset, point.z)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), center)

func _is_valid(xform: Transform3D) -> bool:
	return _check(xform) == ""

## Devuelve "" si se puede crear el bloque ahí, o el motivo si no.
func _check(xform: Transform3D) -> String:
	if blocks.size() >= max_blocks:
		return "Límite de %d bloques: rompe uno (clic der.)" % max_blocks
	if player.stamina < create_cost:
		return "Sin resistencia"
	if player.global_position.distance_to(xform.origin) > place_range:
		return "Muy lejos"
	var space := player.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * (block_size - 0.1)
	params.shape = shape
	params.transform = xform
	params.collision_mask = 1
	if not space.intersect_shape(params, 1).is_empty():
		return "No cabe"
	if not _has_support(xform):
		return "Necesita apoyo (suelo, agua, bloque o pared)"
	return ""

## ¿El bloque toca algo que lo sostenga? Agua bajo él, o cualquier cuerpo
## a su alrededor que no sea Kael ni hielo pulido.
func _has_support(xform: Transform3D) -> bool:
	var water_y := _water_y()
	var bottom := xform.origin.y - block_size * 0.5
	if not is_nan(water_y) and bottom <= water_y + 0.05:
		return true
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * (block_size + support_margin * 2.0)
	params.shape = shape
	params.transform = xform
	params.collision_mask = 1
	params.exclude = [player.get_rid()]
	for r in player.get_world_3d().direct_space_state.intersect_shape(params, 16):
		var c: Object = r.collider
		if c is Node and not (c as Node).is_in_group("no_climb"):
			return true
	return false

func _update_ghost() -> void:
	_ghost.visible = _aim_found
	if not _aim_found:
		return
	_ghost.global_transform = _aim_transform
	_ghost.material_override = _ghost_ok if aim_valid else _ghost_bad

func try_create() -> bool:
	if not _aim_found or not aim_valid:
		return false
	if _create_at(_aim_transform):
		reset_offsets()
		return true
	return false

func try_break() -> bool:
	if not _aim_found or _aim_collider == null or not (_aim_collider is Node):
		return false
	var node := _aim_collider as Node
	if not node.is_in_group("ice_block") or player.global_position.distance_to(node.global_position) > place_range:
		return false
	blocks.erase(node)
	node.shatter()
	return true

## API para pruebas: crea un bloque pegado a `point` según `normal`.
func place_at(point: Vector3, normal: Vector3 = Vector3.UP, on_water: bool = false) -> bool:
	var xform := _transform_for(point, normal, on_water, 0.0)
	if not _is_valid(xform) or (not on_water and _touches_no_ice(point, normal)):
		return false
	return _create_at(xform)

## API para pruebas: apila un bloque encima de la pila de `block`.
func stack_on(block: Node3D) -> bool:
	var xform := _stack_on(block)
	if not _is_valid(xform):
		return false
	return _create_at(xform)

## ¿La superficie en `point` es hielo pulido? (rayo corto contra la normal)
func _touches_no_ice(point: Vector3, normal: Vector3) -> bool:
	var hit := _ray(point + normal * 0.3, point - normal * 0.3)
	return not hit.is_empty() and hit.collider is Node and (hit.collider as Node).is_in_group("no_climb")

func _create_at(xform: Transform3D) -> bool:
	if block_scene == null or _cooldown_timer > 0.0 or player.stamina < create_cost or blocks.size() >= max_blocks:
		return false
	var block := block_scene.instantiate() as Node3D
	player.get_parent().add_child(block)
	block.global_transform = xform
	blocks.append(block)
	block.tree_exited.connect(func(): blocks.erase(block))
	player.stamina -= create_cost
	player.stamina_regen_timer = 0.0
	_cooldown_timer = cooldown
	return true

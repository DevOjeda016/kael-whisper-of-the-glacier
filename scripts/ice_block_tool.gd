extends Node3D

## Herramienta de bloques de hielo (estilo Cryonis de Zelda). Hijo del Player.
## Q activa el modo hielo: clic izquierdo crea un bloque donde apunta la
## cámara, clic derecho rompe el bloque apuntado, la rueda gira la vista previa.
## Crear cuesta resistencia y hay un máximo de bloques activos.

@export var block_scene: PackedScene
@export var max_blocks: int = 4
@export var create_cost: float = 0.8
@export var place_range: float = 12.0
@export var block_size: float = 2.0
@export var yaw_step_deg: float = 15.0
@export var cooldown: float = 0.25
@export var water_float_offset: float = 0.2   # centro del bloque sobre la superficie del agua

var mode_active: bool = false
var aim_valid: bool = false
var blocks: Array[Node3D] = []

var _yaw_offset_deg: float = 0.0
var _cooldown_timer: float = 0.0
var _ghost: MeshInstance3D = null
var _ghost_ok: StandardMaterial3D = null
var _ghost_bad: StandardMaterial3D = null
var _aim_found: bool = false
var _aim_point: Vector3 = Vector3.ZERO
var _aim_normal: Vector3 = Vector3.UP
var _aim_on_water: bool = false
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
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				try_create()
			MOUSE_BUTTON_RIGHT:
				try_break()
			MOUSE_BUTTON_WHEEL_UP:
				_yaw_offset_deg += yaw_step_deg
			MOUSE_BUTTON_WHEEL_DOWN:
				_yaw_offset_deg -= yaw_step_deg

func set_mode(active: bool) -> void:
	if active and (player.state == player.State.CLIMBING or player.state == player.State.DROWNING):
		return
	mode_active = active
	if not active:
		_ghost.visible = false
		aim_valid = false

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
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 80.0)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	var best := INF
	if not hit.is_empty():
		_aim_point = hit.position
		_aim_normal = hit.normal
		_aim_collider = hit.collider
		_aim_on_water = false
		_aim_found = true
		best = from.distance_to(_aim_point)
	var water := get_tree().get_first_node_in_group("water_volume")
	if water and dir.y < -0.001:
		var t: float = (water.get_surface_y() - from.y) / dir.y
		if t > 0.0 and t < best:
			_aim_point = from + dir * t
			_aim_normal = Vector3.UP
			_aim_collider = null
			_aim_on_water = true
			_aim_found = true
	if _aim_found:
		var cam_yaw := cam.global_rotation.y
		var yaw := snappedf(rad_to_deg(cam_yaw), yaw_step_deg) + _yaw_offset_deg
		_aim_transform = _transform_for(_aim_point, _aim_normal, _aim_on_water, yaw)
		aim_valid = _is_valid(_aim_transform)
	else:
		aim_valid = false

func _transform_for(point: Vector3, normal: Vector3, on_water: bool, yaw_deg: float) -> Transform3D:
	var center := point + normal * (block_size * 0.5)
	if on_water:
		center = Vector3(point.x, point.y + water_float_offset, point.z)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), center)

func _is_valid(xform: Transform3D) -> bool:
	if player.global_position.distance_to(xform.origin) > place_range:
		return false
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * (block_size - 0.1)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = xform
	params.collision_mask = 1
	return player.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()

func _update_ghost() -> void:
	_ghost.visible = _aim_found
	if not _aim_found:
		return
	_ghost.global_transform = _aim_transform
	var enough: bool = player.stamina >= create_cost
	_ghost.material_override = _ghost_ok if (aim_valid and enough) else _ghost_bad

func try_create() -> bool:
	if not _aim_found or not aim_valid:
		return false
	return _create_at(_aim_transform)

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
	if not _is_valid(xform):
		return false
	return _create_at(xform)

func _create_at(xform: Transform3D) -> bool:
	if block_scene == null or _cooldown_timer > 0.0 or player.stamina < create_cost:
		return false
	var block := block_scene.instantiate() as Node3D
	player.get_parent().add_child(block)
	block.global_transform = xform
	blocks.append(block)
	block.tree_exited.connect(func(): blocks.erase(block))
	if blocks.size() > max_blocks:
		var oldest: Node3D = blocks.pop_front()
		oldest.shatter()
	player.stamina -= create_cost
	player.stamina_regen_timer = 0.0
	_cooldown_timer = cooldown
	return true

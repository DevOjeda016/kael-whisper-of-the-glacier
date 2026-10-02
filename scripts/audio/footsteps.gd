extends Node

## Pasos de Kael (hijo del Player): un crujido de nieve cada `stride` metros
## caminados, un golpe al aterrizar y brazadas al nadar.

@export var stride: float = 0.6
@export var step_volume_db: float = -10.0
@export var land_min_speed: float = 3.5     # velocidad de caída para sonar al aterrizar
@export var swim_stroke_interval: float = 0.85

@onready var player: CharacterBody3D = get_parent()

var _dist: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _swim_timer: float = 0.0

func _physics_process(delta: float) -> void:
	var on_floor := player.is_on_floor()
	var state: int = player.get("state")
	var horizontal := Vector2(player.velocity.x, player.velocity.z).length()
	var feet := player.global_position

	if state == 0 and on_floor:
		if not _was_on_floor and _fall_speed > land_min_speed:
			Sfx.play_at("step_snow", feet, step_volume_db + 4.0, 0.05)
			_dist = 0.0
		_dist += horizontal * delta
		if _dist >= stride:
			_dist = 0.0
			# En los bloques y el hielo pulido el paso suena más agudo.
			var pitch := 1.0
			var col := player.get_last_slide_collision()
			if col and col.get_collider() is Node:
				var n := col.get_collider() as Node
				if n.is_in_group("ice_block") or n.is_in_group("no_climb"):
					pitch = 1.35
			Sfx.play_at("step_snow", feet, step_volume_db, 0.1, pitch)
	elif state == 2 and horizontal > 0.8:
		_swim_timer -= delta
		if _swim_timer <= 0.0:
			_swim_timer = swim_stroke_interval
			Sfx.play_at("splash", feet, -20.0, 0.2)

	if not on_floor:
		_fall_speed = maxf(_fall_speed, -player.velocity.y)
	else:
		_fall_speed = 0.0
	_was_on_floor = on_floor

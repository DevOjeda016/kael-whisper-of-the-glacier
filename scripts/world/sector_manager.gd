extends Node3D

## Carga los sectores del mundo en segundo plano cuando Kael se acerca.
## Los sectores dentro del radio al iniciar se cargan de inmediato para que
## no haya un frame sin suelo. Por defecto nunca se descargan (el grey-box
## cabe en memoria); activa unload_far_sectors si el rendimiento lo pide.

@export_file("*.tscn") var sector_paths: Array[String] = []
@export var sector_centers: Array[Vector3] = []
@export var load_radius: float = 200.0
@export var unload_margin: float = 40.0
@export var unload_far_sectors: bool = false

var _player: Node3D = null
var _loaded: Dictionary = {}   # índice -> Node
var _loading: Dictionary = {}  # índice -> true

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		push_warning("SectorManager: no hay jugador; se cargan todos los sectores.")
	for i in sector_paths.size():
		if _player == null or _distance_to(i) < load_radius:
			_add_sector(i, load(sector_paths[i]))

func _process(_delta: float) -> void:
	if _player == null:
		return
	for i in sector_paths.size():
		var dist := _distance_to(i)
		if _loaded.has(i):
			if unload_far_sectors and dist > load_radius + unload_margin:
				_loaded[i].queue_free()
				_loaded.erase(i)
		elif _loading.has(i):
			var status := ResourceLoader.load_threaded_get_status(sector_paths[i])
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_loading.erase(i)
				_add_sector(i, ResourceLoader.load_threaded_get(sector_paths[i]))
		elif dist < load_radius:
			ResourceLoader.load_threaded_request(sector_paths[i])
			_loading[i] = true

func _distance_to(i: int) -> float:
	var c := sector_centers[i]
	var p := _player.global_position
	return Vector2(p.x - c.x, p.z - c.z).length()

func _add_sector(i: int, scene: Resource) -> void:
	var t0 := Time.get_ticks_msec()
	var inst := (scene as PackedScene).instantiate()
	add_child(inst)
	_loaded[i] = inst
	print("Sector cargado: %s (%d ms)" % [sector_paths[i], Time.get_ticks_msec() - t0])

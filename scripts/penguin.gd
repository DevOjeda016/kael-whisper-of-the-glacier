extends Node3D

## Escenas adicionales de Meshy (mismo esqueleto) que solo aportan animaciones.
## Se fusionan en el AnimationPlayer del modelo base al iniciar.
@export var extra_animation_scenes: Array[PackedScene] = []

var anim_player: AnimationPlayer
var current_animation: String = ""

func _ready() -> void:
	anim_player = find_animation_player(self)
	if anim_player == null:
		push_warning("Penguin: no se encontró AnimationPlayer en el modelo base.")
		return

	_merge_extra_animations()

	var anims := anim_player.get_animation_list()
	print("Penguin: animaciones disponibles -> ", anims)

## Devuelve el nombre de la animación cuyo nombre contiene 'keyword' (sin
## distinguir mayúsculas) y que tenga la mayor duración. Sirve para evitar
## depender de nombres exactos que Godot puede renombrar al reimportar.
func get_best_animation(keyword: String) -> String:
	if anim_player == null:
		return ""
	var best_name := ""
	var best_length := -1.0
	for anim_name in anim_player.get_animation_list():
		if keyword.to_lower() in anim_name.to_lower():
			var length: float = anim_player.get_animation(anim_name).length
			if length > best_length:
				best_length = length
				best_name = anim_name
	return best_name

func is_playing_animation(anim_name: String) -> bool:
	return anim_player != null and anim_player.current_animation == anim_name and anim_player.is_playing()

## Congela/reanuda la animación actual sin reiniciarla (usa speed_scale en
## vez de stop(), así conserva el frame exacto en el que se pausó).
func set_animation_paused(paused: bool) -> void:
	if anim_player != null:
		anim_player.speed_scale = 0.0 if paused else 1.0

func play_animation(anim_name: String, loop: bool = true, blend: float = 0.2, speed: float = 1.0) -> void:
	if anim_player == null or not anim_player.has_animation(anim_name):
		push_warning("Penguin: animación '%s' no existe." % anim_name)
		return
	if current_animation == anim_name and anim_player.is_playing():
		return
	var anim := anim_player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim_player.speed_scale = speed
	anim_player.play(anim_name, blend)
	current_animation = anim_name

func _merge_extra_animations() -> void:
	for scene in extra_animation_scenes:
		if scene == null:
			continue
		var temp := scene.instantiate()
		var temp_player := find_animation_player(temp)
		if temp_player:
			for lib_name in temp_player.get_animation_library_list():
				var lib := temp_player.get_animation_library(lib_name)
				var target_lib := anim_player.get_animation_library(lib_name)
				if target_lib == null:
					target_lib = AnimationLibrary.new()
					anim_player.add_animation_library(lib_name, target_lib)
				for anim_name in lib.get_animation_list():
					if not target_lib.has_animation(anim_name):
						target_lib.add_animation(anim_name, lib.get_animation(anim_name))
		temp.queue_free()

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := find_animation_player(child)
		if result:
			return result
	return null

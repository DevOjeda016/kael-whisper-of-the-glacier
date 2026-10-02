extends Area3D

## Baliza de un puzzle (como los santuarios de BotW): un cristal gris con un
## haz de luz tenue visible desde lejos. Al tocarla por primera vez se
## enciende en azul, registra el punto de interés, da peces y muestra una nota.

@export var poi_id: String = "baliza"
@export_multiline var note_text: String = ""
@export var fish_reward: int = 1

@onready var crystal: MeshInstance3D = $Crystal
@onready var beam: MeshInstance3D = $Beam
@onready var light: OmniLight3D = $OmniLight3D

var activated: bool = false
var _crystal_mat := StandardMaterial3D.new()
var _beam_mat := StandardMaterial3D.new()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	_crystal_mat.albedo_color = Color(0.55, 0.58, 0.62)
	_crystal_mat.roughness = 0.4
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.2, 0.55, 1.0)
	_crystal_mat.emission_energy_multiplier = 0.0
	crystal.material_override = _crystal_mat

	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(0.85, 0.88, 0.92, 0.1)
	beam.material_override = _beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	light.light_energy = 0.0
	if GameState.is_solved(poi_id):
		_apply_active(1.0)
		activated = true

func _on_body_entered(body: Node3D) -> void:
	if activated or not body.is_in_group("player"):
		return
	activated = true
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_apply_active, 0.0, 1.0, 1.2)

	var first := GameState.solve_poi(poi_id)
	if first:
		Sfx.play("beacon_chime", -4.0)
		GameState.add_fish(fish_reward)
		var ui := get_tree().get_first_node_in_group("note_ui")
		if ui:
			ui.show_note(note_text, fish_reward)
	print("Baliza activada: ", poi_id)

## t = 0 apagada (gris), t = 1 encendida (azul brillante).
func _apply_active(t: float) -> void:
	_crystal_mat.albedo_color = Color(0.55, 0.58, 0.62).lerp(Color(0.5, 0.8, 1.0), t)
	_crystal_mat.emission_energy_multiplier = 2.5 * t
	_beam_mat.albedo_color = Color(0.85, 0.88, 0.92, 0.1).lerp(Color(0.35, 0.7, 1.0, 0.35), t)
	light.light_energy = 3.0 * t

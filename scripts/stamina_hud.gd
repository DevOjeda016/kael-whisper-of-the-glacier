extends Control

## Rueda de resistencia circular estilo Breath of the Wild: solo se muestra
## mientras Kael la está gastando (corriendo o trepando) o hasta que se
## vuelve a llenar del todo; el resto del tiempo permanece invisible.

@export var ring_radius: float = 30.0
@export var ring_width: float = 8.0
@export var fade_speed: float = 4.0       # velocidad de aparición/desvanecido
@export var full_hold_time: float = 0.8   # segundos visible tras llenarse antes de ocultarse

var player: Node = null
var display_alpha: float = 0.0
var full_timer: float = 0.0
var current_ratio: float = 1.0
var flash_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	current_ratio = player.get_stamina_ratio() if player.has_method("get_stamina_ratio") else 1.0

	var target_alpha := 0.0
	if current_ratio < 0.999:
		target_alpha = 1.0
		full_timer = 0.0
	else:
		full_timer += delta
		target_alpha = 1.0 if full_timer < full_hold_time else 0.0

	display_alpha = move_toward(display_alpha, target_alpha, fade_speed * delta)
	modulate.a = display_alpha
	flash_timer += delta

	queue_redraw()

func _draw() -> void:
	if display_alpha <= 0.001:
		return

	var center: Vector2 = size * 0.5

	# Fondo del anillo (siempre visible mientras el HUD está activo).
	draw_arc(center, ring_radius, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.4), ring_width + 3.0, true)

	if current_ratio <= 0.001:
		# Sin resistencia: destello rojo pulsante en el anillo completo.
		var pulse: float = 0.5 + 0.5 * sin(flash_timer * 10.0)
		var empty_color := Color(0.9, 0.15, 0.15).lerp(Color(1.0, 0.55, 0.15), pulse)
		draw_arc(center, ring_radius, 0.0, TAU, 48, empty_color, ring_width, true)
		return

	var fill_color := Color(0.35, 0.95, 0.45)   # verde: resistencia normal
	if current_ratio < 0.25:
		fill_color = Color(0.95, 0.8, 0.2)       # ámbar: resistencia baja

	# Arco que se vacía en sentido horario desde arriba, igual que en BOTW.
	var start_angle := -PI / 2.0
	var end_angle := start_angle + TAU * current_ratio
	var point_count: int = max(2, int(48 * current_ratio))
	draw_arc(center, ring_radius, start_angle, end_angle, point_count, fill_color, ring_width, true)

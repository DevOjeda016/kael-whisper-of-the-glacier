extends Node

## Estado de progreso de la partida (autoload "GameState"): puntos de interés
## resueltos y peces brillantes. Lo usan las balizas, el HUD y, más adelante,
## el guardado y el final (entregar los peces a la colonia).

signal poi_solved(id: String)
signal fish_changed(count: int)

## Meta mínima de puntos de interés del PDF (5 a 8); ajustable.
@export var total_pois: int = 5

var solved_pois: Dictionary = {}
var fish_count: int = 0

func is_solved(id: String) -> bool:
	return solved_pois.has(id)

func solved_count() -> int:
	return solved_pois.size()

## Marca un punto de interés como resuelto. Devuelve false si ya lo estaba.
func solve_poi(id: String) -> bool:
	if solved_pois.has(id):
		return false
	solved_pois[id] = true
	poi_solved.emit(id)
	return true

func add_fish(amount: int = 1) -> void:
	fish_count += amount
	fish_changed.emit(fish_count)

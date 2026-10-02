# Kael: Whisper of the Glacier

Puzzle-platformer 3D en Godot 4.7 (GDScript). Kael, pingüino que trepa y manipula hielo, cruza un glaciar partido para rescatar a su hermana.

## Fuente de verdad
`docs/Portafolio_Kael_Whisper_of_the_Glacier.pdf` es la **visión guía**, no una especificación rígida. Las mecánicas se ajustan iterando según el gusto del autor. Lo que el código hace y el PDF no dice (salto grande, acostarse por inactividad) son ideas válidas en curso.

Límites firmes del diseño: sin combate, sin vida/daño, sin fracaso duro. Un solo glaciar con 5 a 8 puntos de interés (no ampliar). Marea solo narrativa, sin temporizador.

## Estructura
- `scenes/main.tscn`: escena principal (Player, SpringArm3D, HUD con anillo de stamina y FPS) que instancia `scenes/world/world.tscn`.
- `scenes/world/`: `world.tscn` (entorno, luz, agua, muros perimetrales, SectorManager), `sector_start/ridge/far.tscn` (grey-box, **generados**: editarlos a mano en Godot está bien), `point_of_interest.tscn`, `checkpoint_totem.tscn`.
- `scenes/props/`: provisionales `rock.tscn` e `ice_crystal.tscn` (el nodo `Visual` es lo que se reemplaza por el modelo de Meshy).
- `scripts/world/`: `ice_formation.gd` (caja procedural con paredes onduladas verticales + colisión trimesh, ruido en coordenadas de mundo para que las vecinas encajen), `glacier_backdrop.gd` (anillo de glaciares lejanos que esconde el borde del mapa), `prop_scatter.gd` (esparce una escena sobre el terreno con raycast), `sector_manager.gd` (carga sectores por distancia), `point_of_interest.gd` (señal `visited`), `checkpoint_totem.gd` (guarda reaparición).
- `scripts/player_controller.gd`: movimiento, salto, sprint, trepar, stamina, cámara.
- `scripts/penguin.gd`: fusiona animaciones de varios GLB en un AnimationPlayer; `get_best_animation(keyword)`.
- `scripts/stamina_hud.gd`: anillo de resistencia estilo BOTW.
- `assets/models/penguin*/`: GLB de Meshy (modelo base + una carpeta por animación).
- `addons/meshy/`: plugin de Meshy.
- `docs/`: documento de diseño.

## Convenciones
- Comentarios y textos en español. Indentación con tabs.
- Valores de ajuste como `@export`, con comentario del porqué.
- Trepar: cualquier superficie casi vertical (`|normal.y| < climb_max_normal_y`) salvo las del grupo `no_climb`. El jugador está en el grupo `player`.
- Stamina: ~12 m de trepada máximo y solo regenera en suelo; los acantilados del mapa se parten en escalones de ≤10 m con repisas para descansar.
- Caer bajo `fall_limit_y` reaparece en el último tótem tocado, sin castigo.
- Nadar: agua en y=-1.5 (`scenes/world/world.tscn`, `Water/Volume` con `water_volume.gd`). Cansa, no regenera en el agua; sin resistencia = ahogarse (fundido y reaparecer en el último punto seguro). Se sale trepando la orilla o saltando. Esto reemplaza el "sin fracaso duro" del PDF por un fracaso suave.
- Animación 'swim': si hay una animación con "swim" en el nombre se usa sola; si no, correr a 0.6x.
- Animaciones se buscan por palabra clave, no por nombre exacto (Godot renombra al reimportar).

## Meshy
Al descargar animaciones el plugin crea `imported_models/` con copias duplicadas ("Waving Penguin_N"). Está en `.gitignore`: ignorarlo, copiar a `assets/models/` solo lo que se use.

## Git
Binarios (`.glb`, `.png`, audio) van por Git LFS (`.gitattributes`). Se versionan `.import` y `.uid`; `.godot/` no.

## Mapa (grey-box, ~300x300 m, norte = -Z)
Orilla de inicio al sur (y=0) -> cordillera con terrazas (y=15, 30) -> grieta de 12 m (barrera) -> orilla lejana al norte (y=12). Un puente en el extremo este cruza la grieta mientras no existan los bloques de hielo. 6 puntos de interés y 2 tótems. El sector inicial tiene un estanque con isla para nadar.

## Reemplazar provisionales por arte de Meshy
- Prop suelto (rock, ice_crystal, totem): abrir su `.tscn`, borrar el nodo `Visual`/malla y arrastrar ahí el `.glb`; todas las copias se actualizan.
- Esparcido: en el nodo `Rocks`/`Crystals` de cada sector, cambiar `scene` por la escena nueva.
- Formaciones (`IceFormation`): reemplazar el nodo por el modelo con su colisión; mantener paredes casi verticales para poder trepar.

## Siguiente
Nadar y bloques de hielo (apilar/romper) sobre este mapa; luego puzzles de los puntos de interés.

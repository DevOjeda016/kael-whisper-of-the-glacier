# Kael: Whisper of the Glacier

Puzzle-platformer 3D en Godot 4.7 (GDScript). Kael, pingüino que trepa y manipula hielo, cruza un glaciar partido para rescatar a su hermana.

## Fuente de verdad
`docs/Portafolio_Kael_Whisper_of_the_Glacier.pdf` es la **visión guía**, no una especificación rígida. Las mecánicas se ajustan iterando según el gusto del autor. Lo que el código hace y el PDF no dice (salto grande, acostarse por inactividad) son ideas válidas en curso.

Límites firmes del diseño: sin combate, sin vida/daño, sin fracaso duro. Un solo glaciar con 5 a 8 puntos de interés (no ampliar). Marea solo narrativa, sin temporizador.

## Estructura
- `scenes/main.tscn`: escena principal (Player, SpringArm3D, HUD, suelo y pared de prueba).
- `scripts/player_controller.gd`: movimiento, salto, sprint, trepar, stamina, cámara.
- `scripts/penguin.gd`: fusiona animaciones de varios GLB en un AnimationPlayer; `get_best_animation(keyword)`.
- `scripts/stamina_hud.gd`: anillo de resistencia estilo BOTW.
- `assets/models/penguin*/`: GLB de Meshy (modelo base + una carpeta por animación).
- `addons/meshy/`: plugin de Meshy.
- `docs/`: documento de diseño.

## Convenciones
- Comentarios y textos en español. Indentación con tabs.
- Valores de ajuste como `@export`, con comentario del porqué.
- Trepar solo en nodos del grupo `climbable`; el jugador está en el grupo `player`.
- Animaciones se buscan por palabra clave, no por nombre exacto (Godot renombra al reimportar).

## Meshy
Al descargar animaciones el plugin crea `imported_models/` con copias duplicadas ("Waving Penguin_N"). Está en `.gitignore`: ignorarlo, copiar a `assets/models/` solo lo que se use.

## Git
Binarios (`.glb`, `.png`, audio) van por Git LFS (`.gitattributes`). Se versionan `.import` y `.uid`; `.godot/` no.

## Siguiente
Mapa: grey-box del glaciar, terreno trepable, sectores, puntos de interés. Luego nadar y bloques de hielo.

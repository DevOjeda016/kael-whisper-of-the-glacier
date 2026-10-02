# Bitácora de cambios — Kael: Whisper of the Glacier

Una entrada por cambio: qué se hizo, por qué, qué archivos toca y cómo ajustarlo. Lo más reciente va arriba.

---

## Bloques de hielo (crear y romper, estilo Cryonis)

**Qué:** Kael crea bloques de hielo donde apunta la cámara y los rompe. Sirven para puentes, escalones y plataformas: se camina encima y se trepan por las paredes. También flotan sobre el agua.

**Controles:** **Q** activa el modo hielo (mira + vista previa). Dentro: **clic izquierdo** crea, **clic derecho** rompe el bloque apuntado, **rueda** gira 15°, **Q** sale. Empezar a trepar o ahogarse lo apaga solo. Se usa en suelo y nadando.

**Reglas:**
- Cubo de 2 m, colocación libre pegado a la superficie apuntada (se apila sobre otros bloques y contra paredes). El agua cuenta como suelo; el bloque flota con el centro a +0.2 m.
- Alcance de 12 m desde Kael. La vista previa es azul si se puede y roja si no (fuera de alcance, solapado con algo —incluido Kael— o sin resistencia).
- Crear cuesta 0.8 de resistencia. Máximo 4 bloques activos: al crear el quinto, el más viejo se deshace. Romper es gratis.
- Una brecha de agua de ~10 m se cruza con bloques separados 2 m (el salto alcanza ~3 m) o encadenando: cruzar, romper el primero, crear el siguiente.

**Por qué:** es la herramienta central del PDF (bloques modulares para puentes, rampas y rutas de escape); el balance queda en cantidad de bloques y costo de resistencia, no en daño.

**Archivos:**
- `scripts/ice_block_tool.gd` (nuevo, hijo de `Player`): modo, apuntado, vista previa, validación, crear/romper. Tiene `place_at()` para pruebas.
- `scripts/ice_block.gd` + `scenes/props/ice_block.tscn` (nuevos): el bloque. El nodo `Visual` es el que se reemplaza por el modelo de Meshy.
- `scripts/ice_hud.gd` (nuevo): mira y texto de ayuda.
- `assets/materials/ice_block.tres` (nuevo).
- `scripts/world/water_volume.gd`: se agrega al grupo `water_volume` (la herramienta lo usa para apuntar al agua).
- `scenes/main.tscn`: nodos `IceBlockTool` e `IceHud`.

**Ajustes (`@export` de `IceBlockTool`):** `max_blocks`, `create_cost`, `place_range`, `block_size`, `yaw_step_deg`, `cooldown`, `water_float_offset`.

**Pruebas:** en headless: el costo se descuenta, no crea solapado ni sin resistencia, respeta el máximo de 4, Kael trepa y cruza un bloque, y un puente de 2 bloques sobre el estanque lo lleva a la isla sin nadar. Una captura confirma la mira, la vista previa y el texto.

**Notas:** si dos bloques quedan separados exactamente 1 m, la cápsula de Kael (radio 0.5) puede atorarse en el hueco; conviene separarlos 2 m o juntarlos. Sin animaciones de crear/romper (pendientes de Meshy: `apilar bloque`, `romper bloque`). Una captura mostró ~37 FPS justo al cargar; en capturas anteriores iba a 60, por revisar a mano.

---

## Atmósfera: nieve, viento, agua con movimiento y hielo brillante

**Qué:**
- **Nieve:** ~1000 copos caen alrededor del jugador (el emisor lo sigue, los copos se quedan en el mundo).
- **Viento:** empuja los copos con ráfagas que cambian lento. Solo afecta a la nieve, no a la niebla.
- **Agua:** la superficie tiene un mapa de normales de ruido que se desplaza despacio, así que ondula y refleja.
- **Hielo:** los materiales de hielo y nieve ganaron brillo en los bordes (rim) y capa brillante (clearcoat). No es un shader propio: son opciones de `StandardMaterial3D`, así no hay código de shader que mantener.

**Por qué:** era lo que faltaba del ambiente (antes solo había una niebla suave) y le da vida al mapa antes de poner arte final.

**Archivos:**
- `scripts/world/snowfall.gd` (nuevo) + nodo `Snowfall` en `scenes/world/world.tscn`.
- `scripts/world/water_surface.gd` (nuevo) en `Water/Surface`.
- `assets/materials/ice_grey.tres`, `ice_smooth.tres`, `snow_grey.tres`.

**Ajustes:** en `Snowfall`: `wind_direction`, `wind_strength`, `gust_strength`, `gust_speed`, `flake_size`, `area`. En `Water/Surface`: `tile_size`, `scroll_speed`, `normal_strength`. En los `.tres`: `rim`, `clearcoat`, `roughness`.

**Pruebas:** capturas con Godot: 60 FPS con todo activo. La nieve es discreta a propósito; sube `flake_size` o el `amount` del emisor si la quieres más densa.

**Pendiente:** viento sobre la niebla, ventisca más fuerte por zonas, nieve que se acumula, splash al caer al agua.

---

## Nadar y ahogarse (estilo Zelda)

**Qué:** Kael ya puede nadar. Es lento y cansa; no regenera resistencia en el agua y, si se acaba, se ahoga: se hunde, la pantalla se funde a azul oscuro y reaparece en tierra firme (último punto seguro) con la resistencia llena.

**Cómo funciona:**
- El agua está en y=-1.5. Al bajar los pies de la superficie, Kael pasa al estado `SWIMMING`: sin gravedad, flotando con el agua a la altura del pecho.
- Nada a 2.5 m/s (Shift: 3.5) y gasta 0.7/s (+0.7 con Shift). Con 5 de resistencia alcanza ~17 m.
- Para salir: avanzar contra la pared de la orilla (reusa el trepado y el impulso de cornisa) o saltar (cuesta 0.5 de resistencia).
- El punto seguro se guarda cada 0.75 s en suelo, solo si hay suelo firme a 1.3 m alrededor (así no se guardan bordes de orilla). Al ahogarse se usa el de hace ~1.5 s; si no hay, el último tótem.
- Animación provisional: la de correr a 0.6x más un anillo de ondas. Cuando exista una animación con "swim" en el nombre (Meshy), se usa sola.

**Mapa:** el sector inicial tiene un estanque de 60x30 m (z 85..115) con una isla de 10x10 en el centro (punto de interés + cristales). Llegar a la isla cuesta ~4 s de resistencia; volver, otros 4. Los glaciares de fondo ahora tocan el agua (`sea_level` = -1.5).

**Cambio de diseño:** el PDF decía "sin fracaso duro". Ahogarse es ahora un fracaso suave (reaparecer en tierra), sin pantalla de Game Over ni pérdida de progreso. Conviene reflejarlo en el documento de diseño.

**Archivos:**
- `scripts/player_controller.gd`: estados `SWIMMING` y `DROWNING`, `_process_swimming`, `_start_drowning`, rastro de puntos seguros, ondas.
- `scripts/world/water_volume.gd` (nuevo): `Area3D` en la superficie que avisa al jugador.
- `scripts/screen_fade.gd` (nuevo): fundido de pantalla (grupo `screen_fade`).
- `scenes/world/world.tscn`: `Water` (plano + volumen) en y=-1.5.
- `scenes/main.tscn`: nodo `ScreenFade` en el HUD.
- `scenes/world/sector_start.tscn`: suelo partido en 4 losas + estanque + isla (generado; editable en Godot).
- `scripts/world/glacier_backdrop.gd`: `sea_level` -1.5.

**Ajustes (`@export` del Player):** `swim_speed`, `swim_sprint_multiplier`, `swim_stamina_drain_rate`, `swim_sprint_extra_drain`, `swim_float_depth`, `water_jump_velocity`, `water_jump_cost`, `drown_sink_time`, `safe_trail_interval`.

**Pruebas:** en headless, caída al estanque, nado, salida trepando y ahogamiento con reaparición; capturas con Godot confirman el aspecto. No he probado a mano la sensación de control.

**Pendiente:** animación real de nadar (Meshy), splash al caer, agua con movimiento.

---

## Terreno procedural, glaciares de fondo y props provisionales
**Commit:** `a691d60`

**Qué:** el mapa dejó de ser cajas lisas. Las formaciones son mallas generadas por código con paredes onduladas (siguen verticales, se pueden trepar) y cima con relieve. Un anillo de glaciares lejanos esconde el borde del mundo. Rocas y cristales de hielo provisionales se esparcen solos.

**Por qué:** que el mapa se sienta como un glaciar y que el borde no se note. Los provisionales se reemplazan luego por los modelos de Meshy.

**Archivos:**
- `scripts/world/ice_formation.gd`: caja procedural + colisión trimesh. El ruido usa coordenadas de mundo para que las formaciones vecinas encajen.
- `scripts/world/glacier_backdrop.gd`: anillo de glaciares (solo visual, sin colisión).
- `scripts/world/prop_scatter.gd`: esparce una escena sobre el terreno con raycast.
- `scenes/props/rock.tscn`, `scenes/props/ice_crystal.tscn`: provisionales (nodo `Visual` = lo que se reemplaza).
- `scenes/world/sector_*.tscn`: regenerados con las formaciones y el esparcido.

**Ajustes:** `wobble`, `top_bump` y `strata` en cada formación; `peak_height`, `inner_radius` en el fondo; `count`, `area` y `min/max_scale` en `Rocks`/`Crystals`.

**Notas:** cada sector tarda 150–280 ms en generarse al cargar. La niebla (`fog_density` en `world.tscn`) es lo único de ambiente hecho; nieve y viento quedan pendientes.

---

## Grey-box del glaciar con sectores
**Commit:** `0750c8e`

**Qué:** mapa de ~300x300 m: orilla de inicio al sur, cordillera con terrazas, grieta de 12 m y orilla lejana al norte (norte = -Z). 3 sectores que carga `SectorManager` según la distancia, 5 puntos de interés y 2 tótems de punto de control.

**También:**
- Trepar ahora funciona en cualquier superficie casi vertical (`|normal.y| < climb_max_normal_y`), salvo las del grupo `no_climb`.
- Impulso al llegar al borde superior para subirse a la cornisa (`ledge_boost_*`).
- Caer bajo `fall_limit_y` reaparece en el último tótem.
- Contador de FPS en pantalla.

**Por qué:** probar el movimiento en un espacio real. La stamina da ~12 m de trepada, así que los acantilados se parten en escalones de 10 m o menos con repisas para descansar.

**Archivos:** `scripts/player_controller.gd`, `scenes/main.tscn`, `scenes/world/*`, `scripts/world/*`, `scripts/fps_label.gd`, `assets/materials/*`.

---

## Repositorio en GitHub y limpieza inicial
**Commit:** `9bfb44d`

**Qué:** proyecto subido a https://github.com/DevOjeda016/kael-whisper-of-the-glacier (público, MIT). Git LFS para modelos, texturas y audio; `.gitignore` de Godot; `.editorconfig`; `README.md`; `CLAUDE.md` con el contexto del proyecto.

**También:** se movió `imported_models/` (duplicados que genera el plugin de Meshy) y `Meshy_AI_Character_output*` fuera del proyecto; el nombre pasó a "Kael: Whisper of the Glacier".

**Por qué:** poder mover el proyecto entre máquinas y que Claude tenga contexto en cada sesión.

**Notas:** `git-lfs` se instaló en `~/.local/bin` sin sudo. El email de los commits es el `noreply` de GitHub.

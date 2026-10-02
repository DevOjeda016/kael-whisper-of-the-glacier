# Kael: Whisper of the Glacier

Puzzle-platformer de aventura y exploración en un glaciar partido por una grieta. Kael, un pingüino torpe para nadar pero hábil para trepar, debe rescatar a su hermana y a su colonia. Sin combate ni fracaso duro.

Proyecto escolar (Universidad Tecnológica de León). El documento de diseño en [`docs/`](docs/Portafolio_Kael_Whisper_of_the_Glacier.pdf) es la visión guía; las mecánicas se ajustan iterando.

## Requisitos
- [Godot 4.7](https://godotengine.org/) (Forward Plus)
- [Git LFS](https://git-lfs.com/) (modelos y texturas)

## Cómo abrir
```bash
git lfs install
git clone https://github.com/DevOjeda016/kael-whisper-of-the-glacier.git
```
Abrir `project.godot` en Godot. La primera vez reimporta los assets.

## Controles
| Acción | Tecla |
|---|---|
| Mover | WASD / flechas |
| Saltar | Espacio |
| Correr | Shift |
| Cámara | Mouse |
| Liberar mouse | Esc |
| Descansar en un tótem (pasar el tiempo) | E |
| Modo hielo | Q |
| Crear bloque (en modo hielo) | Clic izquierdo |
| Romper bloque (en modo hielo) | Clic derecho |
| Acercar / alejar la vista previa | Rueda |
| Subir / bajar la vista previa | R / F |
| Girar bloque | Shift + rueda |

Apilar: apunta a un bloque (a cualquier cara) y la vista previa se pone encima de su pila.

Trepar: avanzar contra una pared trepable. Correr, trepar y el salto grande gastan resistencia.

## Herramientas
Godot 4.7 + GDScript, [Meshy](https://www.meshy.ai/) (modelos 3D y animaciones), ElevenLabs (voces).

# Gestión Restaurante

Juego de gestión de restaurantes para móvil (Android e iOS), hecho con **Godot 4.5**.

- Diseño del juego: [`docs/GDD.md`](docs/GDD.md)
- Proyecto de Godot: carpeta [`game/`](game/)

## Jugar en el navegador (también en el móvil)

👉 https://fercho-93.github.io/Gestion_Restaurante/

Se actualiza solo con cada cambio en `main` (GitHub Actions → GitHub Pages).
En el móvil, gíralo en horizontal.

## Cómo abrirlo en Godot

1. Descarga [Godot 4.5](https://godotengine.org/download) (versión estándar, no .NET).
2. En el gestor de proyectos: **Importar** → selecciona `game/project.godot`.
3. Pulsa **F5** para jugar.

Al empezar se elige el barrio (universitario, acomodado, alternativo u oficinas): cada
uno tiene su gente, sus precios, su alquiler y sus horas fuertes.

Botón **Construir** (arriba): con el tiempo parado se compran, colocan, giran, mueven y
venden mesas y decoración (verde = se puede, rojo = no, con el motivo).

Controles: tocar el suelo para mover al gestor; tocar a una persona para ir a hablar
con ella (el botón "Ficha" muestra sus necesidades, rasgos, gustos y recuerdos); tocarte a ti mismo para ponerte a atender mesas, limpiar o tomar un café;
tocar una mesa sucia o una mancha para limpiarla; el ordenador del despacho para
gestionar y la cafetera de la barra para recuperar energía; arrastrar para mover la cámara,
pellizcar o rueda para el zoom; barra espaciadora para pausar.

![Servicio de comidas](docs/captura_3d_servicio.png)

## Pruebas

```bash
godot --headless --path game -s res://tests/run_tests.gd
```

## Estructura

```
game/
  simulation/  lógica pura del juego (reloj, economía, cocina...)
  data/        contenido en JSON (ingredientes, recetas, barrios, perfiles, rasgos...)
  scenes/      pantalla de inicio, mundo isométrico y personajes
  ui/          interfaz
  tests/       pruebas automáticas
docs/          documento de diseño
```

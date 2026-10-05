# Documento de Diseño del Juego (GDD)

> Juego de gestión de restaurantes para móvil (Android + iOS).
> Documento vivo: se actualiza a medida que avanzamos.

---

## 1. Decisiones tomadas

| Tema | Decisión |
|---|---|
| Plataformas | Android e iOS |
| Motor | Godot 4.5 (GDScript), renderer *GL Compatibility* (máxima compatibilidad móvil) |
| Vista | Isométrica 2D |
| Orientación | Horizontal (landscape) |
| Tiempo | Tiempo real continuo estilo *Los Sims*: pausa, x1, x2, x4 |
| Gestor (protagonista) | Personaje propio, animado (pendiente de diseño) |
| Monetización | Por decidir más adelante |
| Forma de trabajo | Desarrollo iterativo, *vibe coding*, paso a paso |

---

## 2. Concepto

El jugador es el **gestor** de un restaurante. Empieza con poco dinero, elige dónde
abrir, monta el local, contrata personal, diseña la carta y lo saca adelante día a
día. La capa visual es **amable, colorida y divertida**; la capa de gestión es
**profunda y realista**.

### Pilares

1. **Realismo en la gestión**: cada decisión tiene consecuencias económicas y humanas
   que se pueden entender y medir (escandallos, mermas, turnos, reputación...).
2. **Se ve lo que pasa**: la simulación no es una hoja de cálculo; los problemas se
   ven en el restaurante (colas, camareros que corren, clientes enfadados).
3. **Agradable en el móvil**: partidas que se pueden pausar en cualquier momento,
   controles táctiles cómodos, menús claros.

---

## 3. Bucle de juego

```
 ┌───────────── Planificar (pausa o x1) ──────────────┐
 │  carta · precios · pedidos · turnos · decoración   │
 └──────────────────────┬─────────────────────────────┘
                        ▼
 ┌──────────── Servicio (x1 / x2 / x4) ───────────────┐
 │  llegan clientes · se cocina · se sirve · eventos  │
 └──────────────────────┬─────────────────────────────┘
                        ▼
 ┌──────────────── Cierre del día ────────────────────┐
 │  caja · reseñas · stock · moral · informe diario   │
 └──────────────────────┬─────────────────────────────┘
                        ▼
              Decidir mejoras → vuelta a empezar
```

Bucle largo: local pequeño → reputación → reformas → segundo local → cadena.

---

## 4. Tiempo

- El reloj de juego avanza continuamente. Velocidades: **pausa, x1, x2, x4**.
- A x1, **1 segundo real = 1 minuto de juego** (ajustable). Un servicio de
  12:00 a 24:00 dura 12 minutos reales a x1, 3 minutos a x4.
- El jugador puede **dar órdenes en pausa** (como en Los Sims).
- Calendario: días de la semana, meses y estaciones (afectan a la demanda y a los
  precios de las materias primas).

---

## 5. Sistemas de gestión

### 5.1 Ubicación
- Mapa de ciudad con barrios: centro turístico, zona de oficinas, universitario,
  residencial familiar, periferia.
- Cada barrio: tráfico peatonal por franja horaria, perfil de cliente, poder
  adquisitivo, competencia, precio por m².

### 5.2 Local
- **Alquiler** (fianza + mensualidad) o **compra** (préstamo hipotecario).
- Estado del edificio (instalación eléctrica, salida de humos, accesibilidad):
  condiciona las reformas obligatorias.
- **Licencias**: apertura, terraza, alcohol, música. Tienen plazos y costes.

### 5.3 Distribución y decoración (editor isométrico)
- Rejilla isométrica. Zonas: comedor, cocina, almacén, cámara frigorífica, barra,
  baños, terraza, vestuario.
- **Mobiliario y equipamiento** con: precio, calidad, capacidad, consumo eléctrico,
  desgaste y probabilidad de avería.
- **Decoración**: suma *ambiente* por estilo (rústico, moderno, japonés...). El estilo
  coherente con el tipo de cocina da un bonus.
- **Flujo**: la distancia real entre cocina, pase y mesas afecta a los tiempos de
  servicio (los camareros caminan de verdad por el mapa).

### 5.4 Personal
- Puestos: jefe de cocina, cocinero, ayudante, friegaplatos, camarero, jefe de sala,
  barman, limpieza, encargado.
- Atributos (0-100): **habilidad**, **velocidad**, **trato al cliente**, **higiene**,
  **resistencia**. Estado: **moral**, **cansancio**.
- Contratación: candidatos con CV y expectativa salarial; entrevista revela
  atributos parcialmente.
- Turnos y horarios, horas extra, vacaciones, bajas, formación, despidos
  (con coste de indemnización), conflictos entre empleados.

### 5.5 Proveedores e inventario
- Varios proveedores por categoría: precio, calidad, fiabilidad, plazo de entrega,
  pedido mínimo.
- Inventario por lotes con **fecha de caducidad**; almacenaje seco, refrigerado o
  congelado con capacidad limitada.
- **Mermas**: caducidad, errores de cocina, robos (con baja moral).
- Pedido manual o automático por stock mínimo.

### 5.6 Carta y cocina
- Tipos de cocina: mediterránea, italiana, japonesa, mexicana, hamburguesería,
  alta cocina...
- **Receta** = ingredientes + cantidades + tiempo de preparación + dificultad +
  equipamiento necesario.
- **Escandallo**: coste de materia prima por plato calculado automáticamente con
  los precios reales de compra. Muestra margen y % de coste.
- Popularidad de cada plato (ingeniería de menú: estrellas, caballos, puzzles, perros).
- Alérgenos, menú del día, platos de temporada.

### 5.7 Clientes
- Perfiles: turista, oficinista, estudiante, familia, pareja, *foodie*, crítico.
- Cada cliente tiene: presupuesto, gustos, **paciencia**, tamaño de grupo.
- **Satisfacción** (primera versión de la fórmula, a equilibrar):

  ```
  satisfacción = 0.35·comida + 0.20·tiempo_espera + 0.15·trato
               + 0.10·ambiente + 0.10·limpieza + 0.10·relación_calidad_precio
  ```

- Resultado: propina, reseña (1-5 ★) y probabilidad de volver.

### 5.8 Reputación y marketing
- Nota media online + boca a boca por barrio.
- Campañas: redes sociales, folletos, influencers, ofertas.

### 5.9 Finanzas
- Caja, cuenta de resultados diaria/mensual, balance.
- Fijos: alquiler, suministros, seguros, licencias, nóminas, Seguridad Social.
- Variables: materia prima, mermas, reparaciones.
- IVA e impuesto de sociedades simplificados. Préstamos con interés.

### 5.10 Eventos y problemas
Ejemplos: inspección de sanidad, avería del horno o de la cámara, proveedor que no
entrega, empleado enfermo, intoxicación, visita de un crítico, ola de calor,
subida de precios, competidor que abre al lado, fiesta local, obras en la calle.
Cada evento: condiciones de aparición, probabilidad, efecto y opciones de respuesta.

### 5.11 Progresión
- Objetivos/misiones, logros, desbloqueo de barrios, recetas y equipamiento.
- Expansión a varios locales (fase avanzada).

---

## 6. Arte y sonido

- Estilo isométrico 2D, colores cálidos y alegres, personajes *chibi*/caricaturescos.
- Tamaño de baldosa: **128 × 64 px** (proporción 2:1).
- Personajes animados por esqueleto 2D (Skeleton2D) o *sprite sheets*; 4 direcciones
  isométricas mínimo.
- **El gestor**: personaje protagonista, aparece en el local y en los menús
  (da consejos, reacciona a lo que pasa). Pendiente: diseño definitivo.
- Música ambiente distinta para planificación y servicio; efectos de cocina y sala.

---

## 7. Interfaz (móvil)

- HUD superior: día y hora, velocidad (⏸ ▶ ▶▶ ▶▶▶), dinero, reputación.
- Barra inferior de accesos: Construir · Personal · Carta · Almacén · Finanzas ·
  Ciudad.
- Gestos: arrastrar para mover la cámara, pellizcar para zoom, tocar para
  seleccionar.
- Botones de al menos 48 dp; zonas seguras de *notch* respetadas.

---

## 8. Arquitectura técnica

```
game/
  simulation/   Lógica pura (sin gráficos): reloj, economía, clientes, cocina...
  data/         JSON con el contenido: ingredientes, recetas, muebles, eventos...
  scenes/       Escenas visuales (mundo isométrico, personajes)
  ui/           Interfaz (HUD, menús de gestión)
  assets/       Gráficos, animaciones, sonido
  tests/        Pruebas automáticas de la simulación
```

Reglas:
1. **La simulación no conoce la parte visual.** Las escenas leen el estado de la
   simulación y escuchan sus señales.
2. **Todo el contenido es dato.** Añadir un ingrediente o una receta es editar un
   JSON, no programar.
3. **La simulación se puede probar sin pantalla** (`game/tests`).

---

## 9. Hoja de ruta

| Fase | Contenido | Hito |
|---|---|---|
| 0 · Preproducción | GDD, proyecto base, reloj, mundo isométrico de prueba | ✅ hecho |
| 1 · Prototipo (MVP) | Un local fijo, clientes que entran/piden/comen/pagan, 2-3 empleados, carta de 5-10 platos, inventario básico, informe diario | 🔨 en curso: ciclo de servicio jugable |
| 2 · Núcleo de gestión | Contratación y atributos, proveedores y caducidad, escandallo, finanzas, satisfacción y reputación, guardado | Partida de varios días con sentido |
| 3 · Construcción | Editor isométrico de distribución y decoración, ubicación y locales | El jugador monta su propio local |
| 4 · Profundidad | Eventos, tipos de cocina, temporadas, progresión, varios locales | Partida larga |
| 5 · Lanzamiento | Tutorial, equilibrado, sonido, optimización, beta y publicación | En tiendas |

---

## 10. Estado de la Fase 1

Hecho:
- Clientes en grupos (1-4) que llegan por la calle según la hora (picos de comida y cena),
  hacen cola, se sientan, piden, esperan, comen, piden la cuenta, pagan y se van.
- Paciencia por fase: si esperan demasiado se enfadan y, al doble, se marchan
  (sin mesa, sin que les tomen nota, comida lenta o incluso sin pagar).
- Camareros con prioridades (servir > cobrar > tomar nota), que caminan por el local
  esquivando mesas (A*). Velocidad y trato influyen.
- Cocineros que preparan varios platos a la vez; su habilidad marca la calidad.
- Inventario que se gasta con cada plato y pedido automático diario a las 11:00.
- Elección de plato según la relación precio/valor de la carta.
- Satisfacción según la fórmula del apartado 5.7, propinas (para el personal) y reputación,
  que hace venir más o menos clientes.
- Informe de cierre del día con caja, gastos, beneficio y platos más vendidos.
- Pulsar sobre una persona muestra su estado; sobre el suelo, la zona.

Siguiente:
- Pantallas de gestión: carta y precios, personal, almacén.
- Personajes definitivos y animaciones.

## 11. Pendiente de decidir

- Diseño del personaje gestor.
- Monetización.
- Nombre del juego.
- Moneda y país de ambientación (¿euros/España por defecto?).

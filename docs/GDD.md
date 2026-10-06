# Documento de Diseño del Juego (GDD)

> Juego de gestión de restaurantes para móvil (Android + iOS).
> Documento vivo: se actualiza a medida que avanzamos.

---

## 1. Decisiones tomadas

| Tema | Decisión |
|---|---|
| Plataformas | Android e iOS |
| Motor | Godot 4.5 (GDScript), renderer *GL Compatibility* (máxima compatibilidad móvil) |
| Vista | Isométrica en 3D (cámara ortográfica) |
| Orientación | Horizontal (landscape) |
| Tiempo | Tiempo real continuo estilo *Los Sims*: pausa, x1, x2, x4 |
| Tipo de partida | Continua y abierta, estilo *Los Sims*: sin misiones ni objetivos. El restaurante evoluciona de forma orgánica (crece, mejora o empeora) según tus decisiones |
| Público | Aficionado a la gestión profunda (*Sims*, *tycoons*, simuladores), pero **intuitivo**: fácil de entender, con todo el detalle y el realismo disponibles para quien quiera profundizar |
| Gestor (protagonista) | Tu avatar, al que controlas (personaje de `docs/arte/personaje_referencia.png`). Se mueve por el local y hace las gestiones en persona; puede delegar contratando personal |
| Monetización | Se decide más adelante, cuando la estructura del juego esté asentada |
| Forma de trabajo | Desarrollo iterativo, *vibe coding*, paso a paso |

---

## 2. Concepto

El jugador es el **gestor** de un restaurante: un personaje que controla y que vive en
el local. Empieza con poco dinero, monta el local, contrata personal, diseña la carta
y lo saca adelante día a día, sin fin y sin misiones: como en *Los Sims*, la partida
es una vida continua del restaurante, que puede crecer (más grande, más calidad, más
fama) o venirse abajo. La capa visual es **amable, colorida y divertida**; la capa de
gestión es **profunda y realista**, pero siempre **intuitiva**.

### El gestor: tu avatar

- Lo controlas directamente: tocas el suelo y va andando; tocas un objeto y lo usa.
- **Las gestiones se hacen en persona, en su sitio** (la "física" del local importa):
  - **Despacho / ordenador**: abre el módulo de gestión (carta y precios, personal y
    contratación, pedidos a proveedores, finanzas, informes).
  - **Comedor**: puede saludar, acomodar clientes o echar una mano en momentos de
    agobio; su presencia mejora el ambiente.
  - **Cocina y almacén**: revisar el stock, ver cómo va la cocina.
- Mientras está en el despacho no está en la sala: **su tiempo es un recurso**.
- Según crece el negocio puede **delegar**: contratar un encargado de compras, un
  jefe de sala o un jefe de cocina que hagan solos parte de las gestiones (con su
  habilidad y sus errores).
- Las órdenes se pueden dar también en pausa: se ejecutan al reanudar el tiempo.
- Puede **ponerse a trabajar** cubriendo un puesto para ahorrar un sueldo.

### Evolución orgánica (sin objetivos)

No hay misiones: el progreso sale de la propia simulación.
- **Crecer**: más reputación → más clientes → más caja → ampliar el local, mejores
  muebles y cocina, más personal, carta más ambiciosa, segundo local.
- **Empeorar**: mala comida, esperas, suciedad o malos precios → malas reseñas → menos
  clientes → problemas de caja → deudas.
- Hitos que surgen solos (no se exigen): primera reseña de 5, primer mes en positivo,
  visita de un crítico, aniversario del restaurante… sirven como recuerdos del historial.

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

#### Dificultades económicas y bancarrota (realista y gradual)
Cerrar definitivamente es el final de un largo camino, con margen para reaccionar:
1. **Pérdidas**: los informes avisan y explican el porqué (ventas, costes, mermas…).
2. **Medidas del gestor**: comprar menos materia prima o más barata, cambiar a una carta
   más económica, recortar personal (con indemnización) y **ponerse él mismo a trabajar**
   cubriendo un puesto (camarero, cocina) para ahorrar un sueldo.
3. **Financiación**: préstamos del banco con interés y cuotas; el límite depende de la
   solvencia y del historial del restaurante.
4. **Impagos**: si no llega el dinero, los proveedores dejan de servir a crédito, los
   empleados sin nómina se marchan y las deudas crecen.
5. **Cierre temporal**: se puede cerrar el local unos días para cortar gastos, a costa de
   perder clientela y reputación.
6. **Bancarrota**: si el endeudamiento pasa el límite y no hay forma de pagar, se declara
   la bancarrota y termina la partida.

### 5.10 Eventos y problemas
Ejemplos: inspección de sanidad, avería del horno o de la cámara, proveedor que no
entrega, empleado enfermo, intoxicación, visita de un crítico, ola de calor,
subida de precios, competidor que abre al lado, fiesta local, obras en la calle.
Cada evento: condiciones de aparición, probabilidad, efecto y opciones de respuesta.

### 5.11 Progresión (orgánica)
- Sin misiones ni objetivos obligatorios: se progresa porque el negocio va bien.
- La reputación y la caja abren puertas: proveedores mejores, críticos, ampliar el
  local, mudarse a un barrio mejor, segundo local (fase avanzada).
- Historial del restaurante con hitos espontáneos (primer 5/5, primer mes en positivo…).

---

## 6. Arte y sonido

![Personaje de referencia](arte/personaje_referencia.png)

- **Mundo 3D con cámara isométrica ortográfica** (se ve en diagonal, como un juego
  isométrico clásico, pero con volumen, luces y sombras reales). 1 celda = 1 metro.
- **Personajes**: todos siguen el estilo del gestor (imagen de arriba): cuerpo blanco
  redondeado tipo "judía", visor negro con ojos luminosos, manos y pies ovalados, sin
  boca. Aspecto de vinilo mate, colores suaves.
  - El **gestor** es el protagonista: blanco puro, algo más grande, saluda a los clientes.
  - **Variantes por puesto**: cocinero (gorro y pañuelo), camarero (pajarita y delantal);
    clientes con tono pastel y complementos (gorra, lazo, bufanda).
  - **Expresiones con los ojos**: feliz (^ ^), normal, enfadado y parpadeo. Reflejan el
    ánimo del cliente.
  - Animaciones por código: andar con balanceo, sentarse, comer, cocinar, llevar platos,
    saludar.
  - Pendiente: versiones masculinas y femeninas, más ropa y peinados; sustituir las formas
    básicas por modelos 3D definitivos (Blender) manteniendo el mismo estilo.
- Música ambiente distinta para planificación y servicio; efectos de cocina y sala.

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

Principios: primero **lo jugable con gráficos provisionales**; pronto un **corte
vertical** para fijar el aspecto final en un móvil real; el arte en cantidad, después.
Cada hito termina en algo que se prueba en el móvil.

| Hito | Contenido | Pregunta que responde |
|---|---|---|
| 0 · Base | Motor, web, pruebas, simulación del servicio, vista 3D, cámara, personajes provisionales | ✅ hecho |
| 1 · Primer juego de verdad | **Gestor controlable** (andar, usar objetos, cola de órdenes); **despacho con ordenador** que abre la gestión: carta y precios (con escandallo), personal (candidatos, contratar, despedir, sueldos), pedidos y almacén; **guardar/cargar**; informes que explican resultados; consecuencias reales (caja negativa, deudas) | ¿Es divertido decidir? |
| 2 · Corte vertical | Gestor y camarero con modelo 3D definitivo, un local con aspecto final, estilo final de la interfaz, sonido básico, primera APK de Android | ¿Se ve y funciona bien en un móvil real? ¿Cuánto cuesta producir arte? |
| 3 · Construcción | Editor del local: mover/comprar mesas, cocina y decoración; ambiente; ampliar el local | ¿Es divertido montar y mejorar el local? |
| 4 · Profundidad | Proveedores y caducidad, perfiles de cliente, moral/cansancio/turnos del personal, **delegar** (encargados), eventos, finanzas mensuales y préstamos | ¿Aguanta semanas de juego? |
| 5 · Evolución larga | Ciudad y barrios, mudanzas, alquilar/comprar, segundo local, historial y estaciones | ¿Aguanta meses de juego? |
| 6 · Contenido y arte | Variedad de personajes (masculino/femenino, ropa, puestos), recetas, tipos de cocina, muebles | — |
| 7 · Lanzamiento | Tutorial, equilibrado, monetización, beta con jugadores, tiendas | — |

---

## 10. Estado actual

Hecho (hito 0):
- Clientes en grupos (1-4) que llegan por la calle según la hora (picos de comida y cena),
  hacen cola, se sientan, piden, esperan, comen, piden la cuenta, pagan y se van.
- Paciencia por fase: si esperan demasiado se enfadan y, al doble, se marchan.
- Camareros con prioridades (servir > cobrar > tomar nota) que caminan esquivando mesas (A*).
- Cocineros que preparan varios platos a la vez; su habilidad marca la calidad.
- Inventario que se gasta con cada plato y pedido automático diario a las 11:00.
- Satisfacción (apartado 5.7), propinas, reputación que atrae más o menos clientes.
- Informe de cierre del día. Vista 3D isométrica con personajes al estilo del gestor.

Hito 1 en curso:
- ✅ Gestor controlable: tocar el suelo para que vaya andando, tocar el ordenador para
  usarlo; las órdenes dadas en pausa se ejecutan al reanudar.
- ✅ Despacho con ordenador; al sentarse se abre la gestión (Resumen en directo; Carta,
  Personal, Pedidos y Finanzas por hacer).
- ✅ Nadie atraviesa nada: gestor, empleados y clientes caminan de casilla en casilla
  reservando la siguiente; rodean muebles y sillas (salvo la suya al sentarse), esperan
  si alguien les corta el paso, buscan otro camino, piden paso a quien está parado sin
  hacer nada (se aparta) y, si se encuentran de frente en un pasillo, uno se aparta.
  La cocina tiene puerta y la gente que pasa por la calle respeta la cola.
- ✅ Hablar con la gente: tocar a un cliente o a un empleado hace que el gestor vaya
  hasta él y se abra un cuadro de diálogo. Lo que dicen sale del estado real (esperas,
  lo que han comido, precios, trabajo pendiente). Los camareros se paran a hablar.
  De momento hablar solo informa; más adelante tendrá efectos (ánimo del cliente,
  moral del empleado, quejas, propinas…).
- Siguiente: Carta y precios.

## 11. Pendiente de decidir

- Monetización (más adelante).
- Nombre del juego y del personaje gestor.
- Moneda y país de ambientación (¿euros/España por defecto?).

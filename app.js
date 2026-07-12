const WORDS = [
  "Abeja", "Aeropuerto", "Ajedrez", "Almohada", "Ancla", "Arcoíris", "Ascensor", "Astronauta", "Avión",
  "Ballena", "Biblioteca", "Bicicleta", "Bosque", "Brújula", "Burbuja", "Cactus", "Café", "Camaleón",
  "Campana", "Canguro", "Castillo", "Cebra", "Chocolate", "Cine", "Circo", "Cocodrilo", "Cohete",
  "Colmena", "Concierto", "Corona", "Delfín", "Desierto", "Diamante", "Dinosaurio", "Dragón", "Elefante",
  "Espejo", "Estatua", "Faro", "Fantasma", "Fútbol", "Galleta", "Globo", "Guitarra", "Hamburguesa",
  "Helado", "Hospital", "Hotel", "Imán", "Isla", "Jirafa", "Laberinto", "Lámpara", "León", "Libro",
  "Luna", "Maleta", "Mariposa", "Mercado", "Micrófono", "Montaña", "Museo", "Nube", "Océano",
  "Ordenador", "Palomitas", "Paraguas", "Parque", "Piano", "Pirámide", "Pirata", "Pizza", "Playa",
  "Pulpo", "Reloj", "Robot", "Satélite", "Semáforo", "Sombrero", "Submarino", "Teatro", "Telescopio",
  "Tiburón", "Tobogán", "Tren", "Trompeta", "Volcán", "Zanahoria", "Zapato", "Zoológico"
];

const ICON_EYE = `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="12" r="2.5" fill="currentColor"/></svg>`;

const initialPlayerCount = loadPlayerCount();

const state = {
  screen: "home",
  playerCount: initialPlayerCount,
  names: loadNames(initialPlayerCount),
  impostorCount: Math.min(loadImpostorCount(), maxImpostorsFor(initialPlayerCount)),
  word: "",
  impostors: [],
  revealIndex: 0,
  roleVisible: false,
  order: [],
  turn: 0,
  round: 1,
  timerSeconds: 180,
  timerRunning: false,
  timerId: null,
  caught: null,
  result: null
};

const app = document.querySelector("#app");

function loadPlayerCount() {
  const saved = Number(localStorage.getItem("player-count"));
  return Number.isInteger(saved) && saved >= 4 && saved <= 15 ? saved : 9;
}

function loadNames(count) {
  try {
    const saved = JSON.parse(localStorage.getItem("impostor-names"));
    if (Array.isArray(saved)) return Array.from({ length: count }, (_, i) => saved[i] || `Jugador ${i + 1}`);
  } catch (_) {}
  return Array.from({ length: count }, (_, i) => `Jugador ${i + 1}`);
}

function saveNames() {
  localStorage.setItem("impostor-names", JSON.stringify(state.names));
}

function loadImpostorCount() {
  const saved = Number(localStorage.getItem("impostor-count"));
  return [1, 2, 3].includes(saved) ? saved : 1;
}

function maxImpostorsFor(playerCount) {
  if (playerCount >= 8) return 3;
  if (playerCount >= 5) return 2;
  return 1;
}

function maxImpostors() {
  return maxImpostorsFor(state.playerCount);
}

function majorityNeeded() {
  return Math.floor(state.playerCount / 2) + 1;
}

function randomIndex(max) {
  if (globalThis.crypto?.getRandomValues) {
    const values = new Uint32Array(1);
    crypto.getRandomValues(values);
    return values[0] % max;
  }
  return Math.floor(Math.random() * max);
}

function shuffledIndexes() {
  const items = Array.from({ length: state.playerCount }, (_, i) => i);
  for (let i = items.length - 1; i > 0; i--) {
    const j = randomIndex(i + 1);
    [items[i], items[j]] = [items[j], items[i]];
  }
  return items;
}

function newRound() {
  const previousWord = state.word;
  do state.word = WORDS[randomIndex(WORDS.length)]; while (WORDS.length > 1 && state.word === previousWord);
  state.impostors = shuffledIndexes().slice(0, state.impostorCount);
  state.revealIndex = 0;
  state.roleVisible = false;
  state.order = shuffledIndexes();
  state.turn = 0;
  state.timerSeconds = 180;
  state.timerRunning = false;
  state.caught = null;
  state.result = null;
  clearTimer();
  go("handoff");
}

function go(screen) {
  state.screen = screen;
  window.scrollTo({ top: 0, behavior: "instant" });
  render();
}

function topbar(extra = "") {
  return `<div class="topbar"><div class="brand"><span class="brand-mark">${ICON_EYE}</span> El Impostor</div>${extra}</div>`;
}

function render() {
  const views = {
    home: homeView,
    setup: setupView,
    rules: rulesView,
    handoff: handoffView,
    role: roleView,
    clues: cluesView,
    debate: debateView,
    vote: voteView,
    reveal: revealView,
    guess: guessView,
    result: resultView
  };
  app.innerHTML = views[state.screen]();
  bindEvents();
}

function homeView() {
  return `<section class="screen">
    ${topbar('<span class="round-pill">Jugadores configurables</span>')}
    <span class="eyebrow">Engaña · Deduce · Sobrevive</span>
    <h1>¿Quién está<br><span class="accent">fingiendo?</span></h1>
    <p class="lead">La mayoría conoce la palabra. Entre uno y tres improvisan. El móvil sabe la verdad.</p>
    <div class="hero-eye"><div class="eye-shape"><div class="iris"><div class="pupil"></div></div></div></div>
    <div class="stats"><div class="stat"><strong>4–15</strong><span>jugadores</span></div><div class="stat"><strong>1–3</strong><span>impostores</span></div><div class="stat"><strong>0</strong><span>internet</span></div></div>
    <div class="spacer"></div>
    <div class="button-stack"><button class="btn btn-primary" data-action="setup">Preparar partida</button><button class="btn btn-ghost" data-action="rules">Cómo se juega</button></div>
  </section>`;
}

function setupView() {
  const availableImpostors = Array.from({ length: maxImpostors() }, (_, i) => i + 1);
  return `<section class="screen">
    ${topbar('<button class="icon-button" data-action="home" aria-label="Volver">✕</button>')}
    <span class="eyebrow">Antes de empezar</span><h2>¿Quién juega?</h2>
    <p class="lead">Elige cuántos sois y escribe los nombres en el orden en que estáis sentados.</p>
    <div class="player-count-box">
      <span class="selector-label">Número de jugadores</span>
      <div class="count-stepper"><button class="step-button" data-action="decrease-players" ${state.playerCount === 4 ? "disabled" : ""} aria-label="Quitar un jugador">−</button><strong>${state.playerCount}</strong><button class="step-button" data-action="increase-players" ${state.playerCount === 15 ? "disabled" : ""} aria-label="Añadir un jugador">+</button></div>
    </div>
    <div class="impostor-selector" role="group" aria-label="Número de impostores">
      <span class="selector-label">Número de impostores</span>
      <div class="segmented" style="--segments:${availableImpostors.length}">${availableImpostors.map(count => `<button class="segment ${state.impostorCount === count ? "active" : ""}" data-impostor-count="${count}" aria-pressed="${state.impostorCount === count}">${count}</button>`).join("")}</div>
      <p>${state.impostorCount === 1 ? `La experiencia clásica: ${state.playerCount - 1} conocen la palabra.` : `${state.playerCount - state.impostorCount} conocen la palabra y ${state.impostorCount} improvisan por separado.`}</p>
    </div>
    <div class="player-list">${state.names.map((name, i) => `<label class="player-row"><span class="player-number">${i + 1}</span><input class="player-input" data-player="${i}" value="${escapeHtml(name)}" maxlength="18" autocomplete="off" aria-label="Nombre del jugador ${i + 1}"></label>`).join("")}</div>
    <button class="btn btn-primary" data-action="start">Repartir roles en secreto</button>
  </section>`;
}

function rulesView() {
  const rules = [
    ["1", "Elegid entre 1 y 3 impostores. El móvil los selecciona y muestra la palabra al resto."],
    ["2", "Cada persona dice exactamente una palabra, sin repetir ni usar derivados de la palabra secreta."],
    ["3", `Tras las ${state.playerCount} pistas tenéis 3 minutos para debatir, sin enseñar las tarjetas.`],
    ["4", `Con uno hacen falta ${majorityNeeded()} votos. Con varios, quedan acusados los más votados: tantos como impostores haya.`],
    ["5", "Si atrapáis a todos, tienen una respuesta conjunta para intentar robar la victoria."]
  ];
  return `<section class="screen">${topbar('<button class="icon-button" data-action="home" aria-label="Cerrar">✕</button>')}
    <span class="eyebrow">Reglas para ${state.playerCount}</span><h2>Una palabra.<br>${state.playerCount} sospechosos.</h2>
    <div class="rule-list">${rules.map(([n, t]) => `<div class="rule"><span class="rule-num">${n}</span><p>${t}</p></div>`).join("")}</div>
    <div class="card"><strong>Los empates les favorecen</strong><p class="role-help">Con un impostor hacen falta ${majorityNeeded()} votos. Con varios, un empate en el último puesto acusado significa que los impostores escapan.</p></div>
    <div class="spacer"></div><button class="btn btn-primary" data-action="setup">Entendido</button>
  </section>`;
}

function progressDots() {
  return `<div class="progress" aria-label="Jugador ${state.revealIndex + 1} de ${state.playerCount}">${Array.from({ length: state.playerCount }, (_, i) => `<span class="progress-dot ${i <= state.revealIndex ? "done" : ""}"></span>`).join("")}</div>`;
}

function handoffView() {
  const name = state.names[state.revealIndex];
  return `<section class="screen handoff">${topbar('<span class="round-pill">Reparto secreto</span>')}${progressDots()}
    <div class="spacer"></div><div class="player-badge">${state.revealIndex + 1}</div>
    <span class="eyebrow">Pasa el móvil a</span><h2>${escapeHtml(name)}</h2>
    <p class="lead" style="margin-inline:auto">Que nadie más pueda ver la pantalla.</p>
    <div class="spacer"></div><button class="btn btn-primary" data-action="show-role">Ver mi tarjeta</button>
    <div class="privacy-note"><span>◉</span> Mírala en secreto y memorízala</div>
  </section>`;
}

function roleView() {
  const isImpostor = state.impostors.includes(state.revealIndex);
  return `<section class="screen">${topbar('<span class="round-pill">Solo para ti</span>')}${progressDots()}
    <div class="card role-card ${isImpostor ? "impostor" : ""}">
      <div class="role-icon">${isImpostor ? "?" : "✓"}</div>
      <span class="role-label">${isImpostor ? "Tu papel" : "La palabra secreta"}</span>
      <h2 class="secret-word">${isImpostor ? "Eres el<br>Impostor" : escapeHtml(state.word)}</h2>
      <p class="role-help">${isImpostor ? (state.impostorCount > 1 ? `Hay ${state.impostorCount} impostores. No sabes quiénes son los demás.` : "Escucha, improvisa y no dejes que te descubran.") : "Da una pista útil, pero no se la regales a los impostores."}</p>
    </div>
    <div class="spacer"></div><button class="btn btn-primary" data-action="hide-role">Ya la he memorizado</button>
  </section>`;
}

function cluesView() {
  const playerIndex = state.order[state.turn];
  return `<section class="screen">${topbar(`<span class="round-pill">Pista ${state.turn + 1} de ${state.playerCount}</span>`)}
    <span class="eyebrow">Ronda de pistas</span><h2>Una sola palabra.</h2>
    <div class="turn-order">${state.order.map((idx, i) => `<span class="turn-chip ${i < state.turn ? "done" : i === state.turn ? "active" : ""}">${escapeHtml(state.names[idx])}</span>`).join("")}</div>
    <p class="lead">Es el turno de</p><h2 class="current-player">${escapeHtml(state.names[playerIndex])}</h2>
    <span class="one-word">● Sin frases ni repeticiones</span>
    <div class="spacer"></div><button class="btn btn-primary" data-action="next-clue">Ya ha dicho su pista</button>
  </section>`;
}

function debateView() {
  const minutes = String(Math.floor(state.timerSeconds / 60)).padStart(2, "0");
  const seconds = String(state.timerSeconds % 60).padStart(2, "0");
  const progress = (state.timerSeconds / 180) * 100;
  return `<section class="screen">${topbar('<span class="round-pill">Debate</span>')}
    <span class="eyebrow">Ahora podéis hablar</span><h2>Defended vuestras pistas.</h2>
    <p class="lead">Buscad dudas, pistas extrañas y explicaciones que no encajan.</p>
    <div class="timer-wrap"><div class="timer-ring" style="--timer-progress:${progress}%"><span class="timer-text">${minutes}:${seconds}</span></div></div>
    <div class="spacer"></div><div class="button-stack">
      <button class="btn btn-primary" data-action="toggle-timer">${state.timerRunning ? "Pausar" : state.timerSeconds === 180 ? "Empezar 3 minutos" : "Continuar"}</button>
      <button class="btn btn-secondary" data-action="vote">Ir a la votación</button>
    </div>
  </section>`;
}

function voteView() {
  const multiple = state.impostorCount > 1;
  const majority = majorityNeeded();
  return `<section class="screen">${topbar('<span class="round-pill">Votación</span>')}
    <span class="eyebrow">Sin cambiar el voto</span><h2>Todos a la vez.</h2>
    <p class="lead">Decidid vuestro sospechoso. A la de tres, señalad a esa persona con el dedo.</p>
    <div class="card vote-box"><span class="vote-number">${multiple ? `TOP ${state.impostorCount}` : `${majority}+`}</span><strong>${multiple ? "personas quedarán acusadas" : "votos para atraparlo"}</strong><p class="role-help">${multiple ? `Cada persona vota a un sospechoso. Acusad a los ${state.impostorCount} más votados; un empate en el último puesto hace escapar a los impostores.` : `Si nadie recibe al menos ${majority} votos, el impostor escapa y gana la ronda.`}</p></div>
    <div class="rule-list"><div class="rule"><span class="rule-num">1</span><p>Preparad un único voto en silencio.</p></div><div class="rule"><span class="rule-num">2</span><p>Contad «uno, dos, tres».</p></div><div class="rule"><span class="rule-num">3</span><p>Señalad y contad los votos.</p></div></div>
    <div class="spacer"></div><button class="btn btn-primary" data-action="reveal">Revelar al impostor</button>
  </section>`;
}

function revealView() {
  const names = impostorNames();
  const majority = majorityNeeded();
  return `<section class="screen">${topbar('<span class="round-pill">La verdad</span>')}
    <span class="eyebrow">${state.impostorCount === 1 ? "El impostor era" : "Los impostores eran"}</span><h2 class="reveal-name">${names}</h2>
    <p class="lead">${state.impostorCount === 1 ? `¿Recibió al menos ${majority} votos?` : `¿Eran exactamente las ${state.impostorCount} personas más votadas, sin empates?`}</p>
    <div class="card vote-box"><span class="vote-number">${state.impostorCount === 1 ? `${majority}+` : `${state.impostorCount}/${state.impostorCount}`}</span><strong>${state.impostorCount === 1 ? "votos para atraparlo" : "impostores encontrados"}</strong><p class="role-help">La palabra sigue oculta por si tienen derecho a su último intento.</p></div>
    <div class="spacer"></div><div class="button-stack"><button class="btn btn-primary" data-action="caught">Sí, ${state.impostorCount === 1 ? "lo atrapamos" : "los atrapamos a todos"}</button><button class="btn btn-secondary" data-action="escaped">No, ${state.impostorCount === 1 ? "logró" : "lograron"} escapar</button></div>
  </section>`;
}

function guessView() {
  return `<section class="screen handoff">${topbar('<span class="round-pill">Última oportunidad</span>')}
    <div class="spacer"></div><div class="player-badge">?</div><span class="eyebrow">${state.impostorCount === 1 ? "Solo el impostor" : "Solo los impostores"}</span>
    <h2>${state.impostorCount === 1 ? `${impostorNames()}, puedes` : "Podéis"} robar la victoria.</h2>
    <p class="lead" style="margin-inline:auto">${state.impostorCount === 1 ? "Escribe" : "Acordad y escribid"} una única respuesta. Se ignoran mayúsculas y tildes.</p>
    <input id="guess" class="guess-input" placeholder="Tu respuesta" maxlength="30" autocomplete="off" autocapitalize="words">
    <div class="spacer"></div><button class="btn btn-primary" data-action="check-guess">Comprobar respuesta</button>
  </section>`;
}

function resultView() {
  const groupWon = state.result === "group";
  const reason = state.result === "escaped" ? (state.impostorCount === 1 ? `No hubo una mayoría de ${majorityNeeded()} votos contra el impostor.` : "El grupo no identificó a todos los impostores sin empates.") : state.result === "stolen" ? `${state.impostorCount === 1 ? "Atrapado" : "Atrapados"}, pero ${state.impostorCount === 1 ? "dedujo" : "dedujeron"} la palabra exacta.` : `El grupo encontró a ${state.impostorCount === 1 ? "el impostor" : "todos los impostores"} y fallaron su último intento.`;
  return `<section class="screen">${topbar(`<span class="round-pill">Ronda ${state.round}</span>`)}
    <div class="result-mark ${groupWon ? "" : "bad"}">${groupWon ? "✓" : "?"}</div>
    <span class="eyebrow">${groupWon ? "Victoria del grupo" : "Victoria del impostor"}</span>
    <h2>${groupWon ? "La mesa ha descubierto la mentira." : `${impostorNames()} ${state.impostorCount === 1 ? "os ha engañado" : "os han engañado"}.`}</h2>
    <p class="lead">${reason}</p>
    <div class="card summary"><div class="summary-row"><span>${state.impostorCount === 1 ? "Impostor" : "Impostores"}</span><strong>${impostorNames()}</strong></div><div class="summary-row"><span>Palabra secreta</span><strong>${escapeHtml(state.word)}</strong></div></div>
    <div class="spacer"></div><div class="button-stack"><button class="btn btn-primary" data-action="again">Jugar otra ronda</button><button class="btn btn-ghost" data-action="setup">Cambiar jugadores</button></div>
  </section>`;
}

function bindEvents() {
  app.querySelectorAll("[data-action]").forEach(button => button.addEventListener("click", handleAction));
  app.querySelectorAll("[data-player]").forEach(input => input.addEventListener("input", event => {
    state.names[Number(event.target.dataset.player)] = event.target.value;
  }));
  app.querySelectorAll("[data-impostor-count]").forEach(button => button.addEventListener("click", event => {
    state.impostorCount = Number(event.currentTarget.dataset.impostorCount);
    localStorage.setItem("impostor-count", String(state.impostorCount));
    render();
  }));
  const guess = document.querySelector("#guess");
  if (guess) {
    setTimeout(() => guess.focus(), 100);
    guess.addEventListener("keydown", event => { if (event.key === "Enter") checkGuess(); });
  }
}

function handleAction(event) {
  const action = event.currentTarget.dataset.action;
  if (action === "home") go("home");
  if (action === "setup") { clearTimer(); go("setup"); }
  if (action === "rules") go("rules");
  if (action === "start") {
    state.names = state.names.map((name, i) => name.trim() || `Jugador ${i + 1}`);
    const lowered = state.names.map(name => name.toLocaleLowerCase("es"));
    if (new Set(lowered).size !== state.playerCount) return toast(`Usad ${state.playerCount} nombres diferentes para evitar confusiones.`);
    saveNames();
    newRound();
  }
  if (action === "show-role") go("role");
  if (action === "hide-role") {
    if (state.revealIndex < state.playerCount - 1) { state.revealIndex += 1; go("handoff"); }
    else go("clues");
  }
  if (action === "next-clue") {
    if (state.turn < state.playerCount - 1) { state.turn += 1; render(); }
    else go("debate");
  }
  if (action === "toggle-timer") toggleTimer();
  if (action === "vote") { clearTimer(); go("vote"); }
  if (action === "reveal") go("reveal");
  if (action === "caught") go("guess");
  if (action === "escaped") { state.result = "escaped"; go("result"); }
  if (action === "check-guess") checkGuess();
  if (action === "again") { state.round += 1; newRound(); }
  if (action === "decrease-players") changePlayerCount(-1);
  if (action === "increase-players") changePlayerCount(1);
}

function changePlayerCount(delta) {
  const next = Math.min(15, Math.max(4, state.playerCount + delta));
  if (next === state.playerCount) return;
  state.playerCount = next;
  state.names = Array.from({ length: next }, (_, i) => state.names[i] || `Jugador ${i + 1}`);
  state.impostorCount = Math.min(state.impostorCount, maxImpostors());
  localStorage.setItem("player-count", String(state.playerCount));
  localStorage.setItem("impostor-count", String(state.impostorCount));
  render();
}

function toggleTimer() {
  state.timerRunning = !state.timerRunning;
  if (state.timerRunning) {
    state.timerId = setInterval(() => {
      state.timerSeconds = Math.max(0, state.timerSeconds - 1);
      if (state.timerSeconds === 0) {
        clearTimer();
        if (navigator.vibrate) navigator.vibrate([160, 80, 160]);
      }
      if (state.screen === "debate") render();
    }, 1000);
  } else clearInterval(state.timerId);
  render();
}

function clearTimer() {
  clearInterval(state.timerId);
  state.timerId = null;
  state.timerRunning = false;
}

function normalize(value) {
  return value.trim().toLocaleLowerCase("es").normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function impostorNames() {
  return state.impostors.map(index => escapeHtml(state.names[index])).join(", ");
}

function checkGuess() {
  const input = document.querySelector("#guess");
  if (!input?.value.trim()) return toast("Escribe una palabra antes de comprobarla.");
  state.result = normalize(input.value) === normalize(state.word) ? "stolen" : "group";
  go("result");
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[char]);
}

function toast(message) {
  document.querySelector(".toast")?.remove();
  const element = document.createElement("div");
  element.className = "toast";
  element.textContent = message;
  document.body.append(element);
  setTimeout(() => element.remove(), 2800);
}

render();

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => navigator.serviceWorker.register("./sw.js").catch(() => {}));
}

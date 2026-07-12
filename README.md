# El Impostor

Juego social para **4 a 15 personas**, con selección manual del número de jugadores y de **1, 2 o 3 impostores**. Es una aplicación web instalable (PWA), gratuita y preparada para funcionar sin conexión.

## Jugar en el móvil

1. Abre la dirección publicada del juego en el navegador del móvil.
2. En Android/Chrome, toca **Instalar aplicación** o **Añadir a pantalla de inicio**.
3. En iPhone/Safari, toca **Compartir** → **Añadir a pantalla de inicio**.
4. Abre la app una vez con conexión. A partir de ahí podrás jugar sin internet.

## Publicar gratis con GitHub Pages

1. Sube estos archivos a un repositorio de GitHub.
2. En el repositorio, abre **Settings → Pages**.
3. En **Build and deployment**, elige **Deploy from a branch**.
4. Selecciona la rama `main`, carpeta `/ (root)`, y guarda.

GitHub mostrará la dirección pública de la aplicación tras unos minutos.

## Probar en un ordenador

Como el modo sin conexión necesita un servidor local, sirve la carpeta con cualquier servidor estático. Por ejemplo, si tienes Python:

```sh
python -m http.server 8080
```

Después abre `http://localhost:8080`.

## Privacidad y coste

- No hay anuncios, cuentas, analítica ni servidores.
- Los nombres solo se guardan en el propio dispositivo.
- No usa librerías ni recursos externos.
- El alojamiento en GitHub Pages es gratuito para repositorios compatibles con sus condiciones.

# Cómo usar Taipea

[Read in English](USAGE.md) · [Volver al README](../README.es.md)

Esta guía muestra cada parte de Taipea con capturas de pantalla. Taipea sigue el idioma de
tu Mac (o el que elijas en Ajustes), así que en español verás estas mismas pantallas.

- [1. Primer inicio y permisos](#1-primer-inicio-y-permisos)
- [2. Dictar: el botón flotante](#2-dictar-el-botón-flotante)
- [3. La tarjeta de grabación](#3-la-tarjeta-de-grabación)
- [4. Atajos](#4-atajos)
- [5. La pestaña Historial](#5-la-pestaña-historial)
- [6. Ajustes](#6-ajustes)
- [7. La pestaña Modelos](#7-la-pestaña-modelos)
- [8. Actualizaciones](#8-actualizaciones)
- [9. ¿Problemas?](#9-problemas)

## 1. Primer inicio y permisos

Cuando el instalador termina, reinicia Hammerspoon. Taipea muestra entonces un ícono 🎙 en
la barra de menús y un botón redondo de micrófono flotando en la pantalla. Para abrir la
ventana de Taipea, presiona **Ctrl + Opción + H**, abre **Taipea.app** desde
`~/Applications` (puedes ponerla en el Dock) o elige **Abrir Taipea…** en el menú 🎙.

macOS pide dos permisos una sola vez. Taipea corre dentro de Hammerspoon, así que los dos
son para **Hammerspoon**:

1. **Accesibilidad**, para que Taipea pueda pegar donde está tu cursor. El instalador
   ofrece abrir esa página por ti. Ve a Ajustes del Sistema › Privacidad y seguridad ›
   Accesibilidad y activa **Hammerspoon**.
2. **Micrófono**. macOS pregunta la primera vez que dictas. Haz clic en **Permitir**.

Si Accesibilidad está apagada, la ventana de Taipea muestra un aviso rojo con un botón
grande **Abrir ajustes de Accesibilidad**. Tu texto no se pierde: queda en el portapapeles
(presiona Cmd + V) y en el Historial. Si una grabación sale vacía, un aviso naranja te
lleva a los ajustes de Micrófono.

<img src="images/permission-banner-es.png" width="570" alt="Ventana de Taipea con un aviso rojo arriba: El permiso de Accesibilidad está apagado, con un botón rojo grande Abrir ajustes de Accesibilidad">

## 2. Dictar: el botón flotante

El botón flotante es la forma más fácil de dictar con un mouse, un mouse de cabeza o un
pulsador. Queda encima de las otras ventanas. Arrástralo a donde quieras y recuerda dónde
lo dejaste.

| En reposo (Azul clásico) | En reposo (Estudio) | Grabando |
|---|---|---|
| <img src="images/floating-button-idle-classic.png" width="150" alt="Botón flotante en reposo: un botón redondo azul con un micrófono blanco"> | <img src="images/floating-button-idle-studio.png" width="150" alt="Botón flotante en reposo con los colores Estudio: un botón redondo oscuro con un anillo rojo y un micrófono blanco"> | <img src="images/floating-button-recording.png" width="280" alt="Botón flotante mientras graba: un botón verde grande Parar y pegar con un ícono de portapapeles, un botón azul más pequeño Parar y solo copiar, y un botón rojo más pequeño Cancelar"> |

- **En reposo:** haz clic para empezar a dictar.
- **Grabando:** se pone **verde**. Haz clic para parar: Taipea transcribe, corrige y pega
  en la app que estabas usando. Aparecen dos botones más pequeños al lado: **azul = Parar
  y solo copiar** (el texto va al portapapeles y al Historial, no se pega nada) y **rojo =
  Cancelar**. Crecen y muestran su nombre cuando el puntero está encima.
- **Trabajando:** después de parar, muestra que Taipea está transcribiendo y corrigiendo.
- **Escuchando:** con empezar / parar con la voz activado, tiene un anillo verde mientras
  espera tu frase de inicio.

Los colores nunca cambian de significado: verde = parar y pegar, azul = parar y solo
copiar, rojo = cancelar. Toca **Opción + Comando** para ocultar el botón, y tócalo otra vez
para mostrarlo (mira [Ocultar el botón flotante](#controles-de-grabación-y-ocultar-el-botón-flotante)).

## 3. La tarjeta de grabación

Si apagas el botón flotante, o activas **Mostrar también la tarjeta de grabación**, mientras
dictas aparece una tarjeta con tres botones grandes: **Parar y pegar**, **Parar y solo
copiar** y **Cancelar**. Muestra un contador y cómo terminar. Arrástrala a donde quieras.
(Las capturas de la tarjeta y del botón flotante están en inglés; en tu Mac salen en tu
idioma.)

<img src="images/recording-card-classic.png" width="450" alt="Tarjeta de grabación en Azul clásico (captura en inglés): Listening con un contador 0:03, la ayuda Press Ctrl + Option + Space or a button to finish, y tres botones grandes: verde Stop and Paste, azul Stop and Copy only, rojo Cancel">

<img src="images/recording-card-studio.png" width="450" alt="La misma tarjeta de grabación con los colores Estudio, con fondo oscuro (captura en inglés)">

## 4. Atajos

| Atajo | Qué hace |
|---|---|
| **Ctrl + Opción + Espacio** | Empieza a dictar. Presiónalo otra vez para parar y pegar en tu cursor. |
| **Ctrl + Opción + C** | Activa o desactiva la corrección. Desactivada = texto original, tal como lo oyó Whisper. |
| **Ctrl + Opción + H** | Abre la ventana de Taipea (Historial, Ajustes, Modelos). |
| **Ctrl + Opción + V** | Pega otra vez el último dictado. |
| **Opción + Comando** (toque) | Oculta o muestra el botón flotante. Presiona las dos teclas juntas y suéltalas. Los atajos Cmd + Opción + otra tecla siguen funcionando. |

Puedes cambiar los cuatro primeros en **Ajustes › Atajos**: escribe un atajo como
`ctrl+alt+space` y presiona **Guardar**. **Restablecer los atajos de fábrica** los
devuelve. El toque de Opción + Comando es fijo.

<img src="images/settings-shortcuts-es.png" width="570" alt="Ajustes, tarjeta Atajos: cada atajo con sus teclas actuales, un cuadro de texto y un botón azul Guardar, el toque fijo Opción + Comando y un botón naranja Restablecer los atajos de fábrica">

## 5. La pestaña Historial

Cada dictado se guarda en tu Mac (`~/Library/Application Support/Taipea/history.json`).

<img src="images/history-es.png" width="570" alt="Pestaña Historial con dictados de ejemplo. Cada uno muestra la hora y el estilo, el texto corregido, el texto original, los botones Copiar, Pegar, Copiar original y Borrar, y una fila para convertir el texto original a Ligero, Párrafos, Viñetas o Formal">

- **📋 Pegar otra vez el último dictado** arriba (también Ctrl + Opción + V).
- **Buscar** encuentra palabras en el texto corregido o en el original.
- En cada dictado: **Copiar**, **Pegar** (en la app que estabas usando), **Copiar
  original** (las palabras antes de la corrección) y **Borrar**.
- **Convertir el texto original a:** convierte tus palabras originales en texto
  **Ligero**, **Párrafos**, **Viñetas** o **Formal** con un clic. Las palabras originales
  siempre se conservan.
- **Borrar todo** borra todo el historial. Presiónalo dos veces: la primera vez cambia a
  "Toca otra vez para BORRAR TODO".

## 6. Ajustes

Los ajustes se guardan al momento, sin botón de guardar (salvo en los cuadros de texto).
Cada tarjeta se explica abajo en el orden en que aparece.

### Idioma, tamaño, colores, tamaño del texto y contraste

<img src="images/settings-look-es.png" width="570" alt="Ajustes: Idioma de la interfaz (Automático, English, Español), Tamaño (Normal, Compacto), Colores con ocho juegos de colores mostrados como botones de micrófono, Tamaño del texto (Normal, Grande, Muy grande) y Alto contraste (Automático, Sí, No)">

- **Idioma de la interfaz:** Automático (sigue a tu Mac), English o Español.
- **Tamaño:** Normal o Compacto (una ventana más pequeña).
- **Colores:** 8 juegos para toda la app (ventana, tarjeta de grabación y botón flotante):
  Azul clásico, Estudio, Medianoche, Bosque, Atardecer, Alto contraste, Papel y
  Personalizado (eliges el fondo, el micrófono y el color de acento). El texto que sería
  difícil de leer se ajusta solo.
- **Tamaño del texto:** Normal, Grande o Muy grande.
- **Alto contraste:** Automático (sigue Aumentar contraste de macOS), Sí o No. Las
  animaciones siguen el ajuste Reducir movimiento de macOS.

### Parar con el silencio y empezar / parar con la voz

<img src="images/settings-voice-autostop-es.png" width="570" alt="Ajustes: Parar solo con el silencio (Sí, No), Segundos de silencio (2, 3, 5, 8), Sensibilidad, y Empezar / parar con la voz activado, escuchando con large-v3-turbo, con frases de inicio y de parada editables">

- **Parar solo con el silencio:** con Sí, Taipea para y pega solo cuando dejas de hablar
  durante 2, 3, 5 u 8 segundos. **Sensibilidad:** un valor más alto toma más ruido de
  fondo como silencio.
- **Empezar / parar con la voz** (apagado por defecto): di **"Taipea escribe"** o
  **"Taipea write"** para empezar, y **"listo"**, **"done"** o **"Taipea listo"** solo,
  para parar y pegar. Las frases se pueden editar (sepáralas con comas). Corre solo en tu
  Mac. Mientras escucha, la barra de menús muestra 👂. Lee
  [Empezar / parar con la voz](../README.es.md#empezar--parar-con-la-voz) para saber cómo
  funciona y sus límites.

### Controles de grabación y ocultar el botón flotante

<img src="images/settings-floating-button-es.png" width="570" alt="Ajustes, Controles de grabación: Botón flotante Sí o No, Mostrar también la tarjeta de grabación, y la sección Ocultar el botón flotante con un botón Ocultar por ahora, Ocultar cuando una app está en pantalla completa, Ocultar en estas apps con botones rápidos para TV, VLC, QuickTime Player e IINA, Añadir una app abierta, y botones para restablecer la posición del botón y de la tarjeta">

- **Botón flotante:** Sí o No. **Mostrar también la tarjeta de grabación:** muestra
  también la tarjeta grande mientras dictas.
- **Ocultar el botón flotante:** toca **Opción + Comando** o presiona **Ocultar por
  ahora**. Vuelve cuando tocas otra vez.
- **Ocultar cuando una app está en pantalla completa** (activado por defecto) y
  **Ocultar en estas apps** (botones rápidos para TV, VLC, QuickTime Player e IINA, o
  **Añadir una app abierta**).
- Nunca se oculta mientras grabas o mientras Taipea trabaja, así que Parar siempre está a
  mano.
- **Restablecer la posición del botón** y **Restablecer la posición de la tarjeta** los
  traen de vuelta a la pantalla.

### Otros ajustes

- **Palabras propias:** por ejemplo, escribir "selektdev" cuando Whisper oye "select dev".
- **Corrección (gramática):** Sí, o No (original). **Estilo:** Ligero, Párrafos, Viñetas o
  Formal.
- **Idioma del dictado:** Automático, English o Español.
- **Al parar:** Pegar en el cursor, o Solo copiar.
- **Abrir al iniciar sesión** y **Mostrar la ventana al iniciar sesión**.

## 7. La pestaña Modelos

<img src="images/models-es.png" width="570" alt="Pestaña Modelos: lista Modelo de voz (Whisper) con large-v3-turbo marcado En uso y botones naranjas Descargar para los demás, y Modelo de corrección (Ollama) con gemma4:e4b En uso">

- **Modelo de voz (Whisper)** convierte tu voz en texto. El instalador descarga
  large-v3-turbo (o el turbo q5, más pequeño, si lo elegiste). Presiona **Descargar** para
  bajar otro y **Usar** para cambiar. El que usas muestra **✓ En uso**. Los modelos de voz
  se guardan en `~/Library/Application Support/Taipea/models`.
- **Modelo de corrección (Ollama)** arregla la puntuación y la gramática. Se recomienda
  gemma4:e4b, y qwen2.5:7b es la alternativa más ligera. Taipea usa la alternativa
  automáticamente si el modelo que elegiste no está instalado.
- **Actualizar lista** vuelve a cargar la lista, por ejemplo si instalaste un modelo con
  Ollama por tu cuenta.

## 8. Actualizaciones

Una vez al día Taipea le pregunta a GitHub si hay una versión más nueva. Si la hay, la
ventana muestra un aviso:

<img src="images/update-banner-es.png" width="570" alt="Ventana de Taipea con el aviso Nueva versión disponible: Tienes la v0.2.4, no se descarga ni se instala nada solo, y tres botones grandes: Ver las novedades, Recordármelo después y Omitir esta versión">

- **Ver las novedades** abre la página de la versión en GitHub. **Recordármelo después**
  oculta el aviso durante 7 días. **Omitir esta versión** lo oculta hasta la siguiente
  versión.
- No se descarga ni se instala nada solo. Para actualizar, vuelve a ejecutar el
  instalador: conserva tus ajustes, tu historial y tus modelos.

<img src="images/settings-updates-es.png" width="570" alt="Ajustes, tarjeta Actualizaciones: versión actual v0.2.4, hora de la última revisión, Buscar actualizaciones automáticamente Sí o No, un botón grande Buscar ahora y el mensaje Tienes la última versión">

En **Ajustes › Actualizaciones** ves tu versión y la última búsqueda, puedes presionar
**Buscar ahora** o apagar la búsqueda automática. Es la única conexión a internet de Taipea
además de descargar modelos. Mira [Actualizaciones](../README.es.md#actualizaciones) en el
README.

## 9. ¿Problemas?

- [Solución de problemas](../README.es.md#solución-de-problemas): no se pega nada, "No se
  detectó voz", corrección lenta, una ventana fuera de la pantalla, y más.
- [Permisos](../README.es.md#permisos-una-sola-vez)
- ¿Sigues con problemas? [Abre un issue](https://github.com/PatoSelekta/taipea/issues). Los
  reportes de accesibilidad son muy bienvenidos.

*Las capturas usan dictados de ejemplo.*

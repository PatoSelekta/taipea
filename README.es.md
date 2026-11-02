# Taipea

**Taipea por ti.** Hablas y Taipea escribe tus palabras en cualquier app de tu Mac.
Sin manos, privado, y hecho para español, inglés y la mezcla de los dos.

[Read in English](README.md) · Hecho por [selektdev](https://selektdev.com)

---

## Visión

Taipea está pensado primero para la **comunidad de accesibilidad**. Lo creó un
desarrollador cuadripléjico que maneja su Mac con un mouse de cabeza y un clic con la boca,
y cada decisión viene de ese uso diario:

- **Botones grandes y claros.** Miden de 60 a 110 px de alto y tienen espacio entre ellos,
  para que un mouse de cabeza, seguimiento ocular o pulsador los alcance sin precisión.
- **Sin manos.** Un atajo o un clic empieza y termina el dictado. Nada necesita doble clic,
  mantener una tecla presionada ni arrastrar con precisión.
- **Local y privado.** Tu voz y tu texto nunca salen de tu Mac. Sin cuenta, sin nube.
- **Bilingüe.** Inglés, español y la mezcla que muchos de verdad hablamos.

Ese mismo diseño amplio y tranquilo hace que Taipea sea cómodo para **cualquier persona**
que quiera dictar rápido y en privado: escritores, desarrolladores, personas con las manos
cansadas, o quien prefiera hablar a escribir.

Taipea es además la primera de una serie de apps prácticas de Patricio Escobar, que está
construyendo su carrera como desarrollador en **[selektdev.com](https://selektdev.com)**.
Si Taipea te sirve, una estrella, un reporte de error o un saludo allá significan mucho.

## ¿Qué es Taipea?

Taipea es una herramienta de dictado gratuita para macOS. Presionas un atajo (o haces
clic en un botón grande), hablas, y el texto aparece donde está tu cursor: correo, chat,
documentos, editores de código, formularios web.

La creó un desarrollador cuadripléjico que trabaja con un mouse de cabeza. Para él,
escribir con teclado es lento y cansado, y la mayoría de las herramientas de dictado
fallan cuando cambia entre inglés y español en la misma frase. Taipea es la herramienta
que usa todos los días.

Taipea es para ti si:

- no puedes escribir con teclado, o te duele (discapacidad motriz, lesión, fatiga),
- usas un mouse de cabeza, seguimiento ocular, pulsadores o control por voz,
- hablas español e inglés, a veces en la misma frase,
- quieres un dictado que nunca envíe tu voz a internet.

## Funciones

- **Funciona en cualquier app.** El texto se pega en el cursor. También puedes elegir
  "solo copiar".
- **Español, inglés o mezclado.** "Necesito the report antes del viernes" queda tal cual.
  No se traduce nada.
- **Corrección gramatical (opcional).** Un modelo de IA local corrige puntuación,
  mayúsculas y ortografía, y quita los "eh" y "mmm".
- **Cuatro estilos:** Ligero (solo corregir), Párrafos, Viñetas y Formal (cortés y
  profesional, con "usted").
- **Historial con botones para cambiar el estilo.** Cada dictado se guarda. Convierte uno
  viejo en viñetas o en un correo formal con un clic. Tus palabras originales siempre se
  conservan.
- **Dictados largos.** Hasta 30 minutos. El texto largo se corrige por partes, y si una
  parte no se puede corregir de forma segura, Taipea deja tus palabras originales en esa
  parte.
- **Pensado para mouse de cabeza y pulsadores.** Botones grandes (110 px de alto en el
  panel de grabación) y nada diminuto. Las ventanas se mueven arrastrando la barra de
  título, y esto funciona también con mouse de cabeza que no envían arrastres normales.
- **Interfaz en español o inglés** (sigue el idioma de tu Mac, o elige uno en Ajustes).
- **Tamaño Normal o Compacto**, panel que puedes ubicar donde quieras, abre al iniciar
  sesión.
- **Parada automática opcional** tras 2, 3, 5 u 8 segundos de silencio (un Sí/No grande
  en Ajustes).
- **Empezar / parar con la voz (opcional, apagado por defecto).** Di "Taipea escribe" o
  "Taipea write" para empezar, y "listo", "done" o "Taipea listo" para parar y pegar. Las
  frases se pueden cambiar. Mira [Empezar / parar con la voz](#empezar--parar-con-la-voz)
  para saber cómo funciona y sus límites.
- **Botón flotante 🎙 (activado por defecto).** Un botón redondo de 96 px que queda encima
  de todo: haz clic para empezar y otra vez para parar y pegar en la app que estabas
  usando. Arrástralo donde quieras; recuerda dónde lo dejaste. Se ve distinto en reposo,
  grabando y trabajando.
- **Palabras propias.** Dile a Taipea que "select dev" se escribe "selektdev". No importan
  mayúsculas ni tildes, y solo reemplaza palabras completas. Las palabras también se le dan
  a Whisper como pista, y al modelo de corrección se le pide no cambiarlas nunca.
- **Texto más grande y alto contraste.** Tamaño del texto Normal / Grande / Muy grande, y un
  tema de alto contraste para la ventana, el panel de grabación y el botón flotante. Sigue
  los ajustes Aumentar contraste (Automático) y Reducir movimiento de macOS.
- **Recuperación.** Cada grabación se guarda hasta que su texto se pega. Si Hammerspoon se
  cierra o se recarga en medio, Taipea ofrece **Recuperar la última grabación** y la
  transcribe.
- **Pegar otra vez el último dictado** con Ctrl + Opción + V, el menú o un botón en el
  Historial.

## Privacidad: 100 % local

- Tu voz se graba en un archivo temporal en tu Mac y la transcribe
  [whisper.cpp](https://github.com/ggml-org/whisper.cpp) en tu Mac.
- La corrección gramatical corre en [Ollama](https://ollama.com) en tu Mac.
- Sin cuenta, sin nube, sin analíticas, sin telemetría. Después de que el instalador
  descarga los modelos, Taipea funciona con el Wi-Fi apagado.
- Tu historial es un archivo en tu Mac:
  `~/Library/Application Support/Taipea/history.json`. Bórralo cuando quieras, o usa
  "Borrar todo" en la pestaña Historial.
- El audio del dictado en curso queda en `…/Taipea/tmp/` hasta que se pega, para poder
  recuperarlo si algo falla. El audio recuperado o descartado se borra.
- Empezar / parar con la voz (apagado por defecto) también corre solo en tu Mac. Mira más
  abajo.

## Requisitos

| | Mínimo | Recomendado |
|---|---|---|
| macOS | 13 Ventura | 14 Sonoma o más nuevo |
| Chip | Intel (lento) | Apple Silicon (M1 o más nuevo) |
| Memoria | 8 GB (usa los modelos pequeños o sin corrección) | 16 GB o más |
| Disco libre | unos 3 GB (sin corrección) | unos 13 GB (voz 1,6 GB + Gemma 4 E4B 7–10 GB + herramientas) |

Taipea usa estas herramientas gratuitas, y el instalador las configura por ti:
[Homebrew](https://brew.sh), [Hammerspoon](https://www.hammerspoon.org), whisper.cpp,
[SoX](https://sourceforge.net/projects/sox/) y Ollama.

## Instalar

Abre la app **Terminal**, pega esta línea y presiona Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/PatoSelekta/taipea/main/install.sh | bash
```

El instalador explica cada paso, pregunta antes de algo grande y se puede volver a
ejecutar sin problema (se salta lo que ya está hecho). El instalador:

1. revisa tu Mac (versión de macOS, chip, memoria, espacio en disco),
2. instala Homebrew si no lo tienes (pregunta antes),
3. instala Hammerspoon, whisper.cpp, SoX y Ollama con Homebrew,
4. descarga el modelo de voz `ggml-large-v3-turbo` (1,6 GB) de Hugging Face,
5. descarga el modelo de corrección `gemma4:e4b` de Ollama (si falla, usa `qwen2.5:7b`),
6. agrega una línea a `~/.hammerspoon/init.lua` (primero hace una copia de seguridad y
   no toca lo demás),
7. crea `~/Applications/Taipea.app` e inicia Taipea.

**Opciones.** Agrégalas después de `bash -s --`, por ejemplo
`curl -fsSL .../install.sh | bash -s -- --small`:

| Opción | Qué hace |
|---|---|
| `--small` | Modelo de voz más pequeño (0,57 GB). Bueno para Mac de 8 GB. |
| `--whisper=small` | El modelo de voz más pequeño (0,49 GB). Menos preciso con idiomas mezclados. |
| `--llm=qwen2.5:7b` | Usa otro modelo de corrección. |
| `--no-cleanup` | No instala Ollama. Taipea pega la transcripción sin corregir. |
| `--yes` | No hace preguntas; usa los valores por defecto. |
| `--skip-brew` | No instala ni inicia nada con Homebrew (las herramientas ya deben estar). |
| `--no-start` | No reinicia Hammerspoon, no inicia Ollama ni abre Ajustes del Sistema. |

¿Prefieres revisar antes? Descarga el código, lee `install.sh` y luego ejecuta
`bash install.sh`.

### Desinstalar

```bash
bash uninstall.sh            # pregunta antes de borrar tu historial y modelos
bash uninstall.sh --purge    # borra todo lo que creó Taipea
```

Las herramientas compartidas (Homebrew, Hammerspoon, Ollama…) se conservan, y el script
muestra los comandos para quitarlas también.

## Permisos (una sola vez)

macOS protege tu micrófono y tu teclado. Tienes que darlos una vez. Taipea corre dentro de
Hammerspoon, así que el permiso es para **Hammerspoon**:

1. **Accesibilidad:** Ajustes del Sistema › Privacidad y seguridad › Accesibilidad ›
   activa **Hammerspoon**. Se necesita para los atajos y para pegar el texto.
2. **Micrófono:** la primera vez que dictes, macOS te pregunta. Haz clic en **Permitir**.
   Para revisarlo después: Ajustes del Sistema › Privacidad y seguridad › Micrófono ›
   **Hammerspoon**.

Si el interruptor ya está activado pero no se pega nada, apágalo y vuelve a encenderlo, y
reinicia Hammerspoon.

## Cómo usarlo

Estos son los atajos por defecto. Funcionan apenas se instala Taipea, incluso sin archivo
de configuración.

| Atajo | Qué hace |
|---|---|
| **Ctrl + Opción + Espacio** | Empieza a dictar. Presiona el mismo atajo otra vez para parar: Taipea transcribe, corrige y pega en tu cursor. |
| **Ctrl + Opción + C** | Activa o desactiva la corrección (texto sin corregir). |
| **Ctrl + Opción + H** | Abre la ventana de Taipea: Historial, Ajustes, Modelos. |
| **Ctrl + Opción + V** | Pega otra vez el último dictado. |

¿Sin teclado? Todo funciona también con clics:

- El **botón flotante 🎙** redondo empieza el dictado; haz clic otra vez para parar y pegar.
- Mientras hablas, un panel flotante muestra tres botones grandes: **Parar y pegar**,
  **Parar y solo copiar** y **Cancelar**.
- Abre **Taipea.app** (en `~/Applications`, agrégala a tu Dock) para abrir la ventana.
  Tiene un botón grande **🎙 Dictar**.
- El ícono 🎙 en la barra de menús tiene las mismas acciones.

Puedes ver y cambiar los atajos en Ajustes › Atajos (escribe uno como `ctrl+alt+space` y
presiona Guardar). "Restablecer los atajos de fábrica" vuelve a estos.

### Empezar / parar con la voz

Actívalo en Ajustes › Empezar / parar con la voz (o en el menú 🎙). Después:

1. Di **"Taipea escribe"** o **"Taipea write"** y haz una pausa. Empieza la grabación.
2. Dicta como siempre.
3. Haz una pausa, di **"listo"**, **"done"** o **"Taipea listo"** solo, y otra pausa.
   Taipea para, quita la frase del texto y pega.

Cómo funciona: una grabadora pequeña (SoX) espera sonido, y eso casi no usa CPU (cerca de
0,1 % en un M2). Cuando hablas, guarda un fragmento corto de hasta 4 segundos, y Whisper
transcribe solo ese fragmento, en tu Mac (unos 1,5 s por fragmento con large-v3-turbo; pon
`ggml-small.bin` en la carpeta de modelos para que sea más liviano). Los fragmentos más
largos, como una conversación normal, se saltan sin transcribir. Cada fragmento se borra
apenas se revisa. La barra de menús muestra 👂 y el botón flotante tiene un anillo verde
mientras escucha. Se pausa cuando la pantalla está bloqueada o el Mac duerme.

Ventajas y límites:

- macOS muestra el punto naranja del micrófono todo el tiempo que está activo.
- Hay una pequeña demora: la frase de parada se detecta unos 2 segundos después de decirla.
- Una frase de parada solo se reconoce si la dices sola, después de una pausa; así "ya está
  listo el informe" en medio de una frase no para el dictado. A cambio, "listo." dicho solo
  sí lo para.
- "Taipea" es una palabra nueva para Whisper, así que Taipea también acepta cómo suele oírla
  ("Tapia, right", "Taipei ha listo"). En un lugar con ruido o música, usa mejor el atajo o
  el botón flotante, o sube `voiceThreshold` en config.lua.
- No es un detector de palabra clave como "Oye Siri": es la versión más confiable que
  funciona con las herramientas que Taipea ya usa, sin instalar nada más.

### Palabras propias

Ajustes › Palabras propias tiene una fila grande por palabra: **Se oye** (lo que escribe
Whisper) y **Reemplazar por** (lo que quieres). Añade una fila con el botón verde
**Añadir** y bórrala con **Borrar**; los cambios se guardan al salir de cada casilla. Los
reemplazos se aplican después de transcribir y otra vez después de la corrección, solo a
palabras completas, sin importar mayúsculas ni tildes ("Select Dev", "select-dev" y
"sélect dev" quedan como "selektdev").

### Recuperación

Si un dictado se interrumpe (un cierre inesperado, recargar Hammerspoon, un corte de luz),
Taipea muestra un aviso y la opción **♻️ Recuperar la última grabación** en el menú 🎙 y
arriba del Historial. Al recuperar, Taipea transcribe el audio guardado (y lo corrige si la
corrección está activa), copia el texto al portapapeles y lo añade al Historial.
**Descartar** lo borra.

## Ajustes por defecto

Taipea funciona desde el primer momento con estos ajustes. Cámbialos en la pestaña
**Ajustes** de la ventana, o en `config.lua` (todas las opciones, con su valor por defecto,
están en `config.example.lua`).

| Ajuste | Por defecto | Opciones |
|---|---|---|
| Empezar / parar el dictado | **Ctrl + Opción + Espacio** (al parar, pega) | cualquier atajo |
| Corrección sí / no | **Ctrl + Opción + C** | cualquier atajo |
| Abrir la ventana de Taipea | **Ctrl + Opción + H** | cualquier atajo |
| Pegar otra vez el último dictado | **Ctrl + Opción + V** | cualquier atajo |
| Corrección (gramática) | Sí | Sí / No (texto original) |
| Modelo de corrección | `gemma4:e4b`; si falta, `qwen2.5:7b` y luego `gemma4:e2b` | cualquier modelo de Ollama |
| Estilo | Ligero | Ligero / Párrafos / Viñetas / Formal |
| Modelo de voz | `ggml-large-v3-turbo` | turbo-q5, small, large-v3, medium |
| Idioma del dictado | Automático (mezcla español/inglés) | Automático / English / Español |
| Idioma de la interfaz | Automático (el de tu Mac) | Automático / English / Español |
| Al parar | Pegar en el cursor | Pegar / Solo copiar |
| Restaurar el portapapeles al pegar | Sí | Sí / No |
| Panel de grabación | Sí | Sí / No |
| Tamaño de la ventana | Normal | Normal / Compacto |
| Tamaño del texto | Normal | Normal / Grande / Muy grande |
| Alto contraste | Automático (sigue Aumentar contraste de macOS) | Automático / Sí / No |
| Botón flotante 🎙 | Sí | Sí / No |
| Empezar / parar con la voz | No | Sí / No; frases de inicio "Taipea escribe", "Taipea write"; de parada "listo", "done", "Taipea listo" |
| Palabras propias | ninguna | pares "se oye → reemplazar por" |
| Abrir al iniciar sesión | Sí | Sí / No |
| Mostrar la ventana al iniciar sesión | No | Sí / No |
| Parar solo con el silencio | No (pausa de 3 s y umbral de 1,5 % si se activa) | Sí / No; 2, 3, 5 u 8 s; 0,5–5 % |
| Dictado más largo | 30 minutos | `maxSeconds` en config.lua |
| Historial | últimos 500 dictados | `historyMax` en config.lua |
| Mantener cargado el modelo de corrección | 12 horas | `ollamaKeepAlive` en config.lua |

## Estilos

| Estilo | Qué obtienes |
|---|---|
| **Ligero** | Tus palabras, con puntuación, mayúsculas y ortografía corregidas. Sin muletillas. |
| **Párrafos** | Lo mismo, agrupado en párrafos cuando cambia el tema. |
| **Viñetas** | Una lista limpia, una idea por línea. |
| **Formal** | Redacción cortés y profesional para correos o documentos (con "usted"). |

En todos los estilos, lo que dijiste en inglés queda en inglés y lo que dijiste en
español queda en español, y se conservan nombres, números y fechas. Elige el estilo por
defecto en Ajustes, o convierte cualquier dictado viejo en Historial. La conversión
siempre parte de tus palabras originales.

## Modelos

Puedes cambiar los modelos en la pestaña **Modelos** de la ventana.

- **Voz (Whisper):** `large-v3-turbo` (por defecto, 1,6 GB), `large-v3-turbo-q5`
  (0,57 GB), `small` (0,49 GB) y otros más grandes. Los archivos están en
  `~/Library/Application Support/Taipea/models`.
- **Corrección (Ollama):** `gemma4:e4b` (por defecto), `qwen2.5:7b` (alternativa más
  liviana), `gemma4:e2b` y otros. Si falta el modelo elegido, Taipea usa la primera
  alternativa instalada. Si Ollama no está corriendo, Taipea igual pega el texto sin
  corregir.

Los ajustes avanzados están en `~/Library/Application Support/Taipea/config.lua` (mira
`config.example.lua` en la misma carpeta).

## Solución de problemas

**No pasa nada al presionar el atajo.**
Revisa que Hammerspoon esté abierto (🎙 en la barra de menús) y tenga permiso de
Accesibilidad. Luego elige Hammerspoon › Reload Config en su ícono de la barra de menús.

**Aparece el panel pero no se pega nada.**
Falta el permiso de Accesibilidad o quedó trabado: apaga y enciende Hammerspoon en
Privacidad y seguridad › Accesibilidad. También puedes elegir "Solo copiar" en Ajustes
y pegar con Cmd+V.

**"No se detectó voz" o el texto sale vacío.**
Revisa Ajustes del Sistema › Privacidad y seguridad › Micrófono › Hammerspoon. Revisa que
el micrófono correcto esté elegido en Ajustes del Sistema › Sonido › Entrada.

**"Aún no hay modelo de voz."**
Abre la ventana (Ctrl+Opción+H) › Modelos y haz clic en Descargar, o vuelve a ejecutar el
instalador.

**"Corrección no disponible" / el texto no se corrige.**
Ollama no está corriendo o no hay un modelo de corrección. Ejecuta
`brew services start ollama` y `ollama pull gemma4:e4b`. Si `ollama pull` falla,
actualízalo con `brew upgrade ollama`.

**La primera corrección es lenta.**
El modelo se está cargando en memoria (la primera vez puede tardar 10 a 20 segundos).
Después, Taipea lo mantiene cargado 12 horas.

**La corrección siempre es lenta, o el Mac se pone lento.**
Puede que tu Mac no tenga memoria suficiente para Gemma 4 E4B. Elige `qwen2.5:7b` o
`gemma4:e2b` en Modelos, o desactiva la corrección con Ctrl+Opción+C.

**La ventana o el panel quedaron fuera de la pantalla.**
Ajustes › Panel de grabación › Restablecer la posición del panel. Al moverlas, las ventanas siempre se quedan
dentro de la pantalla.

**Empezar / parar con la voz no reacciona, o empieza solo.**
Di la frase sola, con una pausa corta antes y después. Revisa que 👂 esté en la barra de
menús. Si empieza solo en un lugar con ruido, sube `voiceThreshold` (por ejemplo `"4%"`)
en config.lua, o cambia las frases de inicio. Para ver qué oye, pon `voiceDebug = true` en
config.lua (esto escribe en el registro el texto de los fragmentos cortos).

**El botón flotante estorba o quedó fuera de la pantalla.**
Arrástralo a otro lugar, o usa Ajustes › Botón flotante › Restablecer la posición del
botón, o apágalo ahí.

**¿Dónde están los registros (logs)?**
`~/Library/Application Support/Taipea/logs/taipea.log`, o 🎙 en la barra de menús › Abrir
registro. El registro contiene tu texto dictado, así que revísalo antes de compartirlo.

## Contribuir y reportar problemas de accesibilidad

Taipea es de código abierto y las contribuciones son bienvenidas. Lee
[CONTRIBUTING.md](CONTRIBUTING.md).

**Los problemas de accesibilidad son errores, con prioridad alta.** Si un botón es muy
pequeño, si un paso necesita teclado, o si algo no funciona con tu mouse de cabeza,
seguimiento ocular, pulsador o lector de pantalla,
[abre un reporte de accesibilidad](https://github.com/PatoSelekta/taipea/issues/new?template=accessibility.yml).
No necesitas saber programar. Cuéntanos qué usas y qué te estorbó. Puedes escribir en
español.

## Créditos

Taipea es una capa pequeña sobre excelente software libre:

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) de Georgi Gerganov y colaboradores,
  con los modelos [Whisper](https://github.com/openai/whisper) de OpenAI (MIT).
- [Ollama](https://ollama.com) para correr modelos de lenguaje locales (MIT).
- [Gemma](https://ai.google.dev/gemma) de Google DeepMind, el modelo de corrección por
  defecto (usado bajo los [Términos de uso de Gemma](https://ai.google.dev/gemma/terms)), y
  [Qwen2.5](https://github.com/QwenLM/Qwen2.5) de Alibaba Cloud como alternativa.
- [Hammerspoon](https://www.hammerspoon.org) para los atajos, las ventanas y el pegado (MIT).
- [SoX](https://sourceforge.net/projects/sox/) para grabar el micrófono.
- [Homebrew](https://brew.sh) para instalarlo todo.

## Licencia

[MIT](LICENSE) © 2026 Patricio Escobar / selektdev. Los modelos que descargas tienen sus
propias licencias (mira Créditos).

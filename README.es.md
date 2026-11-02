# Taipea

**Taipea por ti.** Hablas y Taipea escribe tus palabras en cualquier app de tu Mac.
Sin manos, privado, y hecho para español, inglés y la mezcla de los dos.

[Read in English](README.md) · Hecho por [selektdev](https://selektdev.com)

---

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
- **Cuatro estilos:** Light (solo corregir), Paragraph (párrafos), Bullets (viñetas) y
  Formal (cortés y profesional, con "usted").
- **Historial con botones para cambiar el estilo.** Cada dictado se guarda. Convierte uno
  viejo en viñetas o en un correo formal con un clic. Tus palabras originales siempre se
  conservan.
- **Dictados largos.** Hasta 30 minutos. El texto largo se corrige por partes, y si una
  parte no se puede corregir de forma segura, Taipea deja tus palabras originales en esa
  parte.
- **Pensado para mouse de cabeza y pulsadores.** Botones grandes (110 px de alto en el
  panel de grabación) y nada diminuto. Las ventanas se mueven arrastrando la barra de
  título, y esto funciona también con mouse de cabeza que no envían arrastres normales.
- **Tamaño Normal o Compacto**, panel que puedes ubicar donde quieras, abre al iniciar
  sesión.
- **Parada automática opcional** tras unos segundos de silencio.

## Privacidad: 100 % local

- Tu voz se graba en un archivo temporal en tu Mac y la transcribe
  [whisper.cpp](https://github.com/ggml-org/whisper.cpp) en tu Mac.
- La corrección gramatical corre en [Ollama](https://ollama.com) en tu Mac.
- Sin cuenta, sin nube, sin analíticas, sin telemetría. Después de que el instalador
  descarga los modelos, Taipea funciona con el Wi-Fi apagado.
- Tu historial es un archivo en tu Mac:
  `~/Library/Application Support/Taipea/history.json`. Bórralo cuando quieras, o usa
  "Clear all" en la pestaña History.

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
curl -fsSL https://raw.githubusercontent.com/OWNER/taipea/main/install.sh | bash
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

| Atajo | Qué hace |
|---|---|
| **Ctrl + Opción + Espacio** | Empieza a dictar. Presiona otra vez para parar y pegar. |
| **Ctrl + Opción + C** | Activa o desactiva la corrección (texto sin corregir). |
| **Ctrl + Opción + H** | Abre la ventana de Taipea: History, Settings, Models. |

¿Sin teclado? Todo funciona también con clics:

- Mientras hablas, un panel flotante muestra tres botones grandes: **Stop & Paste**
  (parar y pegar), **Stop & Copy only** (parar y solo copiar) y **Cancel** (cancelar).
- Abre **Taipea.app** (en `~/Applications`, agrégala a tu Dock) para abrir la ventana.
  Tiene un botón grande **🎙 Dictate**.
- El ícono 🎙 en la barra de menús tiene las mismas acciones.

Puedes cambiar los atajos en Settings. Por ahora la interfaz está en inglés.

## Estilos

| Estilo | Qué obtienes |
|---|---|
| **Light** | Tus palabras, con puntuación, mayúsculas y ortografía corregidas. Sin muletillas. |
| **Paragraph** | Lo mismo, agrupado en párrafos cuando cambia el tema. |
| **Bullets** | Una lista limpia, una idea por línea. |
| **Formal** | Redacción cortés y profesional para correos o documentos (con "usted"). |

En todos los estilos, lo que dijiste en inglés queda en inglés y lo que dijiste en
español queda en español, y se conservan nombres, números y fechas. Elige el estilo por
defecto en Settings, o convierte cualquier dictado viejo en History. La conversión
siempre parte de tus palabras originales.

## Modelos

Puedes cambiar los modelos en la pestaña **Models** de la ventana.

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
Privacidad y seguridad › Accesibilidad. También puedes elegir "Copy only" en Settings y
pegar con Cmd+V.

**"No speech detected" o el texto sale vacío.**
Revisa Ajustes del Sistema › Privacidad y seguridad › Micrófono › Hammerspoon. Revisa que
el micrófono correcto esté elegido en Ajustes del Sistema › Sonido › Entrada.

**"No speech model yet."**
Abre la ventana (Ctrl+Opción+H) › Models y haz clic en Download, o vuelve a ejecutar el
instalador.

**"Cleanup unavailable" / el texto no se corrige.**
Ollama no está corriendo o no hay un modelo de corrección. Ejecuta
`brew services start ollama` y `ollama pull gemma4:e4b`. Si `ollama pull` falla,
actualízalo con `brew upgrade ollama`.

**La primera corrección es lenta.**
El modelo se está cargando en memoria (la primera vez puede tardar 10 a 20 segundos).
Después, Taipea lo mantiene cargado 12 horas.

**La corrección siempre es lenta, o el Mac se pone lento.**
Puede que tu Mac no tenga memoria suficiente para Gemma 4 E4B. Elige `qwen2.5:7b` o
`gemma4:e2b` en Models, o desactiva la corrección con Ctrl+Opción+C.

**La ventana o el panel quedaron fuera de la pantalla.**
Settings › Overlay › Reset overlay position. Al moverlas, las ventanas siempre se quedan
dentro de la pantalla.

**¿Dónde están los registros (logs)?**
`~/Library/Application Support/Taipea/logs/taipea.log`, o 🎙 en la barra de menús › Open
log. El registro contiene tu texto dictado, así que revísalo antes de compartirlo.

## Contribuir y reportar problemas de accesibilidad

Taipea es de código abierto y las contribuciones son bienvenidas. Lee
[CONTRIBUTING.md](CONTRIBUTING.md).

**Los problemas de accesibilidad son errores, con prioridad alta.** Si un botón es muy
pequeño, si un paso necesita teclado, o si algo no funciona con tu mouse de cabeza,
seguimiento ocular, pulsador o lector de pantalla,
[abre un reporte de accesibilidad](https://github.com/OWNER/taipea/issues/new?template=accessibility.yml).
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

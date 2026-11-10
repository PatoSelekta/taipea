# Live vs full-file Whisper (offline, local WAV only)

Small helper to compare Taipea’s **fixed** live windows (overlapping 24 s slices, 4 s
overlap; `liveChunking = "fixed"`) with the current full-file `whisper-cli` on **the
same local WAV**. The in-app default since v0.3.1 is adaptive pause-aware chunks
(`liveChunking = "adaptive"`); this helper still measures the old 24 s path. It does not
record, does not touch a running Taipea, and does not talk to the network.

English-only fast engines (for example Parakeet) are a **later, separate**
benchmark. Do not mix them into this comparison.

## What it measures

On each file:

| Clock | Meaning |
|---|---|
| `T_live_sum` | Sum of `whisper-cli` time on each 24 s window (serial, same flags Taipea uses: `-l auto -np`, no `-nt`, no `-tr`) |
| `T_full` | One `whisper-cli` on the whole file with the same flags |

`--plan` only prints the windows (same math as `M.liveWindows`). Use it on any machine with Lua 5.4. `--run` needs `whisper-cli`, the Taipea model, and optionally `sox` on a Mac.

This is **not** the in-app live path. In-app live snapshots a *growing* `rec.wav` while you talk, then runs Ollama cleanup **once** on the joined raw. This helper only compares Whisper decode time on finished files.

## Run (Mac, local files)

From the repo:

```bash
# windows only — no model, no network
lua scripts/bench-live.lua --plan /path/to/local.wav

# time live slices vs full-file (same WAV, same model)
export TAIPEA_WHISPER=/opt/homebrew/bin/whisper-cli
export TAIPEA_MODEL="$HOME/Library/Application Support/Taipea/models/ggml-large-v3-turbo.bin"
export TAIPEA_SOX=/opt/homebrew/bin/sox
lua scripts/bench-live.lua --run /path/to/local.wav
```

Use **your own** 16 kHz mono 16-bit WAVs (Taipea’s format). Do not pass URLs.

Intel Homebrew paths are `/usr/local/bin/whisper-cli` and `/usr/local/bin/sox`.

## How to read the numbers

- `T_live_sum` is work that Taipea can hide **during** recording. After Stop you still pay the last slice (and leftover) plus one cleanup.
- `T_full` is today’s post-stop Whisper. If `T_live_sum` is close to `T_full`, Stop only waits on the tail.
- Quality: read both transcripts. Seams should keep mixed EN/ES wording (`necesito the report`). A weak seam is logged in the app as `live:seam:weak`.
- Language stays **Auto** (`-l auto`). Do not add `-nt` or `-tr`.

## In-app clocks (real dictation)

With `liveTranscribe = true` (the default; set `false` in `config.lua` to force the old path), Taipea writes one line after paste:

```
timing: T_rec=… T_live_sum=… T_stop_to_raw=… T_cleanup=… T_stop_to_paste=…
```

| Clock | Meaning |
|---|---|
| `T_rec` | Start → Stop |
| `T_live_sum` | Whisper time spent on slices (including during rec) |
| `T_stop_to_raw` | Stop → joined raw ready (last slice + silence / tail guard) |
| `T_cleanup` | One Ollama cleanup on the joined raw |
| `T_stop_to_paste` | Stop → paste/copy |

Log: `~/Library/Application Support/Taipea/logs/taipea.log`.

## Still needs a real Mac

This helper does **not** replace a real session. On a Mac, still verify:

1. Talk 10 s, 40 s, 2+ min (mixed EN/ES). Stop & Paste / Copy / Cancel.
2. `liveTranscribe = false` matches v0.2.8 full-file behavior.
3. Fallback: force a whisper failure or a >40 s unprocessed leftover → full `transcribe()`.
4. Silent room → nothing pasted. Quiet tail “Thank you.” / “Gracias.” still dropped.
5. Cancel while a slice is running (and while sox trim is running) returns to idle, no paste.
6. Timing line appears; controls stay ≥ 60 px; no new Settings toggle.

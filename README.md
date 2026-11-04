<img src="assets/icon.svg" width="64" height="64" alt="">

# LocalWispr

Push-to-talk dictation for Windows in one 92 KB native executable. It's a minimal take on
[OpenWhispr](https://github.com/OpenWhispr/openwhispr) that does only the parts I use.

| Keys | What happens |
| --- | --- |
| Hold **Left Ctrl + Win**, talk, release | Records, transcribes with OpenAI, cleans up the text, and pastes it into the focused app |
| Hold **Left Ctrl + Win + Alt** | Shows your last 5 dictations. **Up/Down** picks one; releasing copies it to the clipboard. **Esc** cancels. |

Ctrl + Win + any other key (for example Ctrl+Win+Left to switch desktops) cancels the recording.
The Start menu doesn't open. After pasting, whatever was on your clipboard before (text, files,
images) is put back one second later.

## Memory

Written in plain C against Win32: no Electron, no runtime, no background polling. When idle it is
two threads blocked waiting for input. The microphone is open only while you hold the keys.

| | Idle |
| --- | --- |
| Private working set (Task Manager "Memory") | ~0.2 MB |
| Committed private memory | ~6 MB |
| CPU | 0 |

## Install

Needs [Zig](https://ziglang.org) as the C compiler (`winget install zig.zig`).

```powershell
.\build.ps1 -Install
```

This copies the exe to `%LOCALAPPDATA%\Programs\LocalWispr`, registers it to start at login, and
launches it. The tray icon (blue = idle, red = recording, amber = transcribing) has the menu.

## Settings

Everything lives in `%APPDATA%\LocalWispr`. Changes apply on the next dictation; no restart needed.

- `config.ini`: API key, models, language and vocabulary hints. Set `[cleanup] enabled=0` to paste
  the raw transcript.
- `prompt.txt`: the cleanup prompt.
- `history.txt`: every dictation, one per line, with a timestamp.

Defaults: `gpt-4o-mini-transcribe` for speech to text and `gpt-5.4-mini` (reasoning off) for
cleanup. An 18-second clip typically comes back in 2–3 seconds. If cleanup fails, the raw
transcript is pasted and a tray notification says why.

## Testing

`build.ps1 -Test` also builds `localwispr-test.exe`. That build accepts simulated key presses, and
setting `LW_FAKE=<text>` skips OpenAI. `localwispr.exe --test in.wav out.txt` runs one 16 kHz mono
WAV through the real pipeline and writes the raw transcript, the cleaned text and the timing.

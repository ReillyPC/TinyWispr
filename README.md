<img src="assets/icon.svg" width="64" height="64" alt="">

# LocalWispr

Push-to-talk dictation for Windows in one 104 KB native executable. It's a minimal take on
[OpenWhispr](https://github.com/OpenWhispr/openwhispr) that does only the parts I use.

| Keys | What happens |
| --- | --- |
| Hold **Left Ctrl + Win**, talk, release | Records, transcribes with OpenAI, cleans up the text, and pastes it into the focused app |
| Hold **Left Ctrl + Win + Alt** | Shows your last 5 dictations. **Up/Down** picks one; releasing copies it to the clipboard. **Esc** cancels. |

Ctrl + Win + any other key (for example Ctrl+Win+Left to switch desktops) cancels the recording.
The Start menu doesn't open. After pasting, whatever was on your clipboard before (text, files,
images) is put back one second later.

## Dictionary

`dictionary.txt` holds names and jargon, one per line. The list is sent to the transcriber as a
spelling hint and appended to the cleanup prompt ("use these exact spellings"). If the
transcriber only recites the list back (which can happen on near-silence), the result is thrown
away.

**Learning from your edits.** For 30 seconds after a paste, LocalWispr watches the text box it
pasted into. If you fix a misheard word (say *Shunade* to *Sinead*), the corrected word is added
to the dictionary and a pill says "Added to dictionary: Sinead". A word only counts as a fix if:

- it's 3+ letters,
- it isn't an everyday word,
- it's spelled close to the original, and
- you didn't rewrite most of the text.

This is the same rule OpenWhispr uses. It still learns if you fix the word and press Enter right
away. Half-typed words are ignored. Turn it off with `[dictionary] auto_learn=0`, and edit or prune
the list from the tray menu (Edit dictionary).

The watching runs in a short-lived child process (`localwispr.exe --watch`) that reads the field
through Windows UI Automation. It exits after 30 seconds, or as soon as you dictate again, so UI
Automation is never loaded into the resident app. It can't read password fields or apps running
as administrator, and it skips fields over 20,000 characters (whole documents).

## Memory

Written in plain C against Win32: no Electron, no runtime, no background polling. When idle it is
two threads blocked waiting for input. The microphone is open only while you hold the keys.

Measured on Windows 11, median of 3 runs, 6 seconds after launch, with a 300-word dictionary:

| Resident app, idle | Before dictionary | With dictionary |
| --- | --- | --- |
| Private working set (Task Manager "Memory") | 0.18 MB | 0.17 MB |
| Committed private memory | 6.43 MB | 6.48 MB |
| Threads / handles | 5 / 212 | 5 / 212 |
| CPU | 0 | 0 |

The learn-from-edits watcher is the only new cost. It's a separate process that exists for up to
30 seconds after each paste, and only one runs at a time:

| Watcher process | |
| --- | --- |
| Committed private memory, peak | 6.8–7.3 MB (about 1 MB of it is UI Automation) |
| Working set, peak (mostly shared Windows DLL pages) | 24–26 MB |
| CPU over its 30 seconds | 0.05–0.2 s |

## Install

Needs [Zig](https://ziglang.org) as the C compiler (`winget install zig.zig`).

```powershell
.\build.ps1 -Install
```

This copies the exe to `%LOCALAPPDATA%\Programs\LocalWispr`, registers it to start at login, and
launches it. The tray icon (blue = idle, red = recording, amber = transcribing) has the menu.

## Settings

Everything lives in `%APPDATA%\LocalWispr`. Changes apply on the next dictation; no restart needed.

- `config.ini`: API key, models, language, and `auto_learn`. Set `[cleanup] enabled=0` to paste
  the raw transcript.
- `dictionary.txt`: your word list (newest entries last; the newest 800 characters go to the
  transcriber, up to 6,000 to cleanup).
- `prompt.txt`: the cleanup prompt.
- `history.txt`: every dictation, one per line, with a timestamp.

Defaults: `gpt-4o-mini-transcribe` for speech to text and `gpt-5.4-mini` (reasoning off) for
cleanup. An 18-second clip typically comes back in 2–3 seconds. If cleanup fails, the raw
transcript is pasted and a tray notification says why.

## Testing

`build.ps1 -Test` also builds `localwispr-test.exe`. That build accepts simulated key presses, and
setting `LW_FAKE=<text>` skips OpenAI. `localwispr.exe --test in.wav out.txt` runs one 16 kHz mono
WAV through the real pipeline and writes the raw transcript, the cleaned text and the timing.
`localwispr-test.exe --unit out.txt` checks the correction learner and the echo filter.

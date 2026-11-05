<img src="assets/icon.svg" width="64" height="64" alt="">

# TinyWispr

Push-to-talk dictation for Windows in one 124 KB native executable. It's a minimal take on
[OpenWhispr](https://github.com/OpenWhispr/openwhispr) that does only the parts I use.

| Keys | What happens |
| --- | --- |
| Hold **Left Ctrl + Win**, talk, release | Records, transcribes with OpenAI, cleans up the text, and pastes it into the focused app |
| **Tap** Left Ctrl + Win | Hands-free: keeps recording while you click and type in other windows. **Tap Ctrl + Win again** to finish; the text goes into whatever field is focused then. |
| Hold **Left Ctrl + Win + Alt** | Shows your last 5 dictations. **Up/Down** picks one; releasing copies it to the clipboard. **Esc** cancels. **Right** opens the dictionary window. |

A tap is a press shorter than 350 ms (`[hotkey] tap_ms`). During a hold, Ctrl + Win + any other key
(for example Ctrl+Win+Left to switch desktops) cancels the recording. During hands-free, those
shortcuts pass through and recording carries on, and Ctrl + Win + Alt throws the recording away.
The Start menu doesn't open, even if you hold the keys a long time or your finger
catches Win again within 150 ms of letting go. After pasting, whatever was on your clipboard before (text, files,
images) is put back one second later.

## Dictionary

`dictionary.txt` holds names and jargon, one per line. The list is sent to the transcriber as a
spelling hint and appended to the cleanup prompt ("use these exact spellings"). If the
transcriber only recites the list back (which can happen on near-silence), the result is thrown
away.

**Words it mishears as other words.** If the transcriber keeps writing a real word in place of
yours, add what it hears after `# misheard as`:

```
ship it  # misheard as shepherd
```

The cleanup prompt then gets a note that "ship it" is often misheard as "shepherd", and swaps it
only where "ship it" fits ("so shepherd" becomes "so ship it"; "the shepherd walked his dog"
stays). List several with commas: `# misheard as shepherd, shipped it`.

**Learning from your edits.** For 30 seconds after a paste, TinyWispr watches the text box it
pasted into. If you fix a misheard word (say *Shunade* to *Sinead*), the corrected word is added
to the dictionary and a pill says "Added to dictionary: Sinead". A word only counts as a fix if:

- it's 3+ letters,
- it isn't an everyday word,
- it's spelled close to the original, and
- you didn't rewrite most of the text.

This is the same rule OpenWhispr uses. It still learns if you fix the word and press Enter right
away. Half-typed words are ignored. Learned words are tagged `# learned` in the file. Turn learning
off with `[dictionary] auto_learn=0` (the watcher still runs to fill the
[dictation log](#dictation-log) unless that's off too).

**Editing.** Press Right in the Ctrl+Win+Alt popup (or use the tray menu → Edit dictionary) to open
the dictionary window. It stays open after you let go:

- Type a word and press Enter to add it.
- Up/Down picks a word. Newest words are at the top, and learned ones are marked.
- Delete removes the picked word. Esc closes the window.
- **Open file** opens `dictionary.txt` in Notepad for bulk edits.

The window is destroyed when it closes. While open it adds about 0.5 MB.

The watching runs in a short-lived child process (`tinywispr.exe --watch`) that reads the field
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

This copies the exe to `%LOCALAPPDATA%\Programs\TinyWispr`, registers it to start at login, and
launches it. The tray icon (blue = idle, red = recording, amber = transcribing) has the menu.

## Settings

Everything lives in `%APPDATA%\TinyWispr`. Changes apply on the next dictation; no restart needed.

- `config.ini`: API key, models, language, `streaming`, `trim_pauses`, `tap_ms`, `auto_learn`, and
  the `[log]` settings. Set
  `[cleanup] enabled=0` to paste the raw transcript.
- `dictionary.txt`: your word list (newest entries last; the newest 800 characters go to the
  transcriber, up to 6,000 to cleanup).
- `prompt.txt`: the cleanup prompt.
- `history.txt`: every dictation, one per line, with a timestamp.

Defaults: `gpt-transcribe` for speech to text and `gpt-5.4-mini` (reasoning off) for cleanup. An
18-second clip typically comes back about 1.5 seconds after you let go. If cleanup fails, the raw
transcript is pasted and a tray notification says why. `gpt-live-transcribe` cuts about half a
second more, at about four times the price. A config that still names `gpt-4o-mini-transcribe`
(the old default, which leaves the API on Feb 26, 2027) is moved to `gpt-transcribe` on start.

## Dictation log

Every dictation that reaches OpenAI is also kept in `%LOCALAPPDATA%\TinyWispr\log`, which stays
on this computer (it isn't in the roaming profile). It's there to test cleanup prompts against
real dictations, and to train a voice model later.

- `dictations.jsonl`: one JSON line per dictation with the id, time, status (`ok`, `empty`,
  `dropped_echo`, `cleanup_failed`, `error`), audio path and length, transcribe model and the
  word list sent with it, the raw transcript, cleanup model and effort, the cleanup prompt file,
  the final text, any error, and timings.
- `audio\<date>\<time>.wav`: the audio exactly as sent (24 kHz mono 16-bit, with long pauses
  shortened if `trim_pauses` is on). About 2.9 MB per minute of speech.
- `prompts\<hash>.txt`: each distinct cleanup system prompt, dictionary included, saved once.
  A line's `cleanup_prompt` names the one it used.
- `corrections.jsonl`: what you did with each paste in the 30 seconds after it, from the same
  watcher that learns words. One line per dictation, matched by `id`: the app it went into,
  `edited` (true or false), the text as pasted, and the text after your edits (taken just before
  you sent the message or cleared the box). Not written when the field can't be read (see above)
  or the app reformatted the paste (Word lists, for example).

Presses that never reach OpenAI (short taps, no speech, cancelled recordings) aren't logged. In
`config.ini`, `[log] enabled=0` turns the log off, `audio=0` keeps the text without the WAVs, and
`folder=` moves it (environment variables work, such as `%USERPROFILE%\TinyWisprLog`). Nothing
is ever deleted automatically.

## Speed

Audio streams to OpenAI's Realtime API while you talk, so little is left to do when you let go.
An HTTPS connection is also warmed for the cleanup request, which keeps it from paying for a
handshake. The recording stays in memory too: if the stream fails, the clip is uploaded the normal
way. All of this exists only for the length of a dictation.

Because audio leaves as you speak, a recording you cancel or throw away has already been sent, in
part or in full. Set `[openai] streaming=0` to send audio only after you finish, which is about
0.7 seconds slower on an 18-second clip.

## What gets sent

A small speech detector runs on the audio locally, and nothing reaches OpenAI until it hears
someone talking:

- A press under 650 ms is never sent, whatever is in it. There's no connection and no audio.
- A longer press with only room noise or key clicks isn't sent either. If it lasted a second or
  more, a pill says "Didn't hear anything".
- Hands-free mode opens no connection until you start talking.
- Long pauses shrink to under a second: each keeps its first 700 ms and last 200 ms. OpenAI bills
  for silence too, so this lowers the cost. Set `[openai] trim_pauses=0` to send pauses as recorded.

The detector hears speech down to about 30 dB below normal talking volume in a quiet office. Once
it's keeping audio, quiet consonants hold a stretch open, so soft words aren't clipped as pauses.
Quieter than that, the dictation is dropped. It can't tell your voice from other voices, so
someone talking nearby can still start a stream during a longer press.

## Testing

`build.ps1 -Test` also builds `tinywispr-test.exe`. That build accepts simulated key presses, and
setting `TW_FAKE=<text>` skips OpenAI. `tinywispr.exe --test in.wav out.txt` runs one WAV through
the real pipeline and writes the raw transcript, the cleaned text and the timing. `--test-live`
does the same with a 24 kHz mono WAV, streaming it in real time first and timing from the end of
the clip. `tinywispr-test.exe --unit out.txt` checks the correction learner, the echo filter, `# misheard as`
parsing and how the watcher finds an edited paste. `TW_LOG=1` makes `--test` and `TW_FAKE` runs write
to the dictation log (point `LOCALAPPDATA` somewhere else to keep it out of the real one).
In the test build, `TW_LIVE_BREAK`, `TW_LIVE_MODEL=<bad model>`, `TW_LIVE_TIMEOUT` and
`TW_LIVE_CANCEL` force each way the stream can fail. `--trim in.wav out.wav stats.txt` runs a clip
through the speech detector offline, and `--mic-vad seconds stats.txt` runs it on the live
microphone, keeping the audio in memory only and reporting numbers.

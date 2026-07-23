# Codex Buddy

Codex Buddy is a small Windows and Linux overlay for Codex Desktop telemetry. It reads local Codex session JSONL files under `%USERPROFILE%\.codex\sessions` on Windows or `~/.codex/sessions` on Linux and shows live task speed, token flow, context use, rate-limit windows, and Codex process stats.

## Run It

From this folder, double-click:

```text
Start-CodexBuddy.cmd
```

From PowerShell:

```bat
cd "C:\Users\antho\OneDrive\Documents\Codex Buddy"
Start-CodexBuddy.cmd
```

Or directly:

```powershell
cd "C:\Users\antho\OneDrive\Documents\Codex Buddy"
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File .\CodexBuddy.ps1
```

Live limit audit (Spark vs normal):

```powershell
cd "C:\Users\antho\OneDrive\Documents\Codex Buddy"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CodexBuddy.ps1 -DumpLimitEvents
```

The display is always on top and can be dragged from anywhere on the panel. Close it with the `X` button.

## Linux

The Linux edition is designed to run beside the unofficial Electron-based [Codex Desktop for Linux](https://github.com/ilysenko/codex-desktop-linux). It reads the shared local `~/.codex` session stream; it does not inject into or modify the Codex app.

Install the small user-level launcher from this checkout:

```bash
bash ./linux/install.sh
codex-buddy
```

If you received the flat ZIP package, extract it and run `bash ./install.sh` from the extracted folder instead. The installer accepts both layouts, so the package can be copied or extracted by standard Linux tools without preserving a `linux/` directory.

Tkinter is the only Linux GUI dependency. If the installer reports it missing, install `python3-tk` on Debian/Ubuntu, `python3-tkinter` on Fedora, or `tk` on Arch. The Linux dashboard includes session status, model, token/context usage, prompt cost, rate-limit windows, tool activity, Codex process memory, long-context warnings, automatic refresh, and `--once` JSON output.

For a direct checkout run:

```bash
bash ./Start-CodexBuddy.sh
bash ./Start-CodexBuddy.sh --once
```

## Benchmark Workflow

1. Select one conversation tab, then click `Bench`.
2. Send exactly one test prompt in that conversation.
3. Codex Buddy finishes the run automatically at `task_complete` and records timing, token speeds, tools, calls, model, tier, context, and cost.
4. Open `Info` to compare saved runs. Use `Export benchmarks` to write a Markdown print-off under `Documents\Codex Buddy\Benchmarks`.

## Release Model

This project is intended to live in a private source repo, with a separate public repo that only publishes release downloads. See [PUBLISHING.md](./PUBLISHING.md) for the exact workflow and the source-protection caveat.
The release build creates a compiled `CodexBuddy.exe` plus release notes in `.artifacts/release/`.

## What It Shows

- `model speed`: token delta per minute and tokens per second from the latest Codex session log.
- `speed of use`: recent event cadence and tool-call rate.
- `tokens`: total and last-turn token counts from Codex's local telemetry events.
- `context`: latest-turn tokens as a percentage of the model context window.
- `model pricing`: recognizes GPT-5.6 Sol, Terra, and Luna plus the supported GPT-5.5/GPT-5.4 families, showing standard and long-context API input/output prices per 1M tokens.
- `prompt costs`: shows the current prompt cost plus the five most recent prompt costs, with model, token counts, relative cost points, and estimated API cost for model comparisons.
- `benchmark mode`: arm the selected conversation for one prompt, automatically capture the completed turn's timing, token speeds, tools, calls, model, tier, context, and cost, then review or export side-by-side Markdown reports.
- long-context alerts: an over-272K GPT-5.4/GPT-5.5 event, or an overrun of the active model's reported context window, is counted and kept visible until you click the red `OVER n` badge to accept it. The acknowledgement ledger survives Codex Buddy restarts under `%LOCALAPPDATA%\CodexBuddy\long-context-alerts.json`.
- `weekly remaining`: Codex's current weekly usage bucket, including used/remaining percentage and reset countdown. If Codex later supplies another limit bucket, Buddy shows it separately.
- telemetry detail: exact completed-task duration and first-token time, cache-write input, modern custom tool calls, rate-limit metadata, session source, Git identity, and recent context-compaction events when Codex writes them locally.
- cache efficiency: cache-hit percentage, uncached input, and last-prompt cache reuse from Codex token counters.
- task performance: recent completed-task count, average/median duration, and average time to first token from the retained session-log window.
- usage forecast: a local, reset-cycle-aware usage-rate estimate. It starts as `learning`, then reports a projection only after it has enough persisted local samples.
- `process speed`: matching Codex/Code process count, CPU delta, and working-set memory.
- Graphs: rolling `tokens/min`, process CPU, use-speed/event cadence, and remaining available usage buckets.

## Accuracy Notes

The usage-limit values are not scraped from your account page. They are read from the local `event_msg` records Codex Desktop writes during active turns. If Codex has not emitted a fresh token-count event yet, those fields can show `n/a` or the last locally logged value.

For unusually large session logs, prompt-history and benchmark aggregates initialize from a bounded recent log tail so the dashboard stays responsive; current-session and current-turn telemetry remain live.

Usage forecasts are local estimates based only on Buddy's persisted usage-percent observations for the active reset cycle. They are not account billing data or an official Codex exhaustion prediction.

The speed numbers are local estimates from file growth, event cadence, and token deltas. They are useful for a quick on-screen pulse check, not billing-grade measurement.

If you want Spark to show separately, run one short Spark-only Codex call, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CodexBuddy.ps1 -DumpLimitEvents -DumpLimitEventCount 20
```

If the same `LimitId` shows up for Spark and non-Spark calls, then local session telemetry is not separated in this stream.

# Changelog

## v1.10 2026-07-22

### Current Codex telemetry

* Replaced the removed five hour assumption with the locally reported weekly usage bucket, reset time, credits metadata, and limit state.
* Added current task timing, first token time, modern custom tool activity, session source, Git identity, turn settings, message attachment counts, and compaction activity.

### Cost and performance insights

* Added cache efficiency with overall and last prompt cache hit percentages, uncached input, and cache write totals.
* Added recent task performance with completed task count, average duration, median duration, and average first token time.
* Added a local usage forecast that samples the active reset cycle and only projects exhaustion after it has enough observed local usage movement.

### Reliability and packaging

* Fixed mixed session logs that could leave the dashboard without data when a JSON value was not an object.
* Bounded prompt history startup parsing so large active logs do not freeze the dashboard.
* Updated the release wrapper and launcher to run PowerShell in STA mode.
* Added generated benchmark output to git ignore and refreshed the dashboard documentation.

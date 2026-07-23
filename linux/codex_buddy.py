#!/usr/bin/env python3
"""Codex Buddy's Linux dashboard.

The Linux Codex Desktop port writes the same local JSONL session stream as the
macOS and Windows clients. This module intentionally has no third-party
runtime dependency so it can run alongside that app on common distributions.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Iterable


LONG_CONTEXT_INPUT = 272_000
PRICING = {
    "gpt-5.6-sol": (5.0, 0.5, 6.25, 30.0, 10.0, 1.0, 12.5, 45.0),
    "gpt-5.6-terra": (2.5, 0.25, 3.125, 15.0, 5.0, 0.5, 6.25, 22.5),
    "gpt-5.6-luna": (1.0, 0.1, 1.25, 6.0, 2.0, 0.2, 2.5, 9.0),
    "gpt-5.5": (5.0, 0.5, None, 30.0, 10.0, 1.0, None, 45.0),
    "gpt-5.5-pro": (30.0, None, None, 180.0, 60.0, None, None, 270.0),
    "gpt-5.4": (2.5, 0.25, None, 15.0, 5.0, 0.5, None, 22.5),
    "gpt-5.4-mini": (0.75, 0.075, None, 4.5, None, None, None, None),
    "gpt-5.4-pro": (30.0, None, None, 180.0, 60.0, None, None, 270.0),
}


def value(obj: Any, name: str, default: Any = None) -> Any:
    return obj.get(name, default) if isinstance(obj, dict) else default


def number(value_: Any, default: float | None = None) -> float | None:
    try:
        return float(value_)
    except (TypeError, ValueError):
        return default


def timestamp(value_: Any) -> float | None:
    if value_ is None:
        return None
    try:
        if isinstance(value_, (int, float)):
            return float(value_)
        text = str(value_).replace("Z", "+00:00")
        return datetime.fromisoformat(text).timestamp()
    except (TypeError, ValueError, OverflowError):
        return None


def unix_timestamp(value_: Any) -> float | None:
    return number(value_)


def read_tail(path: pathlib.Path, line_count: int = 720) -> list[str]:
    """Read only the end of a growing JSONL file."""
    try:
        size = path.stat().st_size
        with path.open("rb") as handle:
            handle.seek(max(0, size - 1_048_576))
            data = handle.read()
        lines = data.decode("utf-8", errors="replace").splitlines()
        return lines[-line_count:]
    except (OSError, UnicodeError):
        return []


def read_first(path: pathlib.Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            first = handle.readline()
        parsed = json.loads(first)
        return parsed if isinstance(parsed, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def model_key(model: str | None) -> str:
    text = (model or "").strip().lower().replace("_", "-")
    for key in (
        "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna",
        "gpt-5.5-pro", "gpt-5.5", "gpt-5.4-mini", "gpt-5.4-pro", "gpt-5.4",
    ):
        if key in text:
            return key
    return ""


def short_model(model: str | None) -> str:
    if not model:
        return "unknown"
    if "spark" in model.lower():
        return "spark"
    key = model_key(model)
    labels = {
        "gpt-5.6-sol": "GPT-5.6 Sol", "gpt-5.6-terra": "GPT-5.6 Terra",
        "gpt-5.6-luna": "GPT-5.6 Luna", "gpt-5.5-pro": "GPT-5.5 Pro",
        "gpt-5.5": "GPT-5.5", "gpt-5.4-mini": "GPT-5.4 Mini",
        "gpt-5.4-pro": "GPT-5.4 Pro", "gpt-5.4": "GPT-5.4",
    }
    return labels.get(key, model)


def prompt_cost(usage: dict[str, Any], model: str | None) -> float:
    input_tokens = max(0.0, number(value(usage, "input_tokens"), 0.0) or 0.0)
    cached = min(input_tokens, max(0.0, number(value(usage, "cached_input_tokens"), 0.0) or 0.0))
    cache_write = max(0.0, number(value(usage, "cache_write_input_tokens"), 0.0) or 0.0)
    output = max(0.0, number(value(usage, "output_tokens"), 0.0) or 0.0)
    reasoning = min(output, max(0.0, number(value(usage, "reasoning_output_tokens"), 0.0) or 0.0))
    pricing = PRICING.get(model_key(model))
    long_rates = bool(pricing and input_tokens > LONG_CONTEXT_INPUT and pricing[4] is not None)
    if pricing:
        rates = pricing[4:] if long_rates else pricing[:4]
        input_rate, cached_rate, cache_write_rate, output_rate = rates
        input_rate = input_rate or 1.0
        cached_rate = cached_rate if cached_rate is not None else 0.1
        cache_write_rate = cache_write_rate if cache_write_rate is not None else input_rate
        output_rate = output_rate or 6.0
    else:
        input_rate, cached_rate, cache_write_rate, output_rate = 1.0, 0.1, 1.0, 6.0
    fresh_input = max(0.0, input_tokens - cached)
    visible_output = max(0.0, output - reasoning)
    return round(
        fresh_input * input_rate + cached * cached_rate +
        cache_write * cache_write_rate + visible_output * output_rate +
        reasoning * output_rate,
        1,
    )


def format_count(value_: Any) -> str:
    amount = number(value_)
    if amount is None:
        return "n/a"
    if abs(amount) >= 1_000_000:
        return f"{amount / 1_000_000:.1f}m"
    if abs(amount) >= 1_000:
        return f"{amount / 1_000:.1f}k"
    return f"{amount:.0f}"


def format_percent(value_: Any) -> str:
    amount = number(value_)
    return "n/a" if amount is None else f"{amount:.1f}%"


def format_age(seconds: float | None) -> str:
    if seconds is None or seconds < 0:
        return "n/a"
    if seconds < 60:
        return f"{seconds:.0f}s ago"
    if seconds < 3600:
        return f"{seconds / 60:.0f}m ago"
    return f"{seconds / 3600:.1f}h ago"


def format_window(minutes: Any) -> str:
    amount = number(minutes)
    if amount is None:
        return "usage"
    if amount >= 10_080:
        return "week"
    if amount >= 1_440:
        return f"{amount / 1_440:.0f}d"
    if amount >= 60:
        return f"{amount / 60:.0f}h"
    return f"{amount:.0f}m"


def limit_text(limit: dict[str, Any] | None) -> str:
    if not isinstance(limit, dict):
        return "n/a"
    used = number(value(limit, "used_percent"))
    if used is None:
        return "n/a"
    remaining = max(0.0, 100.0 - used)
    return f"{remaining:.1f}% left ({format_window(value(limit, 'window_minutes'))})"


@dataclass
class Session:
    path: str
    session_id: str = "unknown"
    cwd: str = "unknown"
    active_model: str = "unknown"
    status: str = "idle"
    last_write: float = 0.0
    total_tokens: float | None = None
    last_tokens: float | None = None
    last_input_tokens: float | None = None
    last_output_tokens: float | None = None
    input_tokens: float | None = None
    output_tokens: float | None = None
    reasoning_tokens: float | None = None
    cached_tokens: float | None = None
    cache_write_tokens: float | None = None
    context_window: float | None = None
    context_percent: float | None = None
    primary_limit: dict[str, Any] | None = None
    secondary_limit: dict[str, Any] | None = None
    plan_type: str = "unknown"
    limit_id: str = "codex"
    service_tier: str | None = None
    events: int = 0
    token_events_last_minute: int = 0
    tool_calls: int = 0
    tool_outputs: int = 0
    tool_names: dict[str, int] = field(default_factory=dict)
    last_tool: str | None = None
    last_event_type: str | None = None
    user_messages: int = 0
    assistant_messages: int = 0
    last_prompt_text: str | None = None
    last_task_duration_ms: float | None = None
    last_task_ttft_ms: float | None = None
    task_count: int = 0
    tokens_per_second: float = 0.0
    output_tokens_per_second: float = 0.0
    prompt_cost_units: float = 0.0
    last_prompt_cost_units: float | None = None
    prompt_count: int = 0
    prompt_rows: list[dict[str, Any]] = field(default_factory=list)

    @property
    def age(self) -> float:
        return max(0.0, time.time() - self.last_write)

    @property
    def cost_warning(self) -> str | None:
        if self.last_input_tokens is None:
            return None
        if self.last_input_tokens >= LONG_CONTEXT_INPUT:
            return "HIGH COST: start a new chat"
        if self.last_input_tokens >= 230_000:
            return "LONG CHAT: cost is rising"
        if self.last_input_tokens >= 200_000:
            return "LONG CHAT: keep an eye on context"
        return None


class CodexTelemetry:
    def __init__(self, codex_home: pathlib.Path | None = None) -> None:
        self.codex_home = codex_home or pathlib.Path(os.environ.get("CODEX_HOME", pathlib.Path.home() / ".codex"))
        self.session_root = self.codex_home / "sessions"

    def session_files(self, days: int = 14) -> list[pathlib.Path]:
        if not self.session_root.is_dir():
            return []
        cutoff = time.time() - days * 86_400
        files: list[pathlib.Path] = []
        try:
            for path in self.session_root.rglob("*.jsonl"):
                try:
                    if path.stat().st_mtime >= cutoff:
                        files.append(path)
                except OSError:
                    continue
        except OSError:
            return []
        return sorted(files, key=lambda item: item.stat().st_mtime, reverse=True)

    def parse_session(self, path: pathlib.Path) -> Session:
        stat = path.stat()
        meta = read_first(path)
        meta_payload = value(meta, "payload", {})
        session = Session(
            path=str(path),
            session_id=str(value(meta_payload, "id", value(meta_payload, "session_id", "unknown"))),
            cwd=str(value(meta_payload, "cwd", "unknown")),
            last_write=stat.st_mtime,
        )
        active_model = value(meta_payload, "model")
        prompt_rows: dict[str, dict[str, Any]] = {}
        prompt_key = "session-start"
        prompt_order = {prompt_key: 0}
        output_points: list[tuple[float, float]] = []
        last_event_time = stat.st_mtime

        for raw in read_tail(path):
            try:
                entry = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if not isinstance(entry, dict):
                continue
            session.events += 1
            entry_type = value(entry, "type")
            payload = value(entry, "payload", {})
            payload_type = value(payload, "type")
            entry_time = timestamp(value(entry, "timestamp")) or stat.st_mtime
            last_event_time = max(last_event_time, entry_time)
            session.last_event_type = payload_type or entry_type

            tier = value(payload, "service_tier", value(payload, "serviceTier"))
            if tier:
                session.service_tier = str(tier)

            if entry_type == "turn_context":
                if value(payload, "model"):
                    active_model = str(value(payload, "model"))
                if value(payload, "service_tier", value(payload, "serviceTier")):
                    session.service_tier = str(value(payload, "service_tier", value(payload, "serviceTier")))

            if entry_type == "event_msg" and payload_type == "task_complete":
                session.last_task_duration_ms = number(value(payload, "duration_ms"))
                session.last_task_ttft_ms = number(value(payload, "time_to_first_token_ms"))
                if session.last_task_duration_ms is not None:
                    session.task_count += 1
            elif entry_type == "event_msg" and payload_type == "user_message":
                text = value(payload, "message")
                if text:
                    session.last_prompt_text = str(text)
            elif entry_type == "event_msg" and payload_type == "token_count":
                session.token_events_last_minute += int(entry_time >= time.time() - 60)
                info = value(payload, "info", {})
                usage = value(info, "total_token_usage", {})
                last_usage = value(info, "last_token_usage", {})
                if value(usage, "total_tokens") is None or value(last_usage, "total_tokens") is None:
                    continue
                session.total_tokens = number(value(usage, "total_tokens"))
                session.input_tokens = number(value(usage, "input_tokens"))
                session.output_tokens = number(value(usage, "output_tokens"))
                session.reasoning_tokens = number(value(usage, "reasoning_output_tokens"))
                session.cached_tokens = number(value(usage, "cached_input_tokens"))
                session.cache_write_tokens = number(value(usage, "cache_write_input_tokens"))
                session.last_tokens = number(value(last_usage, "total_tokens"))
                session.last_input_tokens = number(value(last_usage, "input_tokens"))
                session.last_output_tokens = number(value(last_usage, "output_tokens"))
                session.context_window = number(value(info, "model_context_window"))
                if session.last_input_tokens is not None and session.context_window:
                    session.context_percent = round(session.last_input_tokens / session.context_window * 100, 1)
                limits = value(payload, "rate_limits", {})
                session.primary_limit = value(limits, "primary")
                session.secondary_limit = value(limits, "secondary")
                session.plan_type = str(value(limits, "plan_type", session.plan_type))
                session.limit_id = str(value(limits, "limit_id", session.limit_id))
                current = prompt_rows.setdefault(prompt_key, {"order": prompt_order.get(prompt_key, entry_time)})
                current.update({
                    "model": active_model or "unknown",
                    "input": session.last_input_tokens,
                    "output": session.last_output_tokens,
                    "total": session.last_tokens,
                    "cost": prompt_cost(last_usage, active_model),
                })
                session.last_prompt_cost_units = current["cost"]
                session.prompt_cost_units = sum(number(row.get("cost"), 0.0) or 0.0 for row in prompt_rows.values())
                total_output = number(value(usage, "output_tokens"))
                if total_output is not None:
                    output_points.append((entry_time, total_output))

            if entry_type == "response_item":
                response_type = value(payload, "type")
                if response_type in {"function_call", "custom_tool_call"}:
                    session.tool_calls += 1
                    tool = value(payload, "name")
                    if tool:
                        session.last_tool = str(tool)
                        session.tool_names[session.last_tool] = session.tool_names.get(session.last_tool, 0) + 1
                elif response_type in {"function_call_output", "custom_tool_call_output"}:
                    session.tool_outputs += 1
                elif response_type == "message":
                    role = value(payload, "role")
                    if role == "assistant":
                        session.assistant_messages += 1
                    elif role == "user":
                        session.user_messages += 1
                        prompt_key = f"prompt-{session.user_messages}-{entry_time:.6f}"
                        prompt_order[prompt_key] = entry_time

        session.active_model = str(active_model or "unknown")
        session.last_write = max(stat.st_mtime, last_event_time)
        session.status = "active" if session.age < 20 else "warm" if session.age < 300 else "idle"
        if len(output_points) >= 2:
            start_time, start_output = output_points[0]
            end_time, end_output = output_points[-1]
            if end_time > start_time:
                session.output_tokens_per_second = max(0.0, end_output - start_output) / (end_time - start_time)
                session.tokens_per_second = session.output_tokens_per_second
        session.prompt_rows = sorted(
            ({**row, "key": key} for key, row in prompt_rows.items() if "total" in row),
            key=lambda row: number(row.get("order"), 0.0) or 0.0,
            reverse=True,
        )[:5]
        session.prompt_count = len(prompt_rows)
        return session

    def snapshot(self) -> dict[str, Any]:
        files = self.session_files()
        sessions: list[Session] = []
        for path in files[:12]:
            try:
                session = self.parse_session(path)
            except OSError:
                continue
            if session.status != "idle" or not sessions:
                sessions.append(session)
        latest = sessions[0] if sessions else None
        return {
            "session": latest,
            "sessions": sessions,
            "active_count": sum(session.status == "active" for session in sessions),
            "warm_count": sum(session.status == "warm" for session in sessions),
            "process": process_metrics(),
        }


def process_metrics() -> dict[str, Any]:
    """Return best-effort Codex process data without psutil."""
    count = 0
    memory_kb = 0
    cpu_ticks = 0
    for proc in pathlib.Path("/proc").glob("[0-9]*"):
        try:
            command = (proc / "cmdline").read_bytes().replace(b"\0", b" ").decode(errors="ignore").lower()
            name = (proc / "comm").read_text(errors="ignore").lower()
            if "codex" not in command and "codex" not in name:
                continue
            count += 1
            status = (proc / "status").read_text(errors="ignore")
            for line in status.splitlines():
                if line.startswith("VmRSS:"):
                    memory_kb += int(line.split()[1])
                    break
            fields = (proc / "stat").read_text(errors="ignore").split()
            if len(fields) > 15:
                cpu_ticks += int(fields[13]) + int(fields[14])
        except (OSError, ValueError, UnicodeError):
            continue
    return {"count": count, "memory_mb": round(memory_kb / 1024, 1), "cpu_percent": None, "cpu_ticks": cpu_ticks}


def json_snapshot(snapshot: dict[str, Any]) -> dict[str, Any]:
    session = snapshot["session"]
    return {
        "active_count": snapshot["active_count"],
        "warm_count": snapshot["warm_count"],
        "process": snapshot["process"],
        "session": None if session is None else {
            "path": session.path, "status": session.status, "model": session.active_model,
            "cwd": session.cwd, "total_tokens": session.total_tokens,
            "last_tokens": session.last_tokens, "last_input_tokens": session.last_input_tokens,
            "last_output_tokens": session.last_output_tokens, "context_percent": session.context_percent,
            "primary_limit": session.primary_limit, "secondary_limit": session.secondary_limit,
            "tool_calls": session.tool_calls, "prompt_cost_units": session.prompt_cost_units,
            "last_prompt_cost_units": session.last_prompt_cost_units,
        },
    }


def run_gui(telemetry: CodexTelemetry, refresh_ms: int) -> None:
    """Render the compact dark dashboard used by the Windows edition."""
    import tkinter as tk

    BG = "#0f1218"
    CARD = "#191e27"
    GRAPH = "#0d1016"
    BORDER = "#28303e"
    TEXT = "#eff2f7"
    MUTED = "#97a3b5"
    ACCENT = "#75e0a7"
    BLUE = "#66aaff"
    AMBER = "#ffc75f"
    CORAL = "#f28482"
    BUTTON = "#1c222c"
    BUTTON_ACTIVE = "#27313f"
    IDLE_BG = "#1f2834"
    ACTIVE_BG = "#1b2d27"
    WARM_BG = "#31261a"
    FONT = ("Sans", 9)
    SMALL = ("Sans", 8)
    SECTION = ("Sans", 9, "bold")
    VALUE = ("Monospace", 9, "bold")
    TITLE = ("Sans", 12, "bold")

    root = tk.Tk()
    root.title("Codex Buddy | Linux")
    root.configure(bg=BG)
    root.attributes("-topmost", True)
    try:
        root.overrideredirect(True)
    except tk.TclError:
        pass

    screen_height = root.winfo_screenheight()
    window_height = min(812, max(600, screen_height - 70))
    root.geometry(f"332x{window_height}")
    root.update_idletasks()
    root.geometry(f"332x{window_height}+{max(0, root.winfo_screenwidth() - 356)}+48")

    def close() -> None:
        root.destroy()

    drag_start: dict[str, int] = {}

    def begin_drag(event: tk.Event) -> None:
        drag_start["x"] = event.x_root - root.winfo_x()
        drag_start["y"] = event.y_root - root.winfo_y()

    def drag(event: tk.Event) -> None:
        if drag_start:
            root.geometry(f"+{event.x_root - drag_start['x']}+{event.y_root - drag_start['y']}")

    header = tk.Frame(root, bg=BG, height=44)
    header.pack(fill="x", padx=12)
    header.pack_propagate(False)
    header.bind("<Button-1>", begin_drag)
    header.bind("<B1-Motion>", drag)

    title = tk.Label(header, text="Codex Buddy", bg=BG, fg=TEXT, font=TITLE, anchor="w")
    title.pack(side="left", padx=(6, 0), pady=9)
    title.bind("<Button-1>", begin_drag)
    title.bind("<B1-Motion>", drag)

    status = tk.Label(header, text="WAITING", bg=IDLE_BG, fg=MUTED, font=SMALL, padx=8, pady=3)
    status.pack(side="left", padx=(12, 4), pady=10)

    button_style = {
        "bg": BUTTON,
        "fg": TEXT,
        "activebackground": BUTTON_ACTIVE,
        "activeforeground": TEXT,
        "relief": "flat",
        "bd": 0,
        "highlightthickness": 1,
        "highlightbackground": BORDER,
        "font": SMALL,
        "cursor": "hand2",
    }
    refresh_button = tk.Button(header, text="Refresh", command=lambda: refresh(), **button_style)
    refresh_button.pack(side="right", padx=(4, 0), pady=9)
    close_button = tk.Button(header, text="X", command=close, width=2, **button_style)
    close_button.pack(side="right", pady=9)

    content = tk.Frame(root, bg=BG)
    content.pack(fill="both", expand=True, padx=12, pady=(0, 8))

    def make_card(parent: tk.Misc, heading: str, color: str, height: int) -> tk.Frame:
        card = tk.Frame(parent, bg=CARD, height=height, highlightbackground=BORDER, highlightthickness=1)
        card.pack(fill="x", pady=(0, 10))
        card.pack_propagate(False)
        tk.Label(card, text=heading, bg=CARD, fg=color, font=SECTION, anchor="w").pack(
            fill="x", padx=10, pady=(9, 5)
        )
        return card

    def make_row(parent: tk.Frame, label_text: str, row: int, color: str = TEXT) -> tk.Label:
        tk.Label(parent, text=label_text, bg=CARD, fg=MUTED, font=FONT, width=12, anchor="w").grid(
            row=row, column=0, sticky="w", padx=(10, 2), pady=2
        )
        value_label = tk.Label(parent, text="n/a", bg=CARD, fg=color, font=VALUE, anchor="w")
        value_label.grid(row=row, column=1, sticky="w", padx=2, pady=2)
        return value_label

    def make_bar(parent: tk.Frame, row: int, color: str) -> tk.Canvas:
        bar = tk.Canvas(parent, width=278, height=7, bg=GRAPH, bd=0, highlightthickness=0)
        bar.grid(row=row, column=0, columnspan=2, sticky="ew", padx=10, pady=(0, 4))
        bar._fill_color = color  # type: ignore[attr-defined]
        return bar

    def set_bar(bar: tk.Canvas, percent: float | None, color: str | None = None) -> None:
        bar.delete("all")
        amount = max(0.0, min(100.0, number(percent, 0.0) or 0.0))
        bar.create_rectangle(0, 0, 278 * amount / 100, 7, fill=color or bar._fill_color, outline="")  # type: ignore[attr-defined]

    now_card = make_card(content, "Now", ACCENT, 218)
    now_grid = tk.Frame(now_card, bg=CARD)
    now_grid.pack(fill="x")
    verdict_value = make_row(now_grid, "Verdict", 0, ACCENT)
    session_use_value = make_row(now_grid, "Session Use", 1)
    speed_value = make_row(now_grid, "Speed", 2)
    tools_value = make_row(now_grid, "Tools", 3)
    system_value = make_row(now_grid, "System", 4)
    last_tool_value = make_row(now_grid, "Last Tool", 5)
    warning_value = tk.Label(now_card, text="", bg=CARD, fg=CORAL, font=SMALL, anchor="w", wraplength=286)
    warning_value.pack(fill="x", padx=10, pady=(5, 0))

    cost_card = make_card(content, "Cost & Limits", BLUE, 334)
    cost_grid = tk.Frame(cost_card, bg=CARD)
    cost_grid.pack(fill="x")
    last_ask_value = make_row(cost_grid, "Last Ask", 0)
    chat_cost_value = make_row(cost_grid, "Chat Cost", 1)
    long_chat_value = make_row(cost_grid, "Long Chat", 2, AMBER)
    context_value = make_row(cost_grid, "Context", 3)
    context_bar = make_bar(cost_grid, 4, BLUE)
    primary_value = make_row(cost_grid, "Primary Limit", 5)
    primary_bar = make_bar(cost_grid, 6, ACCENT)
    secondary_value = make_row(cost_grid, "Week Limit", 7)
    secondary_bar = make_bar(cost_grid, 8, BLUE)
    cost_hint = tk.Label(cost_card, text="", bg=CARD, fg=MUTED, font=SMALL, anchor="w", wraplength=286)
    cost_hint.pack(fill="x", padx=10, pady=(3, 0))

    session_card = make_card(content, "Session", CORAL, 104)
    session_value = tk.Label(session_card, text="waiting", bg=CARD, fg=TEXT, font=VALUE, anchor="w")
    session_value.pack(fill="x", padx=10, pady=(0, 3))
    prompt_value = tk.Label(
        session_card, text="", bg=CARD, fg=MUTED, font=SMALL, anchor="w", wraplength=286, justify="left"
    )
    prompt_value.pack(fill="x", padx=10)

    footer = tk.Label(root, text="Reading local telemetry only | Esc closes", bg=BG, fg=MUTED, font=SMALL, anchor="w")
    footer.pack(fill="x", padx=18, pady=(0, 9))

    def refresh() -> None:
        try:
            snapshot = telemetry.snapshot()
            session = snapshot["session"]
            proc = snapshot["process"]
            if session is None:
                status.configure(text="WAITING", bg=IDLE_BG, fg=MUTED)
                verdict_value.configure(text="Waiting for Codex", fg=AMBER)
                session_use_value.configure(text="n/a")
                speed_value.configure(text="n/a")
                tools_value.configure(text="n/a")
                system_value.configure(text="n/a")
                last_tool_value.configure(text="n/a")
                warning_value.configure(text=f"No session data under {telemetry.session_root}")
                session_value.configure(text="Start Codex Desktop and send a prompt")
                prompt_value.configure(text="")
                for label in (last_ask_value, chat_cost_value, long_chat_value, context_value, primary_value, secondary_value):
                    label.configure(text="n/a")
                cost_hint.configure(text="Linux telemetry is ready. The dashboard will update automatically.")
                set_bar(context_bar, 0)
                set_bar(primary_bar, 0)
                set_bar(secondary_bar, 0)
            else:
                status_color = ACCENT if session.status == "active" else AMBER if session.status == "warm" else MUTED
                status_bg = ACTIVE_BG if session.status == "active" else WARM_BG if session.status == "warm" else IDLE_BG
                status.configure(text=session.status.upper(), bg=status_bg, fg=status_color)
                verdict = session.cost_warning or {
                    "active": "Tracking live", "warm": "Warm session", "idle": "No recent activity"
                }.get(session.status, "Ready")
                verdict_value.configure(text=verdict, fg=CORAL if session.cost_warning else status_color)
                session_use_value.configure(
                    text=f"{format_count(session.last_prompt_cost_units)} last | {format_count(session.prompt_cost_units)} chat"
                )
                speed_value.configure(text=f"{session.tokens_per_second:.1f} output tok/s")
                tools_value.configure(text=f"{session.tool_calls} calls | {session.tool_outputs} outputs")
                system_value.configure(text=f"{proc['count']} process(es) | {proc['memory_mb']:.1f} MB")
                last_tool_value.configure(text=session.last_tool or "n/a")
                warning_value.configure(text=session.cost_warning or "")
                last_ask_value.configure(text=f"{format_count(session.last_prompt_cost_units)} cost units")
                chat_cost_value.configure(text=f"{format_count(session.prompt_cost_units)} | {session.prompt_count} prompts")
                long_chat_value.configure(text=f"{format_count(session.last_input_tokens)} input tokens")
                context_value.configure(text=format_percent(session.context_percent))
                primary_value.configure(text=limit_text(session.primary_limit))
                secondary_value.configure(text=limit_text(session.secondary_limit))
                set_bar(context_bar, session.context_percent, BLUE)
                primary_used = number(value(session.primary_limit, "used_percent")) if session.primary_limit else 0
                secondary_used = number(value(session.secondary_limit, "used_percent")) if session.secondary_limit else 0
                set_bar(primary_bar, 100 - (primary_used or 0), ACCENT)
                set_bar(secondary_bar, 100 - (secondary_used or 0), BLUE)
                project = pathlib.Path(session.cwd).name if session.cwd not in {"", "unknown"} else "unknown project"
                session_value.configure(text=f"{project} | {short_model(session.active_model)} | {format_age(session.age)}")
                prompt_text = str(session.last_prompt_text or "Waiting for a user message").replace("\n", " ")
                prompt_value.configure(text=f"Last prompt: {prompt_text[:220]}")
                cost_hint.configure(text=f"{snapshot['active_count']} active | {snapshot['warm_count']} warm | {session.last_event_type or 'waiting'}")
        except Exception as exc:  # keep the dashboard alive through a rotating log
            status.configure(text="ERROR", bg=WARM_BG, fg=CORAL)
            verdict_value.configure(text="Refresh failed", fg=CORAL)
            warning_value.configure(text=str(exc))
        root.after(refresh_ms, refresh)

    root.protocol("WM_DELETE_WINDOW", close)
    root.bind("<Escape>", lambda _event: close())
    refresh()
    root.mainloop()


def main() -> int:
    parser = argparse.ArgumentParser(description="Codex Buddy Linux dashboard")
    parser.add_argument("--codex-home", type=pathlib.Path, help="Codex data directory (default: ~/.codex)")
    parser.add_argument("--refresh-seconds", type=float, default=1.0)
    parser.add_argument("--once", action="store_true", help="Print one JSON snapshot and exit")
    args = parser.parse_args()
    telemetry = CodexTelemetry(args.codex_home)
    snapshot = telemetry.snapshot()
    if args.once:
        print(json.dumps(json_snapshot(snapshot), indent=2))
        return 0
    try:
        run_gui(telemetry, max(250, int(args.refresh_seconds * 1000)))
    except ImportError:
        print("Codex Buddy needs Tkinter. Install python3-tk, python3-tkinter, or tk for your distribution.", file=os.sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

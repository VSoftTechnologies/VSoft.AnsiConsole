---
title: Rule
description: A horizontal divider line, optionally with an inline title.
---

# Rule

`IRule` renders a single-cell-tall horizontal line that fills its container's
width. It can carry an inline title - `─────── Section ───────` - and use
any of four glyph sets.

## When to use

- Visually separating sections of console output.
- Section headers in long-running scripts.
- Anywhere you'd reach for `WriteLine('---')`.

## Basic usage

```pascal
AnsiConsole.Write(Widgets.Rule);                    // empty rule
AnsiConsole.Write(Widgets.Rule('Section'));         // titled
AnsiConsole.WriteLine;
```

The empty form fills with `─` (or `-` in non-unicode terminals); the titled
form centres the title between left/right border runs by default.

## Configuration

Fluent setters return a copy:

| Method | Purpose |
| --- | --- |
| `WithTitle(value)` | Set or change the inline title. Markup is supported (`'[bold]Section[/]'`); write a literal bracket as `[[` / `]]`. |
| `WithAlignment(value)` | Where the title sits — `TAlignment.Left` / `Center` / `Right`. Default `Center`. |
| `WithBorder(value)` | Glyph set — `TRuleBorder.Default` (light), `Ascii`, `Heavy`, `Double`. |
| `WithStyle(value)` | Style applied to the border characters AND the title text. |

```pascal
AnsiConsole.Write(
  Widgets.Rule('Heavy heading')
    .WithBorder(TRuleBorder.Heavy)
    .WithAlignment(TAlignment.Left)
    .WithStyle(TAnsiStyle.Plain.WithForeground(TAnsiColor.Aqua)));
```

## Glyph sets

| Kind | Unicode | ASCII fallback |
| --- | --- | --- |
| `Default` | `─` | `-` |
| `Ascii` | `-` | `-` |
| `Heavy` | `━` | `-` |
| `Double` | `═` | `-` |

`Ascii` is forced regardless of terminal capability; the others fall back
to `-` when the terminal can't render unicode.

## API reference

- [`Widgets.Rule()`](https://github.com/VSoftTechnologies/VSoft.AnsiConsole/blob/main/source/VSoft.AnsiConsole.pas) — empty rule.
- [`Widgets.Rule(title)`](https://github.com/VSoftTechnologies/VSoft.AnsiConsole/blob/main/source/VSoft.AnsiConsole.pas) — titled rule.
- [`IRule`](https://github.com/VSoftTechnologies/VSoft.AnsiConsole/blob/main/source/Widgets/VSoft.AnsiConsole.Widgets.Rule.pas) — full interface.

## See also

- [Panel](./panel.md) — for an outright bordered region with a header.
- [Markup](./markup.md) — markup tags inside the title text.

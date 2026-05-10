<!-- omit in toc -->
# VSoft.AnsiConsole

[![Delphi: XE3+](https://img.shields.io/badge/Delphi-XE3%2B-red.svg)](https://www.embarcadero.com/products/delphi)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-blue.svg)](#compatibility)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

A Delphi library for writing **rich, interactive console applications**. Tables,
trees, live progress, prompts, syntax-coloured exceptions, ANSI colour, hyperlinks,
emoji, FIGlet text, calendars, charts, recorder + HTML export — composable widgets
that render through a unified pipeline.


![Hero screenshot|480x498](/images/readme-demo.png)

<!-- screenshot: full ReadmeDemo run in Windows Terminal -->

> **Full documentation lives under [`here`](https://vsofttechnologies.github.io/VSoft.AnsiConsole/)** —
> [Quick start](https://vsofttechnologies.github.io/VSoft.AnsiConsole/getting-started/quick-start) ·
> [Architecture](https://vsofttechnologies.github.io/VSoft.AnsiConsole/getting-started/architecture) ·
> [Widgets](https://vsofttechnologies.github.io/VSoft.AnsiConsole/widgets/markup) ·
> [Live displays](https://vsofttechnologies.github.io/VSoft.AnsiConsole/live/status) ·
> [Prompts](https://vsofttechnologies.github.io/VSoft.AnsiConsole/prompts/text-prompt) ·
> [Recorder](https://vsofttechnologies.github.io/VSoft.AnsiConsole/recording/recorder) ·
> [Reference](https://vsofttechnologies.github.io/VSoft.AnsiConsole/reference/markup-syntax)


## Features

- **24-bit / 256 / 16 colour** with automatic downsampling per terminal capability
- **BBCode-style markup** — `[bold red on yellow]hi[/]`, nestable tags
- **Widgets**: Text, Markup, Paragraph, Rule, Panel, Padder, Align, Rows, Columns,
  Grid, Layout, Table, Tree, Calendar, BarChart, BreakdownChart, Canvas, Figlet,
  JsonText, ExceptionWidget
- **Live displays**: Status (spinners) and Progress (multi-task) with auto-refresh
- **Prompts**: TextPrompt, ConfirmationPrompt, SelectionPrompt&lt;T&gt; and
  MultiSelectionPrompt&lt;T&gt; — with search-as-you-type, hierarchical
  parent/child choices, validation, default values, and cancel handling
- **Recorder** — capture rendered output and re-emit as plain text or styled HTML
- **Hyperlinks** (OSC 8), window title, alternate screen buffer
- **Emoji** — 1500+ named shortcodes (`:thumbs_up:`, `:rocket:`)
- **CI-aware** — built-in profile enrichers detect GitHub Actions, AppVeyor,
  Travis, GitLab CI, Jenkins, TeamCity, Bitbucket Pipelines, Continua CI and disable
  interactive features automatically
- **500+ DUnitX tests** covering markup parsing, segment ops, ANSI emission,
  every widget renderer, prompts, live display, profile detection

## Dependencies

VSoft.AnsiConsole keeps its dependency footprint small. 

### Runtime

| Package                                                                                       | Version | Purpose                                                                                       |
|-----------------------------------------------------------------------------------------------|---------|-----------------------------------------------------------------------------------------------|
| [`VSoft.System.Console`](https://github.com/VSoftTechnologies/VSoft.System.Console)           | 1.2.0+  | Low-level primitives: keyboard input (`TConsoleKey`/`TConsoleKeyInfo`), terminal dimensions, raw write helpers. Used by prompts and live displays. |

### Test-only

| Package                                                                                       | Version | Purpose                                                                                       |
|-----------------------------------------------------------------------------------------------|---------|-----------------------------------------------------------------------------------------------|
| [`VSoft.DUnitX`](https://github.com/VSoftTechnologies/DUnitX)                                  | 0.4.5+  | Test framework for the 500+ unit tests in `tests\`. Not required to consume the library.     |

## Installation

Clone this repo and add the Source folders to your project's unit search path. You could also build the package file for your compiler version and reference the dcu output folder to avoid building the source every time.

The library has a single
dependency: [`VSoft.System.Console`](https://github.com/VSoftTechnologies/VSoft.System.Console).

## Quick start

```pascal
program Hello;

{$APPTYPE CONSOLE}

uses
  VSoft.AnsiConsole;

begin
  AnsiConsole.MarkupLine('[bold yellow]Hello[/] [italic]world[/]!');
  AnsiConsole.MarkupLine(
    'Numbers: [red]1[/], [green]2[/], [blue]3[/] :rocket:');
end.
```

The static `AnsiConsole` facade lazily constructs a singleton `IAnsiConsole`
on first use, with capabilities auto-detected from the host terminal. For
testing or redirected output you can build your own `IAnsiConsole` via
`CreateAnsiConsole(...)` or `CreateAnsiConsoleFromSettings(...)`.

## Showcase

### Markup & colour

```pascal
AnsiConsole.MarkupLine('[bold red on yellow]Important[/] message');
AnsiConsole.MarkupLine('Link: [link=https://example.com]click here[/]');
AnsiConsole.MarkupLine('[#ff8800]Custom hex colour[/]');
```

![Markup screenshot](/images/markup.png)

<!-- screenshot: each MarkupLine on its own row -->

### Tables

```pascal
var
  t : ITable;
begin
  t := Widgets.Table.WithBorder(TTableBorderKind.Rounded);
  t.AddColumn('[bold]Name[/]', TAlignment.Left);
  t.AddColumn('[bold]Score[/]', TAlignment.Right);
  t.AddRow(['Alice', '128']);
  t.AddRow(['Bob',   ' 96']);
  t.AddRow(['Carol', '142']);
  AnsiConsole.Write(t);
end;
```

![Table screenshot](/images/table.png)

<!-- screenshot: rounded-border 2-column 3-row table -->

### Trees

```pascal
var
  t       : ITree;
  src     : ITreeNode;
begin
  t := Widgets.Tree('[bold]Project[/]');
  src := t.AddNode('source');
  src.AddNode('VSoft.AnsiConsole.Color.pas');
  src.AddNode('VSoft.AnsiConsole.Style.pas');
  t.AddNode('tests');
  AnsiConsole.Write(t);
end;
```

![Tree screenshot](/images/tree.png)

<!-- screenshot: tree with src/tests showing fork+last glyphs -->

### Panels & rules

```pascal
AnsiConsole.Write(Widgets.Rule('Section'));
AnsiConsole.Write(
  Widgets.Panel(Widgets.Markup('[bold]hello[/] world'))
    .WithHeader('Greeting')
    .WithBorder(TBoxBorderKind.Rounded));
```

![Panel + rule screenshot](/images/panel.png)

<!-- screenshot: rule then rounded panel underneath -->

### Progress

```pascal
AnsiConsole.Progress.Start(
  procedure(const ctx : IProgressContext)
  var
    download : IProgressTask;
    process  : IProgressTask;
  begin
    download := ctx.AddTask('Downloading', 100);
    process  := ctx.AddTask('Processing',  100);
    while not (download.IsFinished and process.IsFinished) do
    begin
      if not download.IsFinished then download.Increment(2);
      if download.PercentComplete > 30 then process.Increment(1);
      Sleep(60);
    end;
  end);
```

![Progress screenshot](/images/progress.png)

<!-- screenshot: two progress bars mid-flight, second slightly behind -->

### Status spinner

```pascal
AnsiConsole.Status.Start('[yellow]Connecting...[/]',
  procedure(const ctx : IStatus)
  begin
    Sleep(1500);
    ctx.SetStatus('[green]Authenticated.[/] Fetching data...');
    Sleep(1500);
  end);
```

![Status screenshot|774x34](/images/status.gif)

<!-- screenshot: spinner + message, mid-rotation -->

### Prompts

```pascal
var
  name    : string;
  proceed : Boolean;
  theme   : string;
begin
  name    := AnsiConsole.Ask('[bold]Name[/]', 'World');
  proceed := AnsiConsole.Confirm('Proceed?', True);

  theme := AnsiConsole.SelectionPrompt<string>
             .WithTitle('Pick a theme')
             .AddChoice('light', 'Light')
             .AddChoice('dark',  'Dark')
             .AddChoice('hc',    'High contrast')
             .Show(AnsiConsole.Console);
end;
```

![Prompts screenshot](/images/prompt.png)

<!-- screenshot: text prompt, confirm, then selection list with one row highlighted -->

### Hierarchical selection

`AddChoiceHierarchy` returns an `ISelectionItem<T>` you can `.AddChild()` on,
nesting arbitrarily deep. Default mode is `TSelectionMode.Leaf` (Spectre default): `Enter`
on a parent toggles expansion; only leaves are returned.

```pascal
var
  picker   : ISelectionPrompt<string>;
  americas,
  asia,
  oceania : ISelectionItem<string>;
  region         : string;
begin
  picker := AnsiConsole.SelectionPrompt<string>
              .WithTitle('[yellow]Pick a region[/] [grey50](Enter to expand)[/]');

  oceania := picker.AddChoiceHierarchy('Oceania', '[bold]Oceania[/]');
  oceania.AddChild('au', 'Australia');
  oceania.AddChild('nz', 'New Zealand');
  oceania.AddChild('fi', 'Fiji');
  oceania.IsExpanded := True; // pre-open this branch

  americas := picker.AddChoiceHierarchy('Americas', '[bold]Americas[/]');
  americas.AddChild('us', 'United States');
  americas.AddChild('ca', 'Canada');
  americas.AddChild('br', 'Brazil');
  americas.IsExpanded := false;

  asia := picker.AddChoiceHierarchy('Asia', '[bold]Asia[/]');
  asia.AddChild('cn', 'China');
  asia.AddChild('jp', 'Japan');
  asia.AddChild('kr', 'South Korea');
  asia.IsExpanded := false;

  region := picker.Show(AnsiConsole.Console);
end;
```

![Hierarchical selection screenshot](/images/hierarchy.png)

<!-- screenshot: list with one parent collapsed, one expanded showing leaves -->

### Calendar

```pascal
AnsiConsole.Write(
  Widgets.Calendar(2026, 4, 25)
    .WithCulture('en-GB'));
```

![Calendar screenshot](/images/calendar.png)

<!-- screenshot: april 2026 calendar with 25 highlighted -->

### Bar & breakdown charts

```pascal
chart := Widgets.BarChart.WithLabel('[bold]Languages[/]');
chart.AddItem('Pascal', 80, TAnsiColor.Aqua);
chart.AddItem('Go',     45, TAnsiColor.Lime);
chart.AddItem('Rust',   60, TAnsiColor.Red);
chart.WithWidth(40);
AnsiConsole.Write(chart);
```

![BarChart screenshot](/images/barchart.png)

<!-- screenshot: 3-row bar chart with values to the right -->

```pascal
brk := Widgets.BreakdownChart;
brk.AddItem('Elixir', 35, TAnsiColor.Magenta);
brk.AddItem('Delphi',     27, TAnsiColor.Aqua);
brk.AddItem('Ruby',   15, TAnsiColor.Red);
brk.WithWidth(50);
AnsiConsole.Write(brk);
```

![BreakdownChart screenshot](/images/breakdown.png)

<!-- screenshot: segmented bar + tag row underneath -->

### Canvas

```pascal
var
  cnv : ICanvas;
  x, y : Integer;
begin
  cnv := Widgets.Canvas(40, 20);
  for y := 0 to 19 do
    for x := 0 to 39 do
      cnv.SetPixel(x, y, TAnsiColor.FromRGB(x * 6, y * 12, 128));
  AnsiConsole.Write(cnv);
end;
```

![Canvas screenshot](/images/canvas.png)

<!-- screenshot: 40x20 colour gradient using half-block glyphs -->

### FIGlet text

```pascal
AnsiConsole.Write(
  Widgets.FigletText('Hello Delphi')
    .WithColor(TAnsiColor.Aqua)
    .WithAlignment(TAlignment.Center));
```

![Figlet screenshot](/images/figlet.png)

<!-- screenshot: large ASCII-art "Hello" centred and coloured -->

### Pretty JSON

```pascal
AnsiConsole.Write(
  Widgets.Json(
    '{"name":"Vincent","skills":["Delphi","Pascal"],"active":true}'));
```

![Json screenshot](/images/json.png)

<!-- screenshot: indented JSON with keys/strings/numbers/booleans coloured differently -->

### Exception widget

```pascal
try
  raise EIOError.Create('disk full');
except
  on E : Exception do
    AnsiConsole.Write(
      Widgets.ExceptionWidget(E)
        .WithStackTrace(MyTraceCollector.AsString)
        .WithFormats([TExceptionFormat.ShortenPaths, TExceptionFormat.ShortenMethods]));
end;
```

![Exception screenshot](/images/exception.png)

<!-- screenshot: type+message header, then a stack frame with shortened path -->

### Recorder + HTML export

```pascal
var
  rec : IRecorder;
begin
  rec := AnsiConsole.Recorder;
  rec.Write(Widgets.Markup('[bold]Captured[/] [yellow]demo[/]'));
  rec.WriteLine;
  rec.Write(Widgets.Panel(Widgets.Text('hi')).WithHeader('panel'));

  // Plain text
  WriteLn(rec.ExportText);

  // HTML — inline styles, ready to paste into a webpage
  TFile.WriteAllText('demo.html', rec.ExportHtml);
end;
```

## Compatibility

| Aspect          | Status                                                                 |
|-----------------|------------------------------------------------------------------------|
| Delphi version  | XE3 and later. |
| Platforms       | Windows (Win32 + Win64). POSIX backend planned                         |
| Terminal        | Windows Terminal, ConHost (Win10+), ConEmu, mintty/Git-Bash, VS Code   |
| ANSI            | True-colour, 256-colour, 16-colour, no-colour — auto-detected          |
| Hyperlinks      | OSC 8, auto-detected on capable terminals                              |

The library probes terminal capability at startup using
`SetConsoleMode(ENABLE_VIRTUAL_TERMINAL_PROCESSING)` rather than the
unreliable `GetVersionEx`, so it correctly classifies modern Windows
hosts even when the executable carries no application manifest.

## Standing on the shoulders of giants

VSoft.AnsiConsole is a from-scratch Delphi port that borrows freely - and
gratefully - from the projects that pioneered rich console rendering on
other platforms. The widget catalogue, render pipeline, markup grammar,
and prompt design all closely mirror prior art so existing knowledge
transfers directly; the Delphi idioms (interfaces, fluent builders,
value-typed records) are native.

### Spectre.Console (.NET)

[Spectre.Console](https://github.com/spectreconsole/spectre.console) by Patrik Svensson is the
direct ancestor. The widget surface, border styles, segment-based render
pipeline, prompt design, status / progress / live-display contracts, and
the recorder all follow Spectre's model very closely. Where there's an
obvious right answer in Spectre, this library uses it. Spectre's
documentation at [spectreconsole.net](https://spectreconsole.net) is a
fantastic companion read — many of the conceptual sections there apply
verbatim.

### Rich (Python)

[Rich](https://github.com/Textualize/rich) by Will McGugan is the project
that pioneered most of these ideas — the segment / renderable model, the
markup syntax, the live display pattern. Spectre.Console (and by
extension this library) owes Rich an enormous debt. Several README
examples and the `Markdown` widget approach were lifted directly from
Rich's walk-through.

### Upstream data tables

A handful of mechanical imports power the polish:

- **xterm-256 colour palette** — the exact RGB values for indices 0..255.
- **Unicode 15.1 cell-width tables** — so wide / combining / zero-width
  characters measure correctly.
- **`cli-spinners`** — 90 named spinner kinds, courtesy of
  [Sindre Sorhus](https://github.com/sindresorhus/cli-spinners).
- **FIGlet font data** — the Standard font is bundled; the `.flf` parser
  follows the [FIGlet 2.0 spec](http://www.jave.de/figlet/figfont.html).
- **Emoji shortcodes** — ~1500 entries generated from the Unicode CLDR
  short-name list, matching the same shortcode set you've seen on
  GitHub, Slack, Discord, and Spectre.

Each generated unit carries an attribution comment at the top citing the
upstream source.

### Why a Delphi port?

Delphi doesn't have a first-class equivalent to Spectre or Rich. Building
a CLI tool that needs colour, tables, prompts, or live displays usually
means reaching for `Crt`, custom escape-code helpers, or shelling out to
PowerShell. This library exists so a Delphi developer can `uses
VSoft.AnsiConsole;` and get the same polish as their .NET / Python
counterparts — without porting half the toolchain.

## License

<!-- placeholder: pick a license (Apache-2.0 / MIT / BSD-3-Clause are the
     usual VSoft conventions), drop the full text into LICENSE at the
     repo root, then update this section + the badge at the top. -->

Copyright &copy; Vincent Parrett and Contributors.

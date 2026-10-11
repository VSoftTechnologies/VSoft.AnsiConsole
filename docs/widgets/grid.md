---
title: Grid
description: A lightweight borderless table — n columns with width strategies (Auto / Fixed / Star), m rows of renderables.
---

# Grid

`IGrid` is a lightweight table without borders, headers, or per-cell
alignment beyond what each child does itself. It's the layout engine
underneath [Table](./table.md).

## When to use

- Aligned columnar data without table borders.
- Two-column "label / value" layouts.
- Building dashboards with mixed-size regions.

For bordered tabular data with headers and footers, use [Table](./table.md).
For named, recursively splittable regions, use [Layout](./layout.md).

## Basic usage

```pascal
var
  g : IGrid;
begin
  g := Widgets.Grid.WithGutter(2);
  g.AddColumn(TGridColumnWidth.Auto, 0, TAlignment.Right);  // labels
  g.AddColumn(TGridColumnWidth.Star);                       // values fill the rest

  g.AddRow([Widgets.Markup('[bold]Name[/]'),    Widgets.Text('Alice')]);
  g.AddRow([Widgets.Markup('[bold]Score[/]'),   Widgets.Text('128')]);
  g.AddRow([Widgets.Markup('[bold]Status[/]'),  Widgets.Markup('[green]OK[/]')]);

  AnsiConsole.Write(g);
end;
```

## Column widths

Each column has one of three kinds (`TGridColumnWidth`):

| Kind | Behaviour |
| --- | --- |
| `Auto` | Column width = max of each cell's natural max measurement. |
| `Fixed` | Column width = user-specified cell count (the `value` argument). |
| `Star` | Column takes a share of leftover width proportional to weight (`value`). |

```pascal
g.AddColumn(TGridColumnWidth.Fixed, 12);  // exactly 12 cells
g.AddColumn(TGridColumnWidth.Star, 2);    // gets 2/3 of leftover
g.AddColumn(TGridColumnWidth.Star, 1);    // gets 1/3 of leftover
```

A `Star` column only stretches to fill the leftover when the grid has
`WithExpand(True)`; otherwise it is sized to its content like `Auto`. Either
way it never takes more than the fixed and auto columns leave - when the
content is too wide for the grid, star columns shrink (and their content
wraps) before any auto column is squeezed.

Convenience methods cover the common cases:

```pascal
g.AddAutoColumn;
g.AddFixedColumn(12);
g.AddStarColumn(2);
```

## Configuration

| Method | Purpose |
| --- | --- |
| `AddColumn(kind, value, alignment, noWrap)` | Long-form column add. |
| `AddAutoColumn` / `AddFixedColumn(w)` / `AddStarColumn(weight)` | Convenience adders. |
| `AddRow(cells)` | Append a row — each cell is an `IRenderable`. |
| `WithGutter(cells)` | Inter-column gap. Default `0`. |
| `WithExpand(value)` | When `True`, fill the available width. |
| `WithWidth(value)` | Explicit grid width in cells. Default auto. |
| `WithColumnAlignment(i, value)` | Retroactive alignment for the i-th column. |
| `WithColumnNoWrap(i, value)` | Mark a column as no-wrap (long lines clip instead of folding). |

## Composition

Grids are widely used inside panels and rows:

```pascal
AnsiConsole.Write(
  Widgets.Panel(g).WithHeader('Summary'));
```

## API reference

- [`Widgets.Grid`](https://github.com/VSoftTechnologies/VSoft.AnsiConsole/blob/main/source/VSoft.AnsiConsole.pas) — empty grid.
- [`IGrid`](https://github.com/VSoftTechnologies/VSoft.AnsiConsole/blob/main/source/Widgets/VSoft.AnsiConsole.Widgets.Grid.pas) — interface.

## See also

- [Table](./table.md) — when you need borders, headers, footers.
- [Columns](./columns.md) / [Rows](./rows.md) — when you don't need column width control.
- [Layout](./layout.md) — for sized recursive splits.

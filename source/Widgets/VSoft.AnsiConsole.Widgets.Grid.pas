unit VSoft.AnsiConsole.Widgets.Grid;

{
  TGrid - a lightweight table: n columns (each with a width strategy) and
  m rows (each row a list of one IRenderable per column). No borders, no
  headers, no cell alignment beyond what the cell renderable itself does.
  Grid is the base for Phase 3's Table.

  Column width strategies:
    TGridColumnWidth.Auto   : column width = max of each cell's natural max measurement.
    TGridColumnWidth.Fixed  : column width = user-specified cell count.
    TGridColumnWidth.Star   : column takes a share of leftover width proportional to weight.

  Layout:
    1. Compute auto / fixed widths.
    2. Subtract from maxWidth (less gutters) - remainder is shared among
       star columns by weight.
    3. Render cells into their column width and stitch rows line-by-line
       (same mechanism as TColumns).
}

{$SCOPEDENUMS ON}

interface

uses
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Segment,
  VSoft.AnsiConsole.Measurement,
  VSoft.AnsiConsole.Rendering;

type
  TGridColumnWidth = (Auto, Fixed, Star);

  TGridColumn = record
    Kind      : TGridColumnWidth;
    Value     : Integer;     // cells for TGridColumnWidth.Fixed, weight for TGridColumnWidth.Star, unused for TGridColumnWidth.Auto
    Alignment : TAlignment;  // cell horizontal alignment within the column
    NoWrap    : Boolean;     // True = clip overflowing lines, False = wrap them
  end;

  TGridRow = TArray<IRenderable>;

  IGrid = interface(IRenderable)
    ['{3C9C5B8A-7F42-4C3B-9AAB-1A0C1D8E3A44}']
    function AddColumn(kind : TGridColumnWidth; value : Integer = 0) : IGrid; overload;
    function AddColumn(kind : TGridColumnWidth; value : Integer;
                        alignment : TAlignment) : IGrid; overload;
    function AddColumn(kind : TGridColumnWidth; value : Integer;
                        alignment : TAlignment; noWrap : Boolean) : IGrid; overload;
    function AddAutoColumn : IGrid;
    function AddFixedColumn(width : Integer) : IGrid;
    function AddStarColumn(weight : Integer = 1) : IGrid;
    function AddRow(const cells : array of IRenderable) : IGrid;
    function WithGutter(cells : Integer) : IGrid;
    function WithExpand(value : Boolean) : IGrid;
    function WithWidth(value : Integer) : IGrid;
    { Apply per-column settings retroactively (after AddColumn). Use
      these when chaining AddAutoColumn/AddFixedColumn/AddStarColumn
      and you don't want to switch to the long-form AddColumn overload. }
    function WithColumnAlignment(columnIndex : Integer; value : TAlignment) : IGrid;
    function WithColumnNoWrap(columnIndex : Integer; value : Boolean) : IGrid;
    function ColumnCount : Integer;
    function RowCount : Integer;
  end;

  TGrid = class(TInterfacedObject, IRenderable, IGrid)
  strict private
    FColumns : TArray<TGridColumn>;
    FRows    : TArray<TGridRow>;
    FGutter  : Integer;
    FExpand  : Boolean;
    FWidth   : Integer;   // -1 = auto
    function ComputeWidths(const options : TRenderOptions; maxWidth : Integer) : TArray<Integer>;
  public
    constructor Create;
    function AddColumn(kind : TGridColumnWidth; value : Integer = 0) : IGrid; overload;
    function AddColumn(kind : TGridColumnWidth; value : Integer;
                        alignment : TAlignment) : IGrid; overload;
    function AddColumn(kind : TGridColumnWidth; value : Integer;
                        alignment : TAlignment; noWrap : Boolean) : IGrid; overload;
    function AddAutoColumn : IGrid;
    function AddFixedColumn(width : Integer) : IGrid;
    function AddStarColumn(weight : Integer = 1) : IGrid;
    function AddRow(const cells : array of IRenderable) : IGrid;
    function WithGutter(cells : Integer) : IGrid;
    function WithExpand(value : Boolean) : IGrid;
    function WithWidth(value : Integer) : IGrid;
    function WithColumnAlignment(columnIndex : Integer; value : TAlignment) : IGrid;
    function WithColumnNoWrap(columnIndex : Integer; value : Boolean) : IGrid;
    function ColumnCount : Integer;
    function RowCount : Integer;
    function Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
    function Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
  end;

function Grid : IGrid;

implementation

uses
  System.SysUtils,
  VSoft.AnsiConsole.Widgets.Text,
  VSoft.AnsiConsole.Internal.SegmentOps;

function Grid : IGrid;
begin
  result := TGrid.Create;
end;

{ TGrid }

constructor TGrid.Create;
begin
  inherited Create;
  FGutter := 1;
  FExpand := False;
  FWidth  := -1;
end;

function TGrid.AddColumn(kind : TGridColumnWidth; value : Integer) : IGrid;
begin
  result := AddColumn(kind, value, TAlignment.Left, False);
end;

function TGrid.AddColumn(kind : TGridColumnWidth; value : Integer;
                          alignment : TAlignment) : IGrid;
begin
  result := AddColumn(kind, value, alignment, False);
end;

function TGrid.AddColumn(kind : TGridColumnWidth; value : Integer;
                          alignment : TAlignment; noWrap : Boolean) : IGrid;
var
  col : TGridColumn;
begin
  col.Kind      := kind;
  col.Value     := value;
  col.Alignment := alignment;
  col.NoWrap    := noWrap;
  if (kind = TGridColumnWidth.Star) and (col.Value < 1) then col.Value := 1;
  SetLength(FColumns, Length(FColumns) + 1);
  FColumns[High(FColumns)] := col;
  result := Self;
end;

function TGrid.WithColumnAlignment(columnIndex : Integer; value : TAlignment) : IGrid;
begin
  if (columnIndex >= 0) and (columnIndex <= High(FColumns)) then
    FColumns[columnIndex].Alignment := value;
  result := Self;
end;

function TGrid.WithColumnNoWrap(columnIndex : Integer; value : Boolean) : IGrid;
begin
  if (columnIndex >= 0) and (columnIndex <= High(FColumns)) then
    FColumns[columnIndex].NoWrap := value;
  result := Self;
end;

function TGrid.AddAutoColumn : IGrid;
begin
  result := AddColumn(TGridColumnWidth.Auto, 0);
end;

function TGrid.AddFixedColumn(width : Integer) : IGrid;
begin
  result := AddColumn(TGridColumnWidth.Fixed, width);
end;

function TGrid.AddStarColumn(weight : Integer) : IGrid;
begin
  result := AddColumn(TGridColumnWidth.Star, weight);
end;

function TGrid.AddRow(const cells : array of IRenderable) : IGrid;
var
  i  : Integer;
  row : TGridRow;
begin
  SetLength(row, Length(FColumns));
  for i := 0 to High(row) do
  begin
    if i <= High(cells) then
      row[i] := cells[i]
    else
      row[i] := Text('');
  end;
  SetLength(FRows, Length(FRows) + 1);
  FRows[High(FRows)] := row;
  result := Self;
end;

function TGrid.WithGutter(cells : Integer) : IGrid;
begin
  if cells < 0 then cells := 0;
  FGutter := cells;
  result := Self;
end;

function TGrid.WithExpand(value : Boolean) : IGrid;
begin
  FExpand := value;
  result := Self;
end;

function TGrid.WithWidth(value : Integer) : IGrid;
begin
  if value < 1 then
    FWidth := -1
  else
    FWidth := value;
  result := Self;
end;

function TGrid.ColumnCount : Integer;
begin
  result := Length(FColumns);
end;

function TGrid.RowCount : Integer;
begin
  result := Length(FRows);
end;

function TGrid.ComputeWidths(const options : TRenderOptions; maxWidth : Integer) : TArray<Integer>;
var
  n          : Integer;
  i, r       : Integer;
  gutters    : Integer;
  totalFixed : Integer;
  remaining  : Integer;
  totalStars : Integer;
  m          : TMeasurement;
  autoWidth  : Integer;
  leftover   : Integer;

  // Take `excess` cells off the columns of `kind`, one cell at a time from
  // whichever is currently widest, never going below `minWidth`. `excess` is
  // left holding whatever could not be taken.
  procedure Shave(kind : TGridColumnWidth; minWidth : Integer; var excess : Integer);
  var
    col    : Integer;
    widest : Integer;
  begin
    while excess > 0 do
    begin
      widest := -1;
      for col := 0 to n - 1 do
      begin
        if (FColumns[col].Kind = kind) and (result[col] > minWidth) and
           ((widest < 0) or (result[col] > result[widest])) then
          widest := col;
      end;
      if widest < 0 then Break;
      Dec(result[widest]);
      Dec(excess);
    end;
  end;

begin
  n := Length(FColumns);
  SetLength(result, n);
  if n = 0 then Exit;

  if n > 1 then
    gutters := FGutter * (n - 1)
  else
    gutters := 0;

  // Pass 1: fixed columns
  totalFixed := 0;
  for i := 0 to n - 1 do
  begin
    if FColumns[i].Kind = TGridColumnWidth.Fixed then
    begin
      result[i] := FColumns[i].Value;
      if result[i] < 0 then result[i] := 0;
      Inc(totalFixed, result[i]);
    end;
  end;

  // Pass 2: auto columns (take max natural width of the column's cells).
  // When FExpand=False, star columns are also sized by content (the grid
  // shouldn't stretch to fill maxWidth).
  for i := 0 to n - 1 do
  begin
    if (FColumns[i].Kind = TGridColumnWidth.Auto) or
       ((FColumns[i].Kind = TGridColumnWidth.Star) and (not FExpand)) then
    begin
      autoWidth := 0;
      for r := 0 to High(FRows) do
      begin
        if (i <= High(FRows[r])) and (FRows[r][i] <> nil) then
        begin
          m := FRows[r][i].Measure(options, maxWidth);
          if m.Max > autoWidth then autoWidth := m.Max;
        end;
      end;
      result[i] := autoWidth;
      Inc(totalFixed, autoWidth);
    end;
  end;

  // Pass 3: distribute remaining space among star columns. Only runs when
  // FExpand=True; otherwise star columns were sized as auto in Pass 2.
  if FExpand then
  begin
    remaining := maxWidth - gutters - totalFixed;
    if remaining < 0 then remaining := 0;
    totalStars := 0;
    for i := 0 to n - 1 do
      if FColumns[i].Kind = TGridColumnWidth.Star then
        Inc(totalStars, FColumns[i].Value);

    if totalStars > 0 then
    begin
      for i := 0 to n - 1 do
      begin
        if FColumns[i].Kind = TGridColumnWidth.Star then
          result[i] := (remaining * FColumns[i].Value) div totalStars;
      end;
      // distribute rounding leftover to leftmost star column
      leftover := remaining;
      for i := 0 to n - 1 do
        if FColumns[i].Kind = TGridColumnWidth.Star then
          Dec(leftover, result[i]);
      if leftover > 0 then
      begin
        for i := 0 to n - 1 do
          if FColumns[i].Kind = TGridColumnWidth.Star then
          begin
            Inc(result[i], leftover);
            Break;
          end;
      end;
    end;
  end;

  // If total exceeds maxWidth (common when content wants more than fits),
  // squeeze. Star columns give way first: they take what the fixed and auto
  // columns leave whether or not the grid expands (FExpand only decides if
  // they grow past their content), but keep one cell so their content is
  // never dropped. Auto columns are squeezed only once the stars have
  // nothing left to give.
  totalFixed := gutters;
  for i := 0 to n - 1 do
    Inc(totalFixed, result[i]);
  if totalFixed > maxWidth then
  begin
    leftover := totalFixed - maxWidth;
    Shave(TGridColumnWidth.Star, 1, leftover);
    Shave(TGridColumnWidth.Auto, 0, leftover);
  end;
end;

function TGrid.Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
var
  widths : TArray<Integer>;
  i      : Integer;
  total  : Integer;
begin
  widths := ComputeWidths(options, maxWidth);
  total := 0;
  for i := 0 to High(widths) do
    Inc(total, widths[i]);
  if Length(widths) > 1 then
    Inc(total, FGutter * (Length(widths) - 1));
  if total > maxWidth then total := maxWidth;
  result := TMeasurement.Create(total, total);
end;

function TGrid.Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
var
  widths   : TArray<Integer>;
  n, i     : Integer;
  r, j, k  : Integer;
  count    : Integer;
  rowLines : TArray<TArray<TAnsiSegments>>;
  rowCount : Integer;
  line     : TAnsiSegments;
  lineWidth : Integer;
  gutter   : string;

  procedure Push(const seg : TAnsiSegment);
  begin
    SetLength(result, count + 1);
    result[count] := seg;
    Inc(count);
  end;

begin
  SetLength(result, 0);
  count := 0;
  n := Length(FColumns);
  if (n = 0) or (Length(FRows) = 0) then Exit;

  // FWidth clamps the grid width independently of the surrounding layout.
  // Never grow past the caller's maxWidth.
  if (FWidth > 0) and (FWidth < maxWidth) then
    widths := ComputeWidths(options, FWidth)
  else
    widths := ComputeWidths(options, maxWidth);
  gutter := StringOfChar(' ', FGutter);

  for r := 0 to High(FRows) do
  begin
    // Render each cell in this row into its column width. NoWrap columns
    // skip the wrap step (split on linebreaks only) and crop overflowing
    // lines to the column width.
    SetLength(rowLines, n);
    rowCount := 0;
    for i := 0 to n - 1 do
    begin
      if (i <= High(FRows[r])) and (FRows[r][i] <> nil) then
      begin
        if FColumns[i].NoWrap then
        begin
          rowLines[i] := SplitLines(FRows[r][i].Render(options, widths[i]), MaxInt);
          for k := 0 to High(rowLines[i]) do
            rowLines[i][k] := CropLineToWidth(rowLines[i][k], widths[i], False);
        end
        else
          rowLines[i] := SplitLines(FRows[r][i].Render(options, widths[i]), widths[i]);
      end
      else
        SetLength(rowLines[i], 0);
      if Length(rowLines[i]) > rowCount then
        rowCount := Length(rowLines[i]);
    end;

    for j := 0 to rowCount - 1 do
    begin
      for i := 0 to n - 1 do
      begin
        if j <= High(rowLines[i]) then
        begin
          line := rowLines[i][j];
          lineWidth := TotalCellCount(line);
          // Per-column horizontal alignment within the cell box.
          if (lineWidth < widths[i]) then
          begin
            case FColumns[i].Alignment of
              TAlignment.Center:
              begin
                Push(TAnsiSegment.Whitespace(StringOfChar(' ', (widths[i] - lineWidth) div 2)));
                for k := 0 to High(line) do
                  Push(line[k]);
                Push(TAnsiSegment.Whitespace(StringOfChar(' ',
                  widths[i] - lineWidth - ((widths[i] - lineWidth) div 2))));
              end;
              TAlignment.Right:
              begin
                Push(TAnsiSegment.Whitespace(StringOfChar(' ', widths[i] - lineWidth)));
                for k := 0 to High(line) do
                  Push(line[k]);
              end;
            else
              for k := 0 to High(line) do
                Push(line[k]);
              Push(TAnsiSegment.Whitespace(StringOfChar(' ', widths[i] - lineWidth)));
            end;
          end
          else
          begin
            for k := 0 to High(line) do
              Push(line[k]);
          end;
        end
        else
          Push(TAnsiSegment.Whitespace(StringOfChar(' ', widths[i])));

        if (i < n - 1) and (FGutter > 0) then
          Push(TAnsiSegment.Whitespace(gutter));
      end;

      if j < rowCount - 1 then
        Push(TAnsiSegment.LineBreak);
    end;

    if r < High(FRows) then
      Push(TAnsiSegment.LineBreak);
  end;
end;

end.

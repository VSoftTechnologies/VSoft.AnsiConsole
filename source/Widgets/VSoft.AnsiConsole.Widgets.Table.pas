unit VSoft.AnsiConsole.Widgets.Table;

{
  TTable - a data table widget with headers, borders, optional title and
  caption. Reuses the Grid column-width solver (TGridColumnWidth.Auto/TGridColumnWidth.Fixed/TGridColumnWidth.Star).

  Layout:

    Title (centred, optional)
    +--------+------+----+      <- TTableBorderPart.TopLeft / TTableBorderPart.Top / TTableBorderPart.TopMid / TTableBorderPart.TopRight
    | header | ...  | .. |      <- TTableBorderPart.CellLeft / TTableBorderPart.CellMid / TTableBorderPart.CellRight
    +--------+------+----+      <- TTableBorderPart.HeadLeft / TTableBorderPart.Head / TTableBorderPart.HeadMid / TTableBorderPart.HeadRight
    | cell   | ...  | .. |      <- data row lines
    | ...    | ...  | .. |
    +--------+------+----+      <- TTableBorderPart.BottomLeft / TTableBorderPart.Bottom / TTableBorderPart.BottomMid / TTableBorderPart.BottomRight
    Caption (centred, optional)

}

interface

uses
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Style,
  VSoft.AnsiConsole.Segment,
  VSoft.AnsiConsole.Measurement,
  VSoft.AnsiConsole.Rendering,
  VSoft.AnsiConsole.Borders.Table,
  VSoft.AnsiConsole.Widgets.Grid;  // reuse TGridColumnWidth

type
  TTableColumn = record
    Header      : string;
    Footer      : string;
    WidthKind   : TGridColumnWidth;
    WidthValue  : Integer;
    Alignment   : TAlignment;
    NoWrap      : Boolean;
  end;

  TTableRow = TArray<IRenderable>;

  { Spectre-style table title/caption. Used when the caller wants a
    centred heading rendered in a specific TAnsiStyle. The plain string
    overloads of WithTitle / WithCaption are kept and unaffected. }
  ITableTitle = interface
    ['{6F18B1A8-2E47-4E1B-94A2-2A5F6D9A4801}']
    function GetText : string;
    function GetStyle : TAnsiStyle;
    function WithStyle(const value : TAnsiStyle) : ITableTitle;
    property Text  : string     read GetText;
    property Style : TAnsiStyle read GetStyle;
  end;

  { A table cell that wraps an IRenderable with a per-cell style. The
    cell's style fills in any field the inner content leaves at default
    (so explicit fg/bg/decorations on inner markup still win). }
  ITableCell = interface(IRenderable)
    ['{6F18B1A8-2E47-4E1B-94A2-2A5F6D9A4802}']
    function GetContent : IRenderable;
    function GetStyle : TAnsiStyle;
    function WithStyle(const value : TAnsiStyle) : ITableCell;
    property Content : IRenderable read GetContent;
    property Style   : TAnsiStyle  read GetStyle;
  end;

  ITable = interface(IRenderable)
    ['{5F18B1A8-2E47-4E1B-94A2-2A5F6D9A47A3}']
    function AddColumn(const header : string) : ITable; overload;
    function AddColumn(const header : string; alignment : TAlignment) : ITable; overload;
    function AddColumn(const header : string; widthKind : TGridColumnWidth;
                        widthValue : Integer; alignment : TAlignment) : ITable; overload;
    function AddRow(const cells : array of IRenderable) : ITable; overload;
    function AddRow(const cells : array of string) : ITable; overload;
    function AddEmptyRow : ITable;
    function InsertRow(index : Integer; const cells : array of IRenderable) : ITable; overload;
    function InsertRow(index : Integer; const cells : array of string) : ITable; overload;
    function RemoveRow(index : Integer) : ITable;
    function UpdateCell(rowIndex, columnIndex : Integer; const cellData : IRenderable) : ITable; overload;
    function UpdateCell(rowIndex, columnIndex : Integer; const cellData : string) : ITable; overload;
    function AddFooter(const cells : array of string) : ITable;

    function WithTitle(const value : string) : ITable; overload;
    function WithTitle(const value : ITableTitle) : ITable; overload;
    function WithCaption(const value : string) : ITable; overload;
    function WithCaption(const value : ITableTitle) : ITable; overload;
    function WithBorder(kind : TTableBorderKind) : ITable; overload;
    function WithBorder(const value : ITableBorder) : ITable; overload;
    function WithBorderStyle(const value : TAnsiStyle) : ITable;
    function WithShowHeader(value : Boolean) : ITable;
    function WithShowFooters(value : Boolean) : ITable;
    function WithShowRowSeparators(value : Boolean) : ITable;
    function WithUseSafeBorder(value : Boolean) : ITable;
    function WithWidth(value : Integer) : ITable;
    function WithExpand(value : Boolean) : ITable;
    function WithColumnNoWrap(columnIndex : Integer; value : Boolean) : ITable;

    function ColumnCount : Integer;
    function RowCount : Integer;
  end;

  TTable = class(TInterfacedObject, IRenderable, ITable)
  strict private
    FColumns            : TArray<TTableColumn>;
    FRows               : TArray<TTableRow>;
    FTitle              : string;
    FTitleStyle         : TAnsiStyle;
    FCaption            : string;
    FCaptionStyle       : TAnsiStyle;
    FBorder             : ITableBorder;
    FBorderStyle        : TAnsiStyle;
    FShowHeader         : Boolean;
    FShowFooters        : Boolean;
    FShowRowSeparators  : Boolean;
    FUseSafeBorder      : Boolean;
    FFixedWidth         : Integer;   // -1 = auto
    FExpand             : Boolean;

    function ComputeWidths(const options : TRenderOptions; maxWidth : Integer) : TArray<Integer>;
    function TotalTableWidth(const widths : TArray<Integer>; hasVerticals : Boolean) : Integer;
    function HasVerticalBorders : Boolean;
    function HasHorizontalBorders : Boolean;
  public
    constructor Create;

    function AddColumn(const header : string) : ITable; overload;
    function AddColumn(const header : string; alignment : TAlignment) : ITable; overload;
    function AddColumn(const header : string; widthKind : TGridColumnWidth;
                        widthValue : Integer; alignment : TAlignment) : ITable; overload;
    function AddRow(const cells : array of IRenderable) : ITable; overload;
    function AddRow(const cells : array of string) : ITable; overload;
    function AddEmptyRow : ITable;
    function InsertRow(index : Integer; const cells : array of IRenderable) : ITable; overload;
    function InsertRow(index : Integer; const cells : array of string) : ITable; overload;
    function RemoveRow(index : Integer) : ITable;
    function UpdateCell(rowIndex, columnIndex : Integer; const cellData : IRenderable) : ITable; overload;
    function UpdateCell(rowIndex, columnIndex : Integer; const cellData : string) : ITable; overload;
    function AddFooter(const cells : array of string) : ITable;

    function WithTitle(const value : string) : ITable; overload;
    function WithTitle(const value : ITableTitle) : ITable; overload;
    function WithCaption(const value : string) : ITable; overload;
    function WithCaption(const value : ITableTitle) : ITable; overload;
    function WithBorder(kind : TTableBorderKind) : ITable; overload;
    function WithBorder(const value : ITableBorder) : ITable; overload;
    function WithBorderStyle(const value : TAnsiStyle) : ITable;
    function WithShowHeader(value : Boolean) : ITable;
    function WithShowFooters(value : Boolean) : ITable;
    function WithShowRowSeparators(value : Boolean) : ITable;
    function WithUseSafeBorder(value : Boolean) : ITable;
    function WithWidth(value : Integer) : ITable;
    function WithExpand(value : Boolean) : ITable;
    function WithColumnNoWrap(columnIndex : Integer; value : Boolean) : ITable;

    function ColumnCount : Integer;
    function RowCount : Integer;
    function Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
    function Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
  end;

  TTableTitle = class(TInterfacedObject, ITableTitle)
  strict private
    FText  : string;
    FStyle : TAnsiStyle;
  public
    constructor Create(const text : string);
    function GetText : string;
    function GetStyle : TAnsiStyle;
    function WithStyle(const value : TAnsiStyle) : ITableTitle;
  end;

  TTableCell = class(TInterfacedObject, IRenderable, ITableCell)
  strict private
    FContent : IRenderable;
    FStyle   : TAnsiStyle;
  public
    constructor Create(const content : IRenderable);
    function GetContent : IRenderable;
    function GetStyle : TAnsiStyle;
    function WithStyle(const value : TAnsiStyle) : ITableCell;
    function Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
    function Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
  end;

function Table : ITable;
function TableTitle(const text : string) : ITableTitle;
function TableCell(const text : string) : ITableCell; overload;
function TableCell(const content : IRenderable) : ITableCell; overload;

implementation

uses
  System.Math,
  System.SysUtils,
  VSoft.AnsiConsole.Widgets.Text,
  VSoft.AnsiConsole.Widgets.Markup,
  VSoft.AnsiConsole.Internal.SegmentOps;

function Table : ITable;
begin
  result := TTable.Create;
end;

function TableTitle(const text : string) : ITableTitle;
begin
  result := TTableTitle.Create(text);
end;

function TableCell(const text : string) : ITableCell;
begin
  result := TTableCell.Create(Markup(text));
end;

function TableCell(const content : IRenderable) : ITableCell;
begin
  result := TTableCell.Create(content);
end;

{ TTableTitle }

constructor TTableTitle.Create(const text : string);
begin
  inherited Create;
  FText  := text;
  FStyle := TAnsiStyle.Plain;
end;

function TTableTitle.GetText : string;
begin
  result := FText;
end;

function TTableTitle.GetStyle : TAnsiStyle;
begin
  result := FStyle;
end;

function TTableTitle.WithStyle(const value : TAnsiStyle) : ITableTitle;
var
  copy : TTableTitle;
begin
  copy := TTableTitle.Create(FText);
  copy.FStyle := value;
  result := copy;
end;

{ TTableCell }

constructor TTableCell.Create(const content : IRenderable);
begin
  inherited Create;
  FContent := content;
  FStyle   := TAnsiStyle.Plain;
end;

function TTableCell.GetContent : IRenderable;
begin
  result := FContent;
end;

function TTableCell.GetStyle : TAnsiStyle;
begin
  result := FStyle;
end;

function TTableCell.WithStyle(const value : TAnsiStyle) : ITableCell;
var
  copy : TTableCell;
begin
  copy := TTableCell.Create(FContent);
  copy.FStyle := value;
  result := copy;
end;

function TTableCell.Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
begin
  if FContent <> nil then
    result := FContent.Measure(options, maxWidth)
  else
    result := TMeasurement.Create(0, 0);
end;

function TTableCell.Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
var
  i : Integer;
  combined : TAnsiStyle;
begin
  if FContent = nil then
  begin
    SetLength(result, 0);
    Exit;
  end;
  result := FContent.Render(options, maxWidth);
  if FStyle.IsPlain then Exit;
  // FStyle as base, segment style as override (so explicit colors on the
  // inner content win, but the cell's defaults fill in any field the
  // content leaves at default).
  for i := 0 to High(result) do
  begin
    if result[i].IsControlCode or result[i].IsLineBreak then Continue;
    combined := FStyle.Combine(result[i].Style);
    if result[i].IsWhitespace then
      result[i] := TAnsiSegment.Whitespace(result[i].Value, combined)
    else
      result[i] := TAnsiSegment.Text(result[i].Value, combined);
  end;
end;

{ TTable }

constructor TTable.Create;
begin
  inherited Create;
  FBorder             := TableBorder(TTableBorderKind.Square);
  FBorderStyle        := TAnsiStyle.Plain;
  FTitleStyle         := TAnsiStyle.Plain;
  FCaptionStyle       := TAnsiStyle.Plain;
  FShowHeader         := True;
  FShowFooters        := True;
  FShowRowSeparators  := False;
  FUseSafeBorder      := True;
  FFixedWidth         := -1;
  FExpand             := False;
end;

function TTable.AddColumn(const header : string) : ITable;
begin
  result := AddColumn(header, TGridColumnWidth.Auto, 0, TAlignment.Left);
end;

function TTable.AddColumn(const header : string; alignment : TAlignment) : ITable;
begin
  result := AddColumn(header, TGridColumnWidth.Auto, 0, alignment);
end;

function TTable.AddColumn(const header : string; widthKind : TGridColumnWidth;
                            widthValue : Integer; alignment : TAlignment) : ITable;
var
  col : TTableColumn;
begin
  col.Header     := header;
  col.Footer     := '';
  col.WidthKind  := widthKind;
  col.WidthValue := widthValue;
  col.Alignment  := alignment;
  col.NoWrap     := False;
  SetLength(FColumns, Length(FColumns) + 1);
  FColumns[High(FColumns)] := col;
  result := Self;
end;

function TTable.AddRow(const cells : array of IRenderable) : ITable;
var
  row : TTableRow;
  i   : Integer;
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

function TTable.AddRow(const cells : array of string) : ITable;
var
  ren : TArray<IRenderable>;
  i   : Integer;
begin
  SetLength(ren, Length(cells));
  for i := 0 to High(cells) do
    ren[i] := Markup(cells[i]);
  result := AddRow(ren);
end;

function TTable.AddEmptyRow : ITable;
var
  row : TTableRow;
  i   : Integer;
begin
  SetLength(row, Length(FColumns));
  for i := 0 to High(row) do
    row[i] := Text('');
  SetLength(FRows, Length(FRows) + 1);
  FRows[High(FRows)] := row;
  result := Self;
end;

function TTable.InsertRow(index : Integer; const cells : array of IRenderable) : ITable;
var
  row    : TTableRow;
  i      : Integer;
  newLen : Integer;
begin
  if index < 0 then index := 0;
  if index > Length(FRows) then index := Length(FRows);

  SetLength(row, Length(FColumns));
  for i := 0 to High(row) do
  begin
    if i <= High(cells) then
      row[i] := cells[i]
    else
      row[i] := Text('');
  end;

  newLen := Length(FRows) + 1;
  SetLength(FRows, newLen);
  // Shift existing rows from `index` onward up by one slot.
  for i := newLen - 1 downto index + 1 do
    FRows[i] := FRows[i - 1];
  FRows[index] := row;
  result := Self;
end;

function TTable.InsertRow(index : Integer; const cells : array of string) : ITable;
var
  ren : TArray<IRenderable>;
  i   : Integer;
begin
  SetLength(ren, Length(cells));
  for i := 0 to High(cells) do
    ren[i] := Markup(cells[i]);
  result := InsertRow(index, ren);
end;

function TTable.RemoveRow(index : Integer) : ITable;
var
  i      : Integer;
  newLen : Integer;
begin
  if (index < 0) or (index > High(FRows)) then
  begin
    result := Self;
    Exit;
  end;
  newLen := Length(FRows) - 1;
  for i := index to newLen - 1 do
    FRows[i] := FRows[i + 1];
  SetLength(FRows, newLen);
  result := Self;
end;

function TTable.UpdateCell(rowIndex, columnIndex : Integer; const cellData : IRenderable) : ITable;
begin
  if (rowIndex < 0) or (rowIndex > High(FRows)) then
  begin
    result := Self;
    Exit;
  end;
  if (columnIndex < 0) or (columnIndex >= Length(FColumns)) then
  begin
    result := Self;
    Exit;
  end;
  if columnIndex > High(FRows[rowIndex]) then
    SetLength(FRows[rowIndex], columnIndex + 1);
  FRows[rowIndex][columnIndex] := cellData;
  result := Self;
end;

function TTable.UpdateCell(rowIndex, columnIndex : Integer; const cellData : string) : ITable;
begin
  result := UpdateCell(rowIndex, columnIndex, Markup(cellData));
end;

function TTable.WithTitle(const value : string) : ITable;
begin
  FTitle      := value;
  FTitleStyle := TAnsiStyle.Plain;
  result := Self;
end;

function TTable.WithTitle(const value : ITableTitle) : ITable;
begin
  if value <> nil then
  begin
    FTitle      := value.Text;
    FTitleStyle := value.Style;
  end
  else
  begin
    FTitle      := '';
    FTitleStyle := TAnsiStyle.Plain;
  end;
  result := Self;
end;

function TTable.WithCaption(const value : string) : ITable;
begin
  FCaption      := value;
  FCaptionStyle := TAnsiStyle.Plain;
  result := Self;
end;

function TTable.WithCaption(const value : ITableTitle) : ITable;
begin
  if value <> nil then
  begin
    FCaption      := value.Text;
    FCaptionStyle := value.Style;
  end
  else
  begin
    FCaption      := '';
    FCaptionStyle := TAnsiStyle.Plain;
  end;
  result := Self;
end;

function TTable.WithBorder(kind : TTableBorderKind) : ITable;
begin
  FBorder := TableBorder(kind);
  result := Self;
end;

function TTable.WithBorder(const value : ITableBorder) : ITable;
begin
  if value <> nil then
    FBorder := value;
  result := Self;
end;

function TTable.WithBorderStyle(const value : TAnsiStyle) : ITable;
begin
  FBorderStyle := value;
  result := Self;
end;

function TTable.WithShowHeader(value : Boolean) : ITable;
begin
  FShowHeader := value;
  result := Self;
end;

function TTable.WithShowFooters(value : Boolean) : ITable;
begin FShowFooters := value; result := Self; end;

function TTable.WithShowRowSeparators(value : Boolean) : ITable;
begin FShowRowSeparators := value; result := Self; end;

function TTable.WithUseSafeBorder(value : Boolean) : ITable;
begin FUseSafeBorder := value; result := Self; end;

function TTable.WithWidth(value : Integer) : ITable;
begin
  if value < 1 then
    FFixedWidth := -1
  else
    FFixedWidth := value;
  result := Self;
end;

function TTable.WithColumnNoWrap(columnIndex : Integer; value : Boolean) : ITable;
begin
  if (columnIndex >= 0) and (columnIndex <= High(FColumns)) then
    FColumns[columnIndex].NoWrap := value;
  result := Self;
end;

function TTable.AddFooter(const cells : array of string) : ITable;
var
  i : Integer;
begin
  for i := 0 to Min(Length(cells), Length(FColumns)) - 1 do
    FColumns[i].Footer := cells[i];
  result := Self;
end;

function TTable.WithExpand(value : Boolean) : ITable;
begin
  FExpand := value;
  result := Self;
end;

function TTable.ColumnCount : Integer;
begin
  result := Length(FColumns);
end;

function TTable.RowCount : Integer;
begin
  result := Length(FRows);
end;

function TTable.HasVerticalBorders : Boolean;
begin
  result := (FBorder <> nil) and (FBorder.Kind <> TTableBorderKind.None);
end;

function TTable.HasHorizontalBorders : Boolean;
begin
  result := (FBorder <> nil) and (FBorder.Kind <> TTableBorderKind.None) and (FBorder.Kind <> TTableBorderKind.Markdown);
end;

function TTable.ComputeWidths(const options : TRenderOptions; maxWidth : Integer) : TArray<Integer>;
var
  n          : Integer;
  i, r       : Integer;
  overhead   : Integer;
  totalFixed : Integer;
  remaining  : Integer;
  totalStars : Integer;
  autoWidth  : Integer;
  m          : TMeasurement;
  headerLen  : Integer;
  leftover   : Integer;
  worstIdx   : Integer;
  worstWidth : Integer;
begin
  n := Length(FColumns);
  SetLength(result, n);
  if n = 0 then Exit;

  // Overhead = 2 (left/right border) + n-1 inter-cell separators + per-cell padding (1 cell each side inside every cell).
  if HasVerticalBorders then
    overhead := 2 + (n - 1)
  else
    overhead := 0;
  overhead := overhead + n * 2; // one cell left pad + one cell right pad per column

  // Pass 1: fixed columns
  totalFixed := 0;
  for i := 0 to n - 1 do
  begin
    if FColumns[i].WidthKind = TGridColumnWidth.Fixed then
    begin
      result[i] := FColumns[i].WidthValue;
      if result[i] < 1 then result[i] := 1;
      Inc(totalFixed, result[i]);
    end;
  end;

  // Pass 2: auto columns - max of header length and each cell's natural width.
  for i := 0 to n - 1 do
  begin
    if FColumns[i].WidthKind = TGridColumnWidth.Auto then
    begin
      autoWidth := 0;
      if FShowHeader then
      begin
        // The header is markup - measure what it renders to, so tags take
        // no room and a multi-line header counts its longest line.
        headerLen := Markup(FColumns[i].Header).Measure(options, maxWidth).Max;
        if headerLen > autoWidth then autoWidth := headerLen;
      end;
      for r := 0 to High(FRows) do
      begin
        if (i <= High(FRows[r])) and (FRows[r][i] <> nil) then
        begin
          m := FRows[r][i].Measure(options, maxWidth);
          if m.Max > autoWidth then autoWidth := m.Max;
        end;
      end;
      if autoWidth < 1 then autoWidth := 1;
      result[i] := autoWidth;
      Inc(totalFixed, autoWidth);
    end;
  end;

  // Pass 3: distribute leftover among star columns.
  remaining := maxWidth - overhead - totalFixed;
  if remaining < 0 then remaining := 0;
  totalStars := 0;
  for i := 0 to n - 1 do
    if FColumns[i].WidthKind = TGridColumnWidth.Star then
      Inc(totalStars, FColumns[i].WidthValue);

  if totalStars > 0 then
  begin
    for i := 0 to n - 1 do
      if FColumns[i].WidthKind = TGridColumnWidth.Star then
        result[i] := (remaining * FColumns[i].WidthValue) div totalStars;
    leftover := remaining;
    for i := 0 to n - 1 do
      if FColumns[i].WidthKind = TGridColumnWidth.Star then
        Dec(leftover, result[i]);
    if leftover > 0 then
      for i := 0 to n - 1 do
        if FColumns[i].WidthKind = TGridColumnWidth.Star then
        begin
          Inc(result[i], leftover);
          Break;
        end;
  end
  else if FExpand then
  begin
    // Expand=True with no star columns: grow auto columns proportionally to fill.
    if remaining > 0 then
    begin
      for i := 0 to n - 1 do
        if FColumns[i].WidthKind = TGridColumnWidth.Auto then
        begin
          Inc(result[i], remaining);
          Break;
        end;
    end;
  end;

  // Squeeze if overshoot: shrink the widest auto/star column one cell at a time.
  totalFixed := overhead;
  for i := 0 to n - 1 do
    Inc(totalFixed, result[i]);

  while totalFixed > maxWidth do
  begin
    worstIdx := -1;
    worstWidth := 0;
    for i := 0 to n - 1 do
    begin
      if (FColumns[i].WidthKind <> TGridColumnWidth.Fixed) and (result[i] > worstWidth) then
      begin
        worstWidth := result[i];
        worstIdx := i;
      end;
    end;
    if (worstIdx < 0) or (worstWidth <= 1) then Break;
    Dec(result[worstIdx]);
    Dec(totalFixed);
  end;
end;

function TTable.TotalTableWidth(const widths : TArray<Integer>; hasVerticals : Boolean) : Integer;
var
  i : Integer;
begin
  result := 0;
  for i := 0 to High(widths) do
    Inc(result, widths[i] + 2); // cell content + 1-cell pad each side
  if hasVerticals then
    Inc(result, Length(widths) + 1);  // left border + (n-1) mids + right border
end;

function AlignLine(const line : TAnsiSegments; width : Integer; alignment : TAlignment) : TAnsiSegments;
var
  count, i : Integer;
  lineW    : Integer;
  pad      : Integer;
  leftPad, rightPad : Integer;

  procedure Push(const seg : TAnsiSegment);
  begin
    SetLength(result, count + 1);
    result[count] := seg;
    Inc(count);
  end;

begin
  SetLength(result, 0);
  count := 0;
  lineW := TotalCellCount(line);
  if lineW >= width then
  begin
    for i := 0 to High(line) do
      Push(line[i]);
    Exit;
  end;
  pad := width - lineW;
  case alignment of
    TAlignment.Center:
      begin
        leftPad  := pad div 2;
        rightPad := pad - leftPad;
      end;
    TAlignment.Right:
      begin
        leftPad  := pad;
        rightPad := 0;
      end;
  else
    leftPad  := 0;
    rightPad := pad;
  end;
  if leftPad > 0 then
    Push(TAnsiSegment.Whitespace(StringOfChar(' ', leftPad)));
  for i := 0 to High(line) do
    Push(line[i]);
  if rightPad > 0 then
    Push(TAnsiSegment.Whitespace(StringOfChar(' ', rightPad)));
end;

function TTable.Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
var
  widths : TArray<Integer>;
  w      : Integer;
begin
  widths := ComputeWidths(options, maxWidth);
  w := TotalTableWidth(widths, HasVerticalBorders);
  if w > maxWidth then w := maxWidth;
  result := TMeasurement.Create(w, w);
end;

function TTable.Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
var
  widths        : TArray<Integer>;
  n, i          : Integer;
  count         : Integer;
  totalWidth    : Integer;
  hasV          : Boolean;
  hasH          : Boolean;
  vLeft, vMid, vRight : Char;
  borderUnicode : Boolean;

  procedure Push(const seg : TAnsiSegment);
  begin
    SetLength(result, count + 1);
    result[count] := seg;
    Inc(count);
  end;

  procedure PushBorder(const s : string);
  begin
    if s <> '' then
      Push(TAnsiSegment.Text(s, FBorderStyle));
  end;

  procedure PushVertical(c : Char);
  begin
    PushBorder(c);
  end;

  procedure PushEdgeRow(leftPart, fillPart, midPart, rightPart : TTableBorderPart);
  var
    col       : Integer;
    leftCh    : Char;
    fillCh    : Char;
    midCh     : Char;
    rightCh   : Char;
    fillLine  : string;
  begin
    if not hasH then Exit;
    leftCh  := FBorder.GetPart(leftPart, borderUnicode);
    fillCh  := FBorder.GetPart(fillPart, borderUnicode);
    midCh   := FBorder.GetPart(midPart, borderUnicode);
    rightCh := FBorder.GetPart(rightPart, borderUnicode);
    // A border with no glyphs for this edge (Simple, Minimal, ... have no
    // top or bottom) has no line to draw - leave the row out rather than
    // emitting a line of spaces.
    if (leftCh = ' ') and (fillCh = ' ') and (midCh = ' ') and (rightCh = ' ') then Exit;
    PushBorder(leftCh);
    for col := 0 to n - 1 do
    begin
      fillLine := StringOfChar(fillCh, widths[col] + 2);
      PushBorder(fillLine);
      if col < n - 1 then
        PushBorder(midCh);
    end;
    PushBorder(rightCh);
    Push(TAnsiSegment.LineBreak);
  end;

  procedure PushCentreLine(const value : string; const titleStyle : TAnsiStyle);
  var
    rendered : TAnsiSegments;
    lines    : TArray<TAnsiSegments>;
    li, si   : Integer;
    lineW    : Integer;
    pad      : Integer;
    combined : TAnsiStyle;
  begin
    if value = '' then Exit;
    // Route through Markup so [bold]Title[/] etc. are honoured. Render with
    // MaxInt to suppress hard-wrap; we split on explicit line breaks only and
    // let any line wider than totalWidth overflow as-is (matches the
    // pre-markup behaviour). This keeps the title text contiguous so callers
    // can still substring-search for it.
    rendered := Markup(value).Render(options, MaxInt);
    if not titleStyle.IsPlain then
    begin
      // Combine the title style as base; explicit per-segment markup wins.
      for si := 0 to High(rendered) do
      begin
        if rendered[si].IsControlCode or rendered[si].IsLineBreak then Continue;
        combined := titleStyle.Combine(rendered[si].Style);
        if rendered[si].IsWhitespace then
          rendered[si] := TAnsiSegment.Whitespace(rendered[si].Value, combined)
        else
          rendered[si] := TAnsiSegment.Text(rendered[si].Value, combined);
      end;
    end;
    lines := SplitLines(rendered, MaxInt);
    for li := 0 to High(lines) do
    begin
      lineW := TotalCellCount(lines[li]);
      if lineW < totalWidth then
      begin
        pad := (totalWidth - lineW) div 2;
        if pad > 0 then
          Push(TAnsiSegment.Whitespace(StringOfChar(' ', pad)));
      end;
      for si := 0 to High(lines[li]) do
        Push(lines[li][si]);
      Push(TAnsiSegment.LineBreak);
    end;
  end;

  procedure RenderRowFromCells(const cells : TArray<TArray<TAnsiSegments>>;
                                 const alignments : TArray<TAlignment>);
  var
    rowHeight : Integer;
    cellIdx   : Integer;
    lineIdx   : Integer;
    blank     : TAnsiSegments;
    padded    : TAnsiSegments;
    s         : Integer;
  begin
    rowHeight := 0;
    for cellIdx := 0 to High(cells) do
      if Length(cells[cellIdx]) > rowHeight then
        rowHeight := Length(cells[cellIdx]);
    if rowHeight = 0 then rowHeight := 1;

    for lineIdx := 0 to rowHeight - 1 do
    begin
      if hasV then PushVertical(vLeft);
      for cellIdx := 0 to n - 1 do
      begin
        Push(TAnsiSegment.Whitespace(' '));  // left pad
        if lineIdx <= High(cells[cellIdx]) then
          padded := AlignLine(cells[cellIdx][lineIdx], widths[cellIdx], alignments[cellIdx])
        else
        begin
          SetLength(blank, 0);
          padded := AlignLine(blank, widths[cellIdx], alignments[cellIdx]);
        end;
        for s := 0 to High(padded) do
          Push(padded[s]);
        Push(TAnsiSegment.Whitespace(' '));  // right pad
        if hasV and (cellIdx < n - 1) then
          PushVertical(vMid);
      end;
      if hasV then PushVertical(vRight);
      Push(TAnsiSegment.LineBreak);
    end;
  end;

var
  headerRenderables : TArray<IRenderable>;
  cellLines         : TArray<TArray<TAnsiSegments>>;
  alignments        : TArray<TAlignment>;
  r, c              : Integer;
  childSegs         : TAnsiSegments;
  hasFooter         : Boolean;
  effMaxWidth       : Integer;
begin
  SetLength(result, 0);
  count := 0;
  n := Length(FColumns);
  if n = 0 then Exit;

  // FFixedWidth caps the table width independently of the surrounding
  // layout's maxWidth. We never grow past the caller's maxWidth, so it
  // acts as a "table never bigger than this" knob.
  effMaxWidth := maxWidth;
  if (FFixedWidth > 0) and (FFixedWidth < effMaxWidth) then
    effMaxWidth := FFixedWidth;

  widths := ComputeWidths(options, effMaxWidth);
  hasV := HasVerticalBorders;
  hasH := HasHorizontalBorders;
  totalWidth := TotalTableWidth(widths, hasV);
  // FUseSafeBorder=False forces unicode glyphs even on a non-unicode-capable
  // terminal (matches Spectre's UseSafeBorder semantics: the "safe" mode
  // downgrades to ASCII; turning it off keeps the unicode characters).
  borderUnicode := options.Unicode or (not FUseSafeBorder);
  if hasV then
  begin
    vLeft  := FBorder.GetPart(TTableBorderPart.CellLeft,  borderUnicode);
    vMid   := FBorder.GetPart(TTableBorderPart.CellMid,   borderUnicode);
    vRight := FBorder.GetPart(TTableBorderPart.CellRight, borderUnicode);
  end
  else
  begin
    vLeft  := ' ';
    vMid   := ' ';
    vRight := ' ';
  end;

  // Title (plain centered line above the table).
  if FTitle <> '' then
    PushCentreLine(FTitle, FTitleStyle);

  // Top edge
  PushEdgeRow(TTableBorderPart.TopLeft, TTableBorderPart.Top, TTableBorderPart.TopMid, TTableBorderPart.TopRight);

  // Header row
  if FShowHeader then
  begin
    SetLength(headerRenderables, n);
    for i := 0 to n - 1 do
      headerRenderables[i] := Markup(FColumns[i].Header);

    SetLength(cellLines, n);
    SetLength(alignments, n);
    for i := 0 to n - 1 do
    begin
      childSegs := headerRenderables[i].Render(options, widths[i]);
      if FColumns[i].NoWrap then
      begin
        cellLines[i] := SplitLines(childSegs, MaxInt);
        for c := 0 to High(cellLines[i]) do
          cellLines[i][c] := CropLineToWidth(cellLines[i][c], widths[i], False);
      end
      else
        cellLines[i] := SplitLines(childSegs, widths[i]);
      alignments[i] := FColumns[i].Alignment;
    end;
    RenderRowFromCells(cellLines, alignments);

    // Header separator
    // Emit regardless of hasH when we have any border (so Markdown gets its
    // '---' separator).
    if FBorder.Kind = TTableBorderKind.Markdown then
    begin
      // Markdown-style: '|---|---|...'
      PushBorder(FBorder.GetPart(TTableBorderPart.HeadLeft, borderUnicode));
      for c := 0 to n - 1 do
      begin
        PushBorder(StringOfChar(FBorder.GetPart(TTableBorderPart.Head, borderUnicode), widths[c] + 2));
        if c < n - 1 then
          PushBorder(FBorder.GetPart(TTableBorderPart.HeadMid, borderUnicode));
      end;
      PushBorder(FBorder.GetPart(TTableBorderPart.HeadRight, borderUnicode));
      Push(TAnsiSegment.LineBreak);
    end
    else if hasH then
      PushEdgeRow(TTableBorderPart.HeadLeft, TTableBorderPart.Head, TTableBorderPart.HeadMid, TTableBorderPart.HeadRight);
  end;

  // Data rows
  for r := 0 to High(FRows) do
  begin
    SetLength(cellLines, n);
    SetLength(alignments, n);
    for c := 0 to n - 1 do
    begin
      if (c <= High(FRows[r])) and (FRows[r][c] <> nil) then
      begin
        if FColumns[c].NoWrap then
        begin
          cellLines[c] := SplitLines(FRows[r][c].Render(options, widths[c]), MaxInt);
          for i := 0 to High(cellLines[c]) do
            cellLines[c][i] := CropLineToWidth(cellLines[c][i], widths[c], False);
        end
        else
          cellLines[c] := SplitLines(FRows[r][c].Render(options, widths[c]), widths[c]);
      end
      else
        SetLength(cellLines[c], 0);
      alignments[c] := FColumns[c].Alignment;
    end;
    RenderRowFromCells(cellLines, alignments);

    // Inter-row separator (using header-bottom glyphs). Skipped after the
    // last row because the bottom edge follows immediately.
    if FShowRowSeparators and hasH and (r < High(FRows)) then
      PushEdgeRow(TTableBorderPart.HeadLeft, TTableBorderPart.Head, TTableBorderPart.HeadMid, TTableBorderPart.HeadRight);
  end;

  // Footer row (per-column FColumn.Footer text) if requested AND at least
  // one column has a footer string set.
  hasFooter := False;
  if FShowFooters then
    for c := 0 to n - 1 do
      if FColumns[c].Footer <> '' then
      begin
        hasFooter := True;
        Break;
      end;

  if hasFooter then
  begin
    // Separator before footer
    if hasH then
      PushEdgeRow(TTableBorderPart.HeadLeft, TTableBorderPart.Head, TTableBorderPart.HeadMid, TTableBorderPart.HeadRight);

    SetLength(cellLines, n);
    SetLength(alignments, n);
    for c := 0 to n - 1 do
    begin
      if FColumns[c].NoWrap then
      begin
        cellLines[c] := SplitLines(Markup(FColumns[c].Footer).Render(options, widths[c]), MaxInt);
        for i := 0 to High(cellLines[c]) do
          cellLines[c][i] := CropLineToWidth(cellLines[c][i], widths[c], False);
      end
      else
        cellLines[c] := SplitLines(Markup(FColumns[c].Footer).Render(options, widths[c]),
                                    widths[c]);
      alignments[c] := FColumns[c].Alignment;
    end;
    RenderRowFromCells(cellLines, alignments);
  end;

  // Bottom edge
  PushEdgeRow(TTableBorderPart.BottomLeft, TTableBorderPart.Bottom, TTableBorderPart.BottomMid, TTableBorderPart.BottomRight);

  if FCaption <> '' then
    PushCentreLine(FCaption, FCaptionStyle);

  // Trim trailing line break so the widget behaves like other widgets.
  if (count > 0) and result[count - 1].IsLineBreak then
  begin
    SetLength(result, count - 1);
    Dec(count);
  end;
end;

end.

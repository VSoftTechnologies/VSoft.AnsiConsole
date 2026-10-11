unit VSoft.AnsiConsole.Widgets.Text;

{
  TText - the simplest IRenderable: a block of plain (unstyled or uniformly-
  styled) text. Splits on explicit line breaks and word-wraps to maxWidth;
  only a word wider than the whole line is broken mid-word.
}

interface

uses
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Style,
  VSoft.AnsiConsole.Segment,
  VSoft.AnsiConsole.Measurement,
  VSoft.AnsiConsole.Rendering;

type
  IText = interface(IRenderable)
    ['{7A5F2A78-3D62-4A85-B4E2-FAE8C8D1D0BA}']
    function GetValue : string;
    function GetStyle : TAnsiStyle;
    function GetAlignment : TAlignment;
    function GetOverflow : TOverflow;

    function WithStyle(const value : TAnsiStyle) : IText;
    function WithAlignment(value : TAlignment) : IText;
    function WithOverflow(value : TOverflow) : IText;

    property Value     : string     read GetValue;
    property Style     : TAnsiStyle read GetStyle;
    property Alignment : TAlignment read GetAlignment;
    property Overflow  : TOverflow  read GetOverflow;
  end;

  TText = class(TInterfacedObject, IRenderable, IText)
  strict private
    FValue     : string;
    FStyle     : TAnsiStyle;
    FAlignment : TAlignment;
    FOverflow  : TOverflow;
    function  GetValue : string;
    function  GetStyle : TAnsiStyle;
    function  GetAlignment : TAlignment;
    function  GetOverflow : TOverflow;
  public
    constructor Create(const value : string); overload;
    constructor Create(const value : string; const style : TAnsiStyle); overload;
    function Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
    function Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
    function WithStyle(const value : TAnsiStyle) : IText;
    function WithAlignment(value : TAlignment) : IText;
    function WithOverflow(value : TOverflow) : IText;
  end;

function Text(const value : string) : IText; overload;
function Text(const value : string; const style : TAnsiStyle) : IText; overload;

implementation

uses
  VSoft.AnsiConsole.Internal.Cell,
  VSoft.AnsiConsole.Internal.SegmentOps;

function Text(const value : string) : IText;
begin
  result := TText.Create(value);
end;

function Text(const value : string; const style : TAnsiStyle) : IText;
begin
  result := TText.Create(value, style);
end;

{ TText }

constructor TText.Create(const value : string);
begin
  inherited Create;
  FValue     := value;
  FStyle     := TAnsiStyle.Plain;
  FAlignment := TAlignment.Left;
  FOverflow  := TOverflow.Fold;
end;

constructor TText.Create(const value : string; const style : TAnsiStyle);
begin
  inherited Create;
  FValue     := value;
  FStyle     := style;
  FAlignment := TAlignment.Left;
  FOverflow  := TOverflow.Fold;
end;

function TText.GetValue : string;
begin
  result := FValue;
end;

function TText.GetStyle : TAnsiStyle;
begin
  result := FStyle;
end;

function TText.GetAlignment : TAlignment;
begin
  result := FAlignment;
end;

function TText.GetOverflow : TOverflow;
begin
  result := FOverflow;
end;

function TText.WithStyle(const value : TAnsiStyle) : IText;
var
  t : TText;
begin
  t := TText.Create(FValue, value);
  t.FAlignment := FAlignment;
  t.FOverflow  := FOverflow;
  result := t;
end;

function TText.WithAlignment(value : TAlignment) : IText;
var
  t : TText;
begin
  t := TText.Create(FValue, FStyle);
  t.FAlignment := value;
  t.FOverflow  := FOverflow;
  result := t;
end;

function TText.WithOverflow(value : TOverflow) : IText;
var
  t : TText;
begin
  t := TText.Create(FValue, FStyle);
  t.FAlignment := FAlignment;
  t.FOverflow  := value;
  result := t;
end;

function LongestLineCellLength(const s : string) : Integer;
var
  i      : Integer;
  cur    : Integer;
  maxLen : Integer;
  ch     : Char;
begin
  cur := 0;
  maxLen := 0;
  for i := 1 to Length(s) do
  begin
    ch := s[i];
    if ch = #10 then
    begin
      if cur > maxLen then maxLen := cur;
      cur := 0;
    end
    else if ch = #13 then
    begin
      // skip
    end
    else
      Inc(cur, CellLengthChar(ch));
  end;
  if cur > maxLen then maxLen := cur;
  result := maxLen;
end;

function LongestWordCellLength(const s : string) : Integer;
var
  i      : Integer;
  cur    : Integer;
  maxLen : Integer;
  ch     : Char;
begin
  cur := 0;
  maxLen := 0;
  for i := 1 to Length(s) do
  begin
    ch := s[i];
    if (ch = ' ') or (ch = #9) or (ch = #10) or (ch = #13) then
    begin
      if cur > maxLen then maxLen := cur;
      cur := 0;
    end
    else
      Inc(cur, CellLengthChar(ch));
  end;
  if cur > maxLen then maxLen := cur;
  result := maxLen;
end;

function TText.Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
var
  minW, maxW : Integer;
begin
  minW := LongestWordCellLength(FValue);
  maxW := LongestLineCellLength(FValue);
  if (maxWidth > 0) and (minW > maxWidth) then
    minW := maxWidth;
  if (maxWidth > 0) and (maxW > maxWidth) then
    maxW := maxWidth;
  result := TMeasurement.Create(minW, maxW);
end;

function TText.Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
var
  i, j       : Integer;
  ch         : Char;
  buf        : string;
  raw        : TAnsiSegments;
  lines      : TArray<TAnsiSegments>;
  line       : TAnsiSegments;
  count      : Integer;
  lineWidth  : Integer;
  pad        : Integer;
  leftPad    : Integer;
  rightPad   : Integer;
  emptyLine  : Boolean;
begin
  // 1. Build a raw segment list from FValue, splitting on line breaks.
  SetLength(raw, 0);
  count := 0;
  buf := '';
  for i := 1 to Length(FValue) do
  begin
    ch := FValue[i];
    if ch = #10 then
    begin
      if buf <> '' then
      begin
        SetLength(raw, count + 1);
        raw[count] := TAnsiSegment.Text(buf, FStyle);
        Inc(count);
        buf := '';
      end;
      SetLength(raw, count + 1);
      raw[count] := TAnsiSegment.LineBreak;
      Inc(count);
    end
    else if ch = #13 then
    begin
      // swallow CR; LF drives the break
    end
    else
      buf := buf + ch;
  end;
  if buf <> '' then
  begin
    SetLength(raw, count + 1);
    raw[count] := TAnsiSegment.Text(buf, FStyle);
    Inc(count);
  end;
  SetLength(raw, count);

  // 2. Word-wrap or crop based on FOverflow.
  if maxWidth <= 0 then
    maxWidth := MaxInt;
  case FOverflow of
    TOverflow.Crop, TOverflow.Ellipsis:
    begin
      lines := SplitLines(raw, MaxInt);  // line break only
      for i := 0 to High(lines) do
        lines[i] := CropLineToWidth(lines[i], maxWidth, FOverflow = TOverflow.Ellipsis);
    end;
  else
    lines := WrapLines(raw, maxWidth);  // TOverflow.Fold default
  end;

  // 3. Apply alignment by padding each line.
  SetLength(result, 0);
  count := 0;
  for i := 0 to High(lines) do
  begin
    line := lines[i];
    lineWidth := TotalCellCount(line);
    emptyLine := (Length(line) = 0);

    if (FAlignment = TAlignment.Left) or (lineWidth >= maxWidth) or emptyLine then
    begin
      // emit line as-is
      for j := 0 to High(line) do
      begin
        SetLength(result, count + 1);
        result[count] := line[j];
        Inc(count);
      end;
    end
    else
    begin
      pad := maxWidth - lineWidth;
      if FAlignment = TAlignment.Center then
      begin
        leftPad  := pad div 2;
        rightPad := pad - leftPad;
      end
      else // TAlignment.Right
      begin
        leftPad  := pad;
        rightPad := 0;
      end;

      if leftPad > 0 then
      begin
        SetLength(result, count + 1);
        result[count] := TAnsiSegment.Whitespace(StringOfChar(' ', leftPad));
        Inc(count);
      end;
      for j := 0 to High(line) do
      begin
        SetLength(result, count + 1);
        result[count] := line[j];
        Inc(count);
      end;
      if rightPad > 0 then
      begin
        SetLength(result, count + 1);
        result[count] := TAnsiSegment.Whitespace(StringOfChar(' ', rightPad));
        Inc(count);
      end;
    end;

    // insert explicit linebreak between lines (not after the last)
    if i < High(lines) then
    begin
      SetLength(result, count + 1);
      result[count] := TAnsiSegment.LineBreak;
      Inc(count);
    end;
  end;

  SetLength(result, count);
end;

end.

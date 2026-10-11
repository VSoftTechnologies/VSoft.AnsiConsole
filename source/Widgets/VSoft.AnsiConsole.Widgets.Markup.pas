unit VSoft.AnsiConsole.Widgets.Markup;

{
  TMarkupWidget - renders a string of markup (e.g. "[red bold]hi[/]") as
  styled segments. Parses once on construction; Measure and Render re-use
  the cached segments.
}

interface

uses
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Style,
  VSoft.AnsiConsole.Segment,
  VSoft.AnsiConsole.Measurement,
  VSoft.AnsiConsole.Rendering;

type
  IMarkup = interface(IRenderable)
    ['{1E5C1F6C-5A80-4DBE-864F-53B0E0BCE6C0}']
    function GetSource : string;
    function GetAlignment : TAlignment;
    function GetOverflow : TOverflow;
    function GetLength : Integer;
    function GetLines : Integer;
    function WithAlignment(value : TAlignment) : IMarkup;
    function WithOverflow(value : TOverflow) : IMarkup;
    property Source    : string     read GetSource;
    property Alignment : TAlignment read GetAlignment;
    property Overflow  : TOverflow  read GetOverflow;
    { Total raw character count across all text segments (control codes
      and line breaks excluded). Mirrors Spectre.Console's Markup.Length. }
    property Length    : Integer    read GetLength;
    { Logical line count (1 + number of explicit line-break segments).
      Empty markup returns 0. Mirrors Spectre.Console's Markup.Lines. }
    property Lines     : Integer    read GetLines;
  end;

  TMarkupWidget = class(TInterfacedObject, IRenderable, IMarkup)
  strict private
    FSource    : string;
    FAlignment : TAlignment;
    FOverflow  : TOverflow;
    FSegments  : TAnsiSegments;   // cached parse result
    function  GetSource : string;
    function  GetAlignment : TAlignment;
    function  GetOverflow : TOverflow;
    function  GetLength : Integer;
    function  GetLines : Integer;
  public
    constructor Create(const source : string); overload;
    constructor Create(const source : string; const baseStyle : TAnsiStyle); overload;
    function Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
    function Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
    function WithAlignment(value : TAlignment) : IMarkup;
    function WithOverflow(value : TOverflow) : IMarkup;
  end;

function Markup(const source : string) : IMarkup; overload;
function Markup(const source : string; const baseStyle : TAnsiStyle) : IMarkup; overload;

{ Escape markup metacharacters. Both '[' and ']' must be doubled - the
  tokenizer treats an unescaped ']' as an error, not just '['. Useful
  when interpolating user input into markup strings. }
function EscapeMarkup(const value : string) : string;

implementation

uses
  VSoft.AnsiConsole.Markup.Parser,
  VSoft.AnsiConsole.Internal.SegmentOps,
  VSoft.AnsiConsole.Internal.Cell;

function Markup(const source : string) : IMarkup;
begin
  result := TMarkupWidget.Create(source);
end;

function Markup(const source : string; const baseStyle : TAnsiStyle) : IMarkup;
begin
  result := TMarkupWidget.Create(source, baseStyle);
end;

function EscapeMarkup(const value : string) : string;
var
  i : Integer;
  ch : Char;
begin
  result := '';
  // Spectre's rule: "[" -> "[[" and "]" -> "]]" so the parser sees a
  // literal bracket. Both must be escaped - the tokenizer raises on an
  // unescaped ']' just as it does on an unterminated '['. Pascal-style
  // string concatenation is fine for the prompt/title strings this is
  // typically used on.
  for i := 1 to Length(value) do
  begin
    ch := value[i];
    if ch = '[' then
      result := result + '[['
    else if ch = ']' then
      result := result + ']]'
    else
      result := result + ch;
  end;
end;

{ TMarkupWidget }

constructor TMarkupWidget.Create(const source : string);
begin
  Create(source, TAnsiStyle.Plain);
end;

constructor TMarkupWidget.Create(const source : string; const baseStyle : TAnsiStyle);
begin
  inherited Create;
  FSource    := source;
  FAlignment := TAlignment.Left;
  FOverflow  := TOverflow.Fold;
  FSegments  := ParseMarkup(source, baseStyle);
end;

function TMarkupWidget.GetSource : string;
begin
  result := FSource;
end;

function TMarkupWidget.GetAlignment : TAlignment;
begin
  result := FAlignment;
end;

function TMarkupWidget.GetOverflow : TOverflow;
begin
  result := FOverflow;
end;

function TMarkupWidget.GetLength : Integer;
var
  i : Integer;
begin
  result := 0;
  for i := 0 to System.Length(FSegments) - 1 do
    if not (FSegments[i].IsControlCode or FSegments[i].IsLineBreak) then
      Inc(result, System.Length(FSegments[i].Value));
end;

function TMarkupWidget.GetLines : Integer;
var
  i : Integer;
begin
  if System.Length(FSegments) = 0 then
  begin
    result := 0;
    Exit;
  end;
  result := 1;
  for i := 0 to System.Length(FSegments) - 1 do
    if FSegments[i].IsLineBreak then
      Inc(result);
end;

function TMarkupWidget.WithAlignment(value : TAlignment) : IMarkup;
var
  m : TMarkupWidget;
begin
  m := TMarkupWidget.Create(FSource);
  m.FSegments  := FSegments;
  m.FAlignment := value;
  m.FOverflow  := FOverflow;
  result := m;
end;

function TMarkupWidget.WithOverflow(value : TOverflow) : IMarkup;
var
  m : TMarkupWidget;
begin
  m := TMarkupWidget.Create(FSource);
  m.FSegments  := FSegments;
  m.FAlignment := FAlignment;
  m.FOverflow  := value;
  result := m;
end;

function TMarkupWidget.Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
var
  maxW : Integer;
begin
  maxW := TotalCellCount(FSegments);
  if (maxWidth > 0) and (maxW > maxWidth) then
    maxW := maxWidth;
  // Without a word-aware scan we treat the whole text as the "minimum".
  // This is a safe upper bound on the min width.
  result := TMeasurement.Create(1, maxW);
end;

function TMarkupWidget.Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
var
  lines : TArray<TAnsiSegments>;
  i, j  : Integer;
  count : Integer;
begin
  if maxWidth <= 0 then
    maxWidth := MaxInt;

  case FOverflow of
    TOverflow.Crop, TOverflow.Ellipsis:
    begin
      // Split on explicit line breaks only; truncate each line that
      // exceeds maxWidth (with or without trailing ellipsis).
      lines := SplitLines(FSegments, MaxInt);
      for i := 0 to High(lines) do
        lines[i] := CropLineToWidth(lines[i], maxWidth, FOverflow = TOverflow.Ellipsis);
    end;
  else
    // TOverflow.Fold: word-wrap at maxWidth.
    lines := WrapLines(FSegments, maxWidth);
  end;

  SetLength(result, 0);
  count := 0;
  for i := 0 to High(lines) do
  begin
    for j := 0 to High(lines[i]) do
    begin
      SetLength(result, count + 1);
      result[count] := lines[i][j];
      Inc(count);
    end;
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

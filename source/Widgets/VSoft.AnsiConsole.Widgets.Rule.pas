unit VSoft.AnsiConsole.Widgets.Rule;

{
  TRule - a horizontal divider line, optionally with a title.

       ─────── Section ───────

  Falls back to ASCII ('-' + ' text ') when the terminal does not support
  Unicode. The title (if present) is markup, styled and aligned; the border
  characters take the rule's style, which is also the title's base style.
}

{$SCOPEDENUMS ON}

interface

uses
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Style,
  VSoft.AnsiConsole.Segment,
  VSoft.AnsiConsole.Measurement,
  VSoft.AnsiConsole.Rendering;

type
  TRuleBorder = (Default, Ascii, Heavy, Double);

  IRule = interface(IRenderable)
    ['{4FFA68E3-2C5C-41C0-8A3B-FCF5C5C2F70E}']
    function GetTitle : string;
    function GetStyle : TAnsiStyle;
    function GetAlignment : TAlignment;
    function GetBorder : TRuleBorder;
    function WithTitle(const value : string) : IRule;
    function WithStyle(const value : TAnsiStyle) : IRule;
    function WithAlignment(value : TAlignment) : IRule;
    function WithBorder(value : TRuleBorder) : IRule;
    property Title     : string      read GetTitle;
    property Style     : TAnsiStyle  read GetStyle;
    property Alignment : TAlignment  read GetAlignment;
    property Border    : TRuleBorder read GetBorder;
  end;

  TRule = class(TInterfacedObject, IRenderable, IRule)
  strict private
    FTitle     : string;
    FStyle     : TAnsiStyle;
    FAlignment : TAlignment;
    FBorder    : TRuleBorder;
    function  GetTitle : string;
    function  GetStyle : TAnsiStyle;
    function  GetAlignment : TAlignment;
    function  GetBorder : TRuleBorder;
    function  Clone : TRule;
    function  BorderChar(unicode : Boolean) : Char;
  public
    constructor Create; overload;
    constructor Create(const title : string); overload;
    function Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
    function Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
    function WithTitle(const value : string) : IRule;
    function WithStyle(const value : TAnsiStyle) : IRule;
    function WithAlignment(value : TAlignment) : IRule;
    function WithBorder(value : TRuleBorder) : IRule;
  end;

function Rule : IRule; overload;
function Rule(const title : string) : IRule; overload;

implementation

uses
  VSoft.AnsiConsole.Markup.Parser,
  VSoft.AnsiConsole.Internal.SegmentOps;

function Rule : IRule;
begin
  result := TRule.Create;
end;

function Rule(const title : string) : IRule;
begin
  result := TRule.Create(title);
end;

{ TRule }

constructor TRule.Create;
begin
  inherited Create;
  FTitle     := '';
  FStyle     := TAnsiStyle.Plain;
  FAlignment := TAlignment.Center;
  FBorder    := TRuleBorder.Default;
end;

constructor TRule.Create(const title : string);
begin
  Create;
  FTitle := title;
end;

function TRule.GetTitle : string;     begin result := FTitle; end;
function TRule.GetStyle : TAnsiStyle; begin result := FStyle; end;
function TRule.GetAlignment : TAlignment; begin result := FAlignment; end;
function TRule.GetBorder : TRuleBorder;   begin result := FBorder; end;

function TRule.Clone : TRule;
begin
  result := TRule.Create(FTitle);
  result.FStyle     := FStyle;
  result.FAlignment := FAlignment;
  result.FBorder    := FBorder;
end;

function TRule.WithTitle(const value : string) : IRule;
var
  r : TRule;
begin
  r := Clone;
  r.FTitle := value;
  result := r;
end;

function TRule.WithStyle(const value : TAnsiStyle) : IRule;
var
  r : TRule;
begin
  r := Clone;
  r.FStyle := value;
  result := r;
end;

function TRule.WithAlignment(value : TAlignment) : IRule;
var
  r : TRule;
begin
  r := Clone;
  r.FAlignment := value;
  result := r;
end;

function TRule.WithBorder(value : TRuleBorder) : IRule;
var
  r : TRule;
begin
  r := Clone;
  r.FBorder := value;
  result := r;
end;

function TRule.BorderChar(unicode : Boolean) : Char;
begin
  if not unicode then
  begin
    result := '-';
    Exit;
  end;
  case FBorder of
    TRuleBorder.Ascii  : result := '-';
    TRuleBorder.Heavy  : result := #$2501;  // ━
    TRuleBorder.Double : result := #$2550;  // ═
  else
    result := #$2500;              // ─
  end;
end;

function TRule.Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
begin
  // A rule wants as much width as the container can provide.
  if maxWidth <= 0 then
    maxWidth := 1;
  result := TMeasurement.Create(1, maxWidth);
end;

function TRule.Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
var
  width      : Integer;
  ch         : Char;
  borderStr  : string;
  titleLen   : Integer;
  titleSegs  : TAnsiSegments;
  titlePart  : TAnsiSegments;
  leftCount  : Integer;
  rightCount : Integer;
  count      : Integer;
  i          : Integer;

  procedure Push(const seg : TAnsiSegment);
  begin
    SetLength(result, count + 1);
    result[count] := seg;
    Inc(count);
  end;

begin
  if maxWidth <= 0 then
    maxWidth := 80;
  width := maxWidth;
  ch := BorderChar(options.Unicode);

  SetLength(result, 0);
  count := 0;

  // The title is markup, with the rule's style as its base style.
  if FTitle <> '' then
    titleSegs := ParseMarkup(FTitle, FStyle)
  else
    SetLength(titleSegs, 0);

  if TotalCellCount(titleSegs) = 0 then
  begin
    Push(TAnsiSegment.Text(StringOfChar(ch, width), FStyle));
    Exit;
  end;

  // Surround title with single-space padding; ensure we still have room.
  // The title sits on the rule line, so a line break in it becomes a space.
  SetLength(titlePart, Length(titleSegs) + 2);
  titlePart[0] := TAnsiSegment.Text(' ', FStyle);
  for i := 0 to High(titleSegs) do
  begin
    if titleSegs[i].IsLineBreak then
      titlePart[i + 1] := TAnsiSegment.Text(' ', FStyle)
    else
      titlePart[i + 1] := titleSegs[i];
  end;
  titlePart[High(titlePart)] := TAnsiSegment.Text(' ', FStyle);

  titleLen := TotalCellCount(titlePart);
  if titleLen + 2 > width then
  begin
    // No room for title + any border - just the title, clipped.
    titlePart := CropLineToWidth(titlePart, width, False);
    for i := 0 to High(titlePart) do
      Push(titlePart[i]);
    Exit;
  end;

  case FAlignment of
    TAlignment.Left:
      begin
        leftCount  := 2;
        rightCount := width - titleLen - leftCount;
      end;
    TAlignment.Right:
      begin
        rightCount := 2;
        leftCount  := width - titleLen - rightCount;
      end;
  else
    leftCount  := (width - titleLen) div 2;
    rightCount := width - titleLen - leftCount;
  end;

  if leftCount > 0 then
  begin
    borderStr := StringOfChar(ch, leftCount);
    Push(TAnsiSegment.Text(borderStr, FStyle));
  end;

  for i := 0 to High(titlePart) do
    Push(titlePart[i]);

  if rightCount > 0 then
  begin
    borderStr := StringOfChar(ch, rightCount);
    Push(TAnsiSegment.Text(borderStr, FStyle));
  end;
end;

end.

unit VSoft.AnsiConsole.Widgets.Paragraph;

{
  TParagraph - a block of text where individual spans can have their own
  style. Unlike Text (uniform style) or Markup (parsed once), Paragraph is
  programmatically built up via Append(text, style) calls:

    para := Paragraph;
    para.Append('The quick ');
    para.Append('brown', TAnsiStyle.Plain.WithForeground(TAnsiColor.Yellow));
    para.Append(' fox jumps.');

  Rendering: text is concatenated in append order, explicit '\n' in the text
  starts a new line, and lines wrap at maxWidth. WithAlignment + WithOverflow
  mirror the Text widget options.
}

interface

uses
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Style,
  VSoft.AnsiConsole.Segment,
  VSoft.AnsiConsole.Measurement,
  VSoft.AnsiConsole.Rendering;

type
  IParagraph = interface(IRenderable)
    ['{C3E6B1F4-8A2D-4B5E-9F20-1D8A3B4C5D60}']
    function Append(const text : string) : IParagraph; overload;
    function Append(const text : string; const style : TAnsiStyle) : IParagraph; overload;
    function WithAlignment(value : TAlignment) : IParagraph;
    function WithOverflow(value : TOverflow) : IParagraph;
    function GetAlignment : TAlignment;
    function GetOverflow : TOverflow;
    property Alignment : TAlignment read GetAlignment;
    property Overflow  : TOverflow  read GetOverflow;
  end;

  TParagraph = class(TInterfacedObject, IRenderable, IParagraph)
  strict private
    FSegments  : TAnsiSegments;
    FAlignment : TAlignment;
    FOverflow  : TOverflow;
    function GetAlignment : TAlignment;
    function GetOverflow  : TOverflow;
    procedure PushSegment(const seg : TAnsiSegment);
  public
    constructor Create;
    function Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
    function Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
    function Append(const text : string) : IParagraph; overload;
    function Append(const text : string; const style : TAnsiStyle) : IParagraph; overload;
    function WithAlignment(value : TAlignment) : IParagraph;
    function WithOverflow(value : TOverflow) : IParagraph;
  end;

function Paragraph : IParagraph; overload;
function Paragraph(const text : string) : IParagraph; overload;
function Paragraph(const text : string; const style : TAnsiStyle) : IParagraph; overload;

implementation

uses
  System.SysUtils,
  VSoft.AnsiConsole.Internal.SegmentOps;

function Paragraph : IParagraph;
begin
  result := TParagraph.Create;
end;

function Paragraph(const text : string) : IParagraph;
begin
  result := TParagraph.Create;
  result.Append(text);
end;

function Paragraph(const text : string; const style : TAnsiStyle) : IParagraph;
begin
  result := TParagraph.Create;
  result.Append(text, style);
end;

{ TParagraph }

constructor TParagraph.Create;
begin
  inherited Create;
  FAlignment := TAlignment.Left;
  FOverflow  := TOverflow.Fold;
end;

function TParagraph.GetAlignment : TAlignment;
begin result := FAlignment; end;

function TParagraph.GetOverflow : TOverflow;
begin result := FOverflow; end;

procedure TParagraph.PushSegment(const seg : TAnsiSegment);
begin
  SetLength(FSegments, Length(FSegments) + 1);
  FSegments[High(FSegments)] := seg;
end;

function TParagraph.Append(const text : string) : IParagraph;
begin
  result := Append(text, TAnsiStyle.Plain);
end;

function TParagraph.Append(const text : string; const style : TAnsiStyle) : IParagraph;
var
  i    : Integer;
  ch   : Char;
  buf  : string;

  procedure Flush;
  begin
    if buf <> '' then
    begin
      PushSegment(TAnsiSegment.Text(buf, style));
      buf := '';
    end;
  end;

begin
  // Split on '\n'; insert explicit LineBreak segments so the render path
  // can preserve the paragraph's line structure. '\r' is swallowed.
  buf := '';
  for i := 1 to Length(text) do
  begin
    ch := text[i];
    if ch = #10 then
    begin
      Flush;
      PushSegment(TAnsiSegment.LineBreak);
    end
    else if ch <> #13 then
      buf := buf + ch;
  end;
  Flush;
  result := Self;
end;

function TParagraph.WithAlignment(value : TAlignment) : IParagraph;
begin FAlignment := value; result := Self; end;

function TParagraph.WithOverflow(value : TOverflow) : IParagraph;
begin FOverflow := value; result := Self; end;

function TParagraph.Measure(const options : TRenderOptions; maxWidth : Integer) : TMeasurement;
var
  maxW : Integer;
begin
  maxW := TotalCellCount(FSegments);
  if (maxWidth > 0) and (maxW > maxWidth) then
    maxW := maxWidth;
  result := TMeasurement.Create(1, maxW);
end;

function TParagraph.Render(const options : TRenderOptions; maxWidth : Integer) : TAnsiSegments;
var
  lines    : TArray<TAnsiSegments>;
  i, j     : Integer;
  count    : Integer;
  lineW    : Integer;
  pad, lp, rp : Integer;
begin
  SetLength(result, 0);
  count := 0;
  if maxWidth <= 0 then
    maxWidth := MaxInt;
  case FOverflow of
    TOverflow.Crop, TOverflow.Ellipsis:
    begin
      lines := SplitLines(FSegments, MaxInt);
      for i := 0 to High(lines) do
        lines[i] := CropLineToWidth(lines[i], maxWidth, FOverflow = TOverflow.Ellipsis);
    end;
  else
    lines := WrapLines(FSegments, maxWidth);
  end;

  for i := 0 to High(lines) do
  begin
    lineW := TotalCellCount(lines[i]);

    // Horizontal alignment padding.
    if (FAlignment <> TAlignment.Left) and (lineW < maxWidth) then
    begin
      pad := maxWidth - lineW;
      if FAlignment = TAlignment.Center then
      begin
        lp := pad div 2;
        rp := pad - lp;
      end
      else
      begin
        lp := pad;
        rp := 0;
      end;

      if lp > 0 then
      begin
        SetLength(result, count + 1);
        result[count] := TAnsiSegment.Whitespace(StringOfChar(' ', lp));
        Inc(count);
      end;
      for j := 0 to High(lines[i]) do
      begin
        SetLength(result, count + 1);
        result[count] := lines[i][j];
        Inc(count);
      end;
      if rp > 0 then
      begin
        SetLength(result, count + 1);
        result[count] := TAnsiSegment.Whitespace(StringOfChar(' ', rp));
        Inc(count);
      end;
    end
    else
    begin
      for j := 0 to High(lines[i]) do
      begin
        SetLength(result, count + 1);
        result[count] := lines[i][j];
        Inc(count);
      end;
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

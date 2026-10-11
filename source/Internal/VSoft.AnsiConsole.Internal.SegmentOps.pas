unit VSoft.AnsiConsole.Internal.SegmentOps;

{
  Segment array operations: measurement, splitting, merging, line-wrapping.
  These are pure functions - they return new arrays rather than mutating.
}

interface

uses
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Style,
  VSoft.AnsiConsole.Segment;

{ Cell width of a single non-linebreak segment. }
function SegmentCellCount(const seg : TAnsiSegment) : Integer;

{ Cell width of a segment array, treating line breaks as resetting to zero
  (i.e. returns the width of the longest line). }
function TotalCellCount(const segs : TAnsiSegments) : Integer;

{ Split a text or whitespace segment at a cell offset. ControlCode and
  LineBreak segments are returned unchanged as `left`, and `right` is empty. }
procedure SplitSegmentAt(const seg : TAnsiSegment; cellOffset : Integer;
                          out left, right : TAnsiSegment);

{ Coalesce adjacent text segments that share the same style. Whitespace,
  line-break and control-code segments are left as independent items. }
function MergeSegments(const segs : TAnsiSegments) : TAnsiSegments;

{ Break segments into an array of lines. A line ends at an TAnsiSegmentFlag.LineBreak segment
  or when the running cell-width reaches maxWidth (hard wrap). Segments wider
  than maxWidth are split at the boundary. Returns an array of per-line
  segment arrays (the trailing linebreak segment is not included in each line).

  This is a hard character wrap - it is what containers use to slice a
  child's already-rendered output into rows. Text-like widgets wrap their own
  content with WrapLines. }
function SplitLines(const segs : TAnsiSegments; maxWidth : Integer) : TArray<TAnsiSegments>;

{ Break segments into lines no wider than maxWidth, breaking between words.
  Explicit TAnsiSegmentFlag.LineBreak segments end a line exactly as they do
  in SplitLines. A line that is too wide ends at the whitespace before the
  first word that does not fit, and that whitespace is consumed by the wrap:
  it neither trails the line it ends nor leads the line it starts. Whitespace
  anywhere else (indentation, gaps between words that share a line) is
  content and is kept.

  A word is a run of non-whitespace cells; it may span several segments, so a
  style change inside a word is not a break opportunity. A word wider than
  maxWidth on its own starts a new line and is hard-wrapped from there. }
function WrapLines(const segs : TAnsiSegments; maxWidth : Integer) : TArray<TAnsiSegments>;

{ Truncate a single line to maxWidth cells. If the line already fits the
  function returns it unchanged. If `addEllipsis` is True and the line had
  to be cropped, an ellipsis ('...') is appended (using the trailing
  segment's style); the truncation budget shrinks by the ellipsis width
  so the result fits in maxWidth. }
function CropLineToWidth(const line : TAnsiSegments; maxWidth : Integer;
                          addEllipsis : Boolean) : TAnsiSegments;

implementation

uses
  VSoft.AnsiConsole.Internal.Cell;

function SegmentCellCount(const seg : TAnsiSegment) : Integer;
begin
  if seg.IsLineBreak or seg.IsControlCode then
    result := 0
  else
    result := CellLength(seg.Value);
end;

function TotalCellCount(const segs : TAnsiSegments) : Integer;
var
  i    : Integer;
  line : Integer;
begin
  result := 0;
  line   := 0;
  for i := 0 to High(segs) do
  begin
    if segs[i].IsLineBreak then
    begin
      if line > result then
        result := line;
      line := 0;
    end
    else
      Inc(line, SegmentCellCount(segs[i]));
  end;
  if line > result then
    result := line;
end;

procedure SplitSegmentAt(const seg : TAnsiSegment; cellOffset : Integer;
                          out left, right : TAnsiSegment);
var
  i       : Integer;
  running : Integer;
  txt     : string;
  style   : TAnsiStyle;
begin
  if seg.IsLineBreak or seg.IsControlCode then
  begin
    left := seg;
    right := TAnsiSegment.Text('');
    Exit;
  end;

  txt := seg.Value;
  style := seg.Style;

  if cellOffset <= 0 then
  begin
    left := TAnsiSegment.Text('', style);
    right := seg;
    Exit;
  end;

  running := 0;
  for i := 1 to Length(txt) do
  begin
    if running >= cellOffset then
    begin
      if seg.IsWhitespace then
        left := TAnsiSegment.Whitespace(Copy(txt, 1, i - 1), style)
      else
        left := TAnsiSegment.Text(Copy(txt, 1, i - 1), style);
      if seg.IsWhitespace then
        right := TAnsiSegment.Whitespace(Copy(txt, i, MaxInt), style)
      else
        right := TAnsiSegment.Text(Copy(txt, i, MaxInt), style);
      Exit;
    end;
    Inc(running, CellLengthChar(txt[i]));
  end;

  // cellOffset >= segment width: all on the left
  left := seg;
  right := TAnsiSegment.Text('', style);
end;

function MergeSegments(const segs : TAnsiSegments) : TAnsiSegments;
var
  i     : Integer;
  count : Integer;
  buf   : string;
  style : TAnsiStyle;
  inRun : Boolean;

  procedure Flush;
  begin
    if inRun then
    begin
      if Length(result) <= count then
        SetLength(result, count + 1);
      result[count] := TAnsiSegment.Text(buf, style);
      Inc(count);
      inRun := False;
      buf := '';
    end;
  end;

begin
  SetLength(result, Length(segs));
  count := 0;
  inRun := False;
  buf := '';
  style := TAnsiStyle.Plain;

  for i := 0 to High(segs) do
  begin
    if segs[i].IsLineBreak or segs[i].IsWhitespace or segs[i].IsControlCode then
    begin
      Flush;
      result[count] := segs[i];
      Inc(count);
      Continue;
    end;

    if inRun and segs[i].Style.Equals(style) then
    begin
      buf := buf + segs[i].Value;
    end
    else
    begin
      Flush;
      buf := segs[i].Value;
      style := segs[i].Style;
      inRun := True;
    end;
  end;
  Flush;

  SetLength(result, count);
end;

function SplitLines(const segs : TAnsiSegments; maxWidth : Integer) : TArray<TAnsiSegments>;
var
  i       : Integer;
  lineIdx : Integer;
  width   : Integer;
  seg     : TAnsiSegment;
  remaining : TAnsiSegment;
  left, right : TAnsiSegment;
  segWidth : Integer;
  line    : TAnsiSegments;

  procedure PushSeg(const s : TAnsiSegment);
  begin
    SetLength(line, Length(line) + 1);
    line[High(line)] := s;
  end;

  procedure NewLine;
  begin
    if Length(result) <= lineIdx then
      SetLength(result, lineIdx + 1);
    result[lineIdx] := line;
    Inc(lineIdx);
    line := nil;
    width := 0;
  end;

begin
  SetLength(result, 0);
  lineIdx := 0;
  width   := 0;
  line    := nil;

  for i := 0 to High(segs) do
  begin
    seg := segs[i];

    if seg.IsLineBreak then
    begin
      NewLine;
      Continue;
    end;

    if seg.IsControlCode then
    begin
      PushSeg(seg);
      Continue;
    end;

    remaining := seg;
    while True do
    begin
      segWidth := SegmentCellCount(remaining);
      if (maxWidth <= 0) or (width + segWidth <= maxWidth) then
      begin
        if remaining.Value <> '' then
        begin
          PushSeg(remaining);
          Inc(width, segWidth);
        end;
        Break;
      end;

      SplitSegmentAt(remaining, maxWidth - width, left, right);
      if left.Value <> '' then
        PushSeg(left);
      NewLine;
      remaining := right;
      if SegmentCellCount(remaining) = 0 then
        Break;
    end;
  end;

  // flush any remaining partial line
  if Length(line) > 0 then
    NewLine;
end;

function IsBreakChar(ch : Char) : Boolean;
begin
  // Space and tab only: a no-break space (U+00A0) must not wrap.
  result := (ch = ' ') or (ch = #9);
end;

{ True for a piece that is a break opportunity. Pieces come out of
  SplitIntoPieces, where a text piece is all-whitespace or has none. }
function IsBlankPiece(const piece : TAnsiSegment) : Boolean;
begin
  if piece.IsControlCode or piece.IsLineBreak then
    result := False
  else if piece.IsWhitespace then
    result := True
  else
    result := (piece.Value <> '') and IsBreakChar(piece.Value[1]);
end;

{ Cut the text segments of one line into alternating whitespace / word
  pieces. Whitespace and control-code segments pass through whole. }
function SplitIntoPieces(const line : TAnsiSegments) : TAnsiSegments;
var
  i, j     : Integer;
  count    : Integer;
  runStart : Integer;
  value    : string;

  procedure Push(const piece : TAnsiSegment);
  begin
    SetLength(result, count + 1);
    result[count] := piece;
    Inc(count);
  end;

begin
  SetLength(result, 0);
  count := 0;
  for i := 0 to High(line) do
  begin
    if line[i].IsControlCode or line[i].IsWhitespace then
    begin
      Push(line[i]);
      Continue;
    end;

    value := line[i].Value;
    runStart := 1;
    for j := 2 to Length(value) + 1 do
    begin
      if (j > Length(value)) or (IsBreakChar(value[j]) <> IsBreakChar(value[runStart])) then
      begin
        Push(TAnsiSegment.Text(Copy(value, runStart, j - runStart), line[i].Style));
        runStart := j;
      end;
    end;
  end;
end;

function WrapLines(const segs : TAnsiSegments; maxWidth : Integer) : TArray<TAnsiSegments>;
var
  hardLines : TArray<TAnsiSegments>;
  pieces    : TAnsiSegments;
  line      : TAnsiSegments;
  lineIdx   : Integer;
  width     : Integer;
  wordWidth : Integer;
  wordEnd   : Integer;
  h, i, k   : Integer;
  wrapped   : Boolean;   // the current line was started by a wrap
  remaining : TAnsiSegment;
  left, right : TAnsiSegment;

  procedure PushPiece(const piece : TAnsiSegment);
  begin
    SetLength(line, Length(line) + 1);
    line[High(line)] := piece;
    Inc(width, SegmentCellCount(piece));
  end;

  procedure AddLine(const value : TAnsiSegments);
  begin
    SetLength(result, lineIdx + 1);
    result[lineIdx] := value;
    Inc(lineIdx);
  end;

  // End the current line at a wrap point. The whitespace before the wrap is
  // dropped; a line left with nothing on it is not emitted.
  procedure WrapHere;
  var
    keep : Integer;
  begin
    keep := Length(line);
    while (keep > 0) and IsBlankPiece(line[keep - 1]) do
      Dec(keep);
    SetLength(line, keep);
    if keep > 0 then
      AddLine(MergeSegments(line));
    line := nil;
    width := 0;
    wrapped := True;
  end;

begin
  // Nothing to wrap when every line already fits - which also keeps the
  // caller's segments exactly as they were.
  if (maxWidth <= 0) or (TotalCellCount(segs) <= maxWidth) then
  begin
    result := SplitLines(segs, maxWidth);
    Exit;
  end;

  SetLength(result, 0);
  lineIdx := 0;
  hardLines := SplitLines(segs, MaxInt);  // explicit line breaks only

  for h := 0 to High(hardLines) do
  begin
    if TotalCellCount(hardLines[h]) <= maxWidth then
    begin
      AddLine(hardLines[h]);
      Continue;
    end;

    pieces := SplitIntoPieces(hardLines[h]);
    line := nil;
    width := 0;
    wrapped := False;
    i := 0;
    while i <= High(pieces) do
    begin
      if IsBlankPiece(pieces[i]) then
      begin
        // Whitespace straight after a wrap is part of what the wrap consumed.
        if not (wrapped and (Length(line) = 0)) then
        begin
          if width + SegmentCellCount(pieces[i]) <= maxWidth then
            PushPiece(pieces[i])
          else
            WrapHere;
        end;
        Inc(i);
        Continue;
      end;

      // The word is every piece up to the next whitespace.
      wordEnd := i;
      wordWidth := 0;
      while (wordEnd <= High(pieces)) and (not IsBlankPiece(pieces[wordEnd])) do
      begin
        Inc(wordWidth, SegmentCellCount(pieces[wordEnd]));
        Inc(wordEnd);
      end;

      if (width > 0) and (width + wordWidth > maxWidth) then
        WrapHere;

      if width + wordWidth <= maxWidth then
      begin
        for k := i to wordEnd - 1 do
          PushPiece(pieces[k]);
      end
      else
      begin
        // Wider than a whole line: no break opportunity, so hard-wrap it.
        for k := i to wordEnd - 1 do
        begin
          remaining := pieces[k];
          while width + SegmentCellCount(remaining) > maxWidth do
          begin
            SplitSegmentAt(remaining, maxWidth - width, left, right);
            if left.Value <> '' then
              PushPiece(left);
            AddLine(MergeSegments(line));
            line := nil;
            width := 0;
            wrapped := True;
            remaining := right;
          end;
          if remaining.Value <> '' then
            PushPiece(remaining);
        end;
      end;
      i := wordEnd;
    end;

    if Length(line) > 0 then
      AddLine(MergeSegments(line));
  end;
end;

function CropLineToWidth(const line : TAnsiSegments; maxWidth : Integer;
                          addEllipsis : Boolean) : TAnsiSegments;
const
  ELLIPSIS = '...';
var
  budget   : Integer;
  consumed : Integer;
  i, count : Integer;
  segW     : Integer;
  left, right : TAnsiSegment;
  lastStyle : TAnsiStyle;

  procedure Push(const seg : TAnsiSegment);
  begin
    SetLength(result, count + 1);
    result[count] := seg;
    Inc(count);
  end;

begin
  SetLength(result, 0);
  count := 0;

  if maxWidth <= 0 then Exit;

  // Quick path: line already fits.
  if TotalCellCount(line) <= maxWidth then
  begin
    SetLength(result, Length(line));
    for i := 0 to High(line) do
      result[i] := line[i];
    Exit;
  end;

  // Reserve room for ellipsis if requested.
  budget := maxWidth;
  if addEllipsis then
  begin
    budget := budget - Length(ELLIPSIS);
    if budget < 0 then budget := 0;
  end;

  consumed := 0;
  lastStyle := TAnsiStyle.Plain;
  for i := 0 to High(line) do
  begin
    if line[i].IsLineBreak then Continue;
    if line[i].IsControlCode then
    begin
      Push(line[i]);
      Continue;
    end;
    segW := SegmentCellCount(line[i]);
    if consumed + segW <= budget then
    begin
      Push(line[i]);
      Inc(consumed, segW);
      lastStyle := line[i].Style;
    end
    else
    begin
      if budget - consumed > 0 then
      begin
        SplitSegmentAt(line[i], budget - consumed, left, right);
        if left.Value <> '' then
        begin
          Push(left);
          lastStyle := left.Style;
        end;
      end;
      Break;
    end;
  end;

  if addEllipsis then
    Push(TAnsiSegment.Text(ELLIPSIS, lastStyle));
end;

end.

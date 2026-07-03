unit VSoft.AnsiConsole.Prompts.Text;

{
  TTextPrompt - read a line of text from the user with optional default,
  validator, and secret/mask mode.

  Loop (per attempt):
    1. Emit the prompt markup (optionally followed by "[default]" hint).
    2. For each keypress:
       - Enter  : validate; on pass, commit and return; on fail, print error
                 on a new line and re-prompt below.
       - Escape : if default is set, return default; else treat as empty commit
                 and run validation normally.
       - Backspace : pop one char from buffer, emit BS+space+BS to erase.
       - Printable char : append to buffer; emit either the char or the
                 secret mask depending on WithSecret.

  The initial line is drawn once; subsequent keystrokes just append (or
  backspace) so we don't need full line redraw here. Validation failure
  restarts on a new line.
}

interface

uses
  System.SysUtils,
  VSoft.AnsiConsole.Style,
  VSoft.AnsiConsole.Segment,
  VSoft.AnsiConsole.Rendering,
  VSoft.AnsiConsole.Console,
  VSoft.AnsiConsole.Prompts.Common;

type
  TTextPromptValidator = reference to function(const value : string) : TPromptValidationResult;

  ITextPrompt = interface
    ['{72A1F0D8-4A22-4C59-A6F1-2E6E9B4C1E73}']
    function WithPrompt(const markup : string) : ITextPrompt;
    function WithDefault(const value : string) : ITextPrompt;
    function WithSecret : ITextPrompt; overload;
    function WithSecret(mask : Char) : ITextPrompt; overload;
    function WithValidator(const validator : TTextPromptValidator) : ITextPrompt;
    function WithAllowEmpty(value : Boolean) : ITextPrompt;

    { Separator emitted after the prompt (and choices/default), before the
      typed input. Defaults to ': '. Pass '' to drop it entirely. }
    function WithPromptSuffix(const value : string) : ITextPrompt;

    { Choice support. When at least one choice is added, the input is
      validated against the choice list before commit; non-matching input
      is rejected with FInvalidChoiceMessage. ShowChoices controls whether
      the available options are echoed inline ("[red/green/blue]"). }
    function WithChoice(const value : string) : ITextPrompt;
    function WithShowChoices(value : Boolean) : ITextPrompt;
    function WithShowDefaultValue(value : Boolean) : ITextPrompt;
    function WithChoicesStyle(const value : TAnsiStyle) : ITextPrompt;
    function WithDefaultValueStyle(const value : TAnsiStyle) : ITextPrompt;
    function WithInvalidChoiceMessage(const markup : string) : ITextPrompt;
    function WithCaseSensitive(value : Boolean) : ITextPrompt;

    { Styles the question text itself. }
    function WithPromptStyle(const value : TAnsiStyle) : ITextPrompt;
    { Markup printed when WithValidator returns a failed result. The
      validator's own error message is appended after this. }
    function WithValidationErrorMessage(const markup : string) : ITextPrompt;
    { When True, erase the prompt + answer line(s) after Show returns. }
    function WithClearOnFinish(value : Boolean) : ITextPrompt;

    function Show(const console : IAnsiConsole) : string;
  end;

  TTextPrompt = class(TInterfacedObject, ITextPrompt)
  strict private
    FPrompt              : string;
    FPromptSuffix        : string;
    FDefault             : string;
    FHasDefault          : Boolean;
    FSecret              : Boolean;
    FMask                : Char;
    FAllowEmpty          : Boolean;
    FValidator           : TTextPromptValidator;
    FChoices             : TArray<string>;
    FShowChoices         : Boolean;
    FShowDefaultValue    : Boolean;
    FChoicesStyle        : TAnsiStyle;
    FDefaultValueStyle   : TAnsiStyle;
    FInvalidChoiceMessage: string;
    FCaseSensitive       : Boolean;
    FPromptStyle             : TAnsiStyle;
    FValidationErrorMessage  : string;
    FClearOnFinish           : Boolean;
    FRenderedLineCount       : Integer;
    procedure DrawPromptLine(const console : IAnsiConsole);
    function  PromptWidth : Integer;
    function  Displayed(const value : string) : string;
    procedure MoveCaret(const console : IAnsiConsole; const fromCell, toCell : Integer; const fromPending : Boolean = False);
    function  PrevWordStart(const value : string; const caret : Integer) : Integer;
    function  NextWordStart(const value : string; const caret : Integer) : Integer;
    function  IsValidChoice(const value : string) : Boolean;
  public
    constructor Create;
    function WithPrompt(const markup : string) : ITextPrompt;
    function WithDefault(const value : string) : ITextPrompt;
    function WithSecret : ITextPrompt; overload;
    function WithSecret(mask : Char) : ITextPrompt; overload;
    function WithValidator(const validator : TTextPromptValidator) : ITextPrompt;
    function WithAllowEmpty(value : Boolean) : ITextPrompt;
    function WithPromptSuffix(const value : string) : ITextPrompt;
    function WithChoice(const value : string) : ITextPrompt;
    function WithShowChoices(value : Boolean) : ITextPrompt;
    function WithShowDefaultValue(value : Boolean) : ITextPrompt;
    function WithChoicesStyle(const value : TAnsiStyle) : ITextPrompt;
    function WithDefaultValueStyle(const value : TAnsiStyle) : ITextPrompt;
    function WithInvalidChoiceMessage(const markup : string) : ITextPrompt;
    function WithCaseSensitive(value : Boolean) : ITextPrompt;
    function WithPromptStyle(const value : TAnsiStyle) : ITextPrompt;
    function WithValidationErrorMessage(const markup : string) : ITextPrompt;
    function WithClearOnFinish(value : Boolean) : ITextPrompt;
    function Show(const console : IAnsiConsole) : string;
  end;

function TextPrompt : ITextPrompt;

{ Convenience: emit arbitrary text to the console (used by other prompt
  units that don't want to import Segment/Rendering directly). }
procedure EmitPlain(const console : IAnsiConsole; const s : string);
procedure EmitMarkup(const console : IAnsiConsole; const markupSource : string);
procedure EmitStyled(const console : IAnsiConsole; const s : string;
                      const style : TAnsiStyle);

implementation

uses
  System.Console.Types,   // TConsoleKey, TConsoleKeyInfo
  VSoft.AnsiConsole.Color,
  VSoft.AnsiConsole.Widgets.Markup;

function TextPrompt : ITextPrompt;
begin
  result := TTextPrompt.Create;
end;

procedure EmitPlain(const console : IAnsiConsole; const s : string);
var
  segs : TAnsiSegments;
begin
  if s = '' then Exit;
  SetLength(segs, 1);
  segs[0] := TAnsiSegment.Text(s);
  console.Write(segs);
end;

procedure EmitMarkup(const console : IAnsiConsole; const markupSource : string);
var
  m : IRenderable;
begin
  if markupSource = '' then Exit;
  m := Markup(markupSource);
  console.Write(m);
end;

procedure EmitStyled(const console : IAnsiConsole; const s : string;
                      const style : TAnsiStyle);
var
  segs : TAnsiSegments;
begin
  if s = '' then Exit;
  SetLength(segs, 1);
  segs[0] := TAnsiSegment.Text(s, style);
  console.Write(segs);
end;

{ Emit a raw control sequence (cursor move / erase) through the normal write
  path so it stays serialised with the rest of the output. }
procedure EmitControl(const console : IAnsiConsole; const s : string);
var
  segs : TAnsiSegments;
begin
  if s = '' then Exit;
  SetLength(segs, 1);
  segs[0] := TAnsiSegment.ControlCode(s);
  console.Write(segs);
end;

{ TTextPrompt }

constructor TTextPrompt.Create;
begin
  inherited Create;
  FMask                  := '*';
  FPromptSuffix          := ': ';
  FAllowEmpty            := True;
  FShowChoices           := True;
  FShowDefaultValue      := True;
  FCaseSensitive         := False;
  FChoicesStyle          := TAnsiStyle.Plain.WithForeground(TAnsiColor.Aqua);
  FDefaultValueStyle     := TAnsiStyle.Plain.WithForeground(TAnsiColor.Green);
  FInvalidChoiceMessage  := '[red]Please select one of the available options.[/]';
  FPromptStyle           := TAnsiStyle.Plain;
  FValidationErrorMessage := '';
  FClearOnFinish         := False;
  FRenderedLineCount     := 0;
end;

function TTextPrompt.WithPrompt(const markup : string) : ITextPrompt;
begin
  FPrompt := markup;
  result := Self;
end;

function TTextPrompt.WithDefault(const value : string) : ITextPrompt;
begin
  FDefault := value;
  FHasDefault := True;
  result := Self;
end;

function TTextPrompt.WithSecret : ITextPrompt;
begin
  FSecret := True;
  result := Self;
end;

function TTextPrompt.WithSecret(mask : Char) : ITextPrompt;
begin
  FSecret := True;
  FMask := mask;
  result := Self;
end;

function TTextPrompt.WithValidator(const validator : TTextPromptValidator) : ITextPrompt;
begin
  FValidator := validator;
  result := Self;
end;

function TTextPrompt.WithAllowEmpty(value : Boolean) : ITextPrompt;
begin
  FAllowEmpty := value;
  result := Self;
end;

function TTextPrompt.WithPromptSuffix(const value : string) : ITextPrompt;
begin
  FPromptSuffix := value;
  result := Self;
end;

function TTextPrompt.WithChoice(const value : string) : ITextPrompt;
var
  n : Integer;
begin
  n := Length(FChoices);
  SetLength(FChoices, n + 1);
  FChoices[n] := value;
  result := Self;
end;

function TTextPrompt.WithShowChoices(value : Boolean) : ITextPrompt;
begin FShowChoices := value; result := Self; end;

function TTextPrompt.WithShowDefaultValue(value : Boolean) : ITextPrompt;
begin FShowDefaultValue := value; result := Self; end;

function TTextPrompt.WithChoicesStyle(const value : TAnsiStyle) : ITextPrompt;
begin FChoicesStyle := value; result := Self; end;

function TTextPrompt.WithDefaultValueStyle(const value : TAnsiStyle) : ITextPrompt;
begin FDefaultValueStyle := value; result := Self; end;

function TTextPrompt.WithInvalidChoiceMessage(const markup : string) : ITextPrompt;
begin FInvalidChoiceMessage := markup; result := Self; end;

function TTextPrompt.WithCaseSensitive(value : Boolean) : ITextPrompt;
begin FCaseSensitive := value; result := Self; end;

function TTextPrompt.WithPromptStyle(const value : TAnsiStyle) : ITextPrompt;
begin FPromptStyle := value; result := Self; end;

function TTextPrompt.WithValidationErrorMessage(const markup : string) : ITextPrompt;
begin FValidationErrorMessage := markup; result := Self; end;

function TTextPrompt.WithClearOnFinish(value : Boolean) : ITextPrompt;
begin FClearOnFinish := value; result := Self; end;

function TTextPrompt.IsValidChoice(const value : string) : Boolean;
var
  i : Integer;
begin
  if Length(FChoices) = 0 then
  begin
    result := True;
    Exit;
  end;
  for i := 0 to High(FChoices) do
  begin
    if FCaseSensitive then
    begin
      if FChoices[i] = value then
      begin
        result := True;
        Exit;
      end;
    end
    else if SameText(FChoices[i], value) then
    begin
      result := True;
      Exit;
    end;
  end;
  result := False;
end;

procedure TTextPrompt.DrawPromptLine(const console : IAnsiConsole);
var
  i        : Integer;
  joined   : string;
begin
  if FPrompt <> '' then
  begin
    if FPromptStyle.IsPlain then
      EmitMarkup(console, FPrompt)
    else
      // FPromptStyle is the base style for the parsed prompt markup;
      // explicit [tag]...[/] segments inside the prompt still combine on
      // top of it (matches Spectre's PromptStyle semantics).
      console.Write(VSoft.AnsiConsole.Widgets.Markup.Markup(FPrompt, FPromptStyle));
  end;

  // Inline choices, e.g. "Pick a colour [red/green/blue]"
  if FShowChoices and (Length(FChoices) > 0) then
  begin
    joined := '';
    for i := 0 to High(FChoices) do
    begin
      if i > 0 then joined := joined + '/';
      joined := joined + FChoices[i];
    end;
    EmitPlain(console, ' [');
    EmitStyled(console, joined, FChoicesStyle);
    EmitPlain(console, ']');
  end;

  if FHasDefault and not FSecret and FShowDefaultValue then
  begin
    EmitPlain(console, ' (');
    EmitStyled(console, FDefault, FDefaultValueStyle);
    EmitPlain(console, ')');
  end;
  EmitPlain(console, FPromptSuffix);
end;

// Visible width of the prompt prefix (prompt markup + choices + default +
// suffix). Used to map a caret offset to its wrapped (row, column) position.
function TTextPrompt.PromptWidth : Integer;
var
  promptMarkup : IMarkup;
  joined       : string;
  i            : Integer;
begin
  result := 0;
  if FPrompt <> '' then
  begin
    promptMarkup := Markup(FPrompt);
    result := result + promptMarkup.Length;
  end;
  if FShowChoices and (Length(FChoices) > 0) then
  begin
    joined := '';
    for i := 0 to High(FChoices) do
    begin
      if i > 0 then joined := joined + '/';
      joined := joined + FChoices[i];
    end;
    result := result + 3 + Length(joined);
  end;
  if FHasDefault and not FSecret and FShowDefaultValue then
    result := result + 3 + Length(FDefault);
  result := result + Length(FPromptSuffix);
end;

function TTextPrompt.Displayed(const value : string) : string;
begin
  if FSecret then
    result := StringOfChar(FMask, Length(value))
  else
    result := value;
end;

// Move the terminal cursor between two positions in the input, given as
// character offsets after the prompt. Both are mapped through the console
// width so the move stays correct when the input wraps across rows.
// fromPending marks that the cursor just printed up to fromCell: a terminal
// with delayed end-of-line wrap then sits on the last column of the previous
// row rather than column 0 of the next one, so that row is used as the origin.
procedure TTextPrompt.MoveCaret(const console : IAnsiConsole; const fromCell, toCell : Integer; const fromPending : Boolean = False);
var
  width   : Integer;
  prompt  : Integer;
  fromAbs : Integer;
  fromRow : Integer;
  toRow   : Integer;
  toCol   : Integer;
  seq     : string;
begin
  if fromCell = toCell then
    Exit;
  width := console.Profile.Width;
  if width < 1 then
    width := 1;
  prompt := PromptWidth;
  fromAbs := prompt + fromCell;
  if fromPending and (fromAbs > 0) and (fromAbs mod width = 0) then
    fromRow := fromAbs div width - 1
  else
    fromRow := fromAbs div width;
  toRow := (prompt + toCell) div width;
  toCol := (prompt + toCell) mod width;
  seq := '';
  if toRow < fromRow then
    seq := seq + ESC + '[' + IntToStr(fromRow - toRow) + 'A'
  else if toRow > fromRow then
    seq := seq + ESC + '[' + IntToStr(toRow - fromRow) + 'B';
  seq := seq + #13;
  if toCol > 0 then
    seq := seq + ESC + '[' + IntToStr(toCol) + 'C';
  EmitControl(console, seq);
end;

// Caret position at the start of the word to the left (skips spaces, then the
// word). caret is the number of characters before the cursor; value is 1-based.
function TTextPrompt.PrevWordStart(const value : string; const caret : Integer) : Integer;
var
  i : Integer;
begin
  i := caret;
  while (i > 0) and (value[i] = ' ') do
    Dec(i);
  while (i > 0) and (value[i] <> ' ') do
    Dec(i);
  result := i;
end;

// Caret position at the start of the next word to the right (skips the rest of
// the current word, then spaces).
function TTextPrompt.NextWordStart(const value : string; const caret : Integer) : Integer;
var
  i, len : Integer;
begin
  len := Length(value);
  i := caret;
  while (i < len) and (value[i + 1] <> ' ') do
    Inc(i);
  while (i < len) and (value[i + 1] = ' ') do
    Inc(i);
  result := i;
end;

function TTextPrompt.Show(const console : IAnsiConsole) : string;
var
  buffer : string;
  caret  : Integer;
  target : Integer;
  width  : Integer;
  tail   : string;
  ctrl   : Boolean;
  key    : TConsoleKeyInfo;
  ch     : Char;
  vr     : TPromptValidationResult;
  committed : Boolean;

  procedure EmitValidationError(const errorMarkup : string);
  begin
    if FValidationErrorMessage <> '' then
      EmitMarkup(console, FValidationErrorMessage)
    else
      EmitMarkup(console, errorMarkup);
    EmitPlain(console, sLineBreak);
  end;

begin
  result := '';
  committed := False;
  FRenderedLineCount := 0;

  while not committed do
  begin
    buffer := '';
    caret := 0;
    DrawPromptLine(console);
    Inc(FRenderedLineCount);

    while True do
    begin
      key := console.Input.ReadKey(True);
      ctrl := TConsoleModifier.Control in key.Modifiers;
      case key.Key of
        TConsoleKey.Enter:
        begin
          EmitPlain(console, sLineBreak);
          if (buffer = '') and FHasDefault then
            buffer := FDefault;

          if (Length(FChoices) > 0) and not IsValidChoice(buffer) then
          begin
            EmitValidationError(FInvalidChoiceMessage);
            Inc(FRenderedLineCount);
            Break;
          end;

          if Assigned(FValidator) then
          begin
            vr := FValidator(buffer);
            if not vr.Valid then
            begin
              EmitValidationError('[red]' + vr.Error + '[/]');
              Inc(FRenderedLineCount);
              Break;
            end;
          end
          else if (buffer = '') and not FAllowEmpty then
          begin
            EmitValidationError('[red]Value is required.[/]');
            Inc(FRenderedLineCount);
            Break;
          end;

          result := buffer;
          committed := True;
          Break;
        end;

        TConsoleKey.Escape:
        begin
          if FHasDefault then
          begin
            buffer := FDefault;
            EmitPlain(console, sLineBreak);
            result := buffer;
            committed := True;
            Break;
          end;
          // No default -> ignore Escape
        end;

        TConsoleKey.LeftArrow:
          begin
            if ctrl then
              target := PrevWordStart(buffer, caret)
            else if caret > 0 then
              target := caret - 1
            else
              target := caret;
            MoveCaret(console, caret, target);
            caret := target;
          end;

        TConsoleKey.RightArrow:
          begin
            if ctrl then
              target := NextWordStart(buffer, caret)
            else if caret < Length(buffer) then
              target := caret + 1
            else
              target := caret;
            MoveCaret(console, caret, target);
            caret := target;
          end;

        TConsoleKey.Home:
          begin
            MoveCaret(console, caret, 0);
            caret := 0;
          end;

        TConsoleKey.&End:
          begin
            MoveCaret(console, caret, Length(buffer));
            caret := Length(buffer);
          end;

        TConsoleKey.UpArrow:
          begin
            width := console.Profile.Width;
            // Only when there is a row above (the input has wrapped).
            if (width > 0) and ((PromptWidth + caret) >= width) then
            begin
              target := caret - width;
              if target < 0 then
                target := 0;
              MoveCaret(console, caret, target);
              caret := target;
            end;
          end;

        TConsoleKey.DownArrow:
          begin
            width := console.Profile.Width;
            // Only when there is a row below the caret.
            if (width > 0) and
               (((PromptWidth + caret) div width) < ((PromptWidth + Length(buffer)) div width)) then
            begin
              target := caret + width;
              if target > Length(buffer) then
                target := Length(buffer);
              MoveCaret(console, caret, target);
              caret := target;
            end;
          end;

        TConsoleKey.Backspace:
          if caret > 0 then
          begin
            Delete(buffer, caret, 1);
            MoveCaret(console, caret, caret - 1);
            Dec(caret);
            tail := Displayed(Copy(buffer, caret + 1, MaxInt));
            EmitPlain(console, tail + ' ');
            MoveCaret(console, Length(buffer) + 1, caret, True);
          end;

        TConsoleKey.Delete:
          if caret < Length(buffer) then
          begin
            Delete(buffer, caret + 1, 1);
            tail := Displayed(Copy(buffer, caret + 1, MaxInt));
            EmitPlain(console, tail + ' ');
            MoveCaret(console, Length(buffer) + 1, caret, True);
          end;

      else
        ch := key.KeyChar;
        if (ch >= #32) and (ch <> #127) then
        begin
          Insert(ch, buffer, caret + 1);
          tail := Displayed(Copy(buffer, caret + 1, MaxInt));
          EmitPlain(console, tail);
          Inc(caret);
          MoveCaret(console, Length(buffer), caret, True);
        end;
      end;
    end;
  end;

  // Erase all the lines we emitted (prompt + any validation errors).
  if FClearOnFinish and (FRenderedLineCount > 0) then
    ClearPreviousLines(console, FRenderedLineCount);
end;

end.

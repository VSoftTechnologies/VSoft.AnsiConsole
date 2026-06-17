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

function TTextPrompt.Show(const console : IAnsiConsole) : string;
var
  buffer : string;
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
    DrawPromptLine(console);
    Inc(FRenderedLineCount);

    while True do
    begin
      key := console.Input.ReadKey(True);
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

        TConsoleKey.Backspace:
        begin
          if Length(buffer) > 0 then
          begin
            SetLength(buffer, Length(buffer) - 1);
            EmitPlain(console, #8 + ' ' + #8);
          end;
        end;

      else
        ch := key.KeyChar;
        if (ch >= #32) and (ch <> #127) then
        begin
          buffer := buffer + ch;
          if FSecret then
            EmitPlain(console, FMask)
          else
            EmitPlain(console, ch);
        end;
      end;
    end;
  end;

  // Erase all the lines we emitted (prompt + any validation errors).
  if FClearOnFinish and (FRenderedLineCount > 0) then
    ClearPreviousLines(console, FRenderedLineCount);
end;

end.

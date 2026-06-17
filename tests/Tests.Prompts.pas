unit Tests.Prompts;

{
  Prompt fixtures driven by TScriptedConsoleInput so nothing actually reads
  from the real keyboard. Each test wires a captured console and a scripted
  input, then asserts on the Show(...) return value and (for a couple of
  cases) on the emitted output text.
}

interface

uses
  DUnitX.TestFramework,
  VSoft.AnsiConsole,
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Console,
  VSoft.AnsiConsole.Input,
  VSoft.AnsiConsole.Prompts.Common,
  VSoft.AnsiConsole.Prompts.Hierarchy,
  VSoft.AnsiConsole.Prompts.Text,
  VSoft.AnsiConsole.Prompts.Text.Generic,
  VSoft.AnsiConsole.Prompts.Confirm,
  VSoft.AnsiConsole.Prompts.Select,
  VSoft.AnsiConsole.Prompts.MultiSelect;

type
  [TestFixture]
  TPromptTests = class
  public
    [Test] procedure Text_Enter_ReturnsTypedValue;
    [Test] procedure Text_EmptyEnter_ReturnsDefault;
    [Test] procedure Text_Backspace_PopsLastChar;
    [Test] procedure Text_PromptSuffix_Custom_Replaces;
    [Test] procedure Text_PromptSuffix_Empty_OmitsDefaultColon;
    [Test] procedure Text_ValidatorRejectsThenAccepts;
    [Test] procedure Text_Secret_MasksInOutput;
    [Test] procedure Text_Choices_RejectsNonMember;
    [Test] procedure Text_Choices_AcceptsCaseInsensitiveByDefault;
    [Test] procedure Text_ShowChoices_EchoesInPrompt;

    [Test] procedure Text_Generic_Integer_ParsesInput;
    [Test] procedure Text_Generic_Integer_RejectsNonNumeric;
    [Test] procedure Text_Generic_Integer_EmptyEnterReturnsDefault;
    [Test] procedure Text_Generic_Boolean_AcceptsYesAndNo;
    [Test] procedure Text_Generic_CustomParser_OverridesDefault;
    [Test] procedure Text_Generic_Choices_RejectsNonMember;

    [Test] procedure Confirm_Y_ReturnsTrue;
    [Test] procedure Confirm_N_ReturnsFalse;
    [Test] procedure Confirm_EnterWithDefaultFalse_ReturnsFalse;
    [Test] procedure Confirm_CustomYesChars_AcceptsJ;
    [Test] procedure Confirm_InvalidChoiceMessage_RendersOnBadInput;
    [Test] procedure Confirm_HideChoices_OmitsBracketHint;

    [Test] procedure Text_ValidationErrorMessage_RendersOnInvalid;
    [Test] procedure Text_ClearOnFinish_ErasesPromptLine;

    [Test] procedure Facade_Prompt_TextPrompt_DelegatesToShow;
    [Test] procedure Facade_Prompt_GenericTextPrompt_DelegatesToShow;

    [Test] procedure Select_DownDownEnter_PicksThird;
    [Test] procedure Select_UpFromFirst_WrapsToLast;
    [Test] procedure Select_Escape_Raises;
    [Test] procedure Select_SearchEnabled_FiltersByLetters;
    [Test] procedure Select_DisabledChoice_EnterIsNoOp;
    [Test] procedure Select_CancelResult_ReturnsValueOnEsc;
    [Test] procedure Select_Hierarchy_Leaf_EnterOnParentTogglesExpansion;
    [Test] procedure Select_Hierarchy_Independent_EnterOnParentReturns;
    [Test] procedure MultiSelect_Hierarchy_LeafModeSpaceTogglesExpansion;

    [Test] procedure MultiSelect_SpaceDownSpaceEnter_TwoSelected;
    [Test] procedure MultiSelect_Required_ReprompsOnEmpty;
    [Test] procedure MultiSelect_MoreChoicesText_RendersWhenOverflowing;
    [Test] procedure MultiSelect_CancelResult_ReturnsArrayOnEsc;

    [Test] procedure Select_Display_HonoursMarkupTags;
    [Test] procedure MultiSelect_Display_HonoursMarkupTags;
  end;

implementation

uses
  System.SysUtils,
  System.Console.Types,
  Testing.AnsiConsole,
  Testing.ConsoleInput;

function BuildScripted(out console : IAnsiConsole;
                        out input   : TScriptedConsoleInput;
                        out captured : ICapturedAnsiOutput) : IAnsiConsole;
begin
  BuildCapturedConsole(TColorSystem.NoColors, 80, False, console, captured);
  input := TScriptedConsoleInput.Create;
  console.Input := input;
  result := console;
end;

// -- Text prompt ------------------------------------------------------------

procedure TPromptTests.Text_Enter_ReturnsTypedValue;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : string;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('hello');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt.WithPrompt('name').Show(console);
  Assert.AreEqual('hello', value);
end;

procedure TPromptTests.Text_EmptyEnter_ReturnsDefault;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : string;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt.WithPrompt('name').WithDefault('alice').Show(console);
  Assert.AreEqual('alice', value);
end;

procedure TPromptTests.Text_Backspace_PopsLastChar;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : string;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('abc');
  input.Enqueue(TConsoleKey.Backspace);
  input.Enqueue('X');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt.Show(console);
  Assert.AreEqual('abX', value);
end;

procedure TPromptTests.Text_PromptSuffix_Custom_Replaces;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('x');
  input.Enqueue(TConsoleKey.Enter);
  TextPrompt.WithPrompt('Name').WithPromptSuffix(' > ').Show(console);
  Assert.IsTrue(Pos(' > ', captured.Text) > 0, 'Custom suffix should be emitted');
  Assert.IsFalse(Pos('Name: ', captured.Text) > 0, 'Default colon suffix should not appear');
end;

procedure TPromptTests.Text_PromptSuffix_Empty_OmitsDefaultColon;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('x');
  input.Enqueue(TConsoleKey.Enter);
  TextPrompt.WithPrompt('Name').WithPromptSuffix('').Show(console);
  Assert.IsFalse(Pos(': ', captured.Text) > 0, 'Empty suffix should omit the default '': ''');
end;

procedure TPromptTests.Text_ValidatorRejectsThenAccepts;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : string;
  validator : TTextPromptValidator;
begin
  BuildScripted(console, input, captured);
  // First attempt: empty Enter, should fail validation
  input.Enqueue(TConsoleKey.Enter);
  // Second attempt: 'ok'
  input.Enqueue('ok');
  input.Enqueue(TConsoleKey.Enter);

  validator :=
    function(const s : string) : TPromptValidationResult
    begin
      if s = '' then
        result := TPromptValidationResult.Fail('Must not be empty')
      else
        result := TPromptValidationResult.Ok;
    end;

  value := TextPrompt.WithPrompt('v').WithValidator(validator).Show(console);
  Assert.AreEqual('ok', value);
  Assert.Contains(captured.Text, 'Must not be empty');
end;

procedure TPromptTests.Text_Secret_MasksInOutput;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : string;
  output  : string;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('pw');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt.WithSecret('#').Show(console);
  Assert.AreEqual('pw', value);
  output := captured.Text;
  Assert.IsTrue(Pos('##', output) > 0, 'Expected mask chars in captured output');
  Assert.IsFalse(Pos('pw', output) > 0, 'Secret must not appear as plain text');
end;

procedure TPromptTests.Text_Choices_RejectsNonMember;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : string;
begin
  BuildScripted(console, input, captured);
  // First attempt: 'purple' (not a choice) -> rejected
  input.Enqueue('purple');
  input.Enqueue(TConsoleKey.Enter);
  // Second attempt: 'red' (valid)
  input.Enqueue('red');
  input.Enqueue(TConsoleKey.Enter);

  value := TextPrompt
             .WithPrompt('Colour')
             .WithChoice('red')
             .WithChoice('green')
             .WithChoice('blue')
             .WithInvalidChoiceMessage('[red]Pick from the list[/]')
             .Show(console);
  Assert.AreEqual('red', value);
  Assert.Contains(captured.Text, 'Pick from the list');
end;

procedure TPromptTests.Text_Choices_AcceptsCaseInsensitiveByDefault;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : string;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('GREEN');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt
             .WithChoice('red')
             .WithChoice('green')
             .WithChoice('blue')
             .Show(console);
  // Case insensitive match: 'GREEN' matches 'green'. The returned value
  // is what the user typed (Spectre returns the typed string, not the
  // canonical choice).
  Assert.AreEqual('GREEN', value);
end;

procedure TPromptTests.Text_ShowChoices_EchoesInPrompt;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('a');
  input.Enqueue(TConsoleKey.Enter);
  TextPrompt
    .WithPrompt('Pick')
    .WithChoice('a')
    .WithChoice('b')
    .Show(console);
  // The prompt line should include the inline choices.
  Assert.Contains(captured.Text, 'a/b');
end;

// -- Generic typed text prompt ----------------------------------------------

procedure TPromptTests.Text_Generic_Integer_ParsesInput;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : Integer;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('42');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt<Integer>.Create.WithPrompt('Age').Show(console);
  Assert.AreEqual(42, value);
end;

procedure TPromptTests.Text_Generic_Integer_RejectsNonNumeric;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : Integer;
begin
  BuildScripted(console, input, captured);
  // First attempt: 'forty-two' (not numeric) -> rejected
  input.Enqueue('forty-two');
  input.Enqueue(TConsoleKey.Enter);
  // Second attempt: '42'
  input.Enqueue('42');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt<Integer>.Create.WithPrompt('Age').Show(console);
  Assert.AreEqual(42, value);
  Assert.Contains(captured.Text, 'parse');
end;

procedure TPromptTests.Text_Generic_Integer_EmptyEnterReturnsDefault;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : Integer;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt<Integer>.Create.WithPrompt('Age').WithDefault(99).Show(console);
  Assert.AreEqual(99, value);
end;

procedure TPromptTests.Text_Generic_Boolean_AcceptsYesAndNo;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : Boolean;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('yes');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt<Boolean>.Create.WithPrompt('Continue').Show(console);
  Assert.IsTrue(value);

  // Re-issue with 'no'.
  BuildScripted(console, input, captured);
  input.Enqueue('no');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt<Boolean>.Create.WithPrompt('Continue').Show(console);
  Assert.IsFalse(value);
end;

procedure TPromptTests.Text_Generic_CustomParser_OverridesDefault;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : Integer;
begin
  BuildScripted(console, input, captured);
  // Custom parser that doubles the input. We pass '5' and expect 10.
  input.Enqueue('5');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt<Integer>.Create
             .WithPrompt('n')
             .WithParser(
               function(const text : string; out v : Integer) : Boolean
               var
                 raw : Integer;
               begin
                 result := TryStrToInt(text, raw);
                 if result then v := raw * 2;
               end)
             .Show(console);
  Assert.AreEqual(10, value);
end;

procedure TPromptTests.Text_Generic_Choices_RejectsNonMember;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  value   : Integer;
begin
  BuildScripted(console, input, captured);
  // First: 7 (not a choice) -> rejected
  input.Enqueue('7');
  input.Enqueue(TConsoleKey.Enter);
  // Second: 2 (valid)
  input.Enqueue('2');
  input.Enqueue(TConsoleKey.Enter);
  value := TextPrompt<Integer>.Create
             .WithPrompt('n')
             .AddChoice(1)
             .AddChoice(2)
             .AddChoice(3)
             .Show(console);
  Assert.AreEqual(2, value);
end;

// -- Confirm prompt ---------------------------------------------------------

procedure TPromptTests.Confirm_Y_ReturnsTrue;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.EnqueueChar('y');
  Assert.IsTrue(ConfirmationPrompt.WithPrompt('OK?').Show(console));
end;

procedure TPromptTests.Confirm_N_ReturnsFalse;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.EnqueueChar('n');
  Assert.IsFalse(ConfirmationPrompt.WithPrompt('OK?').Show(console));
end;

procedure TPromptTests.Confirm_EnterWithDefaultFalse_ReturnsFalse;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);
  Assert.IsFalse(ConfirmationPrompt.WithPrompt('OK?').WithDefault(False).Show(console));
end;

procedure TPromptTests.Confirm_CustomYesChars_AcceptsJ;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  // German 'Ja/Nein' - configure Yes='j', No='n'.
  BuildScripted(console, input, captured);
  input.EnqueueChar('j');
  Assert.IsTrue(ConfirmationPrompt
                  .WithPrompt('Weiter?')
                  .WithYes('j').WithNo('n')
                  .Show(console));
end;

procedure TPromptTests.Confirm_InvalidChoiceMessage_RendersOnBadInput;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.EnqueueChar('x');   // invalid - triggers error message
  input.EnqueueChar('y');   // valid - commits
  ConfirmationPrompt
    .WithPrompt('OK?')
    .WithInvalidChoiceMessage('[red]NOPE TRY AGAIN[/]')
    .Show(console);
  Assert.IsTrue(Pos('NOPE TRY AGAIN', captured.Text) > 0,
    'Custom InvalidChoiceMessage should render after a bad keystroke');
end;

procedure TPromptTests.Confirm_HideChoices_OmitsBracketHint;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.EnqueueChar('y');
  ConfirmationPrompt
    .WithPrompt('OK?')
    .WithShowChoices(False)
    .WithShowDefaultValue(False)
    .Show(console);
  Assert.IsFalse(Pos('[Y/n]', captured.Text) > 0,
    'Choice hint should be omitted when WithShowChoices(False)');
  Assert.IsFalse(Pos('(Y)', captured.Text) > 0,
    'Default-value indicator should be omitted when WithShowDefaultValue(False)');
end;

procedure TPromptTests.Text_ValidationErrorMessage_RendersOnInvalid;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('bad');
  input.Enqueue(TConsoleKey.Enter);
  input.Enqueue('good');
  input.Enqueue(TConsoleKey.Enter);

  TextPrompt
    .WithPrompt('Type good:')
    .WithValidator(
      function(const value : string) : TPromptValidationResult
      begin
        if value = 'good' then
          result := TPromptValidationResult.Ok
        else
          result := TPromptValidationResult.Fail('not good');
      end)
    .WithValidationErrorMessage('[red]VALIDATION FAILED[/]')
    .Show(console);

  Assert.IsTrue(Pos('VALIDATION FAILED', captured.Text) > 0,
    'Custom ValidationErrorMessage should render on validator failure');
end;

procedure TPromptTests.Text_ClearOnFinish_ErasesPromptLine;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('hi');
  input.Enqueue(TConsoleKey.Enter);

  TextPrompt
    .WithPrompt('Greeting')
    .WithClearOnFinish(True)
    .Show(console);

  // ClearPreviousLines emits ESC[2K (erase line) and CR. We just verify
  // the erase sequence appears in the output - the exact byte layout
  // depends on the inflated-shape internals.
  Assert.IsTrue(Pos(#27 + '[2K', captured.Text) > 0,
    'ClearOnFinish should emit at least one erase-line sequence');
end;

procedure TPromptTests.Facade_Prompt_TextPrompt_DelegatesToShow;
var
  console  : IAnsiConsole;
  input    : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  result   : string;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('hello');
  input.Enqueue(TConsoleKey.Enter);

  AnsiConsole.SetConsole(console);
  try
    result := AnsiConsole.Prompt(TextPrompt.WithPrompt('Say:'));
  finally
    AnsiConsole.SetConsole(nil);
  end;
  Assert.AreEqual('hello', result);
end;

procedure TPromptTests.Facade_Prompt_GenericTextPrompt_DelegatesToShow;
var
  console  : IAnsiConsole;
  input    : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  result   : Integer;
begin
  BuildScripted(console, input, captured);
  input.Enqueue('42');
  input.Enqueue(TConsoleKey.Enter);

  AnsiConsole.SetConsole(console);
  try
    result := AnsiConsole.Prompt<Integer>(
      VSoft.AnsiConsole.Prompts.Text.Generic.TextPrompt<Integer>.Create
        .WithPrompt('Number:'));
  finally
    AnsiConsole.SetConsole(nil);
  end;
  Assert.AreEqual(42, result);
end;

// -- Selection prompt -------------------------------------------------------

procedure TPromptTests.Select_DownDownEnter_PicksThird;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : Integer;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.DownArrow);
  input.Enqueue(TConsoleKey.DownArrow);
  input.Enqueue(TConsoleKey.Enter);

  picked := SelectionPrompt<Integer>.Create
              .AddChoice(10, 'ten')
              .AddChoice(20, 'twenty')
              .AddChoice(30, 'thirty')
              .Show(console);
  Assert.AreEqual(30, picked);
end;

procedure TPromptTests.Select_UpFromFirst_WrapsToLast;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : string;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.UpArrow);
  input.Enqueue(TConsoleKey.Enter);

  picked := SelectionPrompt<string>.Create
              .AddChoice('a', 'alpha')
              .AddChoice('b', 'bravo')
              .AddChoice('c', 'charlie')
              .Show(console);
  Assert.AreEqual('c', picked);
end;

procedure TPromptTests.Select_Escape_Raises;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picker  : ISelectionPrompt<Integer>;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Escape);

  picker := SelectionPrompt<Integer>.Create.AddChoice(1, 'one');
  Assert.WillRaise(procedure begin picker.Show(console); end, EPromptCancelled);
end;

procedure TPromptTests.Select_SearchEnabled_FiltersByLetters;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : string;
begin
  // With search enabled and three choices, typing 'b' filters to bravo.
  // Enter then commits the highlighted match.
  BuildScripted(console, input, captured);
  input.EnqueueChar('b');
  input.Enqueue(TConsoleKey.Enter);

  picked := SelectionPrompt<string>.Create
              .WithSearchEnabled(True)
              .AddChoice('a', 'alpha')
              .AddChoice('b', 'bravo')
              .AddChoice('c', 'charlie')
              .Show(console);

  Assert.AreEqual('b', picked);
end;

procedure TPromptTests.Select_DisabledChoice_EnterIsNoOp;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : string;
begin
  // Cursor starts at index 0 (alpha, disabled). Pressing Enter should
  // be a no-op; only after DownArrow to bravo (enabled) does Enter
  // commit.
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);       // ignored - alpha disabled
  input.Enqueue(TConsoleKey.DownArrow);   // -> bravo
  input.Enqueue(TConsoleKey.Enter);       // commits

  picked := SelectionPrompt<string>.Create
              .AddChoice('a', 'alpha', True)
              .AddChoice('b', 'bravo', False)
              .AddChoice('c', 'charlie', False)
              .Show(console);

  Assert.AreEqual('b', picked);
end;

procedure TPromptTests.Select_CancelResult_ReturnsValueOnEsc;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : string;
begin
  // Esc with WithCancelResult set should return the fallback instead
  // of raising EPromptCancelled.
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Escape);

  picked := SelectionPrompt<string>.Create
              .WithCancelResult('fallback')
              .AddChoice('a', 'alpha')
              .AddChoice('b', 'bravo')
              .Show(console);

  Assert.AreEqual('fallback', picked);
end;

procedure TPromptTests.Select_Hierarchy_Leaf_EnterOnParentTogglesExpansion;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picker  : ISelectionPrompt<string>;
  parent  : ISelectionItem<string>;
  picked  : string;
begin
  // Build: Animals (parent, expanded) -> Dog, Cat. Cursor starts at
  // Animals. In TSelectionMode.Leaf mode (default), Enter on the parent toggles its
  // expansion. After two Enters the parent is back to expanded; DownArrow
  // moves into Dog (the first leaf), Enter commits it.
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);       // collapse Animals
  input.Enqueue(TConsoleKey.Enter);       // expand Animals
  input.Enqueue(TConsoleKey.DownArrow);   // -> Dog
  input.Enqueue(TConsoleKey.Enter);       // commit

  picker := SelectionPrompt<string>.Create;
  parent := picker.AddChoiceHierarchy('animals', 'Animals');
  parent.AddChild('dog', 'Dog');
  parent.AddChild('cat', 'Cat');

  picked := picker.Show(console);
  Assert.AreEqual('dog', picked,
    'After expand/collapse/expand and DownArrow, Enter should commit Dog');
end;

procedure TPromptTests.Select_Hierarchy_Independent_EnterOnParentReturns;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picker  : ISelectionPrompt<string>;
  parent  : ISelectionItem<string>;
  picked  : string;
begin
  // TSelectionMode.Independent: Enter on a parent returns the parent's value.
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);   // commit the parent

  picker := SelectionPrompt<string>.Create.WithMode(TSelectionMode.Independent);
  parent := picker.AddChoiceHierarchy('animals', 'Animals');
  parent.AddChild('dog', 'Dog');
  parent.AddChild('cat', 'Cat');

  picked := picker.Show(console);
  Assert.AreEqual('animals', picked);
end;

procedure TPromptTests.MultiSelect_Hierarchy_LeafModeSpaceTogglesExpansion;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picker  : IMultiSelectionPrompt<string>;
  parent  : IMultiSelectionItem<string>;
  picked  : TArray<string>;
begin
  // Build: Animals (parent) -> dog, cat. Cursor on Animals, Space -> toggle
  // expansion (collapse). Down -> wraps or NOPs (no other items). Enter
  // commits with no selections (Required(0) so empty is OK).
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Spacebar);    // collapse parent
  input.Enqueue(TConsoleKey.Enter);       // commit empty

  picker := MultiSelectionPrompt<string>.Create.Required(0);
  parent := picker.AddChoiceHierarchy('animals', 'Animals');
  parent.AddChild('dog', 'Dog');
  parent.AddChild('cat', 'Cat');

  picked := picker.Show(console);
  Assert.AreEqual<integer>(0, Length(picked),
    'Space on parent in TSelectionMode.Leaf mode toggles expansion, not selection');
end;

// -- Multi-selection prompt -------------------------------------------------

procedure TPromptTests.MultiSelect_SpaceDownSpaceEnter_TwoSelected;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : TArray<string>;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Spacebar);   // toggle index 0
  input.Enqueue(TConsoleKey.DownArrow);  // -> index 1
  input.Enqueue(TConsoleKey.Spacebar);   // toggle index 1
  input.Enqueue(TConsoleKey.Enter);

  picked := MultiSelectionPrompt<string>.Create
              .AddChoice('a', 'alpha')
              .AddChoice('b', 'bravo')
              .AddChoice('c', 'charlie')
              .Show(console);

  Assert.AreEqual<integer>(2, Length(picked));
  Assert.AreEqual('a', picked[0]);
  Assert.AreEqual('b', picked[1]);
end;

procedure TPromptTests.MultiSelect_Required_ReprompsOnEmpty;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : TArray<Integer>;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);       // try to commit with zero selected
  input.Enqueue(TConsoleKey.Spacebar);    // now toggle index 0
  input.Enqueue(TConsoleKey.Enter);       // commit

  picked := MultiSelectionPrompt<Integer>.Create
              .AddChoice(1, 'one')
              .AddChoice(2, 'two')
              .Required(1)
              .Show(console);

  Assert.AreEqual<integer>(1, Length(picked));
  Assert.AreEqual(1, picked[0]);
  Assert.Contains(captured.Text, 'At least 1 item');
end;

procedure TPromptTests.MultiSelect_MoreChoicesText_RendersWhenOverflowing;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
begin
  // 5 choices, page size 2 -> 3 hidden. WithMoreChoicesText should
  // render the configured hint instead of the default '(N more)'.
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);  // commit immediately (no Required)

  MultiSelectionPrompt<string>.Create
    .WithPageSize(2)
    .WithMoreChoicesText('[grey]see more below[/]')
    .AddChoice('a', 'alpha')
    .AddChoice('b', 'bravo')
    .AddChoice('c', 'charlie')
    .AddChoice('d', 'delta')
    .AddChoice('e', 'echo')
    .Show(console);

  Assert.IsTrue(Pos('see more below', captured.Text) > 0,
    'Custom MoreChoicesText should appear in rendered output');
end;

procedure TPromptTests.MultiSelect_CancelResult_ReturnsArrayOnEsc;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : TArray<string>;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Escape);

  picked := MultiSelectionPrompt<string>.Create
              .WithCancelResult(TArray<string>.Create('fallback1', 'fallback2'))
              .AddChoice('a', 'alpha')
              .AddChoice('b', 'bravo')
              .Show(console);

  Assert.AreEqual<integer>(2, Length(picked));
  Assert.AreEqual('fallback1', picked[0]);
  Assert.AreEqual('fallback2', picked[1]);
end;

procedure TPromptTests.Select_Display_HonoursMarkupTags;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : string;
begin
  // Display strings can contain markup tags like [bold]Foo[/]; the prompt
  // must parse them through the markup pipeline and NOT echo the literal
  // brackets to the terminal.
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Enter);

  picked := SelectionPrompt<string>.Create
              .AddChoice('x', '[bold]Heading[/]')
              .Show(console);

  Assert.AreEqual('x', picked);
  Assert.IsTrue(Pos('Heading', captured.Text) > 0,
    'Body of the markup tag should appear in the rendered output');
  Assert.IsTrue(Pos('[bold]', captured.Text) = 0,
    'Literal markup tag must not leak through to the terminal');
  Assert.IsTrue(Pos('[/]', captured.Text) = 0,
    'Closing markup tag must not leak through either');
end;

procedure TPromptTests.MultiSelect_Display_HonoursMarkupTags;
var
  console : IAnsiConsole;
  input   : TScriptedConsoleInput;
  captured : ICapturedAnsiOutput;
  picked  : TArray<string>;
begin
  BuildScripted(console, input, captured);
  input.Enqueue(TConsoleKey.Spacebar);
  input.Enqueue(TConsoleKey.Enter);

  picked := MultiSelectionPrompt<string>.Create
              .AddChoice('x', '[italic]Italic option[/]')
              .Show(console);

  Assert.AreEqual<integer>(1, Length(picked));
  Assert.AreEqual('x', picked[0]);
  Assert.IsTrue(Pos('Italic option', captured.Text) > 0,
    'Body of the markup tag should appear in the rendered output');
  Assert.IsTrue(Pos('[italic]', captured.Text) = 0,
    'Literal markup tag must not leak through to the terminal');
end;

initialization
  TDUnitX.RegisterTestFixture(TPromptTests);

end.

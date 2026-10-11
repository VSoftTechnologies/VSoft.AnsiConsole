unit Tests.Widgets.Layout;

{
  End-to-end tests for the Phase 2 layout widgets. Each test renders the
  widget via a captured console and asserts on the resulting text (with
  unicode off, so we can compare to plain-ASCII strings).
}

interface

uses
  DUnitX.TestFramework,
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Console,
  VSoft.AnsiConsole.Widgets.Text,
  VSoft.AnsiConsole.Widgets.Padder,
  VSoft.AnsiConsole.Widgets.Align,
  VSoft.AnsiConsole.Widgets.Rows,
  VSoft.AnsiConsole.Widgets.Columns,
  VSoft.AnsiConsole.Widgets.Grid,
  VSoft.AnsiConsole.Widgets.Panel,
  VSoft.AnsiConsole.Borders.Box;

type
  [TestFixture]
  TLayoutWidgetTests = class
  public
    [Test] procedure Padder_LeftRight_Widens;
    [Test] procedure Padder_Top_AddsBlankLines;
    [Test] procedure Padding_All_AllSidesEqual;
    [Test] procedure Padding_HorizontalVertical_SetsPairs;
    [Test] procedure Padding_GetWidthHeight_SumSides;
    [Test] procedure Padding_Equals_DetectsDifferences;

    [Test] procedure Align_Left_NoLeadingSpace;
    [Test] procedure Align_Center_EqualOrNearEqualPadding;
    [Test] procedure Align_Right_LeadingSpaces;

    [Test] procedure Rows_TwoChildren_SeparatedByLineBreak;
    [Test] procedure Rows_NoExpand_FillingChildShrinksToNaturalWidth;
    [Test] procedure Rows_Expand_FillingChildSpansFullMaxWidth;

    [Test] procedure Columns_TwoChildren_SideBySide;
    [Test] procedure Columns_NoExpand_SizesToNaturalWidths;

    [Test] procedure Grid_FixedColumns_RendersSideBySide;
    [Test] procedure Grid_StarColumn_NoExpand_SizesToNaturalContent;
    [Test] procedure Grid_StarColumn_Expand_AbsorbsLeftover;
    [Test] procedure Grid_StarColumn_NoExpand_TooWide_ShrinksStarNotAuto;
    [Test] procedure Grid_StarColumn_NoExpand_TooWide_StarTakesWhatAutoLeaves;

    [Test] procedure Panel_AsciiBorder_SingleLineChild_Produces3Lines;
    [Test] procedure Panel_WithHeader_InsertsHeaderText;
    [Test] procedure Panel_WithHeader_ParsesMarkupTags;
  end;

implementation

uses
  System.SysUtils,
  Testing.AnsiConsole;

function BuildPlainWithSink(width : Integer; unicode : Boolean;
                             out sink : ICapturedAnsiOutput) : IAnsiConsole;
begin
  BuildCapturedConsole(TColorSystem.NoColors, width, unicode, result, sink);
end;

procedure TLayoutWidgetTests.Padder_LeftRight_Widens;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  console := BuildPlainWithSink(20, False, sink);
  console.Write(Padder(Text('hi')).WithPadding(0, 3, 0, 2));
  // 20 cells total = left(2) + 'hi'(2) + inner-fill(13) + right(3)
  Assert.AreEqual('  hi' + StringOfChar(' ', 16), sink.Text);
end;

procedure TLayoutWidgetTests.Padder_Top_AddsBlankLines;
var
  console   : IAnsiConsole;
  sink      : ICapturedAnsiOutput;
  captured  : string;
  lineCount : Integer;
  i         : Integer;
begin
  console := BuildPlainWithSink(10, False, sink);
  console.Write(Padder(Text('x')).WithPadding(2, 1, 0, 1));
  captured := sink.Text;
  lineCount := 0;
  for i := 1 to Length(captured) do
    if captured[i] = #10 then Inc(lineCount);
  Assert.AreEqual(2, lineCount, 'Two newlines expected before the "x" row');
end;

procedure TLayoutWidgetTests.Padding_All_AllSidesEqual;
var
  p : TPadding;
begin
  p := TPadding.All(3);
  Assert.AreEqual(3, p.Top);
  Assert.AreEqual(3, p.Right);
  Assert.AreEqual(3, p.Bottom);
  Assert.AreEqual(3, p.Left);
end;

procedure TLayoutWidgetTests.Padding_HorizontalVertical_SetsPairs;
var
  p : TPadding;
begin
  p := TPadding.HorizontalVertical(5, 2);
  Assert.AreEqual(2, p.Top);
  Assert.AreEqual(5, p.Right);
  Assert.AreEqual(2, p.Bottom);
  Assert.AreEqual(5, p.Left);
end;

procedure TLayoutWidgetTests.Padding_GetWidthHeight_SumSides;
var
  p : TPadding;
begin
  p := TPadding.Make(1, 2, 3, 4);
  Assert.AreEqual(6, p.GetWidth,  'GetWidth = Left + Right');
  Assert.AreEqual(4, p.GetHeight, 'GetHeight = Top + Bottom');
end;

procedure TLayoutWidgetTests.Padding_Equals_DetectsDifferences;
var
  a, b : TPadding;
begin
  a := TPadding.All(2);
  b := TPadding.All(2);
  Assert.IsTrue(a.Equals(b));
  b := TPadding.Make(2, 2, 2, 3);
  Assert.IsFalse(a.Equals(b));
end;

procedure TLayoutWidgetTests.Align_Left_NoLeadingSpace;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  console := BuildPlainWithSink(10, False, sink);
  console.Write(Align(Text('hi'), TAlignment.Left));
  Assert.AreEqual('hi        ', sink.Text);
end;

procedure TLayoutWidgetTests.Align_Center_EqualOrNearEqualPadding;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  console := BuildPlainWithSink(10, False, sink);
  console.Write(Align(Text('hi'), TAlignment.Center));
  Assert.AreEqual('    hi    ', sink.Text);
end;

procedure TLayoutWidgetTests.Align_Right_LeadingSpaces;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  console := BuildPlainWithSink(10, False, sink);
  console.Write(Align(Text('hi'), TAlignment.Right));
  Assert.AreEqual('        hi', sink.Text);
end;

procedure TLayoutWidgetTests.Rows_TwoChildren_SeparatedByLineBreak;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  console := BuildPlainWithSink(10, False, sink);
  console.Write(Rows.Add(Text('a')).Add(Text('b')));
  Assert.AreEqual('a' + sLineBreak + 'b', sink.Text);
end;

procedure TLayoutWidgetTests.Rows_NoExpand_FillingChildShrinksToNaturalWidth;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  // Padder(Text, padding=0) fills its given width with whitespace. With
  // Rows.Expand=False (default), Rows passes the widest child's natural
  // max (= 'hi' = 2) instead of the full maxWidth, so the Padder renders
  // tight rather than filling 20 cells.
  console := BuildPlainWithSink(20, False, sink);
  console.Write(Rows.Add(Padder(Text('hi')).WithPadding(0)));
  Assert.AreEqual('hi', sink.Text);
end;

procedure TLayoutWidgetTests.Rows_Expand_FillingChildSpansFullMaxWidth;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  // Same widget tree but Rows.Expand=True - the Padder fills all 20 cells.
  console := BuildPlainWithSink(20, False, sink);
  console.Write(Rows.WithExpand(True).Add(Padder(Text('hi')).WithPadding(0)));
  Assert.AreEqual('hi' + StringOfChar(' ', 18), sink.Text);
end;

procedure TLayoutWidgetTests.Columns_TwoChildren_SideBySide;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  // width 10, two equal columns (5 each, no gutter for predictable width)
  console := BuildPlainWithSink(10, False, sink);
  console.Write(Columns.Add(Text('ab')).Add(Text('cd')).WithGutter(0));
  // 'ab   cd   ' (each padded to 5)
  Assert.AreEqual('ab   cd   ', sink.Text);
end;

procedure TLayoutWidgetTests.Columns_NoExpand_SizesToNaturalWidths;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  // Expand=False -> each column gets its child's natural width, not an equal
  // split of maxWidth. 'ab' + gutter(0) + 'cd' = 'abcd', no trailing fill.
  console := BuildPlainWithSink(10, False, sink);
  console.Write(
    Columns.Add(Text('ab')).Add(Text('cd'))
      .WithGutter(0)
      .WithExpand(False));
  Assert.AreEqual('abcd', sink.Text);
end;

procedure TLayoutWidgetTests.Grid_FixedColumns_RendersSideBySide;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  g       : IGrid;
begin
  console := BuildPlainWithSink(20, False, sink);
  g := Grid.WithGutter(1).AddFixedColumn(3).AddFixedColumn(5);
  g.AddRow([Text('abc'), Text('hello')]);
  console.Write(g);
  // col1 = 'abc' (fits 3), gutter = ' ', col2 = 'hello' (fits 5) => 'abc hello'
  Assert.AreEqual('abc hello', sink.Text);
end;

procedure TLayoutWidgetTests.Grid_StarColumn_NoExpand_SizesToNaturalContent;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  g       : IGrid;
begin
  // Default FExpand=False: star column behaves like an auto column (sized to
  // natural content max, not stretched to absorb leftover). With maxWidth=20,
  // the star column 'hello' is 5 chars wide, so total = 3 + 1 + 5 = 9.
  console := BuildPlainWithSink(20, False, sink);
  g := Grid.WithGutter(1).AddFixedColumn(3).AddStarColumn(1);
  g.AddRow([Text('abc'), Text('hello')]);
  console.Write(g);
  Assert.AreEqual('abc hello', sink.Text);
end;

procedure TLayoutWidgetTests.Grid_StarColumn_Expand_AbsorbsLeftover;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  g       : IGrid;
begin
  // FExpand=True: the star column absorbs leftover space in maxWidth.
  // maxWidth=20 - fixed(3) - gutter(1) = 16 for the star column.
  // 'hello' renders left-padded into a 16-cell column -> 'hello' + 11 spaces.
  console := BuildPlainWithSink(20, False, sink);
  g := Grid.WithGutter(1).AddFixedColumn(3).AddStarColumn(1).WithExpand(True);
  g.AddRow([Text('abc'), Text('hello')]);
  console.Write(g);
  Assert.AreEqual('abc hello' + StringOfChar(' ', 11), sink.Text);
end;

procedure TLayoutWidgetTests.Grid_StarColumn_NoExpand_TooWide_ShrinksStarNotAuto;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  g       : IGrid;
begin
  // Expand off, star content (28) too wide for maxWidth=20. The star column
  // is the flexible one: it gives up the excess and folds, while the auto
  // label column keeps its natural 5 cells.
  //   auto(5) + gutter(1) + star(14) = 20
  console := BuildPlainWithSink(20, False, sink);
  g := Grid.WithGutter(1).AddAutoColumn.AddStarColumn(1);
  g.AddRow([Text('Name:'), Text(StringOfChar('x', 28))]);
  console.Write(g);
  Assert.AreEqual(
    'Name: ' + StringOfChar('x', 14) + sLineBreak +
    '      ' + StringOfChar('x', 14),
    sink.Text);
end;

procedure TLayoutWidgetTests.Grid_StarColumn_NoExpand_TooWide_StarTakesWhatAutoLeaves;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  g       : IGrid;
begin
  // Same rule as Expand=True: auto columns are sized first and the star
  // column gets what is left, even when the auto column is the wider one.
  //   auto(12) + gutter(1) + star(7) = 20
  console := BuildPlainWithSink(20, False, sink);
  g := Grid.WithGutter(1).AddAutoColumn.AddStarColumn(1);
  g.AddRow([Text('LongerLabel:'), Text(StringOfChar('x', 10))]);
  console.Write(g);
  Assert.AreEqual(
    'LongerLabel: ' + StringOfChar('x', 7) + sLineBreak +
    StringOfChar(' ', 13) + 'xxx    ',
    sink.Text);
end;

procedure TLayoutWidgetTests.Panel_AsciiBorder_SingleLineChild_Produces3Lines;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  expected : string;
begin
  console := BuildPlainWithSink(7, False, sink);
  console.Write(Panel(Text('x')).WithBorder(TBoxBorderKind.Ascii).WithPadding(1));
  // width=7 => outer = '+-----+' (top), '| x   |' (body), '+-----+' (bottom)
  expected := '+-----+' + sLineBreak +
              '| x   |' + sLineBreak +
              '+-----+';
  Assert.AreEqual(expected, sink.Text);
end;

procedure TLayoutWidgetTests.Panel_WithHeader_InsertsHeaderText;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
begin
  console := BuildPlainWithSink(20, False, sink);
  console.Write(Panel(Text('hi')).WithBorder(TBoxBorderKind.Ascii).WithHeader('Info'));
  Assert.Contains(sink.Text, ' Info ');
  Assert.StartsWith('+', sink.Text);
end;

procedure TLayoutWidgetTests.Panel_WithHeader_ParsesMarkupTags;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  output  : string;
begin
  // The header title must route through the markup parser so callers can
  // include style tags like '[bold]Greeting[/]'.
  console := BuildPlainWithSink(30, False, sink);
  console.Write(Panel(Text('hi')).WithBorder(TBoxBorderKind.Ascii).WithHeader('[bold]Greeting[/]'));
  output := sink.Text;
  Assert.IsTrue(Pos('Greeting', output) > 0,
    'Body of the header markup tag must appear');
  Assert.IsTrue(Pos('[bold]', output) = 0,
    'Literal markup tag must not leak through to the panel header');
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutWidgetTests);

end.

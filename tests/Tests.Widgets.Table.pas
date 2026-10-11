unit Tests.Widgets.Table;

interface

uses
  DUnitX.TestFramework,
  VSoft.AnsiConsole,
  VSoft.AnsiConsole.Types,
  VSoft.AnsiConsole.Console,
  VSoft.AnsiConsole.Color,
  VSoft.AnsiConsole.Style,
  VSoft.AnsiConsole.Widgets.Table,
  VSoft.AnsiConsole.Widgets.Grid,
  VSoft.AnsiConsole.Borders.Table;

type
  [TestFixture]
  TTableWidgetTests = class
  public
    [Test] procedure Ascii_TwoColumnsOneRow_ExactLayout;
    [Test] procedure NoHeader_OmitsHeaderAndSeparator;
    [Test] procedure None_BorderProducesWhitespaceDelimited;
    [Test] procedure Markdown_Border_ProducesMarkdownTable;
    [Test] procedure Title_RendersAboveTable;
    [Test] procedure Title_HonoursMarkup;
    [Test] procedure Caption_HonoursMarkup;

    [Test] procedure AddEmptyRow_AppendsBlankRow;
    [Test] procedure InsertRow_AtIndex_ShiftsExisting;
    [Test] procedure InsertRow_OutOfRange_ClampsToEnd;
    [Test] procedure RemoveRow_AtIndex_RemovesAndShifts;
    [Test] procedure RemoveRow_OutOfRange_LeavesUnchanged;
    [Test] procedure UpdateCell_ChangesRenderedContent;
    [Test] procedure TitleStyle_AppliesAnsiColorWhenColorsOn;
    [Test] procedure Cell_WithStyle_OverridesPlainContent;

    [Test] procedure Header_WithMarkup_MeasuredWithoutTags;
    [Test] procedure Header_MultiLine_MeasuredByLongestLine;
    [Test] procedure Simple_Border_OmitsBlankEdgeLines;
    [Test] procedure Minimal_Border_OmitsBlankEdgeLines;
    [Test] procedure Horizontal_Border_KeepsTopAndBottomEdges;
  end;

implementation

uses
  System.SysUtils,
  Testing.AnsiConsole;

function BuildPlain(width : Integer; unicode : Boolean;
                     out sink : ICapturedAnsiOutput) : IAnsiConsole;
begin
  BuildCapturedConsole(TColorSystem.NoColors, width, unicode, result, sink);
end;

procedure TTableWidgetTests.Ascii_TwoColumnsOneRow_ExactLayout;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  expected : string;
begin
  console := BuildPlain(80, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii);
  t.AddColumn('Name', TGridColumnWidth.Fixed, 4, TAlignment.Left);
  t.AddColumn('Qty',  TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['ab', '12']);
  console.Write(t);

  expected :=
    '+------+-----+' + sLineBreak +
    '| Name | Qty |' + sLineBreak +
    '+------+-----+' + sLineBreak +
    '| ab   | 12  |' + sLineBreak +
    '+------+-----+';
  Assert.AreEqual(expected, sink.Text);
end;

procedure TTableWidgetTests.NoHeader_OmitsHeaderAndSeparator;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  expected : string;
begin
  console := BuildPlain(80, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii).WithShowHeader(False);
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddColumn('B', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['1',  '2']);
  console.Write(t);

  expected :=
    '+-----+-----+' + sLineBreak +
    '| 1   | 2   |' + sLineBreak +
    '+-----+-----+';
  Assert.AreEqual(expected, sink.Text);
end;

procedure TTableWidgetTests.None_BorderProducesWhitespaceDelimited;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
begin
  console := BuildPlain(40, False, sink);
  t := Table.WithBorder(TTableBorderKind.None);
  t.AddColumn('A', TGridColumnWidth.Fixed, 4, TAlignment.Left);
  t.AddColumn('B', TGridColumnWidth.Fixed, 4, TAlignment.Left);
  t.AddRow(['hi', 'bye']);
  console.Write(t);
  text := sink.Text;
  // No pipe or dash characters when border is None.
  Assert.IsFalse(Pos('|', text) > 0, 'None border should not emit pipes');
  Assert.IsFalse(Pos('-', text) > 0, 'None border should not emit dashes');
  // Content must still be present.
  Assert.Contains(text, 'hi');
  Assert.Contains(text, 'bye');
end;

procedure TTableWidgetTests.Markdown_Border_ProducesMarkdownTable;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
begin
  console := BuildPlain(80, False, sink);
  t := Table.WithBorder(TTableBorderKind.Markdown);
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddColumn('B', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['1', '2']);
  console.Write(t);
  text := sink.Text;
  // Markdown tables have header row with pipes, a separator row of dashes, and data rows.
  Assert.Contains(text, '| A   | B   |');
  Assert.Contains(text, '|-----|-----|');
  Assert.Contains(text, '| 1   | 2   |');
end;

procedure TTableWidgetTests.Title_RendersAboveTable;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
  idxTitle, idxTop : Integer;
begin
  console := BuildPlain(40, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii).WithTitle('My Table');
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['x']);
  console.Write(t);
  text := sink.Text;

  idxTitle := Pos('My Table', text);
  idxTop   := Pos('+', text);
  Assert.IsTrue(idxTitle > 0,           'Title text should appear in output');
  Assert.IsTrue(idxTop > 0,             'Top border should appear in output');
  Assert.IsTrue(idxTitle < idxTop,      'Title should appear before the top border');
end;

procedure TTableWidgetTests.Title_HonoursMarkup;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
begin
  // TColorSystem.NoColors strips styling but the markup parser still consumes the
  // [bold]...[/] tags. The output should contain 'Heading', not the raw
  // brackets.
  console := BuildPlain(40, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii).WithTitle('[bold]Heading[/]');
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['x']);
  console.Write(t);
  text := sink.Text;
  Assert.IsTrue(Pos('Heading', text) > 0, 'Title body should appear in output');
  Assert.IsTrue(Pos('[bold]', text) = 0, 'Markup tag should not leak through as literal text');
  Assert.IsTrue(Pos('[/]', text) = 0,    'Closing markup tag should not leak through');
end;

procedure TTableWidgetTests.Caption_HonoursMarkup;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
begin
  console := BuildPlain(40, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii).WithCaption('[italic]Footnote[/]');
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['x']);
  console.Write(t);
  text := sink.Text;
  Assert.IsTrue(Pos('Footnote', text) > 0, 'Caption body should appear in output');
  Assert.IsTrue(Pos('[italic]', text) = 0, 'Markup tag should not leak through as literal text');
  Assert.IsTrue(Pos('[/]', text) = 0,      'Closing markup tag should not leak through');
end;

procedure TTableWidgetTests.AddEmptyRow_AppendsBlankRow;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
begin
  console := BuildPlain(40, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii);
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['xx']);
  t.AddEmptyRow;
  Assert.AreEqual(2, t.RowCount);
  console.Write(t);
  text := sink.Text;
  // Blank row line should look like '|     |' (3 cell width + 2 pad).
  Assert.Contains(text, '|     |');
end;

procedure TTableWidgetTests.InsertRow_AtIndex_ShiftsExisting;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
  posA, posB, posC : Integer;
begin
  console := BuildPlain(40, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii).WithShowHeader(False);
  t.AddColumn('X', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['aa']);
  t.AddRow(['cc']);
  t.InsertRow(1, ['bb']);
  Assert.AreEqual(3, t.RowCount);
  console.Write(t);
  text := sink.Text;
  posA := Pos('aa', text);
  posB := Pos('bb', text);
  posC := Pos('cc', text);
  Assert.IsTrue(posA > 0,           'Row aa missing');
  Assert.IsTrue(posB > posA,        'Row bb should appear after aa');
  Assert.IsTrue(posC > posB,        'Row cc should appear after bb');
end;

procedure TTableWidgetTests.InsertRow_OutOfRange_ClampsToEnd;
var
  t : ITable;
begin
  t := Table;
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['aa']);
  t.InsertRow(99, ['zz']);
  Assert.AreEqual(2, t.RowCount);
end;

procedure TTableWidgetTests.RemoveRow_AtIndex_RemovesAndShifts;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
begin
  console := BuildPlain(40, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii).WithShowHeader(False);
  t.AddColumn('X', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['aa']);
  t.AddRow(['bb']);
  t.AddRow(['cc']);
  t.RemoveRow(1);
  Assert.AreEqual(2, t.RowCount);
  console.Write(t);
  text := sink.Text;
  Assert.IsTrue(Pos('aa', text) > 0, 'aa should remain');
  Assert.IsTrue(Pos('bb', text) = 0, 'bb should be removed');
  Assert.IsTrue(Pos('cc', text) > 0, 'cc should remain');
end;

procedure TTableWidgetTests.RemoveRow_OutOfRange_LeavesUnchanged;
var
  t : ITable;
begin
  t := Table;
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['aa']);
  t.RemoveRow(-1);
  t.RemoveRow(99);
  Assert.AreEqual(1, t.RowCount);
end;

procedure TTableWidgetTests.UpdateCell_ChangesRenderedContent;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  text    : string;
begin
  console := BuildPlain(40, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii).WithShowHeader(False);
  t.AddColumn('A', TGridColumnWidth.Fixed, 5, TAlignment.Left);
  t.AddRow(['old']);
  t.UpdateCell(0, 0, 'new');
  console.Write(t);
  text := sink.Text;
  Assert.IsTrue(Pos('new', text) > 0, 'updated value should appear');
  Assert.IsTrue(Pos('old', text) = 0, 'previous value should be replaced');
end;

procedure TTableWidgetTests.TitleStyle_AppliesAnsiColorWhenColorsOn;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  red     : TAnsiStyle;
  text    : string;
begin
  // TColorSystem.TrueColor lets the writer emit SGR escapes so we can verify the
  // title style flowed through. The exact red SGR is '38;2;255;0;0'.
  BuildCapturedConsole(TColorSystem.TrueColor, 40, False, console, sink);
  red := TAnsiStyle.Plain.WithForeground(TAnsiColor.Red);
  t := Table.WithBorder(TTableBorderKind.Ascii)
       .WithTitle(TableTitle('Heading').WithStyle(red));
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['x']);
  console.Write(t);
  text := sink.Text;
  Assert.IsTrue(Pos('Heading', text) > 0,           'Title text missing');
  Assert.IsTrue(Pos('38;2;255;0;0', text) > 0,
                'Red title style should emit a true-color SGR sequence');
end;

procedure TTableWidgetTests.Cell_WithStyle_OverridesPlainContent;
var
  console : IAnsiConsole;
  sink    : ICapturedAnsiOutput;
  t       : ITable;
  green   : TAnsiStyle;
  cell    : ITableCell;
  text    : string;
begin
  BuildCapturedConsole(TColorSystem.TrueColor, 40, False, console, sink);
  green := TAnsiStyle.Plain.WithForeground(TAnsiColor.Lime); // pure green
  cell := TableCell('hello').WithStyle(green);
  t := Table.WithBorder(TTableBorderKind.Ascii).WithShowHeader(False);
  t.AddColumn('A', TGridColumnWidth.Fixed, 6, TAlignment.Left);
  t.AddRow([cell as IRenderable]);
  console.Write(t);
  text := sink.Text;
  Assert.IsTrue(Pos('hello', text) > 0,           'Cell text missing');
  // Lime in our palette is RGB(0,255,0).
  Assert.IsTrue(Pos('38;2;0;255;0', text) > 0,
                'Cell style should emit a true-color SGR sequence');
end;

procedure TTableWidgetTests.Header_WithMarkup_MeasuredWithoutTags;
var
  console  : IAnsiConsole;
  sink     : ICapturedAnsiOutput;
  t        : ITable;
  expected : string;
begin
  // The header is markup: '[grey]self %[/]' is 6 visible cells, so the auto
  // column is 6 wide - the 9 characters of tag syntax take no room.
  console := BuildPlain(80, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii);
  t.AddColumn('[grey]self %[/]');
  t.AddRow(['1']);
  console.Write(t);

  expected :=
    '+--------+' + sLineBreak +
    '| self % |' + sLineBreak +
    '+--------+' + sLineBreak +
    '| 1      |' + sLineBreak +
    '+--------+';
  Assert.AreEqual(expected, sink.Text);
end;

procedure TTableWidgetTests.Header_MultiLine_MeasuredByLongestLine;
var
  console  : IAnsiConsole;
  sink     : ICapturedAnsiOutput;
  t        : ITable;
  expected : string;
begin
  // A two-line header is as wide as its longest line (5), not the sum of
  // both lines (9).
  console := BuildPlain(80, False, sink);
  t := Table.WithBorder(TTableBorderKind.Ascii);
  t.AddColumn('Total'#10'time');
  t.AddRow(['1']);
  console.Write(t);

  expected :=
    '+-------+' + sLineBreak +
    '| Total |' + sLineBreak +
    '| time  |' + sLineBreak +
    '+-------+' + sLineBreak +
    '| 1     |' + sLineBreak +
    '+-------+';
  Assert.AreEqual(expected, sink.Text);
end;

procedure TTableWidgetTests.Simple_Border_OmitsBlankEdgeLines;
var
  console  : IAnsiConsole;
  sink     : ICapturedAnsiOutput;
  t        : ITable;
  expected : string;
begin
  // Simple has no top or bottom edge glyphs, so those rows are left out
  // entirely instead of being drawn as lines of spaces.
  console := BuildPlain(80, True, sink);
  t := Table.WithBorder(TTableBorderKind.Simple);
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['1']);
  console.Write(t);

  expected :=
    '  A    ' + sLineBreak +
    StringOfChar(#$2500, 7) + sLineBreak +
    '  1    ';
  Assert.AreEqual(expected, sink.Text);
end;

procedure TTableWidgetTests.Minimal_Border_OmitsBlankEdgeLines;
var
  console  : IAnsiConsole;
  sink     : ICapturedAnsiOutput;
  t        : ITable;
  expected : string;
begin
  console := BuildPlain(80, True, sink);
  t := Table.WithBorder(TTableBorderKind.Minimal);
  t.AddColumn('A', TGridColumnWidth.Fixed, 1, TAlignment.Left);
  t.AddColumn('B', TGridColumnWidth.Fixed, 1, TAlignment.Left);
  t.AddRow(['1', '2']);
  console.Write(t);

  expected :=
    '  A ' + #$2502 + ' B  ' + sLineBreak +
    ' ' + StringOfChar(#$2500, 3) + #$253C + StringOfChar(#$2500, 3) + ' ' + sLineBreak +
    '  1 ' + #$2502 + ' 2  ';
  Assert.AreEqual(expected, sink.Text);
end;

procedure TTableWidgetTests.Horizontal_Border_KeepsTopAndBottomEdges;
var
  console  : IAnsiConsole;
  sink     : ICapturedAnsiOutput;
  t        : ITable;
  expected : string;
begin
  // Horizontal does have top / bottom glyphs - only glyph-less edges are
  // dropped.
  console := BuildPlain(80, True, sink);
  t := Table.WithBorder(TTableBorderKind.Horizontal);
  t.AddColumn('A', TGridColumnWidth.Fixed, 3, TAlignment.Left);
  t.AddRow(['1']);
  console.Write(t);

  expected :=
    StringOfChar(#$2500, 7) + sLineBreak +
    '  A    ' + sLineBreak +
    StringOfChar(#$2500, 7) + sLineBreak +
    '  1    ' + sLineBreak +
    StringOfChar(#$2500, 7);
  Assert.AreEqual(expected, sink.Text);
end;

initialization
  TDUnitX.RegisterTestFixture(TTableWidgetTests);

end.

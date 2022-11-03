unit BasicInterpreter;

{$SCOPEDENUMS ON}

interface

uses
  Windows,
  BasicClasses, SysUtils, Generics.Collections,
  Generics.Defaults, BasicScanner;

type
  TInterpreter = class
  private type
    TRecursiveCall = function: Double of object;
  private const
    ColumnWidth = 16;
  private
    Console: IConsole;

    // BASIC Mem
    InstantLine: string;// index = -1
    Lines: TLineList;
    Variables: TVarList;
    ForStack: TForStack;

    // Interpreter
    Scanner: TScanner;
    LineIndex: Integer;
    IsRunning: Boolean;
    ExpressionStackLevel: Integer;
    NeedSkipElse: Boolean;

    procedure RequireToken(const TokenType: TTokenType);
    function RecursiveCall(const Func: TRecursiveCall): Double;
    procedure Error(const Position: Integer; const Message: string);

    // Expression
    function BasicFunction: Double;
    function Primitive: Double;
    function Pow: Double;
    function MulAndDiv: Double;
    function AddAndSub: Double;
    function Condition: Double;
    function Expression: Double;

    // BASIC
    procedure NextLine;
    function IsExpression: Boolean;
    procedure RunLine;
    procedure PrepareLine(const NewLineIndex: Integer);
    procedure PrepareInstantLine(const Line: string);
    procedure PerformUserInput(const Input: string);

    // --------------------------------------------------------------------------------------
    // NEW
    procedure ExecuteNew;
    // LIST / LIST <linenumber> / LIST <linenumber1>-<linenumber2>
    procedure ExecuteList;
    // RUN / RUN <linenumber>
    procedure ExecuteRun;
    // SAVE "filename"
    procedure ExecuteSave;
    // LOAD "filename"
    procedure ExecuteLoad;
    // --------------------------------------------------------------------------------------
    // GOTO <linenumber>
    procedure ExecuteGoto;
    // LET <var> = <expression>
    procedure ExecuteLet;
    // PRINT <var1>/"string" ,/; <var2>/"string" ...
    procedure ExecutePrint;
    // INPUT <var1>; <var2> ... / INPUT "<question>"; <var1>; <var2> ...
    procedure ExecuteInput;
    // IF <condition> THEN ...
    procedure ExecuteIf;
    // ELSE ...
    procedure ExecuteElse;
    // FOR <var> = <number1> TO <number2> / FOR <var> = <number1> TO <number2> STEP <number3>
    procedure ExecuteFor;
    // NEXT / NEXT <var>
    procedure ExecuteNext;
    procedure ExecuteSleep;
    // --------------------------------------------------------------------------------------
  public
    constructor Create(const Console: IConsole);
    destructor Destroy; override;
    procedure Run;
  end;

implementation

uses
  Math, StrUtils;

const
  MaxExpressionStackLevel = 32;

const
  sInvite = 'CRAZZZYBASIC v0.2';
  sReinput = 'Bad input, reinput:';
  sClosingParenthesisExpected = 'Closing parenthesis expected';
  sExpressionExpected = 'Expression expected';
  sUnexpectedSymbol = 'Unexpected symbol';
  sBadNumber = 'Bad number';
  sDivisionByZero = 'Division by zero';
  sBadFunctionArgument = 'Bad function argument';
  sOverflow = 'Overflow';
  sInternalError = 'Internal error! Please submit issue to https://github.com/crazzzypeter/CrazzzyBasic';
  sStackOverflow = 'Stack overflow';
  sVariableNotFound = 'Variable not found';
  sExpected1But2Found = 'Expected "%s" but "%s" found';
  sExpectedCommaOrSemicolon = 'Expected "," or ";" separator';
  sUndefinedLineNumber = 'Undefined line number';
  sLineIndexOutOfRange = 'Line index out of range';
  sNextWithoutFor = 'Next without For';
  sFileCanNotLoadWithMessage = 'File can''t load with message "%s"';
  sFileCanNotSaveWithMessage = 'File can''t save with message "%s"';

function TokenTypeToString(const Token: TTokenType): string;
begin
  case Token of
    // types
    TTokenType.Integer:
      Result := 'Integer';
    TTokenType.Float:
      Result := 'Float';
    TTokenType.&String:
      Result := 'String';
    TTokenType.Variable:
      Result := 'Variable';
    // expressions
    TTokenType.Plus:
      Result := '+';
    TTokenType.Minus:
      Result := '-';
    TTokenType.Multiply:
      Result := '*';
    TTokenType.Divide:
      Result := '/';
    TTokenType.Power:
      Result := '^';
    TTokenType.LeftBracket:
      Result := '(';
    TTokenType.RightBracket:
      Result := ')';
    // separators
    TTokenType.Comma:
      Result := ',';
    TTokenType.Semicolon:
      Result := ';';
    TTokenType.Colon:
      Result := ':';
    // conditions
    TTokenType.Equality:
      Result := '=';
    TTokenType.LessThanOrEqual:
      Result := '<=';
    TTokenType.NotEqual:
      Result := '<>';
    TTokenType.LessThan:
      Result := '<';
    TTokenType.GreaterThanOrEqual:
      Result := '>=';
    TTokenType.GreaterThan:
      Result := '>';
    // directives
    TTokenType.List:
      Result := 'List';
    TTokenType.New:
      Result := 'New';
    TTokenType.Run:
      Result := 'Run';
    TTokenType.Load:
      Result := 'Load';
    TTokenType.Save:
      Result := 'Save';
    // operators
    TTokenType.Print:
      Result := 'Print';
    TTokenType.Input:
      Result := 'Input';
    TTokenType.Let:
      Result := 'Let';
    TTokenType.Rem:
      Result := 'Rem';
    TTokenType.ClearScreen:
      Result := 'ClearScreen';
    TTokenType.&Goto:
      Result := 'Goto';
    TTokenType.&If:
      Result := 'If';
    TTokenType.&Then:
      Result := 'Then';
    TTokenType.&Else:
      Result := 'Else';
    TTokenType.&For:
      Result := 'For';
    TTokenType.&To:
      Result := 'To';
    TTokenType.Step:
      Result := 'Step';
    TTokenType.Next:
      Result := 'Next';
      TTokenType.Sleep:
      Result := 'Sleep';
    // functions
    TTokenType.Sin:
      Result := 'Sin(';
    TTokenType.Cos:
      Result := 'Cos(';
    TTokenType.Tan:
      Result := 'Tan(';
    TTokenType.ArcSin:
      Result := 'ArcSin(';
    TTokenType.ArcCos:
      Result := 'ArcCos(';
    TTokenType.ArcTan:
      Result := 'ArcTan(';
    TTokenType.Sqrt:
      Result := 'Sqrt(';
    TTokenType.Log:
      Result := 'Log(';
    TTokenType.Exp:
      Result := 'Sin(';
    TTokenType.Abs:
      Result := 'Abs(';
    TTokenType.Sign:
      Result := 'Sign(';
    TTokenType.Int:
      Result := 'Int(';
    TTokenType.Frac:
      Result := 'Frac(';
    TTokenType.Random:
      Result := 'Random';
    
    // terminal
    TTokenType.Terminal:
      Result := 'Terminal';
    else
      Result := 'WHAT?' + IntToStr(Integer(Token));
  end;
end;

constructor TInterpreter.Create(const Console: IConsole);
begin
  inherited Create;
  Self.Console := Console;
  Scanner := TScanner.Create;
  Lines := TLineList.Create;
  Variables := TVarList.Create;
  ForStack := TForStack.Create;
end;

destructor TInterpreter.Destroy;
begin
  Lines.Free;
  Scanner.Free;
  Variables.Free;
  ForStack.Free;
  inherited;
end;

function TInterpreter.RecursiveCall(const Func: TRecursiveCall): Double;
begin
  ExpressionStackLevel := ExpressionStackLevel + 1;
  if ExpressionStackLevel > MaxExpressionStackLevel then
    Error(Scanner.PrevPosition, sStackOverflow);
  Result := Func();
  ExpressionStackLevel := ExpressionStackLevel - 1;
end;

procedure TInterpreter.RequireToken(const TokenType: TTokenType);
begin
  if Scanner.Token <> TokenType then
    Error(Scanner.PrevPosition, Format(sExpected1But2Found,
      [TokenTypeToString(TokenType), TokenTypeToString(Scanner.Token)]));
end;

procedure TInterpreter.Error(const Position: Integer; const Message: string);
begin
  if LineIndex = -1 then
    raise EBasicError.Create(Position, Message)
  else
    raise EBasicError.Create(Lines.Numbers[LineIndex], Position, Message)
end;

procedure TInterpreter.PrepareInstantLine(const Line: string);
begin
  LineIndex := -1;
  IsRunning := False;
  InstantLine := Line;
  PrepareLine(LineIndex);
end;

procedure TInterpreter.PrepareLine(const NewLineIndex: Integer);
begin
  if NewLineIndex <> -1 then
  begin
    LineIndex := NewLineIndex;
    Scanner.AssignLine(Lines.Lines[NewLineIndex]);
    IsRunning := True;
  end else
    Scanner.AssignLine(InstantLine);

  NeedSkipElse := True;
end;


function TInterpreter.BasicFunction: Double;
var
  FunctionPos: Integer;
  FunctionToken: TTokenType;
  X: Double;
begin
  FunctionToken := Scanner.Token;
  FunctionPos := Scanner.PrevPosition;
  Scanner.NextToken;
  X := RecursiveCall(Condition);
  RequireToken(TTokenType.RightBracket);
  Scanner.NextToken;

  if IsNan(X) then
    Exit(NaN);

  Result := NaN;// for compiler paranoia
  case FunctionToken of
    // SIN
    TTokenType.Sin:
      Result := Sin(X);
    // COS
    TTokenType.Cos:
      Result := Cos(X);
    // TAN
    TTokenType.Tan:
      Result := Tan(X);
    // ARCSIN
    TTokenType.ArcSin:
      if (X >= 1.0) and (X <= 1.0) then
        Result := ArcSin(X)
      else
        Error(FunctionPos, sBadFunctionArgument);
    // ARCCOS
    TTokenType.ArcCos:
      if (X >= 1.0) and (X <= 1.0) then
        Result := ArcCos(X)
      else
        Error(FunctionPos, sBadFunctionArgument);
    // ARCTAN
    TTokenType.ArcTan:
      Result := ArcTan(X);
    // SQRT
    TTokenType.Sqrt:
      if X >= 0 then
        Result := Sqrt(X)
      else
        Error(FunctionPos, sBadFunctionArgument);
    // LOG
    TTokenType.Log:
      if (X > 0) then
        Result := Log10(X)
      else
        Error(FunctionPos, sBadFunctionArgument);
    // EXP
    TTokenType.Exp:
      Result := Exp(X);
    // ABS
    TTokenType.Abs:
      Result := Abs(X);
    // SIGN
    TTokenType.Sign:
      Result := Sign(X);
    // INT
    TTokenType.Int:
      Result := Int(X);
    // FRAC
    TTokenType.Frac:
      Result := Frac(X);
    else
      Error(FunctionPos, sInternalError);
  end;
end;

function TInterpreter.Primitive: Double;
begin
  case Scanner.Token of
    // Unary operators +/-
    TTokenType.Plus:
    begin
      Scanner.NextToken;
      Result := RecursiveCall(Primitive);
    end;
    TTokenType.Minus:
    begin
      Scanner.NextToken;
      Result := -RecursiveCall(Primitive);
    end;
    // Primitives
    TTokenType.Float:
    begin
      Scanner.NextToken;
      Result := Scanner.Value;
    end;
    TTokenType.Integer:
    begin
      Scanner.NextToken;
      Result := Scanner.IntegerValue;
    end;
    TTokenType.LeftBracket:
    begin
      Scanner.NextToken;
      Result := RecursiveCall(Condition);
      RequireToken(TTokenType.RightBracket);
      Scanner.NextToken;
    end;
    TTokenType.Variable:
    begin
      if not Variables.TryGetVar(Scanner.Identifier, Result) then
        Error(Scanner.PrevPosition, sVariableNotFound);// error
      Scanner.NextToken;
    end;
    TTokenType.Random:
    begin
      Scanner.NextToken;
      Result := Random;
    end;
    // Functions
    TTokenType.Sin,
    TTokenType.Cos,
    TTokenType.Tan,
    TTokenType.ArcSin,
    TTokenType.ArcCos,
    TTokenType.ArcTan,
    TTokenType.Sqrt,
    TTokenType.Log,
    TTokenType.Exp,
    TTokenType.Abs,
    TTokenType.Sign,
    TTokenType.Int,
    TTokenType.Frac:
    begin
      Result := BasicFunction();
    end;
    else
      Error(Scanner.PrevPosition, sExpressionExpected);// error
  end;
end;

function TInterpreter.IsExpression: Boolean;
begin
  Result := Scanner.Token in
  [
    TTokenType.Plus,
    TTokenType.Minus,
    TTokenType.Float,
    TTokenType.Integer,
    TTokenType.LeftBracket,
    TTokenType.Variable,
    // func
    TTokenType.Sin,
    TTokenType.Cos,
    TTokenType.Tan,
    TTokenType.ArcSin,
    TTokenType.ArcCos,
    TTokenType.ArcTan,
    TTokenType.Sqrt,
    TTokenType.Log,
    TTokenType.Exp,
    TTokenType.Abs,
    TTokenType.Sign,
    TTokenType.Int,
    TTokenType.Frac,
    TTokenType.Random
  ];
end;

function TInterpreter.Pow: Double;
begin
  Result := Primitive;

  while True do
  begin
    case Scanner.Token of
      // ^
      TTokenType.Power:
      begin
        Scanner.NextToken;
        Result := Power(Result, RecursiveCall(Pow));
      end;
      else
        break;
    end;
  end;
end;

function TInterpreter.MulAndDiv: Double;
var
  RightValue: Double;
begin
  Result := Pow;

  while True do
  begin
    case Scanner.Token of
      // *
      TTokenType.Multiply:
      begin
        Scanner.NextToken;
        Result := Result * Pow;
      end;
      // /
      TTokenType.Divide:
      begin
        Scanner.NextToken;
        RightValue := Pow;
        if RightValue = 0.0 then
          Error(Scanner.Position, sDivisionByZero);
        Result := Result / RightValue;
      end;
      else
        break;
    end;
  end;
end;

function TInterpreter.AddAndSub: Double;
begin
  Result := MulAndDiv;

  while True do
  begin
    case Scanner.Token of
      // +
      TTokenType.Plus:
      begin
        Scanner.NextToken;
        Result := Result + MulAndDiv;
      end;
      // -
      TTokenType.Minus:
      begin
        Scanner.NextToken;
        Result := Result - MulAndDiv;
      end;
      else
        break;
    end;
  end;
end;

function TInterpreter.Condition: Double;
begin
  Result := AddAndSub;

  while True do
  begin
    case Scanner.Token of
      // =
      TTokenType.Equality:
      begin
        Scanner.NextToken;
        if Result = AddAndSub then
          Result := 1
        else
          Result := 0;
      end;
      // <=
      TTokenType.LessThanOrEqual:
      begin
        Scanner.NextToken;
        if Result <= AddAndSub then
          Result := 1
        else
          Result := 0;
      end;
      // <
      TTokenType.LessThan:
      begin
        Scanner.NextToken;
        if Result < AddAndSub then
          Result := 1
        else
          Result := 0;
      end;
      // <>
      TTokenType.NotEqual:
      begin
        Scanner.NextToken;
        if Result <> AddAndSub then
          Result := 1
        else
          Result := 0;
      end;
      // >=
      TTokenType.GreaterThanOrEqual:
      begin
        Scanner.NextToken;
        if Result >= AddAndSub then
          Result := 1
        else
          Result := 0;
      end;
      // >
      TTokenType.GreaterThan:
      begin
        Scanner.NextToken;
        if Result > AddAndSub then
          Result := 1
        else
          Result := 0;
      end;
      else
        break;
    end;
  end;
end;

function TInterpreter.Expression: Double;
begin
  ExpressionStackLevel := 0;
  Result := Condition;
  if IsInfinite(Result) or IsNaN(Result) then
    Error(Scanner.PrevPosition, sOverflow);
end;

procedure TInterpreter.ExecuteList;
var
  I: Integer;
  BeginNumber: Integer;
  BeginIndex, EndIndex: Integer;
begin
  // LIST
  Scanner.NextToken;
  // default
  BeginIndex := 0;
  EndIndex := Lines.Count - 1;
  // <number>?
  if Scanner.Token = TTokenType.Integer then
  begin
    Scanner.NextToken;
    BeginNumber := Scanner.IntegerValue;
    // -?
    if Scanner.Token = TTokenType.Minus then
    begin
      // -
      Scanner.NextToken;
      // <number>
      RequireToken(TTokenType.Integer);
      Scanner.NextToken;
      BeginIndex := Lines.SearchIndexByNumber(BeginNumber);
      EndIndex := Lines.SearchIndexByNumber(Scanner.IntegerValue, True);
    end else
    begin
      BeginIndex := Lines.IndexByNumber(BeginNumber);
      EndIndex := BeginIndex;
    end;
  end;
  // END
  RequireToken(TTokenType.Terminal);

  if BeginIndex <> -1 then
    for I := BeginIndex to EndIndex do
    begin
      Console.WriteNewLine(IntToStr(Lines.Numbers[I]) + ' ' + Lines.Lines[I]);
    end;
end;

procedure TInterpreter.ExecuteLoad;
var
  CommandPos: Integer;
begin
  // LOAD
  CommandPos := Scanner.PrevPosition;
  Scanner.NextToken;
  // <filename>
  RequireToken(TTokenType.&String);

  try
    Lines.LoadFromFile(ExtractFilePath(ParamStr(0)) + Scanner.StringValue + '.bas');// hack
  except
    on E: Exception do
      Error(CommandPos, Format(sFileCanNotLoadWithMessage, [E.ToString]));
  end;

  Scanner.NextToken;
  RequireToken(TTokenType.Terminal);
end;

procedure TInterpreter.ExecuteNew;
begin
  // NEW
  Scanner.NextToken;
  RequireToken(TTokenType.Terminal);
  // work
  Lines.Clear;
  Variables.Clear;
end;

// ETO PROSTO AD!
// BUT ETO OK
procedure TInterpreter.ExecuteInput;
  function TryInput: Boolean;
  var
  //  UserQuestion: string;
    InputLine: string;
    InputLinePos: Integer;
    InputString: string;
    InputValue: Double;
  begin
    // INPUT
    Scanner.NextToken;
    // <string>? (user question or ?)
    if Scanner.Token = TTokenType.String then
    begin
      // "string"
      Scanner.NextToken;
      // ;
      RequireToken(TTokenType.Semicolon);
      Scanner.NextToken;
      // print
      Console.Write(Scanner.StringValue);
    end else
      Console.Write('? ');
    // read input
    Console.Read(InputLine);
    InputLinePos := 0;

    while True do
    begin
      // <var>
      RequireToken(TTokenType.Variable);
      Scanner.NextToken;
      // parse var
      InputString := '';
      while not CharInSet(PChar(InputLine)[InputLinePos], [',', #0]) do
      begin
        InputString := InputString + PChar(InputLine)[InputLinePos];
        InputLinePos := InputLinePos + 1;
      end;
      if not TryStrToFloatBasic(InputString, InputValue) then
        Exit(False);// reinput needed
      // save var
      Variables.DefineVar(Scanner.Identifier, InputValue);
      // need next var?
      if Scanner.Token <> TTokenType.Comma then
        Break;
      // prepare for parse next var (skip ",")
      if PChar(InputLine)[InputLinePos] <> ',' then
        Exit(False);// reinput needed
      InputLinePos := InputLinePos + 1;
      Scanner.NextToken;
    end;
    // check terminal
    if PChar(InputLine)[InputLinePos] <> #0 then
      Exit(False);
    Result := True;
  end;

var
  InitialPosition: Integer;
begin
  // save scanner pos
  InitialPosition := Scanner.Position;
  while True do
  begin
    if TryInput then
      Break;// ok

    Scanner.Position := InitialPosition;
    Console.WriteNewLine(sReinput);
  end;
end;

procedure TInterpreter.ExecutePrint;
  function NextColumnPos(Pos: Integer): Integer;
  begin
    result := ((Pos + ColumnWidth {- 1}) div ColumnWidth) * ColumnWidth;// for PRODAVLIVANIE delete "- 1"
  end;
var
  OutputValue: string;
  ConsolePos, NewConsolePos: Integer;
  IsNeedSeparator, IsNeedReturn: Boolean;
begin
  // PRINT
  Scanner.NextToken;

  IsNeedSeparator := False;
  IsNeedReturn := True;
  ConsolePos := 0;
  while True do
  begin
    case Scanner.Token of
      // ","
      TTokenType.Comma:
      begin
        // ","
        Scanner.NextToken;
        // write
        NewConsolePos := NextColumnPos(ConsolePos);
        Console.Write(StrUtils.DupeString(' ', NewConsolePos - ConsolePos));
        ConsolePos := NewConsolePos;
        // setup
        IsNeedSeparator := False;
        IsNeedReturn := False;
      end;
      // ";"
      TTokenType.Semicolon:
      begin
        // ";"
        Scanner.NextToken;
        // setup
        IsNeedSeparator := False;
        IsNeedReturn := False;
      end;
      // expr?
      else
      begin
        // end
        if (not IsExpression) and (Scanner.Token <> TTokenType.&String)  then
          Break;
        // get value
        if IsNeedSeparator then
          Error(Scanner.PrevPosition, sExpectedCommaOrSemicolon);
        if Scanner.Token = TTokenType.String then
        begin
          // <string>
          OutputValue := Scanner.StringValue;
          Scanner.NextToken;
        end else
          OutputValue := FloatToStrBasic(Expression, ColumnWidth - 1);
        // write
        Console.Write(OutputValue);
        ConsolePos := ConsolePos + Length(OutputValue);
        // setup
        IsNeedSeparator := True;
        IsNeedReturn := True;
      end;
    end;
  end;
  if IsNeedReturn then
    Console.Write(#10);
end;

(*procedure TInterpreter.ExecutePrint;
  function NextColumnPos(Pos: Integer): Integer;
  begin
    result := ((Pos + ColumnWidth {- 1}) div ColumnWidth) * ColumnWidth;// for PRODAVLIVANIE delete "- 1"
  end;

var
  OutputValue: string;
  ConsolePos, NewConsolePos: Integer;
  ReturnNeeded: Boolean;
begin
  // PRINT
  Scanner.NextToken;

  ReturnNeeded := True;
  ConsolePos := 0;
  while True do
  begin
    // try get value
    if not (Scanner.Token in [TTokenType.Comma, TTokenType.Semicolon]) then
    begin
      // <string> or <expression>
      if Scanner.Token = TTokenType.String then
      begin
        // <string>
        Scanner.NextToken;
        OutputValue := Scanner.StringValue;
      end
      else
        OutputValue := FloatToStrBasic(Expression, ColumnWidth - 1);
      // write value
      Console.Write(OutputValue);
      ReturnNeeded := True;
    end else
      OutputValue := '';
    // increment virtual cursor
    ConsolePos := ConsolePos + Length(OutputValue);
    // [<,>,<;>]
    if Scanner.Token = TTokenType.Comma then
    begin
      // ","
      Scanner.NextToken;
      // write spaces for align
      NewConsolePos := NextColumnPos(ConsolePos);
      Console.Write(StrUtils.DupeString(' ', NewConsolePos - ConsolePos));
      ConsolePos := NewConsolePos;
      ReturnNeeded := True;
    end
    else if Scanner.Token = TTokenType.Semicolon then
    begin
      // ";"
      Scanner.NextToken;
      ReturnNeeded := False;
    end
    else
      break;
  end;

  if ReturnNeeded then
    Console.Write(#10);
end;*)

procedure TInterpreter.ExecuteLet;
var
  VarName: string;
  Result: Double;
begin
  if Scanner.Token = TTokenType.Let  then
  begin
    // LET
    Scanner.NextToken;
  end;
  // get <var name>
  RequireToken(TTokenType.Variable);
  VarName := Scanner.Identifier;
  Scanner.NextToken;
  // skip =
  RequireToken(TTokenType.Equality);
  Scanner.NextToken;
  // get expression result
  Result := Expression;
  // set var
  Variables.DefineVar(VarName, Result);
end;

procedure TInterpreter.ExecuteRun;
begin
  // RUN
  Scanner.NextToken;
  // <line number>?
  if Scanner.Token = TTokenType.Integer then
  begin
    LineIndex := Lines.IndexByNumber(Scanner.IntegerValue);
    if LineIndex = -1 then
      Error(Scanner.PrevPosition, sUndefinedLineNumber);
    // #0
    Scanner.NextToken;
    RequireToken(TTokenType.Terminal);
  end else
  begin
    // #0
    RequireToken(TTokenType.Terminal);
    LineIndex := Lines.SearchIndexByNumber(0);
    if LineIndex = -1 then
      Exit;
  end;
  // clear
  Variables.Clear;
  // work
  PrepareLine(LineIndex);
  RunLine;
end;

procedure TInterpreter.ExecuteSave;
var
  CommandPos: Integer;
begin
  // SAVE
  CommandPos := Scanner.PrevPosition;
  Scanner.NextToken;
  // <filename>
  RequireToken(TTokenType.&String);

  try
    Lines.SaveToFile(ExtractFilePath(ParamStr(0)) + Scanner.StringValue + '.bas');// hack
  except
    on E: Exception do
      Error(CommandPos, Format(sFileCanNotSaveWithMessage, [E.ToString]));
  end;

  Scanner.NextToken;
  RequireToken(TTokenType.Terminal);
end;

procedure TInterpreter.ExecuteGoto;
begin
  // GOTO
  Scanner.NextToken;
  // <line number>
  RequireToken(TTokenType.Integer);
  // work
  LineIndex := Lines.IndexByNumber(Scanner.IntegerValue);
  if LineIndex = -1 then
    Error(Scanner.PrevPosition, sUndefinedLineNumber);
  PrepareLine(LineIndex);
end;

procedure TInterpreter.ExecuteSleep;
begin
  // SLEEP
  Scanner.NextToken;
  // <pause>
  RequireToken(TTokenType.Integer);
  Scanner.NextToken;
  // work
  Sleep(Scanner.IntegerValue);
end;

procedure TInterpreter.NextLine;
begin
  // hack
  if LineIndex = -1 then
    Exit;

  // Is end of program?
  if LineIndex + 1 < Lines.Count then
  begin
    // prepare next line
    LineIndex := LineIndex + 1;
    PrepareLine(LineIndex);
  end else
  begin
    // end
    //LineIndex := -1;
    IsRunning := False;
  end;
end;

procedure TInterpreter.ExecuteIf;
var
  Condition: Double;
  ElseLevel: Integer;
begin
  // IF
  Scanner.NextToken;
  // <condition>
  Condition := Expression;
  // THEN
  RequireToken(TTokenType.&Then);
  Scanner.NextToken;
  // skip to end line if need
  if Condition = 0.0 then
  begin
    NeedSkipElse := False;
    ElseLevel := 1;
    // search else
    while not (Scanner.Token in [TTokenType.Terminal]) do
    begin
      if Scanner.Token = TTokenType.&If then
      begin
        ElseLevel := ElseLevel + 1;
      end
      else if Scanner.Token = TTokenType.&Else then
      begin
        ElseLevel := ElseLevel - 1;
        if ElseLevel = 0 then
          Break;
      end;
      Scanner.NextToken;
    end;
  end else
    NeedSkipElse := True;
end;

// IF 0 THEN IF 0 THEN PRINT 0 ELSE PRINT 1 ELSE PRINT 2
// IF 0 THEN IF 0 THEN PRINT 0 ELSE PRINT 1 ELSE IF 0 THEN PRINT 2 ELSE PRINT 3
// 10 if 1 then print 1 else print 2 : if 1 then print 3 else print 4

procedure TInterpreter.ExecuteElse;
begin
  // ELSE
  Scanner.NextToken;
  if NeedSkipElse then
  begin
    while not (Scanner.Token in [TTokenType.Terminal]) do
    begin
      Scanner.NextToken;
    end;
  end else
    NeedSkipElse := True;
end;

procedure TInterpreter.ExecuteFor;
var
  ForItem: TForItem;
begin
  // FOR
  Scanner.NextToken;

  // <var>
  RequireToken(TTokenType.Variable);
  Scanner.NextToken;
  ForItem.Target := UpperCase(Scanner.Identifier);
  // "="
  RequireToken(TTokenType.Equality);
  Scanner.NextToken;
  // <expression>
  ForItem.Value := Expression;

  // TO
  RequireToken(TTokenType.&To);
  Scanner.NextToken;
  // <expression>
  ForItem.EndValue := Expression;

  // STEP
  if Scanner.Token = TTokenType.Step then
  begin
    // STEP
    Scanner.NextToken;
    // <expression>
    ForItem.Step := Expression;
  end else
    ForItem.Step := 1.0;

  // Save pos
  ForItem.Position := Scanner.PrevPosition;
  ForItem.LineIndex := LineIndex;
  // def var
  Variables.DefineVar(ForItem.Target, ForItem.Value);
  // Add to ForStack
  ForStack.Add(ForItem);
end;

procedure TInterpreter.ExecuteNext;
var
  ItemIndex: Integer;
  ForItem: TForItem;
  NextPosition: Integer;
begin
  // NEXT
  NextPosition := Scanner.PrevPosition;
  Scanner.NextToken;

  // <variable>
  if Scanner.Token = TTokenType.Variable then
  begin
    ItemIndex := ForStack.IndexByTarget(Scanner.Identifier);
    Scanner.NextToken;
  end
  else
    ItemIndex := ForStack.LastIndex;

  // check
  if ItemIndex = -1 then
    Error(NextPosition, sNextWithoutFor);

  // free for's
  while ItemIndex < ForStack.LastIndex do
  begin
    ForStack.Delete(ForStack.LastIndex);
  end;

  // iter
  ForItem := ForStack[ItemIndex];
  ForItem.Value := ForItem.Value + ForItem.Step;
  ForStack[ItemIndex] := ForItem;
  Variables.DefineVar(ForItem.Target, ForItem.Value);

  // cycle
  if ((ForItem.Step >= 0) and (ForItem.EndValue >= ForItem.Value)) or
     ((ForItem.Step < 0) and (ForItem.EndValue <= ForItem.Value)) then
  begin
    PrepareLine(ForItem.LineIndex);
    Scanner.Position := ForItem.Position;
    Scanner.NextToken;
  end else
    ForStack.Delete(ItemIndex);
end;

procedure ClearScreen;
var
  stdout: THandle;
  csbi: TConsoleScreenBufferInfo;
  ConsoleSize: DWORD;
  NumWritten: DWORD;
  Origin: TCoord;
begin
  stdout := GetStdHandle(STD_OUTPUT_HANDLE);
  Win32Check(stdout<>INVALID_HANDLE_VALUE);
  Win32Check(GetConsoleScreenBufferInfo(stdout, csbi));
  ConsoleSize := csbi.dwSize.X * csbi.dwSize.Y;
  Origin.X := 0;
  Origin.Y := 0;
  Win32Check(FillConsoleOutputCharacter(stdout, ' ', ConsoleSize, Origin,
    NumWritten));
  Win32Check(FillConsoleOutputAttribute(stdout, csbi.wAttributes, ConsoleSize, Origin,
    NumWritten));
  Win32Check(SetConsoleCursorPosition(stdout, Origin));
end;

procedure TInterpreter.RunLine;
begin
  while True do
  begin
    case Scanner.Token of
      TTokenType.Colon:
      begin
        Scanner.NextToken;
        Continue;
      end;
      // PRINT
      TTokenType.Print:
      begin
        ExecutePrint;
      end;
      
      // INPUT
      TTokenType.Input:
      begin
        ExecuteInput;
      end;
      // IF
      TTokenType.&If:
      begin
        ExecuteIf;
        Continue;
      end;

      // ELSE
      TTokenType.&Else:
      begin
        ExecuteElse;
        Continue;
      end;
      // GOTO
      TTokenType.Goto:
      begin
        ExecuteGoto;
        Continue;
      end;
      // FOR
      TTokenType.&For:
      begin
        ExecuteFor;
        Continue;
      end;
      // NEXT
      TTokenType.Next:
      begin
        ExecuteNext;
        Continue;
      end;
      
      // NEXT
      TTokenType.Sleep:
      begin
        ExecuteSleep;
        Continue;
      end;

      TTokenType.ClearScreen:
      begin
        ClearScreen;
        Scanner.NextToken;
      end;
      // LET
      TTokenType.Let, TTokenType.Variable:
      begin
        ExecuteLet;
      end;
      // END OF LINE
      TTokenType.Terminal:
      begin
        // nope
      end;
      // UNEXPECTED TOKEN
      else
        Error(Scanner.PrevPosition, sUnexpectedSymbol);
    end;

    // END OF LINE
    if Scanner.Token = TTokenType.Terminal then
    begin
      NextLine;
      // is running?
      if IsRunning then
        Continue
      else
        Break;
    end;

    // ELSE
    if Scanner.Token = TTokenType.&Else then
      Continue;

    // :
    RequireToken(TTokenType.Colon);
    Scanner.NextToken;
  end;
end;

procedure TInterpreter.PerformUserInput(const Input: string);
var
  Line, NumberString: string;
  Number, InputPos, NumberPos, CodePos: Integer;

  procedure SkipSpaces;
  begin
    while CharInSet(PChar(Input)[InputPos], [#9, ' ']) do
    begin
      InputPos := InputPos + 1;
    end;
  end;
  
begin
  LineIndex := -1;
  InputPos := 0;
  SkipSpaces;

  if CharInSet(PChar(Input)[InputPos], ['0'..'9']) then
  begin
    NumberPos := InputPos;
    // get number
    NumberString := '';
    while CharInSet(PChar(Input)[InputPos], ['0'..'9']) do
    begin
      NumberString := NumberString + PChar(Input)[InputPos];
      InputPos := InputPos + 1;
    end;
    if not TryStrToIntegerBasic(NumberString, Number) then
      Error(NumberPos, sBadNumber);
  
    if (Number < 0) or (Number > Lines.MaxLineNumber) then
      Error(NumberPos, sLineIndexOutOfRange);

    // skip one space
    if PChar(Input)[InputPos] = ' ' then
      CodePos := InputPos + 1
    else
      CodePos := InputPos;
    SkipSpaces;

    // editor
    if PChar(Input)[InputPos] <> #0 then
    begin
      // set line
      Line := '';
      while PChar(Input)[CodePos] <> #0 do
      begin
        Line := Line + PChar(Input)[CodePos];
        CodePos := CodePos + 1;
      end;
      Lines.SetLine(Number, Line);
    end else
    begin
      // delete line
      if Lines.IndexByNumber(Number) <> -1 then
        Lines.DeleteLine(Number)
      else
        Error(NumberPos, sUndefinedLineNumber);
    end;
  end else
  begin
    PrepareInstantLine(Input);
    case Scanner.Token of
      // LIST
      TTokenType.List:
      begin
        ExecuteList;
      end;
      // NEW
      TTokenType.New:
      begin
        ExecuteNew;
      end;
      
      // RUN
      TTokenType.Run:
      begin
        ExecuteRun;
      end;
      // SAVE
      TTokenType.Save:
      begin
        ExecuteSave;
      end;
      // LOAD
      TTokenType.Load:
      begin
        ExecuteLoad;
      end;
      // OTHER
      else
      begin
        RunLine;
      end;
    end;
  end;
end;

procedure TInterpreter.Run;
var
  Input: string;
begin
  Randomize;// hack
  Console.WriteNewLine(sInvite);
  while True do
  begin
    Console.ReadNewLine(Input);

    try
      PerformUserInput(Input);
    except
      on E: EBasicError do
      begin
        Console.WriteNewLine('| ' + Scanner.CurrentLine);
        Console.WriteNewLine('| ' + StrUtils.DupeString(' ', E.Position) + '^');
        Console.WriteNewLine('| ' + E.Message);
      end;
      on E: Exception do
      begin
        Console.WriteNewLine(sInternalError);
      end;
    end;
  end;
end;

end.

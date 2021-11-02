unit BasicScanner;

{$SCOPEDENUMS ON}

interface

uses
  Classes, SysUtils, BasicClasses;

type
  TTokenType = (
    // types
    Integer, Float, &String, Variable,
    // expressions
    Plus, Minus, Multiply, Divide, Power,
    LeftBracket, RightBracket,
    // separators
    Comma,// ,
    Semicolon,// ;
    Colon,// :
    // conditions
    Equality,// =
    LessThanOrEqual,// <=
    NotEqual,// <>
    LessThan,// <
    GreaterThanOrEqual,// >=
    GreaterThan,// >
    // directives
    List, New, Run,
    Load, Save,
    // operators
    Print,
    Input,
    Let,
    Rem,
    &Goto,
    &If,
    &Then,
    &Else,
    &For,
    &To,
    Step,
    Next,
    Sleep,
    // functions
    Sin,
    Cos,
    Tan,
    ArcSin,
    ArcCos,
    ArcTan,
    Sqrt,
    Log,
    Exp,
    Abs,
    Sign,
    Int,
    Frac,
    Random,
    // terminal
    Terminal
  );

  TScanner = class
  private
    // code
    FCurrentLine: string;
    // current position in code line
    FPosition: Integer;
    // previous position in code line
    FPrevPosition: Integer;
    // current token
    FToken: TTokenType;
    // current identifier (function/variable name)
    FIdentifier: string;
    // current value
    FValue: Double;
    FStringValue: string;
    FIntegerValue: Integer;
    procedure Error(const Position: Integer; const Message: string);
    function CurentChar: Char; inline;
    procedure NextChar; inline;
    procedure SkipSpaces; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AssignLine(const NewLine: string);
    procedure NextToken;
    property CurrentLine: string read FCurrentLine;
    property Position: Integer read FPosition write FPosition;
    property PrevPosition: Integer read FPrevPosition;
    property Token: TTokenType read FToken;
    property Value: Double read FValue;
    property StringValue: string read FStringValue;
    property IntegerValue: Integer read FIntegerValue;
    property Identifier: string read FIdentifier;
  end;

implementation

const
  sUnexpectedSymbol = 'Unexpected symbol';
  sUnknownFunction = 'Unknown function';
  sBadNumber = 'Bad number';
  sUnexpectedTerminal = 'Unexpected terminal';

{ TScanner }

constructor TScanner.Create;
begin
  AssignLine('');
end;

destructor TScanner.Destroy;
begin
  inherited;
end;

procedure TScanner.Error(const Position: Integer; const Message: string);
begin
  raise EBasicError.Create(Position, Message);
end;

procedure TScanner.AssignLine(const NewLine: string);
begin
  FCurrentLine := NewLine;
  FPosition := 0;
  NextToken;
end;

function TScanner.CurentChar: Char;
begin
  Result := PChar(FCurrentLine)[Position];
end;

procedure TScanner.NextChar;
begin
  FPosition := FPosition + 1;
end;

procedure TScanner.NextToken;
var
  TokenString: string;
begin
  SkipSpaces;
  FPrevPosition := Position;

  case CurentChar of
    '0'..'9':
    begin
      FToken := TTokenType.Integer;
      // for ex: 12.34e+56
      // 12
      while CharInSet(CurentChar, ['0'..'9']) do
      begin
        TokenString := TokenString + CurentChar;
        NextChar;
      end;
      // .
      if CurentChar = '.' then
      begin
        FToken := TTokenType.Float;// has '.' => not int
        TokenString := TokenString + CurentChar;
        NextChar;
      end;
      // 34
      while CharInSet(CurentChar, ['0'..'9']) do
      begin
        TokenString := TokenString + CurentChar;
        NextChar;
      end;
      // e
      if CharInSet(CurentChar, ['e', 'E']) then
      begin
        FToken := TTokenType.Float;// has 'e' => not int
        TokenString := TokenString + CurentChar;
        NextChar;
        // +/-
        if CharInSet(CurentChar, ['-', '+']) then
        begin
          TokenString := TokenString + CurentChar;
          NextChar;
        end;
        // 56
        if not CharInSet(CurentChar, ['0'..'9']) then
          Error(Position, sBadNumber);
          //raise EBasicError.Create(Position, sBadNumber);// error
        while CharInSet(CurentChar, ['0'..'9']) do
        begin
          TokenString := TokenString + CurentChar;
          NextChar;
        end;
      end;

      // convert to IntegerValue if possible
      if (FToken = TTokenType.Float) or (not TryStrToIntegerBasic(TokenString, FIntegerValue)) then
      begin
        // convert to Value if possible
        FToken := TTokenType.Float;
        if not TryStrToFloatBasic(TokenString, FValue) then
          Error(PrevPosition, sBadNumber);
      end;
    end;
    '+':
    begin
      FToken := TTokenType.Plus;
      NextChar;
    end;
    '-':
    begin
      FToken := TTokenType.Minus;
      NextChar;
    end;
    '*':
    begin
      FToken := TTokenType.Multiply;
      NextChar;
    end;
    '/':
    begin
      FToken := TTokenType.Divide;
      NextChar;
    end;
    '^':
    begin
      FToken := TTokenType.Power;
      NextChar;
    end;
    '(':
    begin
      FToken := TTokenType.LeftBracket;
      NextChar;
    end;
    ')':
    begin
      FToken := TTokenType.RightBracket;
      NextChar;
    end;
    'a'..'z', 'A'..'Z':
    begin
      TokenString := '';
      // abc
      while CharInSet(CurentChar, ['a'..'z', 'A'..'Z', '0'..'9']) do
      begin
        TokenString := TokenString + UpCase(CurentChar);
        NextChar;
      end;
      // (
      if CurentChar = '(' then
      begin
        NextChar;

        {nop}if TokenString = 'SIN' then
          FToken := TTokenType.Sin
        else if TokenString = 'COS' then
          FToken := TTokenType.Cos
        else if TokenString = 'TAN' then
          FToken := TTokenType.Tan
        else if TokenString = 'ARCSIN' then
          FToken := TTokenType.ArcSin
        else if TokenString = 'ARCCOS' then
          FToken := TTokenType.ArcCos
        else if TokenString = 'ARCTAN' then
          FToken := TTokenType.ArcTan
        else if TokenString = 'SQRT' then
          FToken := TTokenType.Sqrt
        else if TokenString = 'LOG' then
          FToken := TTokenType.Log
        else if TokenString = 'EXP' then
          FToken := TTokenType.Exp
        else if TokenString = 'ABS' then
          FToken := TTokenType.Abs
        else if TokenString = 'SIGN' then
          FToken := TTokenType.Sign
        else if TokenString = 'INT' then
          FToken := TTokenType.Int
        else if TokenString = 'FRAC' then
          FToken := TTokenType.Frac
        else Error(PrevPosition, sUnknownFunction);
      end else
      begin
        {nop}if TokenString = 'LIST' then
          FToken := TTokenType.List
        else if TokenString = 'NEW' then
          FToken := TTokenType.New
        else if TokenString = 'LOAD' then
          FToken := TTokenType.Load
        else if TokenString = 'SAVE' then
          FToken := TTokenType.Save
        else if TokenString = 'PRINT' then
          FToken := TTokenType.Print
        else if TokenString = 'LET' then
          FToken := TTokenType.Let
        else if TokenString = 'REM' then
          FToken := TTokenType.Rem
        else if TokenString = 'RUN' then
          FToken := TTokenType.Run
        else if TokenString = 'GOTO' then
          FToken := TTokenType.&Goto
        else if TokenString = 'INPUT' then
          FToken := TTokenType.Input
        else if TokenString = 'IF' then
          FToken := TTokenType.&If
        else if TokenString = 'THEN' then
          FToken := TTokenType.&Then
        else if TokenString = 'ELSE' then
          FToken := TTokenType.&Else
        else if TokenString = 'FOR' then
          FToken := TTokenType.&For
        else if TokenString = 'TO' then
          FToken := TTokenType.&To
        else if TokenString = 'STEP' then
          FToken := TTokenType.Step
        else if TokenString = 'NEXT' then
          FToken := TTokenType.Next
        else if TokenString = 'SLEEP' then
          FToken := TTokenType.Sleep
        else if TokenString = 'RANDOM' then
          FToken := TTokenType.Random
        else
        begin
          FToken := TTokenType.Variable;
          FIdentifier := TokenString;
        end;
      end;
    end;
    '"':
    begin
      FToken := TTokenType.&String;
      FStringValue := '';
      NextChar;
      while (CurentChar <> '"') and (CurentChar <> #0) do
      begin
        FStringValue := FStringValue + CurentChar;
        NextChar;
      end;
      if CurentChar = #0 then
        Error(Position, sUnexpectedTerminal);
      NextChar;
    end;
    ',':
    begin
      FToken := TTokenType.Comma;
      NextChar;
    end;
    ';':
    begin
      FToken := TTokenType.Semicolon;
      NextChar;
    end;
    ':':
    begin
      FToken := TTokenType.Colon;
      NextChar;
    end;
    '=':
    begin
      FToken := TTokenType.Equality;
      NextChar;
    end;
    '<':
    begin
      NextChar;
      if CurentChar = '=' then
      begin
        FToken := TTokenType.LessThanOrEqual;
        NextChar;
      end
      else if CurentChar = '>' then
      begin
        FToken := TTokenType.NotEqual;
        NextChar;
      end else
        FToken := TTokenType.LessThan;
    end;
    '>':
    begin
      NextChar;
      if CurentChar = '=' then
      begin
        FToken := TTokenType.GreaterThanOrEqual;
        NextChar;
      end else
        FToken := TTokenType.GreaterThan;
    end;
    #0:
    begin
      FToken := TTokenType.Terminal;
    end;
    else
      Error(Position, sUnexpectedSymbol);// error
  end;
end;

procedure TScanner.SkipSpaces;
begin
  while CharInSet(CurentChar, [#9, ' ']) do
  begin
    NextChar;
  end;
end;

end.

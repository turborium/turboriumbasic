unit BasicClasses;

{$SCOPEDENUMS ON}

interface

uses
  SysUtils, Generics.Collections, Generics.Defaults;

type
  IConsole = interface
    procedure ReadNewLine(out Line: string);
    procedure Read(out Str: string);
    procedure WriteNewLine(const Line: string);
    procedure Write(const Str: string);
  end;

	EBasicError = class(Exception)
	private
		FLineNumber: Integer;
		FPosition: Integer;
	public
		constructor Create(const Position: Integer; const Message: string); overload;
		constructor Create(const LineNumber, Position: Integer; const Message: string); overload;
		property Position: Integer read FPosition;
		property LineNumber: Integer read FLineNumber;
  end;

  TLineList = class
  private type
    TLine = record
    private
      FNumber: Integer;
      FCode: string;
    public
      constructor Create(const Number: Integer; const Code: string);
      function ToString: string;
      property Number: Integer read FNumber;
      property Code: string read FCode;
    end;
    TLineComparer = class(TComparer<TLine>)
    public
      function Compare(const Left, Right: TLine): Integer; override;
    end;
  private
    List: TList<TLine>;
    function GetLine(Index: Integer): string;
    function GetLineCount: Integer;
    function GetNumber(Index: Integer): Integer;
  public const
    MaxLineNumber = 100000;
  public
    constructor Create;
    destructor Destroy; override;
    function SearchIndexByNumber(const Number: Integer; const Upward: Boolean = False): Integer;
    function IndexByNumber(const Number: Integer): Integer;
    property Lines[Index: Integer]: string read GetLine;
    property Numbers[Index: Integer]: Integer read GetNumber;
    property Count: Integer read GetLineCount;
    procedure SetLine(const Number: Integer; const Code: string);
    procedure DeleteLine(const Number: Integer);
    procedure Clear;
    procedure SaveToFile(const FileName: string);
    procedure LoadFromFile(const FileName: string);
  end;

  TVarList = class
  private
    Variables: TDictionary<string, Double>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure DefineVar(const Name: string; const Value: Double);
    function TryGetVar(const Name: string; out Value: Double): Boolean;
  end;

  TForItem = record
    Target: string;
    LineIndex: Integer;
    Position: Integer;
    Value: Double;
    EndValue: Double;
    Step: Double;
  end;

  // fast coded shit
  TForStack = class
  private
    FItems: TList<TForItem>;
    function GetItem(Index: Integer): TForItem;
    procedure SetItem(Index: Integer; const Value: TForItem);
  public
    constructor Create;
    destructor Destroy; override;
    function IndexByTarget(const Target: string): Integer;
    procedure Add(const Item: TForItem);
    function LastIndex: Integer;
    procedure Delete(const Index: Integer);
    property Items[Index: Integer]: TForItem read GetItem write SetItem; default;
  end;

  function TryStrToIntegerBasic(const Str: string; out Value: Integer): Boolean;
  function TryStrToFloatBasic(const Str: string; out Value: Double): Boolean;
  function FloatToStrBasic(const Value: Double; const MaxWidth: Integer): string;

implementation

uses
  Classes;

function TryStrToIntegerBasic(const Str: string; out Value: Integer): Boolean;
var
  Code: Integer;
begin
  Val(Trim(Str), Value, Code);
  Result := Code = 0;
end;

function TryStrToFloatBasic(const Str: string; out Value: Double): Boolean;
var
  Code: Integer;
begin
  Val(Trim(Str), Value, Code);
  Result := Code = 0;
end;

function FloatToStrBasic(const Value: Double; const MaxWidth: Integer): string;
var
  MaxDigits: Integer;
begin
  // minmal width: Length("-1e-222") = 7
  Assert(MaxWidth >= 7);

  MaxDigits := MaxWidth;

  // 1 pass
  Result := FloatToStrF(Value, TFloatFormat.ffGeneral, MaxDigits, 0, TFormatSettings.Invariant);

  // shrink passes (2 or 3)
  while Length(Result) > MaxWidth do
  begin
    MaxDigits := MaxDigits - (Length(Result) - MaxWidth);
    Result := FloatToStrF(Value, TFloatFormat.ffGeneral, MaxDigits,
      0, TFormatSettings.Invariant);
  end;
end;

{ EBasicError }

constructor EBasicError.Create(const Position: Integer; const Message: string);
begin
	inherited Create('Error: ' + Message + ' at ' + IntToStr(Position));
	FLineNumber := -1;
	FPosition := Position;
end;

constructor EBasicError.Create(const LineNumber, Position: Integer; const Message: string);
begin
	inherited Create('Error: ' + Message + ' at ' + IntToStr(LineNumber) + ', ' + IntToStr(Position));
	FLineNumber := LineNumber;
	FPosition := Position;
end;

{ TLineList.TCodelineComparer }

function TLineList.TLineComparer.Compare(const Left, Right: TLine): Integer;
begin
  Result := Left.Number - Right.Number;
end;

{ TLineList.TLine }

constructor TLineList.TLine.Create(const Number: Integer; const Code: string);
begin
  FNumber := Number;
  FCode := Code;
end;

function TLineList.TLine.ToString: string;
begin
  Result := IntToStr(FNumber) + ' ' + FCode;
end;

{ TLineList }

constructor TLineList.Create;
begin
  inherited Create;
  List := TList<TLine>.Create(TLineComparer.Create);
end;

destructor TLineList.Destroy;
begin
  List.Free;
  inherited;
end;

procedure TLineList.SaveToFile(const FileName: string);
var
  Line: TLine;
  Strings: TStringList;
begin
  Strings := TStringList.Create;
  try
    for Line in List do
    begin
      Strings.Add(Line.ToString);
    end;
    Strings.SaveToFile(FileName);
  finally
    Strings.Free;
  end;
end;

procedure TLineList.LoadFromFile(const FileName: string);
var
  Line: TLine;
  Strings: TStringList;
  I, Position, Number, CodePosition: Integer;
  NumberString, Code: string;
begin
  List.Clear;
  Strings := TStringList.Create;
  try
    Strings.LoadFromFile(FileName);
    for I := 0 to Strings.Count - 1 do
    begin
      Position := 0;
      if CharInSet(PChar(Strings[I])[Position], ['0'..'9']) then
      begin
        // get number
        NumberString := '';
        while CharInSet(PChar(Strings[I])[Position], ['0'..'9']) do
        begin
          NumberString := NumberString + PChar(Strings[I])[Position];
          Position := Position + 1;
        end;
        if not TryStrToIntegerBasic(NumberString, Number) or
          (Number < 0) or (Number > MaxLineNumber) or (IndexByNumber(Number) <> -1) then
          raise Exception.Create('Bad line number at ' + IntToStr(I) + ' line');

        // skip one space
        if PChar(Strings[I])[Position] = ' ' then
          CodePosition := Position + 1
        else
          CodePosition := Position;

        while PChar(Strings[I])[Position] = ' ' do
        begin
          Position := Position + 1;
        end;

        // editor
        if PChar(Strings[I])[Position] <> #0 then
        begin
          // set line
          Code := '';
          while PChar(Strings[I])[CodePosition] <> #0 do
          begin
            Code := Code + PChar(Strings[I])[CodePosition];
            CodePosition := CodePosition + 1;
          end;

          Line := Line.Create(Number, Code);
          List.Add(Line);
        end else
          raise Exception.Create('Bad line (' + IntToStr(I) + ')');
      end;
    end;
  finally
    Strings.Free;
  end;
end;

function TLineList.SearchIndexByNumber(const Number: Integer; const Upward: Boolean): Integer;
var
  I: Integer;
begin
  if Upward then
  begin
    for I := List.Count - 1 downto 0 do
      if List[I].Number <= Number then
        Exit(I);
  end else
  begin
    for I := 0 to List.Count - 1 do
      if List[I].Number >= Number then
        Exit(I);
  end;
  Result := -1;
end;

procedure TLineList.SetLine(const Number: Integer; const Code: string);
var
  Index: Integer;
begin
  Index := IndexByNumber(Number);

  if Index < 0 then
    List.Add(TLine.Create(Number, Code))
  else
    List[Index] := TLine.Create(Number, Code);

  List.Sort;
end;

procedure TLineList.Clear;
begin
  List.Clear;
end;

procedure TLineList.DeleteLine(const Number: Integer);
var
  Index: Integer;
begin
  Index := IndexByNumber(Number);

  if Index >= 0 then
    List.Delete(Index);
end;

function TLineList.GetLine(Index: Integer): string;
begin
  Result := List[Index].Code;
end;

function TLineList.GetLineCount: Integer;
begin
  Result := List.Count;
end;

function TLineList.GetNumber(Index: Integer): Integer;
begin
  Result := List[Index].Number;
end;

function TLineList.IndexByNumber(const Number: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do
    if List[I].Number = Number then
      Exit(I);
  Result := -1;
end;

{ TVarList }

procedure TVarList.Clear;
begin
  Variables.Clear;
end;

constructor TVarList.Create;
begin
  Variables := TDictionary<string, Double>.Create;
end;

procedure TVarList.DefineVar(const Name: string; const Value: Double);
begin
  Variables.AddOrSetValue(UpperCase(Name), Value);
end;

destructor TVarList.Destroy;
begin
  Variables.Free;
  inherited;
end;

function TVarList.TryGetVar(const Name: string; out Value: Double): Boolean;
begin
  Result := Variables.TryGetValue(UpperCase(Name), Value);
end;

{ TForStack }

procedure TForStack.Add(const Item: TForItem);
var
  ItemIndex: Integer;
begin
  // Remove old?
  ItemIndex := IndexByTarget(Item.Target);
  if ItemIndex <> -1 then
    FItems.Delete(ItemIndex);
  // add
  FItems.Add(Item);
end;

constructor TForStack.Create;
begin
  FItems := TList<TForItem>.Create;
end;

procedure TForStack.Delete(const Index: Integer);
begin
  FItems.Delete(Index);
end;

destructor TForStack.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TForStack.GetItem(Index: Integer): TForItem;
begin
  Result := FItems[Index];
end;

function TForStack.IndexByTarget(const Target: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if UpperCase(Target) = FItems[I].Target then
    begin
      Exit(I);
    end;
  Result := -1;
end;

function TForStack.LastIndex: Integer;
begin
  Result := FItems.Count - 1;
end;

procedure TForStack.SetItem(Index: Integer; const Value: TForItem);
begin
  FItems[Index] := Value;
end;

end.

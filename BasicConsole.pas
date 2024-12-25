// TurboriumBasic
//
// Turborium(c) 2021-2024
//
// Source code: https://github.com/turborium/turboriumbasic
unit BasicConsole;

{$SCOPEDENUMS ON}
{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  Windows, SysUtils, Classes, BasicClasses;

type
  TConsole = class(TInterfacedPersistent, IConsole)
  strict private
    NeedReturn: Boolean;
    function StdOut(): THandle;
    function StdIn(): THandle;
    procedure FlushInput();
  private
    { IConsole }
    procedure ReadNewLine(out Line: string);
    procedure Read(out Str: string);
    procedure WriteNewLine(const Line: string);
    procedure Write(const Str: string);
    procedure Clear();
    function CheckBreak(): Boolean;
  end;

implementation

{ TConsole }

function TConsole.StdOut(): THandle;
begin
  Result := GetStdHandle(STD_OUTPUT_HANDLE);
  Win32Check(Result <> INVALID_HANDLE_VALUE);
end;

function TConsole.StdIn(): THandle;
begin
  Result := GetStdHandle(STD_INPUT_HANDLE);
  Win32Check(Result <> INVALID_HANDLE_VALUE);
end;

procedure TConsole.FlushInput();
begin
  FlushConsoleInputBuffer(StdIn());
end;

{ IConsole }

procedure TConsole.ReadNewLine(out Line: string);
begin
  FlushInput();
  if NeedReturn then
    System.Writeln;
  System.Readln(Line);
  NeedReturn := False;
end;

procedure TConsole.Read(out Str: string);
begin
  FlushInput();
  System.Readln(Str);
  NeedReturn := False;
end;

procedure TConsole.WriteNewLine(const Line: string);
begin
  if NeedReturn then
    System.Writeln;

  System.Writeln(Line);
  NeedReturn := False;
end;

procedure TConsole.Write(const Str: string);
begin
  System.Write(Str);
  NeedReturn := Str[High(Str)] <> #10;
end;

procedure TConsole.Clear();
var
  Info: TConsoleScreenBufferInfo;
  ConsoleSize: DWORD;
  CharsWritten: DWORD;
  Origin: TCoord;
begin
  // Get the number of character cells in the current buffer.
  Win32Check(GetConsoleScreenBufferInfo(StdOut(), Info));
  ConsoleSize := Info.dwSize.X * Info.dwSize.Y;

  // Fill the entire screen with blanks.
  Origin.X := 0;
  Origin.Y := 0;
  Win32Check(FillConsoleOutputCharacter(StdOut(), ' ', ConsoleSize, Origin, CharsWritten));

  // Get the current text attribute.
  Win32Check(GetConsoleScreenBufferInfo(StdOut(), Info));
  // Set the buffer's attributes accordingly.
  Win32Check(FillConsoleOutputAttribute(StdOut(), Info.wAttributes, ConsoleSize, Origin, CharsWritten));

  // Put the cursor at its home coordinates.
  Win32Check(SetConsoleCursorPosition(StdOut(), Origin));
end;

function TConsole.CheckBreak(): Boolean;
begin
  if GetForegroundWindow() <> GetConsoleWindow() then
    exit(False);

  //repeat
  Result := (GetAsyncKeyState(VK_LCONTROL) and $8000 <> 0) and (GetAsyncKeyState(Ord('B')) and $8000 <> 0);

  if not Result then
    Exit;

  while (GetAsyncKeyState(Ord('B')) and $8000 <> 0) do
    Sleep(10);
end;

end.

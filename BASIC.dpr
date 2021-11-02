program BASIC;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  StrUtils,
  Classes,
  Math,
  BasicInterpreter in 'BasicInterpreter.pas',
  BasicClasses in 'BasicClasses.pas',
  BasicConsole in 'BasicConsole.pas',
  BasicScanner in 'BasicScanner.pas';

var
  Console: TConsole;
  Interpreter: TInterpreter;

begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    Console := nil;
    Interpreter := nil;
    try
      Console := TConsole.Create;
      Interpreter := TInterpreter.Create(Console);
      Interpreter.Run;
    finally
      Console.Free;
      Interpreter.Free;
    end;

  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      readln;
    end;
  end;
end.

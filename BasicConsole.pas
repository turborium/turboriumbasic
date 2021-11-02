unit BasicConsole;

{$SCOPEDENUMS ON}

interface

uses
  Classes, BasicClasses;

type
  TConsole = class(TInterfacedPersistent, IConsole)
  strict private
    NeedReturn: Boolean;
  private
    { IConsole }
    procedure ReadNewLine(out Line: string);
    procedure Read(out Str: string);
    procedure WriteNewLine(const Line: string);
    procedure Write(const Str: string);
  end;

implementation

{ TConsole }

procedure TConsole.Read(out Str: string);
begin
  System.Readln(Str);
  NeedReturn := False;
end;

procedure TConsole.ReadNewLine(out Line: string);
begin
  if NeedReturn then
    System.Writeln;
  System.Readln(Line);
  NeedReturn := False;
end;

procedure TConsole.Write(const Str: string);
begin
  System.Write(Str);
  NeedReturn := Str[High(Str)] <> #10;
end;

procedure TConsole.WriteNewLine(const Line: string);
begin
  if NeedReturn then
    System.Writeln;

  System.Writeln(Line);
  NeedReturn := False;
end;

end.

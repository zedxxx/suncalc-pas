program SunCalcDemo;

uses
  Forms,
  frm_Main in 'src\frm_Main.pas' {frmMain},
  SunCalc in '..\SunCalc.pas',
  u_Tools in 'src\u_Tools.pas',
  u_Moon in 'src\u_Moon.pas',
  u_Sun in 'src\u_Sun.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

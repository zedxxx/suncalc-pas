unit frm_Main;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  StdCtrls,
  ExtCtrls,
  ComCtrls;

type
  TfrmMain = class(TForm)
    dtpDate: TDateTimePicker;
    dtpTime: TDateTimePicker;
    lblDateTime: TLabel;
    edtLat: TEdit;
    edtLon: TEdit;
    lblLat: TLabel;
    lblLon: TLabel;
    btnNow: TButton;
    btnCalc: TButton;
    btnExit: TButton;
    pnlCenter: TPanel;
    pnlBottom: TPanel;
    mmoSun: TMemo;
    mmoMoon: TMemo;
    procedure btnExitClick(Sender: TObject);
    procedure btnCalcClick(Sender: TObject);
    procedure btnNowClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
  end;

var
  frmMain: TfrmMain;

implementation

uses
  IniFiles,
  DateUtils,
  u_Sun,
  u_Moon,
  u_Tools;

function GetIniFileName: string; inline;
begin
  Result := ChangeFileExt(ParamStr(0), '.ini');
end;

{$R *.dfm}

procedure TfrmMain.btnCalcClick(Sender: TObject);
var
  VLat, VLon: Double;
  VDate: TDateTime;
begin
  VLat := StrToCoord(edtLat.Text);
  VLon := StrToCoord(edtLon.Text);

  VDate := DateOf(dtpDate.DateTime) + TimeOf(dtpTime.DateTime);
  VDate := LocalToUniversalTime(VDate);

  mmoMoon.Lines.Clear;
  mmoMoon.Lines.Add('Moon' + #13#10);
  mmoMoon.Lines.Add( GetMoonInfo(VDate, VLat, VLon) );

  mmoSun.Lines.Clear;
  mmoSun.Lines.Add('Sun' + #13#10);
  mmoSun.Lines.Add( GetSunInfo(VDate, VLat, VLon) );
end;

procedure TfrmMain.btnNowClick(Sender: TObject);
var
  VNow: TDateTime;
begin
  VNow := Now;
  dtpDate.DateTime := DateOf(VNow);
  dtpTime.DateTime := TimeOf(VNow);
end;

procedure TfrmMain.btnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  btnNowClick(Sender);

  with TIniFile.Create(GetIniFileName) do
  try
    edtLat.Text := ReadString('Main', 'Lat', '53.0');
    edtLon.Text := ReadString('Main', 'Lon', '28.0');
  finally
    Free;
  end;

  SetFocusedControl(btnCalc);
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
var
  VFileName: string;
begin
  VFileName := GetIniFileName;

  if not FileExists(VFileName) then begin
    with TFileStream.Create(VFileName, fmCreate) do
      Free;
  end;

  with TIniFile.Create(VFileName) do
  try
    WriteString('Main', 'Lat', edtLat.Text);
    WriteString('Main', 'Lon', edtLon.Text);
  finally
    Free;
  end;
end;

end.

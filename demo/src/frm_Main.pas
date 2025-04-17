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
    edtLat: TEdit;
    edtLon: TEdit;
    lblLat: TLabel;
    lblLon: TLabel;
    btnNow: TButton;
    btnCalc: TButton;
    btnExit: TButton;
    pnlCenter: TPanel;
    mmoSun: TMemo;
    mmoMoon: TMemo;
    imgMoonPhase: TImage;
    lblMoonPhase: TLabel;
    lblDate: TLabel;
    lblTime: TLabel;
    edtTimeZone: TEdit;
    lblTzOffset: TLabel;
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
  u_CommonTools,
  u_DateTimeTools;

function GetIniFileName: string; inline;
begin
  Result := ChangeFileExt(ParamStr(0), '.ini');
end;

{$R *.dfm}

procedure TfrmMain.btnCalcClick(Sender: TObject);
var
  VLat, VLon: Double;
  VDate: TDateTime;
  VUtcOffset: Double;
begin
  VLat := StrToCoord(edtLat.Text);
  VLon := StrToCoord(edtLon.Text);

  VDate := DateOf(dtpDate.DateTime) + TimeOf(dtpTime.DateTime);
  VUtcOffset := StrToUtcOffset(Trim(edtTimeZone.Text));
  VDate := LocalToUniversalTime(VDate, VUtcOffset);

  mmoMoon.Lines.Clear;
  mmoMoon.Lines.Add('Moon' + #13#10);
  mmoMoon.Lines.Add( GetMoonInfo(VDate, VUtcOffset, VLat, VLon) );

  DrawMoonPhase(imgMoonPhase, VDate, VLat, VLon);

  mmoSun.Lines.Clear;
  mmoSun.Lines.Add('Sun' + #13#10);
  mmoSun.Lines.Add( GetSunInfo(VDate, VUtcOffset, VLat, VLon) );
end;

procedure TfrmMain.btnNowClick(Sender: TObject);
var
  VNow: TDateTime;
begin
  VNow := Now;
  dtpDate.DateTime := DateOf(VNow);
  dtpTime.DateTime := TimeOf(VNow);
  edtTimeZone.Text := UtcOffsetToStr( GetSystemTzOffset(VNow) );
end;

procedure TfrmMain.btnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  btnNow.Click;

  with TIniFile.Create(GetIniFileName) do
  try
    edtLat.Text := ReadString('Main', 'Lat', '53.0');
    edtLon.Text := ReadString('Main', 'Lon', '28.0');
  finally
    Free;
  end;

  SetFocusedControl(btnCalc);
  btnCalc.Click;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  with TIniFile.Create(GetIniFileName) do
  try
    WriteString('Main', 'Lat', edtLat.Text);
    WriteString('Main', 'Lon', edtLon.Text);
  finally
    Free;
  end;
end;

end.

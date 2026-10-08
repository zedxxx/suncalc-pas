unit u_CommonTools;

interface

function StrToCoord(const AStr: string): Double;

function ShadowToStr(Altitude: Double): string;

implementation

uses
  Math,
  SysUtils;

function StrToCoord(const AStr: string): Double;
var
  VStr: string;
  VFormatSettings: TFormatSettings;
begin
  VStr := Trim(AStr);
  VStr := StringReplace(VStr, #176, '', [rfReplaceAll]);
  VStr := StringReplace(VStr, ',',  '.', [rfReplaceAll]);
  VFormatSettings.DecimalSeparator := '.';
  Result := StrToFloat(VStr, VFormatSettings);
end;

function ShadowToStr(Altitude: Double): string;
begin
  Altitude := Math.DegToRad(Altitude);
  if Altitude > 0 then begin
    Result := Format('%.2f m', [1/Tan(Altitude)]);
  end else begin
    Result := ' - ';
  end;
end;

end.

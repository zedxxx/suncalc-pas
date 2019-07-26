unit u_Sun;

interface

function GetSunInfo(const AUtcDate: TDateTime; const ALat, ALon: Double): string;

implementation

uses
  Math,
  SysUtils,
  SunCalc,
  u_Tools;

function GetSunInfo(const AUtcDate: TDateTime; const ALat, ALon: Double): string;

  function SunTimeToStr(const AName: string; const AInfo: TSunCalcTimesInfo): string;
  var
    VPos: TSunPos;
  begin
    VPos := SunCalc.GetPosition(AInfo.Value, ALat, ALon);
    Result :=
      Format(
        '%s:' + #09 + '%s [az: %.2f' + #176 + ']',
        [AName, DateTimeFmt(AInfo.Value), RadToDeg(VPos.Azimuth + Pi)]
      );
  end;

const
  CRLF = #13#10;
var
  VPos: TSunPos;
  VTimes: TSunCalcTimes;
begin
  NewSunCalcTimes(VTimes);

  VTimes := SunCalc.GetTimes(AUtcDate, ALat, ALon);
  VPos := SunCalc.GetPosition(AUtcDate, ALat, ALon);

  Result :=
    SunTimeToStr('Dawn', VTimes[dawn]) + CRLF +
    SunTimeToStr('Rise', VTimes[sunrise]) + CRLF +
    SunTimeToStr('Noon', VTimes[solarNoon]) + CRLF +
    SunTimeToStr('Set', VTimes[sunset]) + CRLF +
    SunTimeToStr('Dusk', VTimes[dusk]) + CRLF + CRLF +

    'Azimuth:' + #09 + Format('%.2f', [RadToDeg(VPos.Azimuth + Pi)]) + CRLF +
    'Altitude:' + #09 + Format('%.2f', [RadToDeg(VPos.Altitude)]) + CRLF + CRLF +

    'Shadow:' + #09 + ShadowToStr(VPos.Altitude);
end;

end.

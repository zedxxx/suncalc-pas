unit u_Sun;

interface

function GetSunInfo(const AUtcDate: TDateTime; const AUtcOffset: Double;
  const ALat, ALon: Double): string;

implementation

uses
  Math,
  SysUtils,
  SunCalc,
  u_CommonTools,
  u_DateTimeTools;

function GetSunInfo(const AUtcDate: TDateTime; const AUtcOffset: Double;
  const ALat, ALon: Double): string;

  function SunTimeToStr(const AName: string; const AInfo: TSunCalcTimesInfo;
    const AShowAlt: Boolean = False): string;
  var
    VPos: TSunPos;
    VAltitude: string;
  begin
    if AInfo.Value = 0 then begin
      Result := AName + ':' + #09 + ' - ';
    end else begin
      VPos := SunCalc.GetPosition(AInfo.Value, ALat, ALon);
      if AShowAlt then begin
        VAltitude := Format(' alt: %.2f', [RadToDeg(VPos.Altitude)]);
      end else begin
        VAltitude := '';
      end;
      Result := Format('%s:' + #09 + '%s [az: %.2f' + #176 + '%s]',
        [AName, DateTimeFmt(AInfo.Value, AUtcOffset), RadToDeg(VPos.Azimuth), VAltitude]);
    end;
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
    SunTimeToStr('Noon', VTimes[solarNoon], True) + CRLF +
    SunTimeToStr('Set',  VTimes[sunset]) + CRLF +
    SunTimeToStr('Dusk', VTimes[dusk]) + CRLF + CRLF +

    'Azimuth:' + #09 + Format('%.2f', [RadToDeg(VPos.Azimuth)]) + CRLF +
    'Altitude:' + #09 + Format('%.2f', [RadToDeg(VPos.Altitude)]) + CRLF + CRLF +

    'Shadow:' + #09 + ShadowToStr(VPos.Altitude);
end;

end.

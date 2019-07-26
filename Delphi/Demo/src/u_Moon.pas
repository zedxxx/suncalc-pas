unit u_Moon;

interface

function GetMoonInfo(const AUtcDate: TDateTime; const ALat, ALon: Double): string;

implementation

uses
  Math,
  DateUtils,
  SysUtils,
  SunCalc,
  u_Tools;

const
  cMoonPhaseName: array [0..7] of string = (
    'New Moon',
    'Waxing Crescent',
    'First Quarter',
    'Waxing Gibbous',
    'Full Moon',
    'Waning Gibbous',
    'Last Quarter',
    'Waning Crescent'
  );

function MoonPhaseIndex(const APhase1, APhase2: Double): Integer;
// https://github.com/mourner/suncalc/issues/114
const
  cPercentages: array [0..4] of Double = (0, 0.25, 0.5, 0.75, 1);
var
  i, index: integer;
begin
  index := 0;
  if APhase1 <= APhase2 then begin
    for i := 0 to Length(cPercentages) -1 do begin
      if (cPercentages[i] >= APhase1) and (cPercentages[i] <= APhase2) then begin
        index := 2 * i;
        Break;
      end else if (cPercentages[i] > APhase1) then begin
        index := (2 * i) - 1;
        Break;
      end;
    end;
  end;
  Result := index mod 8;
end;

function GetMoonInfo(const AUtcDate: TDateTime; const ALat, ALon: Double): string;
const
  cTab = #09;

  function MoonTimeToStr(const AName: string; const ADateTime: TDateTime): string;
  var
    VPos: TMoonPos;
  begin
    VPos := SunCalc.GetMoonPosition(ADateTime, ALat, ALon);
    Result :=
      Format(
        '%s:' + cTab + '%s [az: %.2f' + #176 + ']',
        [AName, DateTimeFmt(ADateTime), RadToDeg(VPos.Azimuth + Pi)]
      );
  end;

  function MoonPhaseStr(const APhase: Double): string;
  var
    I: Integer;
    VIllumination: TMoonIllumination;
  begin
    VIllumination := SunCalc.GetMoonIllumination(IncDay(AUtcDate));
    I := MoonPhaseIndex(APhase, VIllumination.Phase);
    Result := Format('%.2f [%s]', [APhase, cMoonPhaseName[I] ]);
  end;

const
  CRLF = #13#10;
var
  VPos: TMoonPos;
  VTimes: TMoonTimes;
  VIllumination: TMoonIllumination;
begin
  VTimes := SunCalc.GetMoonTimes(AUtcDate, ALat, ALon);
  VPos := SunCalc.GetMoonPosition(AUtcDate, ALat, ALon);
  VIllumination := SunCalc.GetMoonIllumination(AUtcDate);

  Result :=
    MoonTimeToStr('Rise', VTimes.MoonRise) + CRLF +
    MoonTimeToStr('Set', VTimes.MoonSet) + CRLF + CRLF +

    'Azimuth:' + cTab + Format('%.2f', [RadToDeg(VPos.Azimuth + Pi)]) + CRLF +
    'Altitude:' + cTab + Format('%.2f', [RadToDeg(VPos.Altitude)]) + CRLF +
    'Distance:' + cTab + Format('%.0f km', [VPos.Distance]) + CRLF +
    'Parallactic Angle: ' + Format('%.6f', [VPos.ParallacticAngle]) + CRLF + CRLF +

    'Fraction:' + cTab + Format('%.2f%%', [VIllumination.Fraction * 100]) + CRLF +
    'Phase:' + cTab + MoonPhaseStr(VIllumination.Phase) + CRLF +
    'Angle:' + cTab + Format('%.2f', [VIllumination.Angle]) + CRLF + CRLF +

    'Shadow:' + cTab + ShadowToStr(VPos.Altitude);
end;

end.

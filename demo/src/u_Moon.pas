unit u_Moon;

interface

uses
  ExtCtrls,
  Graphics;

function GetMoonInfo(const AUtcDate: TDateTime; const AUtcOffset: Double;
  const ALat, ALon: Double): string;

procedure DrawMoonPhase(AImage: TImage; const AUtcDate: TDateTime;
  const ALat, ALon: Double);

implementation

uses
  Types,
  Math,
  DateUtils,
  SysUtils,
  SunCalc,
  u_CommonTools,
  u_DateTimeTools;

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
  I, VIndex: Integer;
begin
  VIndex := 0;
  if APhase1 <= APhase2 then begin
    for I := 0 to Length(cPercentages) -1 do begin
      if (cPercentages[I] >= APhase1) and (cPercentages[I] <= APhase2) then begin
        VIndex := 2 * I;
        Break;
      end else if (cPercentages[I] > APhase1) then begin
        VIndex := (2 * I) - 1;
        Break;
      end;
    end;
  end;
  Result := VIndex mod 8;
end;

function GetMoonInfo(const AUtcDate: TDateTime; const AUtcOffset: Double;
  const ALat, ALon: Double): string;

const
  cTab = #09;

  function MoonTimeToStr(const AName: string; const ADateTime: TDateTime;
    const AHasValue: Boolean): string;
  var
    VPos: TMoonPos;
  begin
    if not AHasValue then begin
      Result := AName + ':' + cTab + ' - ';
    end else begin
      VPos := SunCalc.GetMoonPosition(ADateTime, ALat, ALon);
      Result :=
        Format(
          '%s:' + cTab + '%s [az: %.2f' + #176 + ']',
          [AName, DateTimeFmt(ADateTime, AUtcOffset), VPos.Azimuth]
        );
    end;
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
    MoonTimeToStr('Rise', VTimes.MoonRise, VTimes.HasRise) + CRLF +
    MoonTimeToStr('Set', VTimes.MoonSet, VTimes.HasSet) + CRLF + CRLF +

    'Azimuth:' + cTab + Format('%.2f', [VPos.Azimuth]) + CRLF +
    'Altitude:' + cTab + Format('%.2f', [VPos.Altitude]) + CRLF +
    'Distance:' + cTab + Format('%.2n km', [VPos.Distance]) + CRLF +
    'Parallactic Angle: ' + Format('%.2f', [VPos.ParallacticAngle]) + CRLF + CRLF +

    'Fraction:' + cTab + Format('%.2f%%', [VIllumination.Fraction * 100]) + CRLF +
    'Phase:' + cTab + MoonPhaseStr(VIllumination.Phase) + CRLF +
    'Angle:' + cTab + Format('%.2f', [VIllumination.Angle]) + CRLF + CRLF +

    'Shadow:' + cTab + ShadowToStr(VPos.Altitude);
end;

procedure DrawMoonPhase(AImage: TImage; const AUtcDate: TDateTime;
  const ALat, ALon: Double);
const
  cDark  = clWebDarkGray;
  cLight = clWebYellow;
var
  VBitmap: TBitmap;
  VMoon: TMoonIllumination;
  VMoonPos: TMoonPos;
  R, X, Y: Integer;
  U, V: Double;          // pixel position on the unit disc (U: right, V: up)
  A, P: Double;          // the same position in the "bright limb" frame
  W: Double;             // half-width of the disc at the given P
  K: Double;             // terminator shape factor: +1 new moon ... -1 full moon
  Phi, SinPhi, CosPhi: Double;
begin
  VBitmap := TBitmap.Create;
  try
    // transparent (white) background around the disc
    VBitmap.PixelFormat := pf32bit;
    VBitmap.SetSize(AImage.Width, AImage.Height);
    VBitmap.Transparent := True;
    VBitmap.TransparentColor := clWhite;
    VBitmap.Canvas.Brush.Color := clWhite;
    VBitmap.Canvas.FillRect(Rect(0, 0, VBitmap.Width, VBitmap.Height));

    VMoon    := SunCalc.GetMoonIllumination(AUtcDate);
    VMoonPos := SunCalc.GetMoonPosition(AUtcDate, ALat, ALon);

    R := (Min(AImage.Height, AImage.Width) div 2) - 1;   // disc radius in pixels

    // Direction to the middle of the illuminated limb as seen by the observer:
    // clockwise angle from "up" (towards the zenith).
    //   VMoon.Angle                - position angle of the bright limb, measured from
    //                                celestial north (degrees)
    //   VMoonPos.ParallacticAngle  - angle between celestial north and the zenith (degrees)
    // Their difference is the bright limb direction relative to the zenith.
    Phi := (VMoonPos.ParallacticAngle - VMoon.Angle) * Pi / 180;
    SinPhi := Sin(Phi);
    CosPhi := Cos(Phi);

    // Terminator shape factor derived from the illuminated fraction f (0..1):
    //   f = 0   -> K = +1 (everything dark)
    //   f = 0.5 -> K =  0 (terminator is a straight line, half moon)
    //   f = 1   -> K = -1 (everything lit)
    K := 1 - 2 * VMoon.Fraction;

    for Y := -R to R do begin
      for X := -R to R do begin
        // pixel -> unit disc coordinates (screen Y grows downwards, so V is flipped)
        U := X / R;
        V := -Y / R;

        if U * U + V * V > 1 then
          Continue;   // outside of the disc

        // rotate the coordinate system so that the A axis points to the bright limb:
        // A - distance along the axis towards the bright limb
        // P - distance across it (perpendicular)
        A := U * SinPhi + V * CosPhi;
        P := U * CosPhi - V * SinPhi;

        // half-width of the disc along the A axis at this P (circle equation)
        W := Sqrt(Max(0, 1 - P * P));

        // The terminator is the ellipse  A = K * W  (semi-axis K along A, 1 along P).
        // Pixels on the bright-limb side of it are lit.
        if A > W * K then
          VBitmap.Canvas.Pixels[X + R, Y + R] := cLight
        else
          VBitmap.Canvas.Pixels[X + R, Y + R] := cDark;
      end;
    end;

    AImage.Picture.Assign(VBitmap);
  finally
    VBitmap.Free;
  end;
  AImage.Transparent := True;
end;

end.

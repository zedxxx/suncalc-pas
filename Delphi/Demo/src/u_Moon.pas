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

function GetMoonInfo(const AUtcDate: TDateTime; const AUtcOffset: Double;
  const ALat, ALon: Double): string;

const
  cTab = #09;

  function MoonTimeToStr(const AName: string; const ADateTime: TDateTime): string;
  var
    VPos: TMoonPos;
  begin
    if ADateTime = 0 then begin
      Result := AName + ':' + cTab + ' - ';
    end else begin
      VPos := SunCalc.GetMoonPosition(ADateTime, ALat, ALon);
      Result :=
        Format(
          '%s:' + cTab + '%s [az: %.2f' + #176 + ']',
          [AName, DateTimeFmt(ADateTime, AUtcOffset), RadToDeg(VPos.Azimuth)]
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
    MoonTimeToStr('Rise', VTimes.MoonRise) + CRLF +
    MoonTimeToStr('Set', VTimes.MoonSet) + CRLF + CRLF +

    'Azimuth:' + cTab + Format('%.2f', [RadToDeg(VPos.Azimuth)]) + CRLF +
    'Altitude:' + cTab + Format('%.2f', [RadToDeg(VPos.Altitude)]) + CRLF +
    'Distance:' + cTab + Format('%.0f km', [VPos.Distance]) + CRLF +
    'Parallactic Angle: ' + Format('%.6f', [RadToDeg(VPos.ParallacticAngle)]) + CRLF + CRLF +

    'Fraction:' + cTab + Format('%.2f%%', [VIllumination.Fraction * 100]) + CRLF +
    'Phase:' + cTab + MoonPhaseStr(VIllumination.Phase) + CRLF +
    'Angle:' + cTab + Format('%.2f', [RadToDeg(VIllumination.Angle)]) + CRLF + CRLF +

    'Shadow:' + cTab + ShadowToStr(VPos.Altitude);
end;

procedure DrawMoonPhase(AImage: TImage; const AUtcDate: TDateTime;
  const ALat, ALon: Double);
var
  VBitmap: TBitmap;

  procedure _DrawLine(const AColor: TColor; var A, B: TPoint);
  begin
    with VBitmap.Canvas do begin
      Pen.Color := AColor;
      MoveTo(A.X, A.Y);
      LineTo(B.X, B.Y);
    end;
  end;

  procedure _PrepareBitmap;
  begin
    VBitmap.PixelFormat := pf32bit;
    VBitmap.HandleType := bmDIB;
    VBitmap.Height := AImage.Height;
    VBitmap.Width := AImage.Width;
    VBitmap.Transparent := True;
    VBitmap.TransparentColor := clWhite;
    VBitmap.Canvas.Brush.Color := clWhite;
    VBitmap.Canvas.FillRect( Rect(0, 0, VBitmap.Width, VBitmap.Height) );
  end;

const
  cDark = clWebDarkGray;
  cLight = clWebYellow;
var
  R: Integer;
  A, B: TPoint;
  Ypos, Xpos, Xpos1, Xpos2, Rpos: Integer;
  VMoon: TMoonIllumination;
  VMoonPos: TMoonPos;
begin
  VBitmap := TBitmap.Create;
  try
    _PrepareBitmap;

    VMoon := SunCalc.GetMoonIllumination(AUtcDate);

    R := (Min(AImage.Height, AImage.Width) div 2) - 1;

    for Ypos := 0 to R - 1 do begin
      Xpos := Round(sqrt(R*R - Ypos*Ypos));

      A := Point(R-Xpos, Ypos+R);
      B := Point(Xpos+R, Ypos+R);
      _DrawLine(cLight, A, B);

      A := Point(R-Xpos, R-Ypos);
      B := Point(Xpos+R, R-Ypos);
      _DrawLine(cLight, A, B);

      // determine the edges
      Rpos := 2 * Xpos;
      if VMoon.Phase < 0.5 then begin
        Xpos1 := - Xpos;
        Xpos2 := Round(Rpos - 2 * VMoon.Phase * Rpos - Xpos);
      end else begin
        Xpos1 := Xpos;
        Xpos2 := Round(Xpos - 2 * VMoon.Phase * Rpos + Rpos);
      end;

      A := Point(Xpos1+R, R-Ypos);
      B := Point(Xpos2+R, R-Ypos);
      _DrawLine(cDark, A, B);

      A := Point(Xpos1+R, Ypos+R);
      B := Point(Xpos2+R, Ypos+R);
      _DrawLine(cDark, A, B);
    end;

    if VMoon.Angle > 0 then begin
      VMoon.Angle := DegToRad(90) - VMoon.Angle;
    end;
    VMoonPos := SunCalc.GetMoonPosition(AUtcDate, ALat, ALon);
    VMoon.Angle := VMoon.Angle + VMoonPos.ParallacticAngle;

    RotateBitmap(VBitmap, VMoon.Angle, False, clWhite);

    AImage.Picture.Assign(VBitmap);
  finally
    VBitmap.Free;
  end;
  AImage.Transparent := True;
end;

end.

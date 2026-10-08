program SunCalcTest;

{$APPTYPE CONSOLE}

{$ASSERTIONS ON}

uses
  Types,
  Math,
  DateUtils,
  SysUtils,
  SunCalc in '..\SunCalc.pas';

function ISOToDateTime(const AISODateTime: string): TDateTime;
var
  VDate, VTime: TDateTime;
  VFormatSettings: TFormatSettings;
begin
  // ISO format: 2009-07-06T01:53:23Z

  VFormatSettings.DateSeparator := '-';
  VFormatSettings.ShortDateFormat := 'yyyy-mm-dd';
  VFormatSettings.TimeSeparator := ':';
  VFormatSettings.ShortTimeFormat := 'hh:mm:ss';

  VDate := StrToDate(Copy(AISODateTime, 1, Pos('T', AISODateTime) - 1), VFormatSettings);
  VTime := StrToTime(Copy(AISODateTime, Pos('T', AISODateTime) + 1, 8), VFormatSettings);

  Result := Trunc(VDate) + Frac(VTime);
end;

function SameSecond(const A, B: TDateTime): Boolean;
begin
  Result := Abs(A - B) < 1 / (24 * 60 * 60);
end;

procedure TestSunCalcUnit;
const
  cEpsilon = 1E-6;
  cDistEpsilon = 1E-3; // km
var
  I: TSunCalcTimesID;
  VDate: TDateTime;
  VTimes: TSunCalcTimes;
  VTimesArr: TSunCalcTimesArr;
  VTestTimes: TSunCalcTimes;
  VTestTimesArr: TSunCalcTimesArr;
  VFormatSettings: TFormatSettings;
  VLat, VLon: Double;
  VSunPos: TSunPos;
  VMoonPos: TMoonPos;
  VMoonTimes: TMoonTimes;
  VMoonIllum: TMoonIllumination;
begin
  VFormatSettings.DateSeparator := '-';
  VFormatSettings.ShortDateFormat := 'yyyy-mm-dd';

  VDate := StrToDate('2013-03-05', VFormatSettings);
  VLat := 50.5;
  VLon := 30.5;

  // Sun tests

  VSunPos := SunCalc.GetPosition(VDate, VLat, VLon);

  Assert(CompareValue(VSunPos.Azimuth, 36.94707507400062, cEpsilon) = EqualsValue);
  Assert(CompareValue(VSunPos.Altitude, -39.46550678343545, cEpsilon) = EqualsValue);

  NewSunCalcTimes(VTestTimes);

  VTestTimesArr := VTestTimes.Times;

  VTestTimesArr[solarNoon].Value     := ISOToDateTime('2013-03-05T10:09:28Z');
  VTestTimesArr[nadir].Value         := ISOToDateTime('2013-03-04T22:09:28Z');
  VTestTimesArr[sunrise].Value       := ISOToDateTime('2013-03-05T04:33:31Z');
  VTestTimesArr[sunset].Value        := ISOToDateTime('2013-03-05T15:46:19Z');
  VTestTimesArr[sunriseEnd].Value    := ISOToDateTime('2013-03-05T04:36:54Z');
  VTestTimesArr[sunsetStart].Value   := ISOToDateTime('2013-03-05T15:42:56Z');
  VTestTimesArr[dawn].Value          := ISOToDateTime('2013-03-05T04:00:55Z');
  VTestTimesArr[dusk].Value          := ISOToDateTime('2013-03-05T16:18:59Z');
  VTestTimesArr[nauticalDawn].Value  := ISOToDateTime('2013-03-05T03:23:12Z');
  VTestTimesArr[nauticalDusk].Value  := ISOToDateTime('2013-03-05T16:56:49Z');
  VTestTimesArr[nightEnd].Value      := ISOToDateTime('2013-03-05T02:45:02Z');
  VTestTimesArr[night].Value         := ISOToDateTime('2013-03-05T17:35:07Z');
  VTestTimesArr[goldenHourEnd].Value := ISOToDateTime('2013-03-05T05:17:32Z');
  VTestTimesArr[goldenHour].Value    := ISOToDateTime('2013-03-05T15:02:14Z');

  for I := Low(VTestTimesArr) to High(VTestTimesArr) do begin
    VTestTimesArr[I].HasValue := True;
  end;

  VTimes := SunCalc.GetTimes(VDate, VLat, VLon);
  VTimesArr := VTimes.Times;

  Assert(VTimes.AlwaysUp = VTestTimes.AlwaysUp);
  Assert(VTimes.AlwaysDown = VTestTimes.AlwaysDown);

  for I := Low(VTimesArr) to High(VTimesArr) do begin
    Assert(CompareValue(VTimesArr[I].Angle, VTestTimesArr[I].Angle, cEpsilon) = EqualsValue);

    Assert(VTimesArr[I].HasValue = VTestTimesArr[I].HasValue);

    if VTimesArr[I].HasValue then begin
      Assert(SameSecond(VTimesArr[I].Value, VTestTimesArr[I].Value));
    end;

    Assert(VTimesArr[I].IsRiseInfo = VTestTimesArr[I].IsRiseInfo);
  end;

  // Moon tests

  VMoonPos := SunCalc.GetMoonPosition(VDate, VLat, VLon);

  Assert(CompareValue(VMoonPos.Azimuth, 124.64084971129068, cEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonPos.Altitude, 0.4567101966692874, cEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonPos.Distance, 370193.9925193064, cDistEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonPos.ParallacticAngle, -33.94130620826365, cEpsilon) = EqualsValue);

  VMoonIllum := SunCalc.GetMoonIllumination(VDate);

  Assert(CompareValue(VMoonIllum.Fraction, 0.4911927817602366, cEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonIllum.Phase, 0.7531998905377861, cEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonIllum.Angle, 96.04975326478946, cEpsilon) = EqualsValue);
  Assert(VMoonIllum.Waxing = False);

  VDate := StrToDate('2013-03-04', VFormatSettings);

  // AUtcOffset=0 anchors the scanned 24h window to UTC civil midnight (the calendar day of VDate)
  VMoonTimes := SunCalc.GetMoonTimes(VDate, VLat, VLon, 0);

  Assert(VMoonTimes.HasRise);
  Assert(SameSecond(VMoonTimes.MoonRise, ISOToDateTime('2013-03-04T23:53:32Z')));

  Assert(VMoonTimes.HasSet);
  Assert(SameSecond(VMoonTimes.MoonSet, ISOToDateTime('2013-03-04T07:42:17Z')));

  Assert(VMoonTimes.HasTransit);
  Assert(SameSecond(VMoonTimes.Transit, ISOToDateTime('2013-03-04T03:17:02Z')));

  Assert(VMoonTimes.HasLowerTransit);
  Assert(SameSecond(VMoonTimes.LowerTransit, ISOToDateTime('2013-03-04T15:46:08Z')));

  Assert(not VMoonTimes.AlwaysUp);
  Assert(not VMoonTimes.AlwaysDown);
end;

begin
  try
    TestSunCalcUnit;
    Writeln('Done!');
  except
    on E:Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;
  Writeln;
  Writeln('Press ENTER to exit...');
  Readln;
end.

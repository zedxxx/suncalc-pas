program SunCalcTest;

{$APPTYPE CONSOLE}

uses
  Types,
  Math,
  DateUtils,
  SysUtils,
  SunCalc in 'SunCalc.pas';

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

procedure TestSunCalcUnit;
const
  cEpsilon = 1E-10;
var
  I: TSunCalcTimesID;
  VDate: TDateTime;
  VTimes: TSunCalcTimes;
  VTestTimes: TSunCalcTimes;
  VFormatSettings: TFormatSettings;
  VLat, VLon: Double;
  VSunPos: TSunPos;
  VMoonPos: TMoonPos;
  VMoonTimes: TMoonTimes;
  VMoonIllum: TMoonIllumination;
  VStr1, VStr2: string;
begin
  VFormatSettings.DateSeparator := '-';
  VFormatSettings.ShortDateFormat := 'yyyy-mm-dd';

  VDate := StrToDate('2013-03-05', VFormatSettings);
  VLat := 50.5;
  VLon := 30.5;

  // sun tests
  
  VSunPos := SunCalc.GetPosition(VDate, VLat, VLon);

  Assert(CompareValue(VSunPos.Azimuth, -2.5003175907168385, cEpsilon) = EqualsValue);
  Assert(CompareValue(VSunPos.Altitude, -0.7000406838781611, cEpsilon) = EqualsValue);

  NewSunCalcTimes(VTestTimes);

  VTestTimes[solarNoon].Value     := ISOToDateTime('2013-03-05T10:10:57Z');
  VTestTimes[nadir].Value         := ISOToDateTime('2013-03-04T22:10:57Z');
  VTestTimes[sunrise].Value       := ISOToDateTime('2013-03-05T04:34:56Z');
  VTestTimes[sunset].Value        := ISOToDateTime('2013-03-05T15:46:57Z');
  VTestTimes[sunriseEnd].Value    := ISOToDateTime('2013-03-05T04:38:19Z');
  VTestTimes[sunsetStart].Value   := ISOToDateTime('2013-03-05T15:43:34Z');
  VTestTimes[dawn].Value          := ISOToDateTime('2013-03-05T04:02:17Z');
  VTestTimes[dusk].Value          := ISOToDateTime('2013-03-05T16:19:36Z');
  VTestTimes[nauticalDawn].Value  := ISOToDateTime('2013-03-05T03:24:31Z');
  VTestTimes[nauticalDusk].Value  := ISOToDateTime('2013-03-05T16:57:22Z');
  VTestTimes[nightEnd].Value      := ISOToDateTime('2013-03-05T02:46:17Z');
  VTestTimes[night].Value         := ISOToDateTime('2013-03-05T17:35:36Z');
  VTestTimes[goldenHourEnd].Value := ISOToDateTime('2013-03-05T05:19:01Z');
  VTestTimes[goldenHour].Value    := ISOToDateTime('2013-03-05T15:02:52Z');

  VTimes := SunCalc.GetTimes(VDate, VLat, VLon);

  for I := Low(VTimes) to High(VTimes) do begin
    Assert(CompareValue(VTimes[I].Angle, VTestTimes[I].Angle, cEpsilon) = EqualsValue);
    
    VStr1 := DateTimeToStr(VTimes[I].Value);
    VStr2 := DateTimeToStr(VTestTimes[I].Value);
    Assert(SameText(VStr1, VStr2));

    Assert(VTimes[I].IsRiseInfo = VTestTimes[I].IsRiseInfo);
  end;

  // moon tests

  VMoonPos := SunCalc.GetMoonPosition(VDate, VLat, VLon);

  Assert(CompareValue(VMoonPos.Azimuth, -0.9783999522438226, cEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonPos.Altitude, 0.014551482243892251, cEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonPos.Distance, 364121.37256256194, cEpsilon) = EqualsValue);

  VMoonIllum := SunCalc.GetMoonIllumination(VDate);

  Assert(CompareValue(VMoonIllum.Fraction, 0.4848068202456373, cEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonIllum.Phase, 0.7548368838538762, cEpsilon) = EqualsValue);
  Assert(CompareValue(VMoonIllum.Angle, 1.6732942678578346, cEpsilon) = EqualsValue);

  VDate := StrToDate('2013-03-04', VFormatSettings);
  VMoonTimes := SunCalc.GetMoonTimes(VDate, VLat, VLon);

  VStr1 := DateTimeToStr(VMoonTimes.MoonRise);
  VStr2 := DateTimeToStr(ISOToDateTime('2013-03-04T23:54:29Z'));
  Assert(SameText(VStr1, VStr2));

  VStr1 := DateTimeToStr(VMoonTimes.MoonSet);
  VStr2 := DateTimeToStr(ISOToDateTime('2013-03-04T07:47:58Z'));
  Assert(SameText(VStr1, VStr2));
end;

begin
  try
    TestSunCalcUnit;
    Writeln('Done.');
  except
    on E:Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;
  Readln;
end.

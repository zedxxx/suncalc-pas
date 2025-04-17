program SunCalcTest;

{$APPTYPE CONSOLE}

{$ASSERTIONS ON}

uses
  Types,
  Math,
  DateUtils,
  SysUtils,
  SunCalc in '..\SunCalc.pas';

function ISOToDateTime(const AISODateTime: string; const AIncSecond: Integer = 0): TDateTime;
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

  if AIncSecond <> 0 then begin
    Result := IncSecond(Result, AIncSecond);
  end;
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

  Assert(CompareValue(VSunPos.Azimuth, -2.5003175907168385 + Pi, cEpsilon) = EqualsValue);
  Assert(CompareValue(VSunPos.Altitude, -0.7000406838781611, cEpsilon) = EqualsValue);

  NewSunCalcTimes(VTestTimes);

  VTestTimes[solarNoon].Value     := ISOToDateTime('2013-03-05T10:10:57Z', -5);
  VTestTimes[nadir].Value         := ISOToDateTime('2013-03-05T22:10:57Z', -5);
  VTestTimes[sunrise].Value       := ISOToDateTime('2013-03-05T04:34:56Z', -4);
  VTestTimes[sunset].Value        := ISOToDateTime('2013-03-05T15:46:57Z', -4);
  VTestTimes[sunriseEnd].Value    := ISOToDateTime('2013-03-05T04:38:19Z', -4);
  VTestTimes[sunsetStart].Value   := ISOToDateTime('2013-03-05T15:43:34Z', -4);
  VTestTimes[dawn].Value          := ISOToDateTime('2013-03-05T04:02:17Z', -4);
  VTestTimes[dusk].Value          := ISOToDateTime('2013-03-05T16:19:36Z', -4);
  VTestTimes[nauticalDawn].Value  := ISOToDateTime('2013-03-05T03:24:31Z', -5);
  VTestTimes[nauticalDusk].Value  := ISOToDateTime('2013-03-05T16:57:22Z', -4);
  VTestTimes[nightEnd].Value      := ISOToDateTime('2013-03-05T02:46:17Z', -4);
  VTestTimes[night].Value         := ISOToDateTime('2013-03-05T17:35:36Z', -4);
  VTestTimes[goldenHourEnd].Value := ISOToDateTime('2013-03-05T05:19:01Z', -4);
  VTestTimes[goldenHour].Value    := ISOToDateTime('2013-03-05T15:02:52Z', -4);

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

  Assert(CompareValue(VMoonPos.Azimuth, -0.9783999522438226 + Pi, cEpsilon) = EqualsValue);
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
    Writeln('Done!');
  except
    on E:Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;
  Writeln;
  Writeln('Press ENTER to exit...');
  Readln;
end.

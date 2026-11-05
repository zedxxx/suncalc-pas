program SunCalcFullTest;

(*
  Full console test suite for the Delphi SunCalc port.

  This is a framework-free port of suncalc/test/accuracy.test.js: every test is
  anchored to the vendored external-truth fixtures (JPL Horizons positions +
  USNO rise/set/transit times, see fixtures.json) or to the USNO lunar-phase
  instants in moon-phases.json. No DUnit, no third-party test framework and no
  network access are used.

  Run from this directory:
      SunCalcFullTest.exe
  or point it at the data directory explicitly:
      SunCalcFullTest.exe C:\path\to\data

  Exit code: 0 = all tests passed, 1 = test failures, 2 = harness/data error.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Math,
  System.DateUtils,
  System.Generics.Collections,
  System.JSON,
  SunCalc in '..\..\SunCalc.pas',
  SunCalcFullTestSupport in 'SunCalcFullTestSupport.pas';

type
  TTolerance = record
    Field: string;
    MeanTolerance: Double;
    MaxTolerance: Double;
    UnitName: string;
  end;

  TSunTimePair = record
    Angle: Double;
    RiseID: TSunCalcTimesID;
    SetID: TSunCalcTimesID;
  end;

  TUtcOffsetCase = record
    Date: string;
    Lat: Double;
    Lon: Double;
    UtcOffset: Double;
  end;

  TTransitCase = record
    Lat: Double;
    Lon: Double;
    UtcOffset: Double;
  end;

  TGrazingCase = record
    Day: string;
    Lat: Double;
    Lon: Double;
    Field: string;
    Expected: string;
  end;

const
  cSecondsPerDay = 24 * 60 * 60;
  cMinutesPerDay = 24 * 60;

  // JavaScript accuracy.test.js tolerance ceilings, in each field's own unit
  // (degrees, fraction, km, minutes).
  cTolerances: array [0..14] of TTolerance = (
    (Field: 'sun.altitude';           MeanTolerance: 0.12;  MaxTolerance: 0.25;  UnitName: 'deg'),
    (Field: 'sun.azimuth';            MeanTolerance: 0.02;  MaxTolerance: 0.05;  UnitName: 'deg'),
    (Field: 'sun.angularSep';         MeanTolerance: 0.12;  MaxTolerance: 0.25;  UnitName: 'deg'),
    (Field: 'time.sunrise';           MeanTolerance: 0.4;   MaxTolerance: 0.8;   UnitName: 'min'),
    (Field: 'time.sunset';            MeanTolerance: 0.4;   MaxTolerance: 0.8;   UnitName: 'min'),
    (Field: 'time.solarNoon';         MeanTolerance: 0.4;   MaxTolerance: 0.8;   UnitName: 'min'),
    (Field: 'time.dawn';              MeanTolerance: 0.4;   MaxTolerance: 0.8;   UnitName: 'min'),
    (Field: 'time.dusk';              MeanTolerance: 0.4;   MaxTolerance: 0.8;   UnitName: 'min'),
    (Field: 'moon.angularSep';        MeanTolerance: 0.12;  MaxTolerance: 0.25;  UnitName: 'deg'),
    (Field: 'moon.fraction';          MeanTolerance: 0.002; MaxTolerance: 0.005; UnitName: ''),
    (Field: 'moon.distance_km';       MeanTolerance: 100;   MaxTolerance: 100;   UnitName: 'km'),
    (Field: 'moontime.rise';          MeanTolerance: 0.4;   MaxTolerance: 0.9;   UnitName: 'min'),
    (Field: 'moontime.set';           MeanTolerance: 0.4;   MaxTolerance: 0.9;   UnitName: 'min'),
    (Field: 'moontime.transit';       MeanTolerance: 0.4;   MaxTolerance: 0.9;   UnitName: 'min'),
    (Field: 'moontime.lowerTransit';  MeanTolerance: 0.4;   MaxTolerance: 0.9;   UnitName: 'min')
  );

  cSunTimePairs: array [0..5] of TSunTimePair = (
    (Angle: -0.833; RiseID: sunrise;      SetID: sunset),
    (Angle: -0.3;   RiseID: sunriseEnd;   SetID: sunsetStart),
    (Angle: -6;     RiseID: dawn;         SetID: dusk),
    (Angle: -12;    RiseID: nauticalDawn; SetID: nauticalDusk),
    (Angle: -18;    RiseID: nightEnd;     SetID: night),
    (Angle: 6;      RiseID: goldenHourEnd; SetID: goldenHour)
  );

  cSunTimeNames: array [TSunCalcTimesID] of string = (
    'solarNoon', 'nadir', 'sunrise', 'sunset', 'sunriseEnd', 'sunsetStart',
    'dawn', 'dusk', 'nauticalDawn', 'nauticalDusk', 'nightEnd', 'night',
    'goldenHourEnd', 'goldenHour'
  );

  cUtcOffsetCases: array [0..5] of TUtcOffsetCase = (
    (Date: '2020-10-09'; Lat: 56;       Lon: 35;        UtcOffset: 180),   // issue #149
    (Date: '2022-04-14'; Lat: -14.415;  Lon: 128.525;   UtcOffset: 480),   // issue #174
    (Date: '2026-09-30'; Lat: 42.764767; Lon: -71.042023; UtcOffset: -240), // issue #189
    (Date: '2026-08-19'; Lat: 40;       Lon: -179.7;    UtcOffset: -720),
    (Date: '2026-08-19'; Lat: 40;       Lon: 179.7;     UtcOffset: 720),
    (Date: '2026-08-19'; Lat: 27.7;     Lon: 85.3;      UtcOffset: 345)
  );

  cTransitCases: array [0..3] of TTransitCase = (
    (Lat: 51.5; Lon: -0.1;   UtcOffset: 0),
    (Lat: -33.9; Lon: 151.2; UtcOffset: 600),
    (Lat: 40;   Lon: -179.7; UtcOffset: -720),
    (Lat: 78.2; Lon: 15.6;   UtcOffset: 60)
  );

  cGrazingCases: array [0..8] of TGrazingCase = (
    (Day: '2026-05-22'; Lat: 51.5074; Lon: -0.1278; Field: 'night';         Expected: 'null'),
    (Day: '2026-05-22'; Lat: 51.5074; Lon: -0.1278; Field: 'nightEnd';      Expected: '2026-05-22T00:18:06Z'),
    (Day: '2027-07-26'; Lat: 52.52;   Lon: 13.405;  Field: 'nightEnd';      Expected: 'null'),
    (Day: '2027-07-26'; Lat: 52.52;   Lon: 13.405;  Field: 'night';         Expected: '2027-07-26T22:50:31Z'),
    (Day: '2026-08-14'; Lat: 69.6496; Lon: 18.956;  Field: 'dawn';          Expected: 'null'),
    (Day: '2026-08-14'; Lat: 69.6496; Lon: 18.956;  Field: 'dusk';          Expected: '2026-08-14T22:14:03Z'),
    (Day: '2026-05-18'; Lat: 69.6496; Lon: 18.956;  Field: 'sunrise';       Expected: '2026-05-17T22:52:02Z'),
    (Day: '2026-07-25'; Lat: 69.6496; Lon: 18.956;  Field: 'sunset';        Expected: '2026-07-25T22:37:09Z'),
    (Day: '2026-04-18'; Lat: 67;      Lon: 18.956;  Field: 'nauticalDusk';  Expected: 'null')
  );

var
  GFx: TFx;
  GCollectors: TCollectors;

// --- helpers shared by several tests ---

function PhaseDelta(const ATime: TDateTime; const ATargetPhase: Double): Double;
var
  LPhase: Double;
begin
  // Signed offset of the actual phase from the target, wrapped into +/-0.5
  // (mirrors accuracy.test.js: (phase - target + 1.5) % 1 - 0.5).
  LPhase := SunCalc.GetMoonIllumination(ATime).Phase;
  Result := FMod(LPhase - ATargetPhase + 1.5, 1) - 0.5;
end;

procedure CheckSunHalfDay(const ATimes: TSunCalcTimes; const AID: TSunCalcTimesID;
  const AIsRise: Boolean; const AAngle, ALat: Double; const AContext: string);
var
  LDeltaSeconds, LAltitude: Double;
begin
  if not ATimes.Times[AID].HasValue then
    Exit;

  LDeltaSeconds := (ATimes.Times[AID].Value - ATimes.Times[solarNoon].Value) * cSecondsPerDay;
  if AIsRise then
    LDeltaSeconds := -LDeltaSeconds;
  Check((LDeltaSeconds >= 0) and (LDeltaSeconds <= 43200),
    Format('%s: %s is %.1f s from solar noon, outside its half day',
      [AContext, cSunTimeNames[AID], LDeltaSeconds], GFormat));

  if AAngle < -1 then
  begin
    // Below the horizon the apparent position adds the constant ~0.484 deg refraction.
    LAltitude := SunCalc.GetPosition(ATimes.Times[AID].Value, ALat, 10).Altitude - 0.484;
    Check(Abs(LAltitude - AAngle) < 0.01,
      Format('%s: %s seen at %.4f deg, expected %.4f deg',
        [AContext, cSunTimeNames[AID], LAltitude, AAngle], GFormat));
  end;
end;

procedure CheckMoonInSolarDay(const AMoon: TMoonTimes; const ANadir: TDateTime;
  const AContext: string);
var
  LMin, LMax: TDateTime;
begin
  LMin := ANadir - 60 / cSecondsPerDay;
  LMax := ANadir + 1 + 60 / cSecondsPerDay;

  if AMoon.HasRise then
    Check((AMoon.MoonRise >= LMin) and (AMoon.MoonRise < LMax),
      Format('%s: moonrise %s outside [%s, %s)',
        [AContext, ISOText(AMoon.MoonRise), ISOText(LMin), ISOText(LMax)]));
  if AMoon.HasSet then
    Check((AMoon.MoonSet >= LMin) and (AMoon.MoonSet < LMax),
      Format('%s: moonset %s outside [%s, %s)',
        [AContext, ISOText(AMoon.MoonSet), ISOText(LMin), ISOText(LMax)]));
  if AMoon.HasTransit then
    Check((AMoon.Transit >= LMin) and (AMoon.Transit < LMax),
      Format('%s: moon transit %s outside [%s, %s)',
        [AContext, ISOText(AMoon.Transit), ISOText(LMin), ISOText(LMax)]));
  if AMoon.HasLowerTransit then
    Check((AMoon.LowerTransit >= LMin) and (AMoon.LowerTransit < LMax),
      Format('%s: lower transit %s outside [%s, %s)',
        [AContext, ISOText(AMoon.LowerTransit), ISOText(LMin), ISOText(LMax)]));
end;

// --- truth-anchored accuracy gates (mirror accuracy.test.js) ---

procedure PrintMeasurementSummary;
var
  I: Integer;
  LBag: TSampleBag;
begin
  Writeln('Measured external-truth errors (units: deg / fraction / km / min):');
  Writeln(Format('  %-22s %8s %12s %12s  %s',
    ['field', 'n', 'mean', 'max', 'unit'], GFormat));
  for I := Low(cTolerances) to High(cTolerances) do
  begin
    LBag := GCollectors.Bag(cTolerances[I].Field);
    if LBag = nil then
      Continue;
    Writeln(Format('  %-22s %8d %12.5f %12.5f  %s',
      [cTolerances[I].Field, LBag.Count, LBag.Mean, LBag.Max,
       cTolerances[I].UnitName], GFormat));
  end;
  Writeln;
end;

procedure RunAccuracyGates;
var
  I: Integer;
begin
  for I := Low(cTolerances) to High(cTolerances) do
    RunTest('accuracy: ' + cTolerances[I].Field,
      procedure
      var
        LBag: TSampleBag;
        LMean, LMax: Double;
      begin
        LBag := GCollectors.Bag(cTolerances[I].Field);
        Check(LBag <> nil, 'no samples recorded for ' + cTolerances[I].Field);
        if LBag = nil then
          Exit;
        Check(LBag.Count > 0, 'empty sample set for ' + cTolerances[I].Field);

        LMean := LBag.Mean;
        LMax := LBag.Max;
        Check(LMean <= cTolerances[I].MeanTolerance,
          Format('%s mean %.5f %s exceeds tolerance %.5f (n=%d)',
            [cTolerances[I].Field, LMean, cTolerances[I].UnitName,
             cTolerances[I].MeanTolerance, LBag.Count], GFormat));
        Check(LMax <= cTolerances[I].MaxTolerance,
          Format('%s max %.5f %s exceeds tolerance %.5f (n=%d)',
            [cTolerances[I].Field, LMax, cTolerances[I].UnitName,
             cTolerances[I].MaxTolerance, LBag.Count], GFormat));
      end);

  RunTest('accuracy: no dropped samples (every truth event has a SunCalc time)',
    procedure
    var
      LKey, LDropped: string;
      LKeys: TArray<string>;
    begin
      LDropped := '';
      LKeys := GCollectors.Keys.ToArray;
      for LKey in LKeys do
      begin
        if Copy(LKey, 1, 8) <> 'missing.' then
          Continue;
        if LDropped <> '' then
          LDropped := LDropped + ', ';
        LDropped := LDropped + Format('%s x%d',
          [Copy(LKey, 9, MaxInt), GCollectors.Bag(LKey).Count]);
      end;
      Check(LDropped = '',
        'SunCalc produced no time where truth has an event: ' + LDropped);
    end);
end;

// --- fixture-driven structural contracts ---

procedure RunFixtureContracts;
begin
  RunTest('getTimes flags polar day/night instead of returning invalid dates',
    procedure
    var
      LLocName, LDate: string;
      LLat, LLon: Double;
      LTimesRoot, LDays: TJSONObject;
      LTimes: TSunCalcTimes;
      I, J, K: Integer;
      LSawPolar: Boolean;
      LID: TSunCalcTimesID;
    begin
      LSawPolar := False;
      LTimesRoot := JsonObj(GFx.Root.GetValue('times'));
      for I := 0 to LTimesRoot.Count - 1 do
      begin
        LLocName := LTimesRoot.Pairs[I].JsonString.Value;
        if not GFx.LocationByName(LLocName, LLat, LLon) then
          Continue;
        LDays := JsonObj(LTimesRoot.Pairs[I].JsonValue);

        for J := 0 to LDays.Count - 1 do
        begin
          LDate := LDays.Pairs[J].JsonString.Value;
          LTimes := SunCalc.GetTimes(ParseISO(LDate + 'T12:00:00Z'), LLat, LLon);

          for K := Low(cSunTimePairs) to High(cSunTimePairs) do
          begin
            LID := cSunTimePairs[K].RiseID;
            Check(not IsNaN(LTimes.Times[LID].Value),
              Format('%s is Invalid Date at %s %s',
                [cSunTimeNames[LID], LLocName, LDate]));
            LID := cSunTimePairs[K].SetID;
            Check(not IsNaN(LTimes.Times[LID].Value),
              Format('%s is Invalid Date at %s %s',
                [cSunTimeNames[LID], LLocName, LDate]));
          end;

          if not LTimes.Times[sunrise].HasValue then
          begin
            LSawPolar := True;
            Check(Ord(LTimes.AlwaysUp) + Ord(LTimes.AlwaysDown) = 1,
              Format('expected exactly one of AlwaysUp/AlwaysDown at %s %s',
                [LLocName, LDate]));
          end
          else
          begin
            Check((not LTimes.AlwaysUp) and (not LTimes.AlwaysDown),
              Format('AlwaysUp/AlwaysDown set on a normal day at %s %s',
                [LLocName, LDate]));
          end;
        end;
      end;
      Check(LSawPolar, 'fixture matrix should include at least one polar day/night case');
    end);

  RunTest('getMoonTimes flags no-crossing days instead of returning a bogus time',
    procedure
    var
      LLocName, LDate: string;
      LLat, LLon, LPolarLat, LPolarLon: Double;
      LTimesRoot, LDays: TJSONObject;
      LMoon: TMoonTimes;
      I, J: Integer;
    begin
      // The JavaScript test picks the fixture location with the largest |lat|.
      LPolarLat := 0;
      LPolarLon := 0;
      LLocName := '';
      for I := 0 to GFx.LocationCount - 1 do
      begin
        if not GFx.LocationByName(GFx.LocationName(I), LLat, LLon) then
          Continue;
        if (I = 0) or (Abs(LLat) > Abs(LPolarLat)) then
        begin
          LPolarLat := LLat;
          LPolarLon := LLon;
          LLocName := GFx.LocationName(I);
        end;
      end;

      LTimesRoot := JsonObj(GFx.Root.GetValue('times'));
      for I := 0 to LTimesRoot.Count - 1 do
      begin
        if LTimesRoot.Pairs[I].JsonString.Value <> LLocName then
          Continue;
        LDays := JsonObj(LTimesRoot.Pairs[I].JsonValue);
        for J := 0 to LDays.Count - 1 do
        begin
          LDate := LDays.Pairs[J].JsonString.Value;
          LMoon := SunCalc.GetMoonTimes(ParseISO(LDate + 'T00:00:00Z'),
            LPolarLat, LPolarLon, 0);
          if (not LMoon.HasRise) and (not LMoon.HasSet) then
            Check(LMoon.AlwaysUp or LMoon.AlwaysDown,
              Format('expected AlwaysUp/AlwaysDown flag on %s at %s',
                [LDate, LLocName]))
          else
          begin
            Check((not LMoon.HasRise) or (not IsNaN(LMoon.MoonRise)),
              Format('moonrise Invalid Date %s at %s', [LDate, LLocName]));
            Check((not LMoon.HasSet) or (not IsNaN(LMoon.MoonSet)),
              Format('moonset Invalid Date %s at %s', [LDate, LLocName]));
          end;
        end;
      end;
    end);
end;

// --- regression tests ported one-for-one from accuracy.test.js ---

procedure RunRegressionTests;
begin
  RunTest('getMoonTimes no-crossing flag matches the actual altitude sign (issue #186)',
    procedure
    const
      cDates: array [0..2] of string = ('2022-01-14', '2022-01-15', '2022-01-16');
    var
      LDate: string;
      LMoon: TMoonTimes;
      LMoonPos: TMoonPos;
      LDayStart: TDateTime;
      LMin, LMax: Double;
      LStep: Integer;
    begin
      for LDate in cDates do
      begin
        LMoon := SunCalc.GetMoonTimes(ParseISO(LDate + 'T12:00:00Z'), 78, 78, 0);
        Check(not LMoon.HasRise, 'unexpected moonrise on ' + LDate);
        Check(not LMoon.HasSet, 'unexpected moonset on ' + LDate);

        LDayStart := ParseISO(LDate + 'T00:00:00Z');
        LMin := Infinity;
        LMax := -Infinity;
        for LStep := 0 to 48 do
        begin
          LMoonPos := SunCalc.GetMoonPosition(LDayStart + (LStep / 2) / 24, 78, 78);
          LMin := Min(LMin, LMoonPos.Altitude);
          LMax := Max(LMax, LMoonPos.Altitude);
        end;

        Check(LMin > 0, Format('%s: moon dips below the horizon (%.2f deg)',
          [LDate, LMin], GFormat));
        Check(LMoon.AlwaysUp, Format('%s: moon stays up (%.1f..%.1f deg) but not AlwaysUp',
          [LDate, LMin, LMax], GFormat));
        Check(not LMoon.AlwaysDown, LDate + ': moon stays up but flagged AlwaysDown');
      end;
    end);

  RunTest('getTimes resolves the anchored solar day at every longitude (issue #187)',
    procedure
    const
      cLongitudes: array [0..9] of Double =
        (-180, -179.9, -179.7, -179.676, -179.6, -90, 0, 90, 179.9, 180);
    var
      LBase, LAnchor, LNoon: TDateTime;
      LLng, LOffsetHours: Double;
      LTimes: TSunCalcTimes;
      K: Integer;
    begin
      LBase := ParseISO('2026-08-19T12:00:00Z');
      for K := Low(cLongitudes) to High(cLongitudes) do
      begin
        LLng := cLongitudes[K];
        LAnchor := LBase - (LLng / 15) / 24; // that longitude's own local solar noon
        LTimes := SunCalc.GetTimes(LAnchor, 40, LLng);
        LNoon := LTimes.Times[solarNoon].Value;
        LOffsetHours := (LNoon - LAnchor) * 24;
        Check(Abs(LOffsetHours) < 1,
          Format('lng %.3f: solarNoon is %.2f h from local solar noon',
            [LLng, LOffsetHours], GFormat));
      end;
    end);

  RunTest('getMoonTimes scans the local solar day getTimes resolves (issue #189)',
    procedure
    const
      cLongitudes: array [0..7] of Double = (-180, -179.7, -90, -71, 0, 90, 179.9, 180);
      cHourOffsets: array [0..2] of Double = (-6, 0, 6);
    var
      LMoon: TMoonTimes;
      LSun: TSunCalcTimes;
      LBase, LDt, LNadir: TDateTime;
      LLng, LHour: Double;
      LContext: string;
      K, H: Integer;
    begin
      LMoon := SunCalc.GetMoonTimes(ParseISO('2026-09-30T16:00:00Z'),
        42.764767, -71.042023);
      Check(LMoon.HasRise, 'Boston 2026-09-30: expected a moonrise');
      if LMoon.HasRise then
        CheckTimeNear(LMoon.MoonRise, ParseISO('2026-10-01T00:23:00Z'), 60,
          'Boston 2026-09-30 moonrise');

      LBase := ParseISO('2026-09-30T12:00:00Z');
      for K := Low(cLongitudes) to High(cLongitudes) do
      begin
        LLng := cLongitudes[K];
        for H := Low(cHourOffsets) to High(cHourOffsets) do
        begin
          LHour := cHourOffsets[H];
          LDt := LBase - ((LLng / 15) - LHour) / 24;
          LSun := SunCalc.GetTimes(LDt, 40, LLng);
          LNadir := LSun.Times[nadir].Value;
          LMoon := SunCalc.GetMoonTimes(LDt, 40, LLng);
          LContext := Format('lng %.1f h %.0f', [LLng, LHour], GFormat);
          CheckMoonInSolarDay(LMoon, LNadir, LContext);
        end;
      end;
    end);

  RunTest('getTimes resolves grazing events or reports them absent (issue #191)',
    procedure
    var
      LC: TGrazingCase;
      LTimes: TSunCalcTimes;
      LFound: Boolean;
      LValue: TDateTime;
      LLat: Double;
      LContext: string;
      LDay, LPairIndex, LStep: Integer;
      LPair: TSunTimePair;
    begin
      for LC in cGrazingCases do
      begin
        LTimes := SunCalc.GetTimes(ParseISO(LC.Day + 'T12:00:00Z'), LC.Lat, LC.Lon);
        LFound := SunTimeByName(LTimes, LC.Field, LValue);
        if LC.Expected = 'null' then
          Check(not LFound,
            Format('%s %s: expected no event, got %s',
              [LC.Day, LC.Field, ISOText(LValue)]))
        else
        begin
          Check(LFound, Format('%s %s: expected an event', [LC.Day, LC.Field]));
          if LFound then
            CheckTimeNear(LValue, ParseISO(LC.Expected), 60,
              Format('%s %s', [LC.Day, LC.Field]));
        end;
      end;

      // Sweep the high latitudes: each event stays inside its own half day, and
      // below-horizon twilight events land on their configured altitude.
      for LStep := 0 to 48 do
      begin
        LLat := 48 + LStep / 2;
        for LDay := 0 to 121 do // days 0, 3, ..., 363 of 2026
        begin
          LTimes := SunCalc.GetTimes(ParseISO('2026-01-01T12:00:00Z') + LDay * 3,
            LLat, 10);
          for LPairIndex := Low(cSunTimePairs) to High(cSunTimePairs) do
          begin
            LPair := cSunTimePairs[LPairIndex];
            LContext := Format('%s %.1f day %d',
              [cSunTimeNames[LPair.RiseID], LLat, LDay * 3], GFormat);
            CheckSunHalfDay(LTimes, LPair.RiseID, True, LPair.Angle, LLat, LContext);
            LContext := Format('%s %.1f day %d',
              [cSunTimeNames[LPair.SetID], LLat, LDay * 3], GFormat);
            CheckSunHalfDay(LTimes, LPair.SetID, False, LPair.Angle, LLat, LContext);
          end;
        end;
      end;
    end);

  RunTest('utcOffset anchors getTimes and getMoonTimes to the civil day',
    procedure
    var
      LC: TUtcOffsetCase;
      LStart, LEnd, LSample: TDateTime;
      LSun: TSunCalcTimes;
      LMoon: TMoonTimes;
      LSolarNoon, LValue: TDateTime;
      LContext: string;
      K: Integer;
    begin
      for LC in cUtcOffsetCases do
      begin
        LStart := ParseISO(LC.Date + 'T00:00:00Z') - LC.UtcOffset / cMinutesPerDay;
        LEnd := LStart + 1;
        for K := 0 to 2 do
        begin
          case K of
            0: LSample := LStart;
            1: LSample := LStart + 0.5;
          else
            LSample := LEnd - 1 / cMinutesPerDay;
          end;

          LContext := Format('%s lng %.3f offset %.0f',
            [LC.Date, LC.Lon, LC.UtcOffset], GFormat);

          LSun := SunCalc.GetTimes(LSample, LC.Lat, LC.Lon, 0, LC.UtcOffset);
          LSolarNoon := LSun.Times[solarNoon].Value;
          Check((LSolarNoon >= LStart) and (LSolarNoon < LEnd),
            Format('%s: solarNoon %s outside [%s, %s)',
              [LContext, ISOText(LSolarNoon), ISOText(LStart), ISOText(LEnd)]));

          LMoon := SunCalc.GetMoonTimes(LSample, LC.Lat, LC.Lon, LC.UtcOffset);
          if LMoon.HasRise then
          begin
            LValue := LMoon.MoonRise;
            Check((LValue >= LStart) and (LValue < LEnd),
              Format('%s: moonrise %s outside civil day', [LContext, ISOText(LValue)]));
          end;
          if LMoon.HasSet then
          begin
            LValue := LMoon.MoonSet;
            Check((LValue >= LStart) and (LValue < LEnd),
              Format('%s: moonset %s outside civil day', [LContext, ISOText(LValue)]));
          end;
          if LMoon.HasTransit then
          begin
            LValue := LMoon.Transit;
            Check((LValue >= LStart) and (LValue < LEnd),
              Format('%s: moon transit %s outside civil day', [LContext, ISOText(LValue)]));
          end;
          if LMoon.HasLowerTransit then
          begin
            LValue := LMoon.LowerTransit;
            Check((LValue >= LStart) and (LValue < LEnd),
              Format('%s: lower transit %s outside civil day', [LContext, ISOText(LValue)]));
          end;
        end;
      end;

      // Reporter input with an explicit -04:00 offset: both rise and set must survive.
      LMoon := SunCalc.GetMoonTimes(ParseISO('2026-09-30T04:00:00Z'),
        42.764767, -71.042023, -240);
      Check(LMoon.HasRise and LMoon.HasSet,
        'reporter input with offset should get both moonrise and moonset');
    end);

  RunTest('getMoonTimes reports each moon transit exactly once across consecutive days',
    procedure
    const
      cFields: array [0..1] of string = ('transit', 'lowerTransit');
    var
      LC: TTransitCase;
      LMoon: TMoonTimes;
      LValue, LPrev: TDateTime;
      LPrevSet: Boolean;
      LGapHours: Double;
      LField: string;
      LDay, LSkipped, K, F: Integer;
      LContext: string;
    begin
      for K := Low(cTransitCases) to High(cTransitCases) do
      begin
        LC := cTransitCases[K];
        for F := Low(cFields) to High(cFields) do
        begin
          LField := cFields[F];
          LPrevSet := False;
          LPrev := 0;
          LSkipped := 0;

          for LDay := 0 to 59 do
          begin
            LMoon := SunCalc.GetMoonTimes(
              ParseISO('2026-01-01T12:00:00Z') + LDay, LC.Lat, LC.Lon, LC.UtcOffset);
            if not MoonTimeByName(LMoon, LField, LValue) then
            begin
              Inc(LSkipped);
              Continue;
            end;

            LContext := Format('%.1f,%.1f %s', [LC.Lat, LC.Lon, LField], GFormat);
            if LPrevSet then
            begin
              LGapHours := (LValue - LPrev) * 24;
              Check((LGapHours > 24.2) and (LGapHours < 25.6),
                Format('%s: %.2f h after previous', [LContext, LGapHours], GFormat));
            end;
            LPrev := LValue;
            LPrevSet := True;
          end;

          Check(LSkipped = 2,
            Format('%.1f,%.1f %s: %d days without one in 60 (expected 2)',
              [LC.Lat, LC.Lon, LField, LSkipped], GFormat));
        end;
      end;
    end);
end;

procedure RunMoonPhaseTest;
begin
  RunTest('getMoonIllumination phase crosses the named values at the USNO phase instants (issue #190)',
    procedure
    var
      LPhases: TJSONArray;
      LPair: TJSONArray;
      LTarget, LError, LSum, LMax: Double;
      LInstant, LA, LB, LMid: TDateTime;
      LSecondsPerDay: Double;
      I: Integer;
    begin
      LPhases := GFx.MoonPhases;
      Check(LPhases.Count > 0, 'moon-phases.json is empty');
      LSum := 0;
      LMax := 0;
      LSecondsPerDay := cSecondsPerDay;

      for I := 0 to LPhases.Count - 1 do
      begin
        LPair := JsonArr(LPhases.Items[I]);
        LInstant := ParseISO((LPair.Items[0] as TJSONString).Value);
        LTarget := (LPair.Items[1] as TJSONNumber).AsDouble;

        // Bisect the instant at which the phase passes the target within +/-12 h;
        // the signed offset wraps across 0/1.
        LA := LInstant - 0.5;
        LB := LInstant + 0.5;
        while (LB - LA) > 1 / LSecondsPerDay do
        begin
          LMid := (LA + LB) / 2;
          if PhaseDelta(LMid, LTarget) < 0 then
            LA := LMid
          else
            LB := LMid;
        end;

        LError := Abs(LB - LInstant) * cMinutesPerDay;
        LSum := LSum + LError;
        LMax := Max(LMax, LError);
      end;

      // USNO times are rounded to the minute, so ~0.5 min mean is the floor.
      Check((LSum / LPhases.Count) < 1.0,
        Format('phase crossing mean error %.2f min (limit 1.00)', [LSum / LPhases.Count], GFormat));
      Check(LMax < 2.0,
        Format('phase crossing max error %.2f min (limit 2.00)', [LMax], GFormat));
    end);
end;

// --- API contract tests ---

procedure RunContractTests;
begin
  RunTest('NewSunCalcTimes initializes the documented defaults',
    procedure
    var
      LID: TSunCalcTimesID;
      LTimes: TSunCalcTimes;
    begin
      NewSunCalcTimes(LTimes);
      CheckNear(LTimes.Times[sunrise].Angle, -0.833, 1E-12, 'sunrise angle');
      CheckNear(LTimes.Times[sunset].Angle, -0.833, 1E-12, 'sunset angle');
      CheckNear(LTimes.Times[sunriseEnd].Angle, -0.3, 1E-12, 'sunriseEnd angle');
      CheckNear(LTimes.Times[sunsetStart].Angle, -0.3, 1E-12, 'sunsetStart angle');
      CheckNear(LTimes.Times[dawn].Angle, -6, 1E-12, 'dawn angle');
      CheckNear(LTimes.Times[dusk].Angle, -6, 1E-12, 'dusk angle');
      CheckNear(LTimes.Times[nauticalDawn].Angle, -12, 1E-12, 'nauticalDawn angle');
      CheckNear(LTimes.Times[nauticalDusk].Angle, -12, 1E-12, 'nauticalDusk angle');
      CheckNear(LTimes.Times[nightEnd].Angle, -18, 1E-12, 'nightEnd angle');
      CheckNear(LTimes.Times[night].Angle, -18, 1E-12, 'night angle');
      CheckNear(LTimes.Times[goldenHourEnd].Angle, 6, 1E-12, 'goldenHourEnd angle');
      CheckNear(LTimes.Times[goldenHour].Angle, 6, 1E-12, 'goldenHour angle');

      for LID := Low(TSunCalcTimesID) to High(TSunCalcTimesID) do
        Check(not LTimes.Times[LID].HasValue,
          'NewSunCalcTimes must not mark ' + cSunTimeNames[LID] + ' as present');
      Check(not LTimes.AlwaysUp, 'NewSunCalcTimes must clear AlwaysUp');
      Check(not LTimes.AlwaysDown, 'NewSunCalcTimes must clear AlwaysDown');

      for LID := sunrise to goldenHour do
      begin
        if LID in [sunrise, sunriseEnd, dawn, nauticalDawn, nightEnd, goldenHourEnd] then
          Check(LTimes.Times[LID].IsRiseInfo,
            cSunTimeNames[LID] + ' should be a rise event')
        else
          Check(not LTimes.Times[LID].IsRiseInfo,
            cSunTimeNames[LID] + ' should be a set event');
      end;
    end);

  RunTest('positions and angles obey their documented domains',
    procedure
    const
      cDates: array [0..2] of string = ('2026-01-03T00:00:00Z',
        '2026-06-21T12:00:00Z', '2050-12-21T18:00:00Z');
    var
      LDate: string;
      LDt: TDateTime;
      LSun: TSunPos;
      LMoon: TMoonPos;
      LIllum: TMoonIllumination;
    begin
      for LDate in cDates do
      begin
        LDt := ParseISO(LDate);
        LSun := SunCalc.GetPosition(LDt, 50.5, 30.5);
        Check((LSun.Azimuth >= 0) and (LSun.Azimuth < 360),
          Format('%s: Sun azimuth %.6f outside [0, 360)', [LDate, LSun.Azimuth], GFormat));
        Check((LSun.Altitude >= -90.001) and (LSun.Altitude <= 90.001),
          Format('%s: Sun altitude %.6f outside [-90, 90]', [LDate, LSun.Altitude], GFormat));

        LMoon := SunCalc.GetMoonPosition(LDt, 50.5, 30.5);
        Check((LMoon.Azimuth >= 0) and (LMoon.Azimuth < 360),
          Format('%s: Moon azimuth %.6f outside [0, 360)', [LDate, LMoon.Azimuth], GFormat));
        Check((LMoon.Altitude >= -90.001) and (LMoon.Altitude <= 90.001),
          Format('%s: Moon altitude %.6f outside [-90, 90]', [LDate, LMoon.Altitude], GFormat));
        Check((LMoon.ParallacticAngle >= -180) and (LMoon.ParallacticAngle <= 180),
          Format('%s: parallactic angle %.6f outside [-180, 180]',
            [LDate, LMoon.ParallacticAngle], GFormat));
        Check((LMoon.Distance > 350000) and (LMoon.Distance < 410000),
          Format('%s: Moon distance %.1f km outside [350000, 410000]',
            [LDate, LMoon.Distance], GFormat));

        LIllum := SunCalc.GetMoonIllumination(LDt);
        Check((LIllum.Fraction >= 0) and (LIllum.Fraction <= 1),
          Format('%s: illuminated fraction %.6f outside [0, 1]',
            [LDate, LIllum.Fraction], GFormat));
        Check((LIllum.Phase >= 0) and (LIllum.Phase < 1),
          Format('%s: phase %.6f outside [0, 1)', [LDate, LIllum.Phase], GFormat));
        Check((LIllum.Angle >= -180) and (LIllum.Angle <= 180),
          Format('%s: bright-limb angle %.6f outside [-180, 180]',
            [LDate, LIllum.Angle], GFormat));
        Check(LIllum.Waxing = (LIllum.Phase < 0.5),
          Format('%s: Waxing does not agree with Phase %.6f',
            [LDate, LIllum.Phase], GFormat));
      end;
    end);

  RunTest('observer height raises the horizon and keeps solar noon fixed',
    procedure
    var
      LGround, LHigh: TSunCalcTimes;
      LDate: TDateTime;
    begin
      LDate := ParseISO('2026-06-21T12:00:00Z');
      LGround := SunCalc.GetTimes(LDate, 40, 10, 0);
      LHigh := SunCalc.GetTimes(LDate, 40, 10, 1000); // 1 km above the horizon

      Check(LGround.Times[sunrise].HasValue and LHigh.Times[sunrise].HasValue,
        'both ground and mountain sunrises should exist at 40N in June');
      if LGround.Times[sunrise].HasValue and LHigh.Times[sunrise].HasValue then
        Check(LHigh.Times[sunrise].Value <= LGround.Times[sunrise].Value,
          'a higher observer should see sunrise no later than ground level');

      Check(LGround.Times[sunset].HasValue and LHigh.Times[sunset].HasValue,
        'both ground and mountain sunsets should exist at 40N in June');
      if LGround.Times[sunset].HasValue and LHigh.Times[sunset].HasValue then
        Check(LHigh.Times[sunset].Value >= LGround.Times[sunset].Value,
          'a higher observer should see sunset no earlier than ground level');

      CheckTimeNear(LHigh.Times[solarNoon].Value, LGround.Times[solarNoon].Value,
        60, 'solar noon should not move appreciably with observer height');
    end);
end;

var
  LExitCode: Integer;
  LGenerated: string;
begin
  GFx := nil;
  GCollectors := nil;

  try
    try
      GFx := TFx.Create(ResolveDataDir);
      GCollectors := TCollectors.Create;
      LGenerated := JsonStr(GFx.Root, 'generated');

      Writeln('SunCalc full console test suite');
      Writeln('  data directory : ', GFx.DataDir);
      Writeln('  fixtures built : ', LGenerated);
      Writeln('  compiler       : ', {$IFDEF WIN64}'Win64'{$ELSE}'Win32'{$ENDIF});
      Writeln;

      MeasureAll(GFx, GCollectors);
      Writeln(Format('Collected %d measured fields from the external-truth fixtures.',
        [GCollectors.Count]));
      Writeln;

      PrintMeasurementSummary;
      RunAccuracyGates;
      RunFixtureContracts;
      RunRegressionTests;
      RunMoonPhaseTest;
      RunContractTests;

      Writeln;
      Writeln(Format('Tests: %d run, %d failed. Checks: %d run, %d failed.',
        [TestsRun, TestsFailed, ChecksRun, ChecksFailed]));

      if AllPassed then
      begin
        Writeln('ALL TESTS PASSED');
        LExitCode := 0;
      end
      else
      begin
        Writeln('TESTS FAILED');
        LExitCode := 1;
      end;
    except
      on E: Exception do
      begin
        Writeln('FATAL: ', E.ClassName, ': ', E.Message);
        LExitCode := 2;
      end;
    end;
  finally
    GCollectors.Free;
    GFx.Free;
  end;

  Halt(LExitCode);
end.

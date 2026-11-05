unit SunCalcFullTestSupport;

(*
  Minimal self-contained support code for the full SunCalc console test suite.

  Deliberately framework-free: no DUnit, no external packages. Only the Delphi
  RTL is used, and only for JSON parsing (System.JSON), file reading and Math.
*)

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.DateUtils,
  System.Generics.Collections,
  System.JSON,
  System.IOUtils,
  SunCalc;

type
  TTestProc = reference to procedure;

  TSampleBag = class
  private
    FData: TArray<Double>;
    FCount: Integer;
  public
    procedure Add(const AValue: Double);
    function Mean: Double;
    function Max: Double;
    property Count: Integer read FCount;
  end;

  TCollectors = class(TObjectDictionary<string, TSampleBag>)
  public
    constructor Create;
    procedure AddSample(const AField: string; const AValue: Double);
    function Bag(const AField: string): TSampleBag;
  end;

  TFx = class
  private
    FRoot: TJSONValue;
    FPhases: TJSONValue;
    FDataDir: string;
  public
    constructor Create(const ADataDir: string);
    destructor Destroy; override;
    function Root: TJSONObject;
    function MoonPhases: TJSONArray;
    function LocationCount: Integer;
    function LocationName(const AIndex: Integer): string;
    function LocationByName(const AName: string; out ALat, ALon: Double): Boolean;
    property DataDir: string read FDataDir;
  end;

  TSunPhenField = record
    Phen: string;
    Field: string;
  end;

const
  // The five USNO Sun events measured by the JavaScript accuracy gate.
  SunPhenFields: array [0..4] of TSunPhenField = (
    (Phen: 'Rise';                 Field: 'sunrise'),
    (Phen: 'Set';                  Field: 'sunset'),
    (Phen: 'Upper Transit';        Field: 'solarNoon'),
    (Phen: 'Begin Civil Twilight'; Field: 'dawn'),
    (Phen: 'End Civil Twilight';   Field: 'dusk')
  );

  // The four USNO Moon events measured by the JavaScript accuracy gate.
  MoonPhenFields: array [0..3] of TSunPhenField = (
    (Phen: 'Rise';           Field: 'rise'),
    (Phen: 'Set';            Field: 'set'),
    (Phen: 'Upper Transit';  Field: 'transit'),
    (Phen: 'Lower Transit';  Field: 'lowerTransit')
  );

var
  // Invariant formatting so diagnostics do not change with the user's locale.
  GFormat: TFormatSettings;

// --- ISO-8601 helpers (all times are UTC, stored in a naive TDateTime) ---

function ParseISO(const AText: string): TDateTime;
function ISOText(const AValue: TDateTime): string;

// --- numeric / angle helpers ---

function Wrap180(const AValue: Double): Double;
function AngularSep(const AAz1, AAlt1, AAz2, AAlt2: Double): Double;
function MinutesBetween(const A, B: TDateTime): Double;
function WrapMinutes(const AMinutes: Double): Double;

// --- JSON helpers ---

function JsonObj(const AValue: TJSONValue): TJSONObject;
function JsonArr(const AValue: TJSONValue): TJSONArray;
function JsonNum(const AObj: TJSONObject; const AName: string): Double;
function JsonStr(const AObj: TJSONObject; const AName: string): string;
function PhenTime(const AData: TJSONArray; const APhen: string): string;

// --- SunCalc field accessors (mirror the JavaScript property names) ---

function SunTimeByName(const ATimes: TSunCalcTimes; const AName: string;
  out AValue: TDateTime): Boolean;
function MoonTimeByName(const ATimes: TMoonTimes; const AName: string;
  out AValue: TDateTime): Boolean;

// Runs the whole external-truth fixture matrix exactly like the JavaScript
// compare.js harness and fills ACollectors with one sample array per field.
procedure MeasureAll(const AFx: TFx; const ACollectors: TCollectors);

// --- tiny console test harness ---

procedure RunTest(const AName: string; const AProc: TTestProc);
procedure Check(const ACondition: Boolean; const AMessage: string);
procedure CheckNear(const AActual, AExpected, ATolerance: Double;
  const AMessage: string);
procedure CheckTimeNear(const AActual, AExpected: TDateTime;
  const AToleranceSeconds: Double; const AMessage: string);
function TestsRun: Integer;
function TestsFailed: Integer;
function ChecksRun: Integer;
function ChecksFailed: Integer;
function AllPassed: Boolean;

// --- fixture location ---

function ResolveDataDir: string;

implementation

var
  GTestsRun: Integer = 0;
  GTestsFailed: Integer = 0;
  GChecksRun: Integer = 0;
  GChecksFailed: Integer = 0;
  GCurrentTest: string = '';
  GCurrentChecks: Integer = 0;
  GCurrentFailures: Integer = 0;
  GCurrentPrinted: Integer = 0;

const
  cSecondsPerDay = 24 * 60 * 60;
  cMinutesPerDay = 24 * 60;

{ TSampleBag }

procedure TSampleBag.Add(const AValue: Double);
begin
  if FCount = Length(FData) then
  begin
    if Length(FData) = 0 then
      SetLength(FData, 64)
    else
      SetLength(FData, Length(FData) * 2);
  end;
  FData[FCount] := AValue;
  Inc(FCount);
end;

function TSampleBag.Mean: Double;
var
  I: Integer;
begin
  Result := 0;
  if FCount = 0 then
    Exit;
  for I := 0 to FCount - 1 do
    Result := Result + FData[I];
  Result := Result / FCount;
end;

function TSampleBag.Max: Double;
var
  I: Integer;
begin
  Result := 0;
  if FCount = 0 then
    Exit;
  Result := FData[0];
  for I := 1 to FCount - 1 do
    if FData[I] > Result then
      Result := FData[I];
end;

{ TCollectors }

constructor TCollectors.Create;
begin
  inherited Create([doOwnsValues]);
end;

procedure TCollectors.AddSample(const AField: string; const AValue: Double);
var
  LBag: TSampleBag;
begin
  if not TryGetValue(AField, LBag) then
  begin
    LBag := TSampleBag.Create;
    Add(AField, LBag);
  end;
  LBag.Add(AValue);
end;

function TCollectors.Bag(const AField: string): TSampleBag;
begin
  if not TryGetValue(AField, Result) then
    Result := nil;
end;

{ TFx }

constructor TFx.Create(const ADataDir: string);
var
  LText: string;
  LValue: TJSONValue;
begin
  inherited Create;
  FDataDir := IncludeTrailingPathDelimiter(ADataDir);

  if not FileExists(TPath.Combine(FDataDir, 'fixtures.json')) then
    raise Exception.CreateFmt('fixtures.json not found in "%s"', [FDataDir]);
  if not FileExists(TPath.Combine(FDataDir, 'moon-phases.json')) then
    raise Exception.CreateFmt('moon-phases.json not found in "%s"', [FDataDir]);

  LText := TFile.ReadAllText(TPath.Combine(FDataDir, 'fixtures.json'), TEncoding.UTF8);
  LValue := TJSONObject.ParseJSONValue(LText);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise Exception.Create('fixtures.json does not contain a JSON object');
  end;
  FRoot := LValue;

  LText := TFile.ReadAllText(TPath.Combine(FDataDir, 'moon-phases.json'), TEncoding.UTF8);
  LValue := TJSONObject.ParseJSONValue(LText);
  if not (LValue is TJSONArray) then
  begin
    LValue.Free;
    FRoot.Free;
    FRoot := nil;
    raise Exception.Create('moon-phases.json does not contain a JSON array');
  end;
  FPhases := LValue;
end;

destructor TFx.Destroy;
begin
  FPhases.Free;
  FRoot.Free;
  inherited Destroy;
end;

function TFx.Root: TJSONObject;
begin
  Result := FRoot as TJSONObject;
end;

function TFx.MoonPhases: TJSONArray;
begin
  Result := FPhases as TJSONArray;
end;

function TFx.LocationCount: Integer;
begin
  Result := JsonArr(Root.GetValue('locations')).Count;
end;

function TFx.LocationName(const AIndex: Integer): string;
begin
  Result := JsonStr(JsonObj(JsonArr(Root.GetValue('locations')).Items[AIndex]), 'name');
end;

function TFx.LocationByName(const AName: string; out ALat, ALon: Double): Boolean;
var
  LArr: TJSONArray;
  LObj: TJSONObject;
  I: Integer;
begin
  ALat := 0;
  ALon := 0;
  LArr := JsonArr(Root.GetValue('locations'));
  for I := 0 to LArr.Count - 1 do
  begin
    LObj := JsonObj(LArr.Items[I]);
    if JsonStr(LObj, 'name') = AName then
    begin
      ALat := JsonNum(LObj, 'lat');
      ALon := JsonNum(LObj, 'lng');
      Exit(True);
    end;
  end;
  Result := False;
end;

{ ISO-8601 }

function ParseISO(const AText: string): TDateTime;
var
  LText, LTime, LZone: string;
  LYear, LMonth, LDay, LHour, LMinute, LSecond: Integer;
  LZoneSign, LZoneHour, LZoneMinute, LZonePos: Integer;
begin
  LText := Trim(AText);
  LYear := StrToInt(Copy(LText, 1, 4));
  LMonth := StrToInt(Copy(LText, 6, 2));
  LDay := StrToInt(Copy(LText, 9, 2));
  Result := EncodeDate(LYear, LMonth, LDay);

  if Pos('T', LText) = 0 then
    Exit;

  LTime := Copy(LText, Pos('T', LText) + 1, MaxInt);
  LZone := '';
  if (LTime <> '') and (LTime[Length(LTime)] = 'Z') then
  begin
    SetLength(LTime, Length(LTime) - 1);
  end
  else
  begin
    // Optional numeric offset, e.g. -04:00. Keep it out of the time part.
    LZonePos := 9;
    if (Length(LTime) >= LZonePos) and
       ((LTime[LZonePos] = '+') or (LTime[LZonePos] = '-')) then
    begin
      LZone := Copy(LTime, LZonePos, MaxInt);
      SetLength(LTime, LZonePos - 1);
    end;
  end;

  LHour := StrToInt(Copy(LTime, 1, 2));
  if Length(LTime) >= 5 then
    LMinute := StrToInt(Copy(LTime, 4, 2))
  else
    LMinute := 0;
  if Length(LTime) >= 8 then
    LSecond := StrToInt(Copy(LTime, 7, 2))
  else
    LSecond := 0;

  Result := Result + (LHour * 3600 + LMinute * 60 + LSecond) / cSecondsPerDay;

  if (LZone <> '') and (Length(LZone) >= 6) then
  begin
    if LZone[1] = '-' then
      LZoneSign := -1
    else
      LZoneSign := 1;
    LZoneHour := StrToInt(Copy(LZone, 2, 2));
    LZoneMinute := StrToInt(Copy(LZone, 5, 2));
    // local = UTC + offset  =>  UTC = local - offset
    Result := Result - LZoneSign * (LZoneHour * 60 + LZoneMinute) / cMinutesPerDay;
  end;
end;

function ISOText(const AValue: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', AValue);
end;

{ numeric / angle }

function Wrap180(const AValue: Double): Double;
begin
  Result := AValue - 360 * Floor((AValue + 180) / 360);
end;

function AngularSep(const AAz1, AAlt1, AAz2, AAlt2: Double): Double;
var
  LC: Double;
begin
  LC := Sin(DegToRad(AAlt1)) * Sin(DegToRad(AAlt2)) +
        Cos(DegToRad(AAlt1)) * Cos(DegToRad(AAlt2)) *
        Cos(DegToRad(AAz1 - AAz2));
  LC := Min(1, Max(-1, LC));
  Result := RadToDeg(ArcCos(LC));
end;

function MinutesBetween(const A, B: TDateTime): Double;
begin
  Result := Abs(A - B) * cMinutesPerDay;
end;

function WrapMinutes(const AMinutes: Double): Double;
var
  LM: Double;
begin
  // Fold a time-of-day difference into +/-12 h (mirrors compare.js minutesDiff).
  LM := FMod(AMinutes, cMinutesPerDay);
  if LM < 0 then
    LM := LM + cMinutesPerDay;
  Result := Min(LM, cMinutesPerDay - LM);
end;

{ JSON helpers }

function JsonObj(const AValue: TJSONValue): TJSONObject;
begin
  if not (AValue is TJSONObject) then
    raise Exception.Create('expected a JSON object');
  Result := AValue as TJSONObject;
end;

function JsonArr(const AValue: TJSONValue): TJSONArray;
begin
  if not (AValue is TJSONArray) then
    raise Exception.Create('expected a JSON array');
  Result := AValue as TJSONArray;
end;

function JsonNum(const AObj: TJSONObject; const AName: string): Double;
var
  LValue: TJSONValue;
begin
  LValue := AObj.GetValue(AName);
  if not (LValue is TJSONNumber) then
    raise Exception.CreateFmt('expected numeric JSON field "%s"', [AName]);
  Result := (LValue as TJSONNumber).AsDouble;
end;

function JsonStr(const AObj: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  LValue := AObj.GetValue(AName);
  if not (LValue is TJSONString) then
    raise Exception.CreateFmt('expected string JSON field "%s"', [AName]);
  Result := (LValue as TJSONString).Value;
end;

function PhenTime(const AData: TJSONArray; const APhen: string): string;
var
  I: Integer;
  LObj: TJSONObject;
  LValue: TJSONValue;
begin
  Result := '';
  if AData = nil then
    Exit;
  for I := 0 to AData.Count - 1 do
  begin
    LObj := JsonObj(AData.Items[I]);
    if JsonStr(LObj, 'phen') = APhen then
    begin
      LValue := LObj.GetValue('time');
      if LValue is TJSONString then
        Result := (LValue as TJSONString).Value;
      Exit;
    end;
  end;
end;

{ SunCalc field accessors }

function SunTimeByName(const ATimes: TSunCalcTimes; const AName: string;
  out AValue: TDateTime): Boolean;
var
  LID: TSunCalcTimesID;
begin
  AValue := 0;
  if AName = 'sunrise' then LID := sunrise
  else if AName = 'sunset' then LID := sunset
  else if AName = 'sunriseEnd' then LID := sunriseEnd
  else if AName = 'sunsetStart' then LID := sunsetStart
  else if AName = 'dawn' then LID := dawn
  else if AName = 'dusk' then LID := dusk
  else if AName = 'nauticalDawn' then LID := nauticalDawn
  else if AName = 'nauticalDusk' then LID := nauticalDusk
  else if AName = 'nightEnd' then LID := nightEnd
  else if AName = 'night' then LID := night
  else if AName = 'goldenHourEnd' then LID := goldenHourEnd
  else if AName = 'goldenHour' then LID := goldenHour
  else if AName = 'solarNoon' then LID := solarNoon
  else if AName = 'nadir' then LID := nadir
  else
    raise Exception.CreateFmt('unknown Sun time field "%s"', [AName]);

  Result := ATimes.Times[LID].HasValue;
  if Result then
    AValue := ATimes.Times[LID].Value;
end;

function MoonTimeByName(const ATimes: TMoonTimes; const AName: string;
  out AValue: TDateTime): Boolean;
begin
  AValue := 0;
  if AName = 'rise' then
  begin
    Result := ATimes.HasRise;
    if Result then AValue := ATimes.MoonRise;
  end
  else if AName = 'set' then
  begin
    Result := ATimes.HasSet;
    if Result then AValue := ATimes.MoonSet;
  end
  else if AName = 'transit' then
  begin
    Result := ATimes.HasTransit;
    if Result then AValue := ATimes.Transit;
  end
  else if AName = 'lowerTransit' then
  begin
    Result := ATimes.HasLowerTransit;
    if Result then AValue := ATimes.LowerTransit;
  end
  else
    raise Exception.CreateFmt('unknown Moon time field "%s"', [AName]);
end;

{ fixture measurement, mirroring suncalc-js/test/compare.js }

procedure MeasureAll(const AFx: TFx; const ACollectors: TCollectors);
var
  LPositions, LPosition, LBody, LTruth, LTimesRoot, LDays, LDay, LMoonGeo: TJSONObject;
  LSunData, LMoonData: TJSONArray;
  LField: TSunPhenField;
  LLat, LLon, LValue: Double;
  LISO, LDate, LTimeText: string;
  LSun: TSunPos;
  LMoon: TMoonPos;
  LIllum: TMoonIllumination;
  LSunTimes: TSunCalcTimes;
  LMoonTimes: TMoonTimes;
  I, J, LOffset: Integer;
  LBest: Double;
  LFound: Boolean;
  LDt, LTruthTime, LNoon: TDateTime;
begin
  // Positions: Sun and Moon against JPL Horizons.
  LPositions := JsonObj(AFx.Root.GetValue('positions'));
  for I := 0 to LPositions.Count - 1 do
  begin
    if not AFx.LocationByName(LPositions.Pairs[I].JsonString.Value, LLat, LLon) then
      raise Exception.CreateFmt('unknown fixture location "%s"',
        [LPositions.Pairs[I].JsonString.Value]);
    LPosition := JsonObj(LPositions.Pairs[I].JsonValue);

    LBody := JsonObj(LPosition.GetValue('sun'));
    for J := 0 to LBody.Count - 1 do
    begin
      LISO := LBody.Pairs[J].JsonString.Value;
      LTruth := JsonObj(LBody.Pairs[J].JsonValue);
      LSun := SunCalc.GetPosition(ParseISO(LISO), LLat, LLon);
      LValue := JsonNum(LTruth, 'altitude');
      ACollectors.AddSample('sun.altitude', Abs(LSun.Altitude - LValue));
      LValue := JsonNum(LTruth, 'azimuth');
      ACollectors.AddSample('sun.azimuth', Abs(Wrap180(LSun.Azimuth - LValue)));
      ACollectors.AddSample('sun.angularSep',
        AngularSep(LSun.Azimuth, LSun.Altitude, LValue, JsonNum(LTruth, 'altitude')));
    end;

    LBody := JsonObj(LPosition.GetValue('moon'));
    for J := 0 to LBody.Count - 1 do
    begin
      LISO := LBody.Pairs[J].JsonString.Value;
      LTruth := JsonObj(LBody.Pairs[J].JsonValue);
      LMoon := SunCalc.GetMoonPosition(ParseISO(LISO), LLat, LLon);
      LValue := JsonNum(LTruth, 'altitude');
      ACollectors.AddSample('moon.altitude', Abs(LMoon.Altitude - LValue));
      LValue := JsonNum(LTruth, 'azimuth');
      ACollectors.AddSample('moon.azimuth', Abs(Wrap180(LMoon.Azimuth - LValue)));
      ACollectors.AddSample('moon.angularSep',
        AngularSep(LMoon.Azimuth, LMoon.Altitude, LValue, JsonNum(LTruth, 'altitude')));
    end;
  end;

  // Geocentric Moon illumination and distance.
  LMoonGeo := JsonObj(AFx.Root.GetValue('moonGeo'));
  for I := 0 to LMoonGeo.Count - 1 do
  begin
    LISO := LMoonGeo.Pairs[I].JsonString.Value;
    LTruth := JsonObj(LMoonGeo.Pairs[I].JsonValue);
    LDt := ParseISO(LISO);
    LIllum := SunCalc.GetMoonIllumination(LDt);
    LMoon := SunCalc.GetMoonPosition(LDt, 0, 0);
    ACollectors.AddSample('moon.fraction', Abs(LIllum.Fraction - JsonNum(LTruth, 'fraction')));
    ACollectors.AddSample('moon.distance_km', Abs(LMoon.Distance - JsonNum(LTruth, 'distance')));
  end;

  // USNO Sun and Moon rise/set/transit times.
  LTimesRoot := JsonObj(AFx.Root.GetValue('times'));
  for I := 0 to LTimesRoot.Count - 1 do
  begin
    if not AFx.LocationByName(LTimesRoot.Pairs[I].JsonString.Value, LLat, LLon) then
      raise Exception.CreateFmt('unknown fixture location "%s"',
        [LTimesRoot.Pairs[I].JsonString.Value]);
    LDays := JsonObj(LTimesRoot.Pairs[I].JsonValue);

    for J := 0 to LDays.Count - 1 do
    begin
      LDate := LDays.Pairs[J].JsonString.Value;
      LDay := JsonObj(LDays.Pairs[J].JsonValue);
      LSunData := JsonArr(LDay.GetValue('sundata'));
      LMoonData := JsonArr(LDay.GetValue('moondata'));

      for LField in SunPhenFields do
      begin
        LTimeText := PhenTime(LSunData, LField.Phen);
        if LTimeText = '' then
          Continue; // USNO did not report it (polar day/night): not a miss

        LTruthTime := ParseISO(LDate + 'T' + LTimeText + ':00Z');
        LNoon := ParseISO(LDate + 'T12:00:00Z');
        LBest := Infinity;
        for LOffset := -1 to 1 do
        begin
          LSunTimes := SunCalc.GetTimes(LNoon + LOffset, LLat, LLon);
          if SunTimeByName(LSunTimes, LField.Field, LDt) then
            LBest := Min(LBest, MinutesBetween(LDt, LTruthTime));
        end;

        if IsInfinite(LBest) then
          ACollectors.AddSample('missing.time.' + LField.Field, 1)
        else
          ACollectors.AddSample('time.' + LField.Field, LBest);
      end;

      LMoonTimes := SunCalc.GetMoonTimes(ParseISO(LDate + 'T00:00:00Z'), LLat, LLon, 0);
      for LField in MoonPhenFields do
      begin
        LTimeText := PhenTime(LMoonData, LField.Phen);
        if LTimeText = '' then
          Continue;

        LTruthTime := ParseISO(LDate + 'T' + LTimeText + ':00Z');
        LFound := MoonTimeByName(LMoonTimes, LField.Field, LDt);
        if LFound then
          ACollectors.AddSample('moontime.' + LField.Field,
            WrapMinutes((LDt - LTruthTime) * cMinutesPerDay))
        else
          ACollectors.AddSample('missing.moontime.' + LField.Field, 1);
      end;
    end;
  end;
end;

{ console harness }

procedure RunTest(const AName: string; const AProc: TTestProc);
begin
  Inc(GTestsRun);
  GCurrentTest := AName;
  GCurrentChecks := 0;
  GCurrentFailures := 0;
  GCurrentPrinted := 0;
  Writeln(Format('[ RUN      ] %s', [AName]));

  try
    AProc();
  except
    on E: Exception do
    begin
      Inc(GCurrentFailures);
      Inc(GChecksFailed);
      Writeln(Format('    [ERROR] %s: %s', [E.ClassName, E.Message]));
    end;
  end;

  if GCurrentFailures = 0 then
    Writeln(Format('[       OK ] %s (%d checks)', [AName, GCurrentChecks]))
  else
  begin
    Inc(GTestsFailed);
    Writeln(Format('[   FAILED ] %s (%d of %d checks failed)',
      [AName, GCurrentFailures, GCurrentChecks]));
  end;
end;

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  Inc(GChecksRun);
  Inc(GCurrentChecks);
  if ACondition then
    Exit;

  Inc(GChecksFailed);
  Inc(GCurrentFailures);
  if GCurrentPrinted < 12 then
  begin
    Writeln('    [FAIL] ', AMessage);
    Inc(GCurrentPrinted);
  end
  else if GCurrentPrinted = 12 then
  begin
    Writeln('    [FAIL] ... further failures in this test suppressed');
    Inc(GCurrentPrinted);
  end;
end;

procedure CheckNear(const AActual, AExpected, ATolerance: Double;
  const AMessage: string);
begin
  Check(Abs(AActual - AExpected) <= ATolerance,
    Format('%s (actual %.9f, expected %.9f, tolerance %.9f)',
      [AMessage, AActual, AExpected, ATolerance], GFormat));
end;

procedure CheckTimeNear(const AActual, AExpected: TDateTime;
  const AToleranceSeconds: Double; const AMessage: string);
begin
  Check(Abs(AActual - AExpected) * cSecondsPerDay <= AToleranceSeconds,
    Format('%s (actual %s, expected %s, tolerance %.3f s)',
      [AMessage, ISOText(AActual), ISOText(AExpected), AToleranceSeconds]));
end;

function TestsRun: Integer;
begin
  Result := GTestsRun;
end;

function TestsFailed: Integer;
begin
  Result := GTestsFailed;
end;

function ChecksRun: Integer;
begin
  Result := GChecksRun;
end;

function ChecksFailed: Integer;
begin
  Result := GChecksFailed;
end;

function AllPassed: Boolean;
begin
  Result := (GTestsFailed = 0) and (GChecksFailed = 0);
end;

function ResolveDataDir: string;
const
  cRelativeCandidates: array [0..6] of string = (
    '', '..\', '..\..\', '..\..\..\',
    '..\..\test\full\', '..\test\full\', 'test\full\'
  );
var
  LBase, LCandidate: string;
  I: Integer;
begin
  if ParamStr(1) <> '' then
  begin
    LCandidate := TPath.GetFullPath(ParamStr(1));
    if FileExists(TPath.Combine(LCandidate, 'fixtures.json')) then
      Exit(LCandidate);
    raise Exception.CreateFmt('fixtures.json not found in "%s"', [LCandidate]);
  end;

  LBase := ExtractFilePath(ParamStr(0));
  for I := Low(cRelativeCandidates) to High(cRelativeCandidates) do
  begin
    if cRelativeCandidates[I] = '' then
      LCandidate := LBase
    else
      LCandidate := TPath.GetFullPath(TPath.Combine(LBase, cRelativeCandidates[I]));
    if FileExists(TPath.Combine(LCandidate, 'fixtures.json')) and
       FileExists(TPath.Combine(LCandidate, 'moon-phases.json')) then
      Exit(LCandidate);
  end;

  LCandidate := GetCurrentDir;
  if FileExists(TPath.Combine(LCandidate, 'fixtures.json')) then
    Exit(LCandidate);

  raise Exception.Create('fixtures.json not found; pass the data directory as the first argument');
end;

initialization
  GFormat := TFormatSettings.Invariant;

end.

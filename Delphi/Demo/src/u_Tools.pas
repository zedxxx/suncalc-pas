unit u_Tools;

interface

function StrToCoord(const AStr: string): Double;

function ShadowToStr(const AAltitude: Double): string;

function DateTimeFmt(const AUtcDate: TDateTime): string;

function LocalToUniversalTime(const ALocalTime: TDateTime): TDateTime;
function UniversalToLocalTime(const AUtcTime: TDateTime): TDateTime;

implementation

uses
  Windows,
  Math,
  SysUtils,
  DateUtils;

function StrToCoord(const AStr: string): Double;
var
  VStr: string;
  VFormatSettings: TFormatSettings;
begin
  VStr := Trim(AStr);
  VStr := StringReplace(VStr, #176, '', [rfReplaceAll]);
  VStr := StringReplace(VStr, ',',  '.', [rfReplaceAll]);
  VFormatSettings.DecimalSeparator := '.';
  Result := StrToFloat(VStr, VFormatSettings);
end;

function ShadowToStr(const AAltitude: Double): string;
begin
  if AAltitude > 0 then begin
    Result := Format('%.2f m', [1/Tan(AAltitude)]);
  end else begin
    Result := ' - ';
  end;
end;

function DateTimeFmt(const AUtcDate: TDateTime): string;
begin
  Result := DateTimeToStr( UniversalToLocalTime(AUtcDate) );
end;

function LocalToUniversalTime(const ALocalTime: TDateTime): TDateTime;
var
  ST1, ST2: TSystemTime;
  TZ: TTimeZoneInformation;
begin
  GetTimeZoneInformation(TZ);

  TZ.Bias := -TZ.Bias;
  TZ.StandardBias := -TZ.StandardBias;
  TZ.DaylightBias := -TZ.DaylightBias;

  DateTimeToSystemTime(ALocalTime, ST1);

  SystemTimeToTzSpecificLocalTime(@TZ, ST1, ST2);

  Result := SystemTimeToDateTime(ST2);
end;

function UniversalToLocalTime(const AUtcTime: TDateTime): TDateTime;

  function _GetSystemTzOffset: Extended;
  var
    VTmpDate: TDateTime;
    ST1, ST2: TSystemTime;
    TZ: TTimeZoneInformation;
  begin
    GetTimeZoneInformation(TZ);
    DateTimeToSystemTime(AUtcTime, ST1);
    SystemTimeToTzSpecificLocalTime(@TZ, ST1, ST2);
    VTmpDate := SystemTimeToDateTime(ST2);
    Result := MinutesBetween(VTmpDate, AUtcTime) / 60;
    if VTmpDate < AUtcTime then begin
      Result := -Result;
    end;
  end;

var
  VOffset: Extended;
begin
  VOffset := _GetSystemTzOffset;
  if VOffset = 0 then begin
    Result := AUtcTime;
  end else begin
    Result := IncHour(AUtcTime, Trunc(VOffset));
    Result := IncMinute(Result, Round(Frac(VOffset) * 60));
  end;
end;

end.

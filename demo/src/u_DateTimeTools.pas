unit u_DateTimeTools;

interface

function UtcOffsetToStr(const AUtcOffset: Double): string;
function StrToUtcOffset(const AStr: string): Double;

function DateTimeFmt(const AUtcDate: TDateTime; const AUtcOffset: Double): string;

function GetSystemTzOffset(const ADateTime: TDateTime): Double;

function LocalToUniversalTime(const ALocalTime: TDateTime; const AUtcOffset: Double): TDateTime;
function UniversalToLocalTime(const AUtcTime: TDateTime; const AUtcOffset: Double): TDateTime;

implementation

uses
  Windows,
  SysUtils,
  DateUtils;

function UtcOffsetToStr(const AUtcOffset: Double): string;
const
  cSign: array [Boolean] of string = ('-', '+');
begin
  Result :=
    cSign[AUtcOffset >= 0] +
    Format('%.2d:%.2d', [Trunc(AUtcOffset), Round(Frac(AUtcOffset) * 60)]);
end;

function StrToUtcOffset(const AStr: string): Double;
var
  I: Integer;
  VStr: string;
begin
  I := Pos(':', AStr);
  if I > 0 then begin
    VStr := Copy(AStr, 1, I-1);
    Result := StrToInt(VStr);
    VStr := Copy(AStr, I+1);
    if VStr <> '' then begin
      Result := Result + StrToInt(VStr) / 64;
    end;
  end else if Length(AStr) > 0 then begin
    Result := StrToInt(AStr);
  end else begin
    Result := 0;
  end;
end;

function DateTimeFmt(const AUtcDate: TDateTime; const AUtcOffset: Double): string;
var
  VLocalTime: TDateTime;
begin
  VLocalTime := UniversalToLocalTime(AUtcDate, AUtcOffset);
  Result := FormatDateTime('hh:nn dd.mm.yy', VLocalTime);
end;

function GetSystemTzOffset(const ADateTime: TDateTime): Double;
var
  VTmpDate: TDateTime;
  ST1, ST2: TSystemTime;
  TZ: TTimeZoneInformation;
begin
  GetTimeZoneInformation(TZ);
  DateTimeToSystemTime(ADateTime, ST1);
  SystemTimeToTzSpecificLocalTime(@TZ, ST1, ST2);
  VTmpDate := SystemTimeToDateTime(ST2);
  Result := MinutesBetween(VTmpDate, ADateTime) / 60;
  if VTmpDate < ADateTime then begin
    Result := -Result;
  end;
end;

function LocalToUniversalTime(const ALocalTime: TDateTime; const AUtcOffset: Double): TDateTime;
begin
  Result := UniversalToLocalTime(ALocalTime, -AUtcOffset);
end;

function UniversalToLocalTime(const AUtcTime: TDateTime; const AUtcOffset: Double): TDateTime;
begin
  if AUtcOffset = 0 then begin
    Result := AUtcTime;
  end else begin
    Result := IncHour(AUtcTime, Trunc(AUtcOffset));
    Result := IncMinute(Result, Round(Frac(AUtcOffset) * 60));
  end;
end;

end.

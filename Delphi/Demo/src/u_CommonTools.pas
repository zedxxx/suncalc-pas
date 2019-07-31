unit u_CommonTools;

interface

uses
  Windows,
  Graphics;

function StrToCoord(const AStr: string): Double;

function ShadowToStr(const AAltitude: Double): string;

procedure RotateBitmap(Bmp: TBitmap; Rads: Single; AdjustSize: Boolean; BkColor: TColor);

implementation

uses
  Math,
  SysUtils;

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

procedure RotateBitmap(Bmp: TBitmap; Rads: Single; AdjustSize: Boolean; BkColor: TColor);
var
  C: Single;
  S: Single;
  XForm: tagXFORM;
  Tmp: TBitmap;
begin
  C := Cos(Rads);
  S := Sin(Rads);
  XForm.eM11 := C;
  XForm.eM12 := S;
  XForm.eM21 := -S;
  XForm.eM22 := C;
  Tmp := TBitmap.Create;
  try
    Tmp.TransparentColor := Bmp.TransparentColor;
    Tmp.TransparentMode := Bmp.TransparentMode;
    Tmp.Transparent := Bmp.Transparent;
    Tmp.Canvas.Brush.Color := BkColor;
    if AdjustSize then
    begin
      Tmp.Width := Round(Bmp.Width * Abs(C) + Bmp.Height * Abs(S));
      Tmp.Height := Round(Bmp.Width * Abs(S) + Bmp.Height * Abs(C));
      XForm.eDx := (Tmp.Width - Bmp.Width * C + Bmp.Height * S) / 2;
      XForm.eDy := (Tmp.Height - Bmp.Width * S - Bmp.Height * C) / 2;
    end
    else
    begin
      Tmp.Width := Bmp.Width;
      Tmp.Height := Bmp.Height;
      XForm.eDx := (Bmp.Width - Bmp.Width * C + Bmp.Height * S) / 2;
      XForm.eDy := (Bmp.Height - Bmp.Width * S - Bmp.Height * C) / 2;
    end;
    SetGraphicsMode(Tmp.Canvas.Handle, GM_ADVANCED);
    SetWorldTransform(Tmp.Canvas.Handle, XForm);
    BitBlt(Tmp.Canvas.Handle, 0, 0, Tmp.Width, Tmp.Height, Bmp.Canvas.Handle,
      0, 0, SRCCOPY);
    Bmp.Assign(Tmp);
  finally
    Tmp.Free;
  end;
end;

end.

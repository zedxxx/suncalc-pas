object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'SunCalc Demo'
  ClientHeight = 338
  ClientWidth = 713
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnClose = FormClose
  OnShow = FormShow
  PixelsPerInch = 106
  TextHeight = 14
  object lblLat: TLabel
    Left = 8
    Top = 8
    Width = 49
    Height = 14
    Caption = 'Latitude:'
  end
  object lblLon: TLabel
    Left = 156
    Top = 8
    Width = 59
    Height = 14
    Caption = 'Longitude:'
  end
  object lblDate: TLabel
    Left = 304
    Top = 8
    Width = 30
    Height = 14
    Caption = 'Date:'
  end
  object lblTime: TLabel
    Left = 430
    Top = 8
    Width = 31
    Height = 14
    Caption = 'Time:'
  end
  object lblTzOffset: TLabel
    Left = 556
    Top = 8
    Width = 90
    Height = 14
    Caption = 'Time Zone UTC:'
  end
  object edtLat: TEdit
    Left = 8
    Top = 25
    Width = 142
    Height = 22
    TabOrder = 0
    Text = '53.0'
  end
  object dtpDate: TDateTimePicker
    Left = 304
    Top = 25
    Width = 120
    Height = 22
    Align = alCustom
    Anchors = [akTop, akRight]
    Date = 43671.928867870370000000
    Time = 43671.928867870370000000
    TabOrder = 1
    OnChange = btnCalcClick
  end
  object dtpTime: TDateTimePicker
    Left = 430
    Top = 25
    Width = 120
    Height = 22
    Align = alCustom
    Anchors = [akTop, akRight]
    Date = 43671.928867870370000000
    Time = 43671.928867870370000000
    Kind = dtkTime
    TabOrder = 2
  end
  object edtLon: TEdit
    Left = 156
    Top = 25
    Width = 142
    Height = 22
    TabOrder = 3
    Text = '28.0'
  end
  object pnlCenter: TPanel
    Left = 0
    Top = 53
    Width = 713
    Height = 285
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    object imgMoonPhase: TImage
      Left = 605
      Top = 25
      Width = 100
      Height = 100
      Transparent = True
    end
    object lblMoonPhase: TLabel
      Left = 605
      Top = 0
      Width = 70
      Height = 14
      Caption = 'Moon Phase:'
    end
    object mmoSun: TMemo
      AlignWithMargins = True
      Left = 3
      Top = 0
      Width = 295
      Height = 281
      Margins.Top = 0
      ReadOnly = True
      TabOrder = 0
    end
    object mmoMoon: TMemo
      AlignWithMargins = True
      Left = 304
      Top = 0
      Width = 295
      Height = 281
      Margins.Top = 0
      ReadOnly = True
      TabOrder = 1
    end
    object btnCalc: TButton
      Left = 605
      Top = 223
      Width = 100
      Height = 25
      Align = alCustom
      Anchors = [akRight, akBottom]
      Caption = 'Calculate'
      TabOrder = 2
      OnClick = btnCalcClick
    end
    object btnExit: TButton
      Left = 605
      Top = 254
      Width = 100
      Height = 25
      Align = alCustom
      Anchors = [akRight, akBottom]
      Caption = 'Exit'
      TabOrder = 3
      OnClick = btnExitClick
    end
  end
  object btnNow: TButton
    Left = 680
    Top = 25
    Width = 31
    Height = 22
    Hint = 'Reset Date and Time'
    Align = alCustom
    Anchors = [akTop, akRight]
    Caption = '>|<'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 5
    OnClick = btnNowClick
  end
  object edtTimeZone: TEdit
    Left = 556
    Top = 25
    Width = 118
    Height = 22
    TabOrder = 6
  end
end

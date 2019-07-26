object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'SunCalc Demo'
  ClientHeight = 368
  ClientWidth = 602
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
  object lblDateTime: TLabel
    Left = 304
    Top = 8
    Width = 116
    Height = 14
    Caption = 'Local Date and Time:'
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
    Width = 125
    Height = 22
    Align = alCustom
    Anchors = [akTop, akRight]
    Date = 43671.928867870370000000
    Time = 43671.928867870370000000
    TabOrder = 1
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 338
    Width = 602
    Height = 30
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnExit: TButton
      Left = 494
      Top = 0
      Width = 100
      Height = 25
      Align = alCustom
      Anchors = [akRight, akBottom]
      Caption = 'Exit'
      TabOrder = 0
      OnClick = btnExitClick
    end
    object btnCalc: TButton
      Left = 388
      Top = 0
      Width = 100
      Height = 25
      Align = alCustom
      Anchors = [akRight, akBottom]
      Caption = 'Calculate'
      TabOrder = 1
      OnClick = btnCalcClick
    end
  end
  object dtpTime: TDateTimePicker
    Left = 435
    Top = 25
    Width = 125
    Height = 22
    Align = alCustom
    Anchors = [akTop, akRight]
    Date = 43671.928867870370000000
    Time = 43671.928867870370000000
    Kind = dtkTime
    TabOrder = 3
  end
  object edtLon: TEdit
    Left = 156
    Top = 25
    Width = 142
    Height = 22
    TabOrder = 4
    Text = '28.0'
  end
  object pnlCenter: TPanel
    Left = 0
    Top = 53
    Width = 602
    Height = 285
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 5
    object mmoSun: TMemo
      AlignWithMargins = True
      Left = 3
      Top = 0
      Width = 295
      Height = 282
      Margins.Top = 0
      Align = alClient
      ReadOnly = True
      TabOrder = 0
    end
    object mmoMoon: TMemo
      AlignWithMargins = True
      Left = 304
      Top = 0
      Width = 295
      Height = 282
      Margins.Top = 0
      Align = alRight
      ReadOnly = True
      TabOrder = 1
    end
  end
  object btnNow: TButton
    Left = 568
    Top = 25
    Width = 31
    Height = 22
    Hint = 'Reset Date and Time'
    Align = alCustom
    Anchors = [akTop, akRight]
    Caption = '>|<'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 6
    OnClick = btnNowClick
  end
end

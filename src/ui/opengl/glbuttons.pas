{
  Copyright 2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Button drawn inside OpenGL context.

  This is TUIControl descendant, so to use it just add it to
  the TGLUIWindow.Controls or TKamOpenGLControl.Controls list.
  You will also usually want to adjust position (TGLButton.Left,
  TGLButton.Bottom), TGLButton.Caption,
  and assign TGLButton.OnClick (or ovevrride TGLButton.DoClick). }
unit GLButtons;

interface

uses UIControls, OpenGLFonts, KeysMouse, Classes;

type
  TGLButton = class(TUIControl)
  private
    Font: TGLBitmapFont_Abstract;
    FLeft: Integer;
    FBottom: Integer;
    FWidth: Cardinal;
    FHeight: Cardinal;
    FOnClick: TNotifyEvent;
    FCaption: string;
    FAutoSize: boolean;
    TextWidth, TextHeightBase: Cardinal;
    procedure SetCaption(const Value: string);
    procedure SetAutoSize(const Value: boolean);
    { Calculate TextWidth, TextHeightBase and (if AutoSize) update Width, Height.
      This depends on Caption, AutoSize, Font availability. }
    procedure UpdateTextSize;
  public
    constructor Create(AOwner: TComponent); override;
    function DrawStyle: TUIControlDrawStyle; override;
    procedure Draw; override;
    function PositionInside(const X, Y: Integer): boolean; override;
    procedure GLContextInit; override;
    procedure GLContextClose; override;
    function MouseDown(const Button: TMouseButton): boolean; override;
    { Called when user clicks the button. In this class, simply calls
      OnClick callback. }
    procedure DoClick; virtual;
  published
    property Left: Integer read FLeft write FLeft default 0;
    property Bottom: Integer read FBottom write FBottom default 0;
    property Width: Cardinal read FWidth write FWidth default 0;
    property Height: Cardinal read FHeight write FHeight default 0;

    { When AutoSize is @true (the default) then Width/Height are automatically
      adjusted when you change the Caption. They take into account Caption
      width/height with current font, and add some margin to make it look good.

      Note that this adjustment happens only when OpenGL context is initialized
      (because only then we actually know the font used).
      So don't depend on Width/Height values calculated correctly before
      OpenGL context is ready. }
    property AutoSize: boolean read FAutoSize write SetAutoSize default true;

    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property Caption: string read FCaption write SetCaption;
  end;

{ Create and destroy the default UI interface bitmap font.

  They don't actually create new font each time --- first create
  creates the font, next ones only increase the internal counter.
  Destroy decreases the counter and only really frees when it goes to zero.

  The bottom line: you should use them just like normal create / destroy
  (always pair a destroy with a create; destroying @nil is allowed NOOP
  for comfort). But they work fast.

  @groupBegin }
function CreateUIFont: TGLBitmapFont_Abstract;
procedure DestroyUIFont(var Font: TGLBitmapFont_Abstract);
{ @groupEnd }

implementation

uses SysUtils, GL, BFNT_BitstreamVeraSans_Unit, OpenGLBmpFonts, VectorMath,
  KambiGLUtils;

{ TGLButton ------------------------------------------------------------------ }

constructor TGLButton.Create(AOwner: TComponent);
begin
  inherited;
  FAutoSize := true;
  { no need to UpdateTextSize here yet, since Font is for sure not ready yet. }
end;

function TGLButton.DrawStyle: TUIControlDrawStyle;
begin
  Result := ds2D;
end;

procedure TGLButton.Draw;
const
  { These colors match somewhat our TGLMenu slider images }
  { Original TGLMenu inside color: (143, 213, 182); }
  ColInsideUp: TVector3Byte = (165, 245, 210);
  ColInsideDown: TVector3Byte = (126, 188, 161);
  ColDarkFrame: TVector3Byte = (99, 99, 99);
  ColLightFrame: TVector3Byte = (221, 221, 221);
  ColText: TVector3Byte = (0, 0, 0);

  procedure DrawFrame(const Level: Cardinal; const Inset: boolean);
  begin
    if Inset then glColorv(ColLightFrame) else glColorv(ColDarkFrame);
    glVertex2i( Level + Left            ,  Level + Bottom);
    glVertex2i(-Level + Left + Width - 1,  Level + Bottom);
    glVertex2i(-Level + Left + Width - 1,  Level + Bottom);
    glVertex2i(-Level + Left + Width - 1, -Level + Bottom + Height - 1);
    if Inset then glColorv(ColDarkFrame) else glColorv(ColLightFrame);
    glVertex2i( Level + Left            ,  Level + Bottom + 1);
    glVertex2i( Level + Left            , -Level + Bottom + Height - 1);
    glVertex2i( Level + Left            , -Level + Bottom + Height - 1);
    glVertex2i(-Level + Left + Width    , -Level + Bottom + Height - 1);
  end;

begin
  glShadeModel(GL_SMOOTH);
  glBegin(GL_QUADS);
    glColorv(ColInsideDown);
    glVertex2i(Left        , Bottom);
    glVertex2i(Left + Width, Bottom);
    glColorv(ColInsideUp);
    glVertex2i(Left + Width, Bottom + Height);
    glVertex2i(Left        , Bottom + Height);
  glEnd;

  glBegin(GL_LINES);
    DrawFrame(0, false);
    DrawFrame(1, false);
  glEnd;

  glColorv(ColText);
  glRasterPos2i(
    Left + (Width - TextWidth) div 2,
    Bottom + (Height - TextHeightBase) div 2);
  Font.Print(Caption);
end;

function TGLButton.PositionInside(const X, Y: Integer): boolean;
begin
  Result :=
    (X >= Left) and
    (X  < Left + Width) and
    (ContainerHeight - Y >= Bottom) and
    (ContainerHeight - Y  < Bottom + Height);
end;

procedure TGLButton.GLContextInit;
begin
  inherited;
  Font := CreateUIFont;
  UpdateTextSize;
end;

procedure TGLButton.GLContextClose;
begin
  DestroyUIFont(Font);
  inherited;
end;

function TGLButton.MouseDown(const Button: KeysMouse.TMouseButton): boolean;
begin
  { TODO: it would be better to make "mouse capture" in containers,
    and generate there click only when you press moue button over this control,
    and then release over this control. (and in between, all mouse events
    go to the "captured" control.) }
  DoClick;
  Result := true;
end;

procedure TGLButton.DoClick;
begin
  if Assigned(OnClick) then
    OnClick(Self);
end;

procedure TGLButton.SetCaption(const Value: string);
begin
  if Value <> FCaption then
  begin
    FCaption := Value;
    UpdateTextSize;
  end;
end;

procedure TGLButton.SetAutoSize(const Value: boolean);
begin
  if Value <> FAutoSize then
  begin
    FAutoSize := Value;
    UpdateTextSize;
  end;
end;

procedure TGLButton.UpdateTextSize;
const
  HorizontalMargin = 10;
  VerticalMargin = 10;
begin
  if Font <> nil then
  begin
    TextWidth := Font.TextWidth(Caption);
    TextHeightBase := Font.RowHeightBase;

    if AutoSize then
    begin
      Width := TextWidth + HorizontalMargin * 2;
      Height := TextHeightBase + VerticalMargin * 2;
    end;
  end;
end;

{ UIFont --------------------------------------------------------------------- }

var
  UIFont: TGLBitmapFont_Abstract;
  UIFontUsed: Cardinal;

function CreateUIFont: TGLBitmapFont_Abstract;
begin
  if UIFont = nil then
  begin
    UIFont := TGLBitmapFont.Create(@BFNT_BitstreamVeraSans);
    UIFontUsed := 0;
  end;

  Inc(UIFontUsed);
  Result := UIFont;
end;

procedure DestroyUIFont(var Font: TGLBitmapFont_Abstract);
begin
  if Font <> nil then
  begin
    Assert(Font = UIFont, 'You can pass to DestroyUIFont only fonts created with CreateUIFont');
    Dec(UIFontUsed);
    if UIFontUsed = 0 then
      FreeAndNil(UIFont);
    Font := nil;
  end;
end;

end.

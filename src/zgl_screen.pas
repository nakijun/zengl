{
 *  Copyright © Kemka Andrey aka Andru
 *  mail: dr.andru@gmail.com
 *  site: http://andru-kun.inf.ua
 *
 *  This file is part of ZenGL.
 *
 *  ZenGL is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as
 *  published by the Free Software Foundation, either version 3 of
 *  the License, or (at your option) any later version.
 *
 *  ZenGL is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with ZenGL. If not, see http://www.gnu.org/licenses/
}
unit zgl_screen;

{$I zgl_config.cfg}

interface
uses
  {$IFDEF LINUX}
  X, XLib, XUtil, XRandr, UnixType,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  {$IFDEF DARWIN}
  MacOSAll,
  {$ENDIF}
  zgl_opengl_all;

const
  REFRESH_MAXIMUM = 0;
  REFRESH_DEFAULT = 1;

procedure scr_Init;
function  scr_Create : Boolean;
procedure scr_GetResList;
procedure scr_Destroy;
procedure scr_Reset;
procedure scr_Clear;
procedure scr_Flush;

procedure scr_SetWindowedMode;
procedure scr_SetOptions( const Width, Height, Refresh : Word; const FullScreen, VSync : Boolean );
procedure scr_CorrectResolution( const Width, Height : Word );
procedure scr_SetViewPort;
procedure scr_SetVSync( const VSync : Boolean );
procedure scr_SetFSAA( const FSAA : Byte );

{$IFDEF LINUX}
function XOpenIM(para1:PDisplay; para2:PXrmHashBucketRec; para3:Pchar; para4:Pchar):PXIM;cdecl;external;
function XCreateIC(para1 : PXIM; para2 : array of const):PXIC;cdecl;external;
{$ENDIF}
{$IFDEF WINDOWS}
const
  MONITOR_DEFAULTTOPRIMARY = $00000001;

type
  HMONITOR = THANDLE;
  MONITORINFOEX = record
    cbSize    : LongWord;
    rcMonitor : TRect;
    rcWork    : TRect;
    dwFlags   : LongWord;
    szDevice  : array[ 0..CCHDEVICENAME - 1 ] of WideChar;
  end;

function MonitorFromWindow( hwnd : HWND; dwFlags : LongWord ) : THandle; stdcall; external 'user32.dll';
function GetMonitorInfoW( monitor : HMONITOR; var moninfo : MONITORINFOEX ) : BOOL; stdcall; external 'user32.dll';
{$ENDIF}

type
  zglPResolutionList = ^zglTResolutionList;
  zglTResolutionList = record
    Count  : Integer;
    Width  : array of Integer;
    Height : array of Integer;
end;

var
  scr_Width   : Integer = 800;
  scr_Height  : Integer = 600;
  scr_Refresh : Integer;
  scr_VSync   : Boolean;
  scr_ResList : zglTResolutionList;
  scr_Initialized : Boolean;
  scr_Changing : Boolean;

  // Resolution Correct
  scr_ResW  : Integer;
  scr_ResH  : Integer;
  scr_ResCX : Single  = 1;
  scr_ResCY : Single  = 1;
  scr_AddCX : Integer = 0;
  scr_AddCY : Integer = 0;
  scr_SubCX : Integer = 0;
  scr_SubCY : Integer = 0;

  {$IFDEF LINUX}
  scr_Display   : PDisplay;
  scr_Default   : cint;
  scr_Settings  : Pointer;
  scr_Desktop   : LongInt;
  scr_Current   : LongInt;
  scr_ModeCount : LongInt;
  scr_ModeList  : PXRRScreenSize;
  {$ENDIF}
  {$IFDEF WINDOWS}
  scr_Settings : DEVMODEW;
  scr_Desktop  : DEVMODEW;
  scr_Monitor  : HMONITOR;
  scr_MonInfo  : MONITORINFOEX;
  {$ENDIF}
  {$IFDEF DARWIN}
  scr_Display  : CGDirectDisplayID;
  scr_Desktop  : CFDictionaryRef;
  scr_DesktopW : Integer;
  scr_DesktopH : Integer;
  scr_Settings : CFDictionaryRef;
  scr_EraseClr : RGBColor;
  scr_Restore  : MacOSAll.Ptr;
  {$ENDIF}

implementation
uses
  zgl_types,
  zgl_main,
  zgl_application,
  zgl_window,
  zgl_opengl,
  zgl_opengl_simple,
  zgl_camera_2d,
  zgl_log,
  zgl_utils;

{$IFDEF WINDOWS}
function GetDisplayColors : Integer;
  var
    tHDC: hdc;
begin
  tHDC := GetDC( 0 );
  Result := GetDeviceCaps( tHDC, BITSPIXEL ) * GetDeviceCaps( tHDC, PLANES );
  ReleaseDC( 0, tHDC );
end;

function GetDisplayRefresh : Integer;
  var
    tHDC: hdc;
begin
  tHDC := GetDC( 0 );
  Result := GetDeviceCaps( tHDC, VREFRESH );
  ReleaseDC( 0, tHDC );
end;
{$ENDIF}

procedure scr_Init;
  {$IFDEF LINUX}
  var
    Rotation : Word;
  {$ENDIF}
begin
  scr_Initialized := TRUE;
{$IFDEF LINUX}
  log_Init;

  if Assigned( scr_Display ) Then
    XCloseDisplay( scr_Display );

  scr_Display := XOpenDisplay( nil );
  if not Assigned( scr_Display ) Then
    begin
      u_Error( 'Cannot connect to X server.' );
      exit;
    end;

  scr_Default := DefaultScreen( scr_Display );
  wnd_Root    := DefaultRootWindow( scr_Display );

  scr_ModeList := XRRSizes( scr_Display, XRRRootToScreen( scr_Display, wnd_Root ), @scr_ModeCount );
  scr_Settings := XRRGetScreenInfo( scr_Display, wnd_Root );
  scr_Desktop  := XRRConfigCurrentConfiguration( scr_Settings, @Rotation );
{$ENDIF}
{$IFDEF WINDOWS}
  scr_Monitor := MonitorFromWindow( wnd_Handle, MONITOR_DEFAULTTOPRIMARY );
  FillChar( scr_MonInfo, SizeOf( MONITORINFOEX ), 0 );
  scr_MonInfo.cbSize := SizeOf( MONITORINFOEX );
  GetMonitorInfoW( scr_Monitor, scr_MonInfo );

  with scr_Desktop do
    begin
      dmSize             := SizeOf( DEVMODEW );
      dmPelsWidth        := GetSystemMetrics( SM_CXSCREEN );
      dmPelsHeight       := GetSystemMetrics( SM_CYSCREEN );
      dmBitsPerPel       := GetDisplayColors();
      dmDisplayFrequency := GetDisplayRefresh();
      dmFields           := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL or DM_DISPLAYFREQUENCY;
    end;
{$ENDIF}
{$IFDEF DARWIN}
  scr_Display  := CGMainDisplayID();
  scr_Desktop  := CGDisplayCurrentMode( scr_Display );
  scr_DesktopW := CGDisplayPixelsWide( scr_Display );
  scr_DesktopH := CGDisplayPixelsHigh( scr_Display );
{$ENDIF}
end;

function scr_Create;
  {$IFDEF LINUX}
  var
    i, j : Integer;
  {$ENDIF}
begin
  Result := FALSE;
{$IFDEF LINUX}
  scr_Init();

  if DefaultDepth( scr_Display, scr_Default ) < 24 Then
    begin
      u_Error( 'DefaultDepth not set to 24-bit.' );
      zgl_Exit;
      exit;
    end;

  if not glXQueryExtension( scr_Display, i, j ) Then
    begin
      u_Error( 'GLX Extension not found' );
      exit;
    end else log_Add( 'GLX Extension - ok' );

  app_XIM := XOpenIM( scr_Display, nil, nil, nil );
  if not Assigned( app_XIM ) Then
    log_Add( 'XOpenIM - Fail' )
  else
    log_Add( 'XOpenIM - ok' );

  app_XIC := XCreateIC( app_XIM, [ XNInputStyle, XIMPreeditNothing or XIMStatusNothing, 0 ] );
  if not Assigned( app_XIC ) Then
    log_Add( 'XCreateIC - Fail' )
  else
    log_Add( 'XCreateIC - ok' );

  ogl_zDepth := 24;
  repeat
    FillChar( ogl_Attr[ 0 ], length( ogl_Attr ) * 4, None );
    ogl_Attr[ 0  ] := GLX_RGBA;
    ogl_Attr[ 1  ] := GL_TRUE;
    ogl_Attr[ 2  ] := GLX_RED_SIZE;
    ogl_Attr[ 3  ] := 8;
    ogl_Attr[ 4  ] := GLX_GREEN_SIZE;
    ogl_Attr[ 5  ] := 8;
    ogl_Attr[ 6  ] := GLX_BLUE_SIZE;
    ogl_Attr[ 7  ] := 8;
    ogl_Attr[ 8  ] := GLX_ALPHA_SIZE;
    ogl_Attr[ 9  ] := 8;
    ogl_Attr[ 10 ] := GLX_DOUBLEBUFFER;
    ogl_Attr[ 11 ] := GL_TRUE;
    ogl_Attr[ 12 ] := GLX_DEPTH_SIZE;
    ogl_Attr[ 13 ] := ogl_zDepth;
    i := 14;
    if ogl_Stencil > 0 Then
      begin
        ogl_Attr[ i     ] := GLX_STENCIL_SIZE;
        ogl_Attr[ i + 1 ] := ogl_Stencil;
        INC( i, 2 );
      end;
    if ogl_FSAA > 0 Then
      begin
        ogl_Attr[ i     ] := GLX_SAMPLES_SGIS;
        ogl_Attr[ i + 1 ] := ogl_FSAA;
      end;

    log_Add( 'glXChooseVisual: zDepth = ' + u_IntToStr( ogl_zDepth ) + '; ' + 'stencil = ' + u_IntToStr( ogl_Stencil ) + '; ' + 'fsaa = ' + u_IntToStr( ogl_FSAA )  );
    ogl_VisualInfo := glXChooseVisual( scr_Display, scr_Default, @ogl_Attr[ 0 ] );
    if ( not Assigned( ogl_VisualInfo ) and ( ogl_zDepth = 1 ) ) Then
      begin
        if ogl_FSAA = 0 Then
          break
        else
          begin
            ogl_zDepth := 24;
            DEC( ogl_FSAA, 2 );
          end;
      end else
        if not Assigned( ogl_VisualInfo ) Then DEC( ogl_zDepth, 8 );
  if ogl_zDepth = 0 Then ogl_zDepth := 1;
  until Assigned( ogl_VisualInfo );

  if not Assigned( ogl_VisualInfo ) Then
    begin
      u_Error( 'Cannot choose pixel format.' );
      exit;
    end;

  ogl_zDepth := ogl_VisualInfo.depth;
{$ENDIF}
{$IFDEF WINDOWS}
  scr_Init();
  if ( not wnd_FullScreen ) and ( scr_Desktop.dmBitsPerPel <> 32 ) Then
    scr_SetWindowedMode();
{$ENDIF}
{$IFDEF DARWIN}
  scr_Init();
  if CGDisplayBitsPerPixel( scr_Display ) <> 32 Then
    begin
      u_Error( 'Desktop not set to 32-bit mode.' );
      zgl_Exit;
      exit;
    end;
{$ENDIF}
  log_Add( 'Current mode: ' + u_IntToStr( zgl_Get( DESKTOP_WIDTH ) ) + ' x ' + u_IntToStr( zgl_Get( DESKTOP_HEIGHT ) ) );
  scr_GetResList();
  Result := TRUE;
end;

procedure scr_GetResList;
  var
    i : Integer;
  {$IFDEF LINUX}
    tmp_Settings : PXRRScreenSize;
  {$ENDIF}
  {$IFDEF WINDOWS}
    tmp_Settings : DEVMODEW;
  {$ENDIF}
  function Already( Width, Height : Integer ) : Boolean;
    var
      j : Integer;
  begin
    Result := FALSE;
    for j := 0 to scr_ResList.Count - 1 do
      if ( scr_ResList.Width[ j ] = Width ) and ( scr_ResList.Height[ j ] = Height ) Then Result := TRUE;
  end;
begin
{$IFDEF LINUX}
  for i := 0 to scr_ModeCount - 1 do
    begin
      tmp_Settings := scr_ModeList;
      if not Already( tmp_Settings.Width, tmp_Settings.Height ) Then
        begin
          INC( scr_ResList.Count );
          SetLength( scr_ResList.Width, scr_ResList.Count );
          SetLength( scr_ResList.Height, scr_ResList.Count );
          scr_ResList.Width[ scr_ResList.Count - 1 ]  := tmp_Settings.Width;
          scr_ResList.Height[ scr_ResList.Count - 1 ] := tmp_Settings.Height;
        end;
      INC( tmp_Settings );
    end;
{$ENDIF}
{$IFDEF WINDOWS}
  i := 0;
  while EnumDisplaySettingsW( scr_MonInfo.szDevice, i, tmp_Settings ) <> FALSE do
    begin
      if not Already( tmp_Settings.dmPelsWidth, tmp_Settings.dmPelsHeight ) Then
        begin
          INC( scr_ResList.Count );
          SetLength( scr_ResList.Width, scr_ResList.Count );
          SetLength( scr_ResList.Height, scr_ResList.Count );
          scr_ResList.Width[ scr_ResList.Count - 1 ]  := tmp_Settings.dmPelsWidth;
          scr_ResList.Height[ scr_ResList.Count - 1 ] := tmp_Settings.dmPelsHeight;
        end;
      INC( i );
    end;
{$ENDIF}
end;

procedure scr_Destroy;
begin
  scr_Reset();
  {$IFDEF LINUX}
  XRRFreeScreenConfigInfo( scr_Settings );
  {$ENDIF}
end;

procedure scr_Reset;
begin
{$IFDEF LINUX}
  XRRSetScreenConfig( scr_Display, scr_Settings, wnd_Root, scr_Desktop, 1, 0 );
{$ENDIF}
{$IFDEF WINDOWS}
  ChangeDisplaySettingsExW( scr_MonInfo.szDevice, DEVMODEW( nil^ ), 0, 0, nil );
{$ENDIF}
{$IFDEF DARWIN}
  CGDisplaySwitchToMode( scr_Display, scr_Desktop );
  //CGDisplayRelease( scr_Display );
{$ENDIF}
end;

procedure scr_Clear;
begin
  glClear( GL_COLOR_BUFFER_BIT * Byte( app_Flags and COLOR_BUFFER_CLEAR > 0 ) or GL_DEPTH_BUFFER_BIT * Byte( app_Flags and DEPTH_BUFFER_CLEAR > 0 ) or
           GL_STENCIL_BUFFER_BIT * Byte( app_Flags and STENCIL_BUFFER_CLEAR > 0 ) );
end;

procedure scr_Flush;
begin
{$IFDEF LINUX}
  glXSwapBuffers( scr_Display, wnd_Handle );
{$ENDIF}
{$IFDEF WINDOWS}
  SwapBuffers( wnd_DC );
{$ENDIF}
{$IFDEF DARWIN}
  aglSwapBuffers( ogl_Context );
{$ENDIF}
end;

procedure scr_SetWindowedMode;
  {$IFDEF WINDOWS}
  var
    settings : DEVMODEW;
  {$ENDIF}
begin
  {$IFDEF LINUX}
  scr_Reset();
  XMapWindow( scr_Display, wnd_Handle );
  {$ENDIF}
  {$IFDEF WINDOWS}
  if scr_Desktop.dmBitsPerPel <> 32 Then
    begin
      settings              := scr_Desktop;
      settings.dmBitsPerPel := 32;

      if ChangeDisplaySettingsExW( scr_MonInfo.szDevice, settings, 0, CDS_TEST, nil ) <> DISP_CHANGE_SUCCESSFUL Then
        begin
          u_Error( 'Desktop doesn''t support 32-bit color mode.' );
          zgl_Exit;
        end else
          ChangeDisplaySettingsExW( scr_MonInfo.szDevice, settings, 0, 0, nil );
    end else
      scr_Reset();
  {$ENDIF}
  {$IFDEF DARWIN}
  scr_Reset();
  ShowMenuBar();
  {$ENDIF}
end;

procedure scr_SetOptions;
  var
  {$IFDEF LINUX}
    modeToSet : Integer;
    mode      : PXRRScreenSize;
  {$ENDIF}
  {$IFDEF WINDOWS}
    i : Integer;
    r : Integer;
  {$ENDIF}
  {$IFDEF DARWIN}
    b  : Integer;
    dW : SInt16;
    dH : SInt16;
    nw : WindowRef;
  {$ENDIF}
begin
  scr_Changing   := TRUE;
  ogl_Width      := Width;
  ogl_Height     := Height;
  wnd_Width      := Width;
  wnd_Height     := Height;
  scr_Width      := Width;
  scr_Height     := Height;
  wnd_FullScreen := FullScreen;
  scr_Vsync      := VSync;
  if not app_Initialized Then exit;
  scr_SetVSync( scr_VSync );

  if Height >= zgl_Get( DESKTOP_HEIGHT ) Then
    wnd_FullScreen := TRUE;
  if wnd_FullScreen Then
    begin
      scr_Width  := Width;
      scr_Height := Height;
    end else
      begin
        scr_Width  := zgl_Get( DESKTOP_WIDTH );
        scr_Height := zgl_Get( DESKTOP_HEIGHT );
        {$IFDEF WINDOWS}
        scr_Refresh := GetDisplayRefresh;
        {$ENDIF}
      end;
{$IFDEF LINUX}
  if wnd_FullScreen Then
    begin
      scr_Current := -1;
      mode        := scr_ModeList;

      for modeToSet := 0 to scr_ModeCount - 1 do
        if ( mode.Width = scr_Width ) and ( mode.Height = scr_Height ) Then
          begin
            scr_Current := modeToSet;
            break;
          end else
            INC( mode );

      if scr_Current = -1 Then
        begin
          u_Warning( 'Cannot set fullscreen mode.' );
          scr_Current    := scr_Desktop;
          wnd_FullScreen := FALSE;
        end;
      XRRSetScreenConfig( scr_Display, scr_Settings, wnd_Root, scr_Current, 1, 0 );
    end else
      scr_SetWindowedMode();
{$ENDIF}
{$IFDEF WINDOWS}
  if wnd_FullScreen Then
    begin
      i := 0;
      r := 0;
      while EnumDisplaySettingsW( scr_MonInfo.szDevice, i, scr_Settings ) <> FALSE do
        with scr_Settings do
          begin
            dmSize   := SizeOf( DEVMODEW );
            dmFields := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL or DM_DISPLAYFREQUENCY;
            if ( dmPelsWidth = scr_Width  ) and ( dmPelsHeight = scr_Height ) and ( dmBitsPerPel = 32 ) and ( dmDisplayFrequency > r ) and
               ( dmDisplayFrequency <= scr_Desktop.dmDisplayFrequency ) Then
              begin
                if ChangeDisplaySettingsExW( scr_MonInfo.szDevice, scr_Settings, 0, CDS_TEST, nil ) = DISP_CHANGE_SUCCESSFUL Then
                  r := dmDisplayFrequency
                else
                  break;
              end;
            INC( i );
          end;

      with scr_Settings do
        begin
          dmSize := SizeOf( DEVMODEW );
          if scr_Refresh = REFRESH_MAXIMUM Then scr_Refresh := r;
          if scr_Refresh = REFRESH_DEFAULT Then scr_Refresh := 0;

          dmPelsWidth        := scr_Width;
          dmPelsHeight       := scr_Height;
          dmBitsPerPel       := 32;
          dmDisplayFrequency := scr_Refresh;
          dmFields           := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL or DM_DISPLAYFREQUENCY;
        end;

      if ChangeDisplaySettingsExW( scr_MonInfo.szDevice, scr_Settings, 0, CDS_TEST, nil ) <> DISP_CHANGE_SUCCESSFUL Then
        begin
          u_Warning( 'Cannot set fullscreen mode.' );
          wnd_FullScreen := FALSE;
        end else
          ChangeDisplaySettingsExW( scr_MonInfo.szDevice, scr_Settings, 0, 0, nil );
    end else
      scr_SetWindowedMode();
{$ENDIF}
{$IFDEF DARWIN}
  if wnd_FullScreen Then
    begin
      //CGDisplayCapture( scr_Display );
      if scr_Refresh <> 0 Then
        begin
          scr_Settings := CGDisplayBestModeForParametersAndRefreshRate( scr_Display, 32, scr_Width, scr_Height, scr_Refresh, b );
          scr_Refresh  := b;
        end;
      if scr_Refresh = 0 Then
        scr_Settings := CGDisplayBestModeForParameters( scr_Display, 32, scr_Width, scr_Height, b );

      if b = 1 Then
        CGDisplaySwitchToMode( scr_Display, scr_Settings )
      else
        begin
          u_Warning( 'Cannot set fullscreen mode.' );
          wnd_FullScreen := FALSE;
        end;

      HideMenuBar();
    end else
      scr_SetWindowedMode();
{$ENDIF}
  if wnd_FullScreen Then
    log_Add( 'Set screen options: ' + u_IntToStr( scr_Width ) + ' x ' + u_IntToStr( scr_Height ) + ' fullscreen' )
  else
    log_Add( 'Set screen options: ' + u_IntToStr( wnd_Width ) + ' x ' + u_IntToStr( wnd_Height ) + ' windowed' );
  if app_Work Then
    wnd_Update();
end;

procedure scr_CorrectResolution;
begin
  scr_ResW  := Width;
  scr_ResH  := Height;
  scr_ResCX := wnd_Width  / Width;
  scr_ResCY := wnd_Height / Height;

  if scr_ResCX < scr_ResCY Then
    begin
      scr_AddCX := 0;
      scr_AddCY := Round( ( wnd_Height - Height * scr_ResCX ) / 2 );
      scr_ResCY := scr_ResCX;
    end else
      begin
        scr_AddCX := Round( ( wnd_Width - Width * scr_ResCY ) / 2 );
        scr_AddCY := 0;
        scr_ResCX := scr_ResCY;
      end;

  if app_Flags and CORRECT_HEIGHT = 0 Then
    begin
      scr_ResCY := wnd_Height / Height;
      scr_AddCY := 0;
    end;
  if app_Flags and CORRECT_WIDTH = 0 Then
    begin
      scr_ResCX := wnd_Width / Width;
      scr_AddCX := 0;
    end;

  ogl_Width  := Round( wnd_Width / scr_ResCX );
  ogl_Height := Round( wnd_Height / scr_ResCY );
  scr_SubCX  := ogl_Width - Width;
  scr_SubCY  := ogl_Height - Height;
  SetCurrentMode();

  cam2dZoomX := cam2dGlobal.Zoom.X;
  cam2dZoomY := cam2dGlobal.Zoom.Y;
  ogl_ClipR  := Round( sqrt( sqr( ogl_ClipW / scr_ResCX / cam2dZoomX ) + sqr( ogl_ClipH / scr_ResCY / cam2dZoomY ) ) ) div 2;
end;

procedure scr_SetViewPort;
begin
  if ogl_Target = TARGET_SCREEN Then
    begin
      cam2dSX := Round( -ogl_Width / 2 + scr_AddCX / scr_ResCX );
      cam2dSY := Round( -ogl_Height / 2 + scr_AddCY / scr_ResCY );

      if ( app_Flags and CORRECT_RESOLUTION > 0 ) and ( ogl_Mode = 2 ) Then
        begin
          ogl_ClipX := 0;
          ogl_ClipY := 0;
          ogl_ClipW := wnd_Width - scr_AddCX * 2;
          ogl_ClipH := wnd_Height - scr_AddCY * 2;
          glViewPort( scr_AddCX, scr_AddCY, ogl_ClipW, ogl_ClipH );
        end else
          begin
            ogl_ClipX := 0;
            ogl_ClipY := 0;
            ogl_ClipW := wnd_Width;
            ogl_ClipH := wnd_Height;
            glViewPort( 0, 0, ogl_ClipW, ogl_ClipH );
          end;
    end else
      begin
        cam2dSX   := Round( -ogl_Width / 2 );
        cam2dSY   := Round( -ogl_Height / 2 );
        ogl_ClipX := 0;
        ogl_ClipY := 0;
        ogl_ClipW := ogl_Width;
        ogl_ClipH := ogl_Height;
        glViewPort( 0, 0, ogl_ClipW, ogl_ClipH );
      end;
end;

procedure scr_SetVSync;
begin
  scr_VSync := VSync;
{$IFDEF LINUX}
  if ogl_CanVSync Then
    glXSwapIntervalSGI( Integer( scr_VSync ) );
{$ENDIF}
{$IFDEF WINDOWS}
  if ogl_CanVSync Then
    wglSwapIntervalEXT( Integer( scr_VSync ) );
{$ENDIF}
{$IFDEF DARWIN}
  if Assigned( ogl_Context ) Then
    aglSetInt( ogl_Context, AGL_SWAP_INTERVAL, Byte( scr_VSync ) );
{$ENDIF}
end;

procedure scr_SetFSAA;
begin
  if ogl_FSAA = FSAA Then exit;
  ogl_FSAA := FSAA;

{$IFDEF LINUX}
  XFree( scr_ModeList );
  scr_Destroy();
  scr_Create();
{$ENDIF}

  gl_Destroy();
  wnd_Update();
  gl_Create();
  if ogl_FSAA <> 0 Then
    log_Add( 'Set FSAA: ' + u_IntToStr( ogl_FSAA ) + 'x' )
  else
    log_Add( 'Set FSAA: off' );
end;

end.

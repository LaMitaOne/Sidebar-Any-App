unit SidebarAnyApp;

// =============================================================================
//  SidebarAnyApp  -  a reusable, drop-on-form VCL component
// -----------------------------------------------------------------------------
//  Pure standard VCL, no third-party units. The component builds and owns its
//  own host form (FHost) entirely in code, so no .dfm entry is required for the
//  sidebar itself. Just drop TSidebarAnyApp on any form (or create it in code),
//  set Active := True, and the sidebar appears docked to the chosen edge.
//
//  What the component does:
//    * Hosts a thin 28px tab strip (TPaintBox) at the screen edge.
//    * A fixed "Settings" tab (gear glyph, index 0) toggles the 270px settings
//      panel that holds the dockable-window list (TStringGrid) and a live
//      window preview (TImage). After picking windows the panel collapses
//      back to the 28px strip on its own.
//    * Each docked window becomes a 34px tab showing the first capital letter
//      of its title, centered, plus a small coloured side-bar when the window
//      is currently slid in. Hover shows the full title as a tooltip.
//    * Docking moves windows by their stored HWND (IsWindow + MoveWindow), so
//      browser tab-title changes no longer break the slide animation.
//    * On destroy every docked/hidden window is pulled back to the desktop so
//      nothing is left stranded off-screen.
//    * All four edges (Left/Right/Top/Bottom) with multi-monitor support. The
//      edge is switched from the right-click menu only - there is NO edge
//      jumping on mouse-at-border.
//
//  Replacement map vs. the original Sidebar-Control project:
//    TNextGrid6              -> TStringGrid
//    TAdvOfficeTabSet        -> TPaintBox (owner-drawn vertical tab strip)
//    TAdvSmoothPanel         -> TPanel
//    TAdvShapeButton         -> TSpeedButton
//    TfspTaskbarPreviews/Mgr -> GetWindowScreenshot (PrintWindow) on TImage
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types,
  System.IOUtils, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.Menus, Vcl.StdCtrls, Vcl.Buttons, Vcl.Grids, Vcl.Themes;

type
  // Which screen edge the sidebar lives on.
  TSidebarEdge = (seLeft, seRight, seTop, seBottom);

  // Notification fired whenever the active edge changes.
  TEdgeChangeEvent = procedure(Sender: TObject; NewEdge: TSidebarEdge) of object;

  // One docked window = one entry in the tab strip.
  TDockTab = class
    Handle: HWND;
    Caption: string;
    SlidIn: Boolean;       // True = window currently visible next to the strip
    OriginalRect: TRect;    // window position before docking (for restore)
    constructor Create(AHandle: HWND; const ACaption: string);
  end;

  // Forward declaration of the privately-owned host form.
  TSidebarHostForm = class;

  // The component.
  TSidebarAnyApp = class(TComponent)
  private
    FHost: TSidebarHostForm;
    FActive: Boolean;
    FEdge: TSidebarEdge;
    FAutoStart: Boolean;
    FStatusFile: string;
    FOnEdgeChange: TEdgeChangeEvent;
    procedure SetActive(const Value: Boolean);
    procedure SetEdge(const Value: TSidebarEdge);
    function  GetEdge: TSidebarEdge;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Show;   inline;
    procedure Hide;   inline;
    procedure RefreshWindowList;
    procedure RestoreAllWindows;
    procedure MoveToEdge(AEdge: TSidebarEdge);
    procedure SendToScreen(MonitorIndex: Integer);
    property HostForm: TSidebarHostForm read FHost;
  published
    property Active: Boolean read FActive write SetActive default False;
    property Edge: TSidebarEdge read GetEdge write SetEdge default seRight;
    property AutoStart: Boolean read FAutoStart write FAutoStart default True;
    property OnEdgeChange: TEdgeChangeEvent read FOnEdgeChange write FOnEdgeChange;
  end;

  // ---------------------------------------------------------------------------
  //  Privately-owned host form. Built entirely in code (no DFM).
  // ---------------------------------------------------------------------------
  TSidebarHostForm = class(TForm)
    pnlStrip: TPanel;          // 28px host panel for the tab strip
    pbTabs: TPaintBox;        // owner-drawn tab strip (settings tab + window tabs)
    pnlSettings: TPanel;      // 270px settings panel (collapsible)
    grdWindows: TStringGrid;  // dockable window list
    btnRefresh: TSpeedButton;
    btnClose: TSpeedButton;
    TrayIcon1: TTrayIcon;
    TrayPopupMenu: TPopupMenu;
    TimerWindowCheck: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure pbTabsPaint(Sender: TObject);
    procedure pbTabsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbTabsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbTabsMouseLeave(Sender: TObject);
    procedure grdWindowsDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure grdWindowsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure TrayPopupMenuPopup(Sender: TObject);
    procedure TrayMenuTabPosClick(Sender: TObject);
    procedure TrayMenuSendToScreenClick(Sender: TObject);
    procedure TrayMenuRestoreAllClick(Sender: TObject);
    procedure TrayMenuExitClick(Sender: TObject);
    procedure TimerWindowCheckTimer(Sender: TObject);
  private
    FOwnerComp: TSidebarAnyApp;
    FEdge: TSidebarEdge;
    FExpanded: Boolean;        // True = settings panel visible (270px)
    FHoverTabIndex: Integer;   // tab under the mouse (-1 = none)
    FActiveTabIndex: Integer;  // currently active tab (-1 = none)
    FTabs: TList;              // list of TDockTab
    FStatusFile: string;
    procedure BuildControls;
    procedure ApplyEdge(AEdge: TSidebarEdge);
    procedure ApplyExpanded(AExpanded: Boolean);
    procedure RepositionForEdge;
    function  CurrentWorkArea: TRect;
    procedure GetAllXWindows;
    procedure MagneticWindow(TargetHWND: HWND; SlideIN: Boolean);
    procedure AddTab(AHandle: HWND; const ACaption: string);
    procedure RemoveTab(AHandle: HWND);
    function  FindTabIndexByHandle(AHandle: HWND): Integer;
    function  TabAtPoint(X, Y: Integer): Integer;
    function  TabCount: Integer;
    procedure CheckSidebarWindows;
    procedure SendAllBackToDesktop;
    procedure SaveSidebarStatus;
    procedure LoadSidebarStatus;
    procedure SetTabPositionByEdgeMenu(AEdge: TSidebarEdge);
    function  IsFilteredWindow(XhWnd: HWND; const ATitle: string): Boolean;
    function  FirstCapitalOf(const S: string): string;
  public
    constructor CreateFor(AOwnerComp: TSidebarAnyApp; AOwner: TComponent);
    destructor Destroy; override;
  end;

procedure Register;

implementation

const
  STRIP_THICKNESS = 28;     // tab-strip thickness along the edge
  EXPANDED_SIZE   = 270;    // settings panel size when expanded
  TAB_HEIGHT      = 34;     // height of each tab in the strip
  SETTINGS_TAB    = 0;      // fixed index of the settings (gear) tab

{ TDockTab }

constructor TDockTab.Create(AHandle: HWND; const ACaption: string);
begin
  Handle := AHandle;
  Caption := ACaption;
  SlidIn := False;
  FillChar(OriginalRect, SizeOf(OriginalRect), 0);
end;

{ TSidebarAnyApp }

constructor TSidebarAnyApp.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FActive := False;
  FEdge := seRight;
  FAutoStart := True;
  FStatusFile := TPath.Combine(ExtractFilePath(ParamStr(0)), 'SidebarAnyApp.txt');
  FHost := nil;
end;

destructor TSidebarAnyApp.Destroy;
begin
  SetActive(False);
  inherited Destroy;
end;

procedure TSidebarAnyApp.Loaded;
begin
  inherited Loaded;
  if (csDesigning in ComponentState) then Exit;
  if FAutoStart and (not (csLoading in ComponentState)) then
    SetActive(True);
end;

procedure TSidebarAnyApp.SetActive(const Value: Boolean);
begin
  if FActive = Value then Exit;
  if Value then
  begin
    if FHost = nil then
      // Owner = nil: Application must NOT own the host form, otherwise during
      // shutdown Application frees FHost first and the component's destructor
      // frees it again -> EInvalidPointer "Ungueltige Zeigeroperation".
      FHost := TSidebarHostForm.CreateFor(Self, nil);
    FHost.FStatusFile := FStatusFile;
    FHost.ApplyEdge(FEdge);
    FHost.Show;
    // Bug 1: OnShow may have already fired inside Show() if the window was
    // created visible, but on a fresh form it does not run until the message
    // pump ticks. Force the window list + correct edge position right here so
    // the sidebar never appears with an empty grid in the top-left corner.
    try FHost.GetAllXWindows;     except end;
    try FHost.LoadSidebarStatus;  except end;
    try FHost.RepositionForEdge;  except end;
    FActive := True;
  end
  else
  begin
    if FHost <> nil then
    begin
      FHost.Close;
      FreeAndNil(FHost);
    end;
    FActive := False;
  end;
end;

procedure TSidebarAnyApp.SetEdge(const Value: TSidebarEdge);
begin
  FEdge := Value;
  if FHost <> nil then
    FHost.ApplyEdge(Value);
end;

function TSidebarAnyApp.GetEdge: TSidebarEdge;
begin
  if FHost <> nil then
    Result := FHost.FEdge
  else
    Result := FEdge;
end;

procedure TSidebarAnyApp.Show;
begin
  SetActive(True);
end;

procedure TSidebarAnyApp.Hide;
begin
  SetActive(False);
end;

procedure TSidebarAnyApp.RefreshWindowList;
begin
  if FHost <> nil then FHost.GetAllXWindows;
end;

procedure TSidebarAnyApp.RestoreAllWindows;
begin
  if FHost <> nil then FHost.SendAllBackToDesktop;
end;

procedure TSidebarAnyApp.MoveToEdge(AEdge: TSidebarEdge);
begin
  SetEdge(AEdge);
  if FHost <> nil then FHost.RepositionForEdge;
end;

procedure TSidebarAnyApp.SendToScreen(MonitorIndex: Integer);
var
  wa: TRect;
begin
  if (FHost = nil) or (MonitorIndex < 0) or (MonitorIndex >= Screen.MonitorCount) then Exit;
  wa := Screen.Monitors[MonitorIndex].WorkAreaRect;
  FHost.Left := wa.Left;
  FHost.Top := wa.Top;
  FHost.RepositionForEdge;
end;

{ TSidebarHostForm }

constructor TSidebarHostForm.CreateFor(AOwnerComp: TSidebarAnyApp; AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  FOwnerComp := AOwnerComp;
  FEdge := seRight;
  FExpanded := True;        // start expanded so the user can pick windows
  FHoverTabIndex := -1;
  FActiveTabIndex := -1;
  FTabs := TList.Create;
  BuildControls;
end;

destructor TSidebarHostForm.Destroy;
var
  i: Integer;
begin
  if FTabs <> nil then
  begin
    for i := 0 to FTabs.Count - 1 do
      TDockTab(FTabs[i]).Free;
    FTabs.Free;
    FTabs := nil;
  end;
  inherited Destroy;
end;

procedure TSidebarHostForm.FormCreate(Sender: TObject);
begin
  // Empty: all construction happens in CreateFor/BuildControls. Kept only so a
  // DFM-less form has an OnCreate slot if someone ever assigns one.
end;

procedure TSidebarHostForm.FormDestroy(Sender: TObject);
begin
  try
    SendAllBackToDesktop;
  except
  end;
end;

procedure TSidebarHostForm.FormShow(Sender: TObject);
begin
  GetAllXWindows;
  LoadSidebarStatus;
  ApplyEdge(FEdge);
  ApplyExpanded(FExpanded);
  RepositionForEdge;
  TimerWindowCheck.Interval := 3000;
  TimerWindowCheck.Enabled := True;
  TrayIcon1.Visible := True;
  TrayIcon1.PopupMenu := TrayPopupMenu;
end;

// --- Build every control in code -------------------------------------------

procedure TSidebarHostForm.BuildControls;
begin
  Name := 'SidebarHostForm';
  Caption := 'Sidebar AnyApp';
  BorderStyle := bsNone;
  Color := clBlack;
  Position := poDesigned;
  FormStyle := fsStayOnTop;
  Width := EXPANDED_SIZE;
  Height := 596;

  // --- Form events (bug 1): wire OnShow / OnDestroy explicitly, otherwise
  //     GetAllXWindows, RepositionForEdge and TrayIcon1.Visible never ran at
  //     start - the list stayed empty and the form sat in the top-left corner.
  Self.OnShow := FormShow;
  Self.OnDestroy := FormDestroy;

  // --- Popup menu (bug 3): create FIRST, before any control assigns it.
  //     Previously this stood at the bottom, so pbTabs.PopupMenu := TrayPopupMenu
  //     grabbed nil and right-click did nothing on the tab strip.
  TrayPopupMenu := TPopupMenu.Create(Self);
  TrayPopupMenu.AutoPopup := True;
  TrayPopupMenu.OnPopup := TrayPopupMenuPopup;
  // The form itself gets the menu too, so right-click anywhere on the empty
  // border / caption area still works.
  Self.PopupMenu := TrayPopupMenu;

  // --- Tray icon (bug 2): without a real icon Windows shows nothing in the
  //     tray even if Visible := True. Borrow Application.Icon, fall back to
  //     the default application icon from the OS if it is empty.
  TrayIcon1 := TTrayIcon.Create(Self);
  TrayIcon1.Hint := 'Sidebar AnyApp';
  TrayIcon1.PopupMenu := TrayPopupMenu;
  if (Application.Icon <> nil) and (not Application.Icon.Empty) then
    TrayIcon1.Icon.Assign(Application.Icon)
  else
    TrayIcon1.Icon.Handle := LoadIcon(0, IDI_APPLICATION);

  // --- 28px tab-strip host panel (pbTabs) ---
  pnlStrip := TPanel.Create(Self);
  pnlStrip.Parent := Self;
  pnlStrip.BevelOuter := bvNone;
  pnlStrip.Color := clBlack;
  pnlStrip.ParentBackground := False;
  pnlStrip.Align := alRight;
  pnlStrip.Width := STRIP_THICKNESS;
  pnlStrip.PopupMenu := TrayPopupMenu;

  pbTabs := TPaintBox.Create(Self);
  pbTabs.Parent := pnlStrip;
  pbTabs.Align := alClient;
  pbTabs.Color := clBlack;
  pbTabs.ParentColor := False;
  pbTabs.OnPaint := pbTabsPaint;
  pbTabs.OnMouseDown := pbTabsMouseDown;
  pbTabs.OnMouseMove := pbTabsMouseMove;
  pbTabs.OnMouseLeave := pbTabsMouseLeave;
  pbTabs.PopupMenu := TrayPopupMenu;
  pbTabs.ShowHint := True;
  pbTabs.Hint := '';

  // --- 270px settings panel ---
  pnlSettings := TPanel.Create(Self);
  pnlSettings.Parent := Self;
  pnlSettings.BevelOuter := bvNone;
  pnlSettings.Color := clBlack;
  pnlSettings.ParentBackground := False;
  pnlSettings.Align := alClient;
  pnlSettings.Caption := '';
  pnlSettings.PopupMenu := TrayPopupMenu;
  pnlSettings.OnMouseDown := nil; // no drag-move; strip stays at edge

  // Refresh / Close buttons, top-right inside the settings panel.
  btnRefresh := TSpeedButton.Create(Self);
  btnRefresh.Parent := pnlSettings;
  btnRefresh.Flat := True;
  btnRefresh.Font.Name := 'Segoe UI Symbol';
  btnRefresh.Font.Size := 12;
  btnRefresh.Font.Color := clAqua;
  btnRefresh.Caption := #$21BB; // U+21BB CLOCKWISE OPEN CIRCLE ARROW
  btnRefresh.Hint := 'Refresh window list';
  btnRefresh.ShowHint := True;
  btnRefresh.OnClick := btnRefreshClick;
  btnRefresh.PopupMenu := TrayPopupMenu;

  btnClose := TSpeedButton.Create(Self);
  btnClose.Parent := pnlSettings;
  btnClose.Flat := True;
  btnClose.Font.Name := 'Segoe UI Symbol';
  btnClose.Font.Size := 12;
  btnClose.Font.Color := clRed;
  btnClose.Caption := #$2715; // U+2715 MULTIPLICATION X
  btnClose.Hint := 'Exit';
  btnClose.ShowHint := True;
  btnClose.OnClick := btnCloseClick;
  btnClose.PopupMenu := TrayPopupMenu;

  // Window list (col 0 = checkbox glyph, col 1 = title; HWND in Objects[0, Row]).
  grdWindows := TStringGrid.Create(Self);
  grdWindows.Parent := pnlSettings;
  grdWindows.BorderStyle := bsNone;
  grdWindows.Color := clBlack;          // empty / fixed cells are black, not white
  grdWindows.FixedColor := clBlack;
  grdWindows.DrawingStyle := gdsClassic; // classic = we paint, no themed white background
  grdWindows.Enabled := True;            // grid must accept input on clBlack
  grdWindows.DefaultDrawing := False;   // we fully own cell painting -> no white flash
  grdWindows.ColCount := 2;
  grdWindows.RowCount := 1;
  grdWindows.FixedCols := 0;
  grdWindows.FixedRows := 0;
  grdWindows.DefaultRowHeight := 20;
  grdWindows.Options := [goVertLine, goHorzLine, goRowSelect, goColSizing];
  grdWindows.ScrollBars := ssVertical;
  grdWindows.GridLineWidth := 0;
  grdWindows.Font.Name := 'Segoe UI';
  grdWindows.Font.Color := clSilver;
  grdWindows.OnDrawCell := grdWindowsDrawCell;
  grdWindows.OnMouseDown := grdWindowsMouseDown;
  grdWindows.PopupMenu := TrayPopupMenu;
  grdWindows.Cells[0, 0] := '';
  grdWindows.Cells[1, 0] := '';
  grdWindows.Objects[0, 0] := Pointer(0);

  // Window-check timer (created last; enabled in FormShow).
  TimerWindowCheck := TTimer.Create(Self);
  TimerWindowCheck.Enabled := False;
  TimerWindowCheck.Interval := 3000;
  TimerWindowCheck.OnTimer := TimerWindowCheckTimer;

  // DoubleBuffered everywhere (anti-flicker): the owner-drawn tab strip
  // repaints on every mouse move / slide animation, so the whole hierarchy
  // gets buffered. Child controls inherit via ParentDoubleBuffered.
  Self.DoubleBuffered := True;
  pnlStrip.DoubleBuffered := True;
  pnlSettings.DoubleBuffered := True;
  grdWindows.DoubleBuffered := True;
end;

// --- Edge / expand geometry --------------------------------------------------

function TSidebarHostForm.CurrentWorkArea: TRect;
begin
  Result := Screen.MonitorFromRect(BoundsRect).WorkareaRect;
end;

procedure TSidebarHostForm.ApplyEdge(AEdge: TSidebarEdge);
begin
  FEdge := AEdge;
  // The strip sits on the chosen edge; the settings panel fills the rest.
  case AEdge of
    seLeft:
      begin
        pnlStrip.Align := alLeft;
        pnlStrip.Width := STRIP_THICKNESS;
        pnlStrip.Height := 0; // ignored under alLeft
        pnlSettings.Align := alClient;
      end;
    seRight:
      begin
        pnlStrip.Align := alRight;
        pnlStrip.Width := STRIP_THICKNESS;
        pnlSettings.Align := alClient;
      end;
    seTop:
      begin
        pnlStrip.Align := alTop;
        pnlStrip.Height := STRIP_THICKNESS;
        pnlStrip.Width := 0;  // ignored under alTop
        pnlSettings.Align := alClient;
      end;
    seBottom:
      begin
        pnlStrip.Align := alBottom;
        pnlStrip.Height := STRIP_THICKNESS;
        pnlSettings.Align := alClient;
      end;
  end;
  pbTabs.Invalidate;
  ApplyExpanded(FExpanded);
  if Assigned(FOwnerComp) and Assigned(FOwnerComp.FOnEdgeChange) then
    FOwnerComp.FOnEdgeChange(FOwnerComp, AEdge);
end;

procedure TSidebarHostForm.ApplyExpanded(AExpanded: Boolean);
var
  wa: TRect;
  size, big: Integer;
begin
  FExpanded := AExpanded;
  wa := CurrentWorkArea;
  if AExpanded then
    size := EXPANDED_SIZE
  else
    size := STRIP_THICKNESS;

  case FEdge of
    seLeft, seRight:
      begin
        big := 596;
        ClientWidth := size;
        ClientHeight := big;
      end;
    seTop, seBottom:
      begin
        big := 596;
        ClientHeight := size;
        ClientWidth := big;
      end;
  end;

  pnlSettings.Visible := AExpanded;
  if AExpanded then
  begin
    // Re-anchor the two buttons and the grid inside the settings panel.
    btnRefresh.Left := pnlSettings.ClientWidth - 38;
    btnRefresh.Top := 4;
    btnRefresh.Width := 16;
    btnRefresh.Height := 18;
    btnClose.Left := pnlSettings.ClientWidth - 18;
    btnClose.Top := 4;
    btnClose.Width := 16;
    btnClose.Height := 18;

    grdWindows.Left := 12;
    grdWindows.Top := 28;
    grdWindows.Width := pnlSettings.ClientWidth - 24;
    grdWindows.Height := pnlSettings.ClientHeight - 40;
    grdWindows.ColWidths[0] := 22;
    grdWindows.ColWidths[1] := grdWindows.ClientWidth - grdWindows.ColWidths[0] - 4;
  end;
  pbTabs.Invalidate;
end;

procedure TSidebarHostForm.RepositionForEdge;
var
  wa: TRect;
begin
  wa := CurrentWorkArea;
  case FEdge of
    seLeft:
      begin
        Left := wa.Left;
        Top := wa.Top + (wa.Bottom - wa.Top - ClientHeight) div 2;
      end;
    seRight:
      begin
        Left := wa.Right - ClientWidth;
        Top := wa.Top + (wa.Bottom - wa.Top - ClientHeight) div 2;
      end;
    seTop:
      begin
        Left := wa.Left + (wa.Right - wa.Left - ClientWidth) div 2;
        Top := wa.Top;
      end;
    seBottom:
      begin
        Left := wa.Left + (wa.Right - wa.Left - ClientWidth) div 2;
        Top := wa.Bottom - ClientHeight;
      end;
  end;
end;

// --- Window enumeration & filtering -----------------------------------------

function TSidebarHostForm.IsFilteredWindow(XhWnd: HWND; const ATitle: string): Boolean;
var
  style, exstyle: NativeInt;
  ownHandle: HWND;
begin
  Result := True; // filter out by default
  if XhWnd = 0 then Exit;

  // Exclude our own host window.
  ownHandle := Self.Handle;
  if XhWnd = ownHandle then Exit;

  // Exclude well-known desktop shell windows.
  if (ATitle = 'Program Manager') or (ATitle = '') then Exit;
  if (ATitle = 'Windows Input Experience') or
     (ATitle = 'Windows-Eingabeerfahrung') or
     (ATitle = 'MS Shell Dlg') then Exit;

  // Exclude tool-windows (docks, palette windows, tray popups, ...).
  exstyle := GetWindowLong(XhWnd, GWL_EXSTYLE);
  if (exstyle and WS_EX_TOOLWINDOW) <> 0 then Exit;

  // Must be visible and have a non-empty title.
  if not IsWindowVisible(XhWnd) then Exit;
  if ATitle = '' then Exit;

  Result := False; // keep this window
end;

function TSidebarHostForm.FirstCapitalOf(const S: string): string;
var
  i: Integer;
  ch: Char;
begin
  Result := '?';
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    if CharInSet(ch, ['A'..'Z', #$00C0..#$00DE]) and (ch <> #$00D7) then
    begin
      Result := ch;
      Exit;
    end;
  end;
  // Fall back to first non-space character upper-cased.
  for i := 1 to Length(S) do
    if S[i] > ' ' then
    begin
      Result := UpCase(S[i]);
      Exit;
    end;
end;

procedure TSidebarHostForm.GetAllXWindows;
var
  XhWnd: HWND;
  Title: array[0..255] of Char;
  TitleStr: string;
  Row, idx: Integer;
  isDocked: Boolean;
begin
  // Drop stale HWNDs from the dock tab list first.
  for idx := FTabs.Count - 1 downto 0 do
    if not IsWindow(TDockTab(FTabs[idx]).Handle) then
    begin
      TDockTab(FTabs[idx]).Free;
      FTabs.Delete(idx);
    end;

  grdWindows.RowCount := 1;
  grdWindows.Cells[0, 0] := '';
  grdWindows.Cells[1, 0] := '';
  grdWindows.Objects[0, 0] := Pointer(0);
  Row := 0;
  XhWnd := GetWindow(GetDesktopWindow, GW_CHILD);
  while XhWnd <> 0 do
  begin
    GetWindowText(XhWnd, Title, SizeOf(Title));
    TitleStr := StrPas(Title);
    if not IsFilteredWindow(XhWnd, TitleStr) then
    begin
      if Row > 0 then
        grdWindows.RowCount := grdWindows.RowCount + 1;
      grdWindows.Cells[1, Row] := TitleStr;
      grdWindows.Objects[0, Row] := Pointer(XhWnd);
      isDocked := (FindTabIndexByHandle(XhWnd) >= 0);
      if isDocked then
        grdWindows.Cells[0, Row] := 'x'
      else
        grdWindows.Cells[0, Row] := '';
      Inc(Row);
    end;
    XhWnd := GetWindow(XhWnd, GW_HWNDNEXT);
  end;
  grdWindows.ColWidths[1] := grdWindows.ClientWidth - grdWindows.ColWidths[0] - 4;
  pbTabs.Invalidate;
end;

// --- Grid drawing & interaction ---------------------------------------------

procedure TSidebarHostForm.grdWindowsDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  s: string;
  chk: TRect;
begin
  with grdWindows.Canvas do
  begin
    // Body fill: pure black for both empty and populated cells (no white).
    Brush.Color := clBlack;
    if (gdSelected in State) or (gdRowSelected in State) then
      Brush.Color := $00101010; // subtle dark grey for the selected row
    FillRect(Rect);
    if ACol = 0 then
    begin
      chk.Left := Rect.Left + 3;
      chk.Top := Rect.Top + (Rect.Height - 13) div 2;
      chk.Right := chk.Left + 13;
      chk.Bottom := chk.Top + 13;
      Brush.Color := clWhite;
      Pen.Color := clSilver;
      Rectangle(chk);
      s := grdWindows.Cells[0, ARow];
      if s = 'x' then
      begin
        Pen.Color := clBlack;
        Pen.Width := 2;
        MoveTo(chk.Left + 2, chk.Top + 6);
        LineTo(chk.Left + 5, chk.Bottom - 3);
        LineTo(chk.Right - 2, chk.Top + 3);
        Pen.Width := 1;
      end;
    end
    else
    begin
      Font.Color := clSilver;
      s := grdWindows.Cells[1, ARow];
      TextRect(Rect, Rect.Left + 4, Rect.Top + 1, s);
    end;
  end;
end;

procedure TSidebarHostForm.grdWindowsMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  ACol, ARow: Integer;
  h: HWND;
  idx: Integer;
  t: TDockTab;
  R: TRect;
begin
  grdWindows.MouseToCell(X, Y, ACol, ARow);
  if (ACol <> 0) or (ARow < 0) then Exit;
  h := HWND(grdWindows.Objects[0, ARow]);
  if h = 0 then Exit;

  idx := FindTabIndexByHandle(h);
  if grdWindows.Cells[0, ARow] = 'x' then
  begin
    // Uncheck -> undock: restore original position.
    grdWindows.Cells[0, ARow] := '';
    if idx >= 0 then
    begin
      t := TDockTab(FTabs[idx]);
      if IsWindow(h) then
      begin
        R := t.OriginalRect;
        if (R.Right - R.Left) > 0 then
          MoveWindow(h, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, True)
        else
          ShowWindow(h, SW_SHOWNOACTIVATE);
      end;
      RemoveTab(h);
    end;
  end
  else
  begin
    // Check -> dock: remember position, add tab, slide the window out.
    grdWindows.Cells[0, ARow] := 'x';
    if idx < 0 then
    begin
      if IsWindow(h) then
        GetWindowRect(h, R)
      else
        FillChar(R, SizeOf(R), 0);
      AddTab(h, grdWindows.Cells[1, ARow]);
      TDockTab(FTabs[FindTabIndexByHandle(h)]).OriginalRect := R;
      MagneticWindow(h, False);
    end;
  end;
  SaveSidebarStatus;
  pbTabs.Invalidate;

  // After picking a window, collapse the settings panel back to the strip.
  ApplyExpanded(False);
  RepositionForEdge;
end;

function TSidebarHostForm.TabCount: Integer;
begin
  Result := FTabs.Count;
end;

function TSidebarHostForm.TabAtPoint(X, Y: Integer): Integer;
var
  i, topY, botY, leftX, rightX: Integer;
begin
  // Index 0 is the settings (gear) tab. Window tabs start at 1.
  Result := -1;
  for i := 0 to TabCount do // 0 .. TabCount  (gear + N windows)
  begin
    if (FEdge = seLeft) or (FEdge = seRight) then
    begin
      topY := i * TAB_HEIGHT;
      botY := topY + TAB_HEIGHT;
      if (Y >= topY) and (Y < botY) and (X >= 0) and (X < pbTabs.ClientWidth) then
      begin
        Result := i;
        Exit;
      end;
    end
    else // seTop / seBottom: tabs run horizontally
    begin
      leftX := i * TAB_HEIGHT;
      rightX := leftX + TAB_HEIGHT;
      if (X >= leftX) and (X < rightX) and (Y >= 0) and (Y < pbTabs.ClientHeight) then
      begin
        Result := i;
        Exit;
      end;
    end;
  end;
end;

procedure TSidebarHostForm.pbTabsPaint(Sender: TObject);
var
  i: Integer;
  r: TRect;
  t: TDockTab;
  isActive, isHover: Boolean;
  bg, fg: TColor;
  glyph: string;
  gx, gy: Integer;
  size: TSize;
begin
  with pbTabs.Canvas do
  begin
    Brush.Color := clBlack;
    FillRect(pbTabs.ClientRect);

    // --- Settings tab (index 0) ---
    if (FEdge = seLeft) or (FEdge = seRight) then
      r := Rect(0, 0, pbTabs.ClientWidth, TAB_HEIGHT)
    else
      r := Rect(0, 0, TAB_HEIGHT, pbTabs.ClientHeight);

    isActive := (FActiveTabIndex = 0);
    isHover := (FHoverTabIndex = 0);
    if isActive then begin bg := clAqua;  fg := clBlack; end
    else if isHover then begin bg := clGray; fg := clWhite; end
    else begin bg := $00202020; fg := clSilver; end;
    Brush.Color := bg;
    Pen.Color := clGray;
    Rectangle(r);
    Font.Name := 'Segoe UI Symbol';
    Font.Size := 14;
    Font.Color := fg;
    glyph := #$2699; // gear
    size := TextExtent(glyph);
    gx := r.Left + (r.Width - size.cx) div 2;
    gy := r.Top + (r.Height - size.cy) div 2;
    TextOut(gx, gy, glyph);

    // --- Window tabs (index 1 .. TabCount) ---
    for i := 1 to TabCount do
    begin
      t := TDockTab(FTabs[i - 1]);
      if (FEdge = seLeft) or (FEdge = seRight) then
        r := Rect(0, i * TAB_HEIGHT, pbTabs.ClientWidth, (i + 1) * TAB_HEIGHT)
      else
        r := Rect(i * TAB_HEIGHT, 0, (i + 1) * TAB_HEIGHT, pbTabs.ClientHeight);

      isActive := (FActiveTabIndex = i);
      isHover := (FHoverTabIndex = i);
      if isActive then begin bg := clAqua;  fg := clBlack; end
      else if isHover then begin bg := clGray; fg := clWhite; end
      else begin bg := $00202020; fg := clSilver; end;

      Brush.Color := bg;
      Pen.Color := clGray;
      Rectangle(r);

      // Coloured side indicator when SlidIn (visible next to the strip).
      if t.SlidIn then
      begin
        Brush.Color := clLime;
        Pen.Color := clLime;
        if FEdge = seLeft then
          FillRect(Rect(r.Right - 4, r.Top, r.Right, r.Bottom))
        else if FEdge = seRight then
          FillRect(Rect(r.Left, r.Top, r.Left + 4, r.Bottom))
        else if FEdge = seTop then
          FillRect(Rect(r.Left, r.Bottom - 4, r.Right, r.Bottom))
        else
          FillRect(Rect(r.Left, r.Top, r.Right, r.Top + 4));
      end;

      // First capital letter, centered.
      Font.Name := 'Segoe UI';
      Font.Size := 14;
      Font.Style := [fsBold];
      Font.Color := fg;
      glyph := FirstCapitalOf(t.Caption);
      size := TextExtent(glyph);
      gx := r.Left + (r.Width - size.cx) div 2;
      gy := r.Top + (r.Height - size.cy) div 2;
      TextOut(gx, gy, glyph);
      Font.Style := [];
    end;
  end;
end;

procedure TSidebarHostForm.pbTabsMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  idx: Integer;
  t: TDockTab;
begin
  if Button <> mbLeft then Exit;
  idx := TabAtPoint(X, Y);
  if idx < 0 then Exit;

  if idx = 0 then
  begin
    // Settings tab: toggle expand/collapse.
    FActiveTabIndex := 0;
    ApplyExpanded(not FExpanded);
    RepositionForEdge;
    pbTabs.Invalidate;
    Exit;
  end;

  // Window tab: toggle slide in / out.
  t := TDockTab(FTabs[idx - 1]);
  if not IsWindow(t.Handle) then Exit;
  FActiveTabIndex := idx;
  if t.SlidIn then
  begin
    MagneticWindow(t.Handle, False);
    t.SlidIn := False;
  end
  else
  begin
    MagneticWindow(t.Handle, True);
    t.SlidIn := True;
  end;
  pbTabs.Invalidate;
end;

procedure TSidebarHostForm.pbTabsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  idx: Integer;
  t: TDockTab;
begin
  idx := TabAtPoint(X, Y);
  if idx <> FHoverTabIndex then
  begin
    FHoverTabIndex := idx;
    pbTabs.Invalidate;
  end;

  // Tooltip: full window title when hovering a window tab.
  if (idx > 0) and (idx <= TabCount) then
  begin
    t := TDockTab(FTabs[idx - 1]);
    pbTabs.Hint := t.Caption;
    Application.ActivateHint(Mouse.CursorPos);
  end
  else if idx = 0 then
  begin
    pbTabs.Hint := 'Settings / window list';
    Application.ActivateHint(Mouse.CursorPos);
  end
  else
    pbTabs.Hint := '';
end;

procedure TSidebarHostForm.pbTabsMouseLeave(Sender: TObject);
begin
  if FHoverTabIndex <> -1 then
  begin
    FHoverTabIndex := -1;
    pbTabs.Invalidate;
  end;
end;

// --- Tab list management ----------------------------------------------------

procedure TSidebarHostForm.AddTab(AHandle: HWND; const ACaption: string);
var
  t: TDockTab;
begin
  if FindTabIndexByHandle(AHandle) >= 0 then Exit;
  t := TDockTab.Create(AHandle, ACaption);
  FTabs.Add(t);
  FActiveTabIndex := TabCount;
  pbTabs.Invalidate;
end;

procedure TSidebarHostForm.RemoveTab(AHandle: HWND);
var
  idx: Integer;
begin
  idx := FindTabIndexByHandle(AHandle);
  if idx < 0 then Exit;
  TDockTab(FTabs[idx]).Free;
  FTabs.Delete(idx);
  if FActiveTabIndex > TabCount then
    FActiveTabIndex := TabCount;
  pbTabs.Invalidate;
end;

function TSidebarHostForm.FindTabIndexByHandle(AHandle: HWND): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FTabs.Count - 1 do
    if TDockTab(FTabs[i]).Handle = AHandle then
    begin
      Result := i;
      Exit;
    end;
end;

// --- MagneticWindow / docking by HWND ----------------------------------------

procedure TSidebarHostForm.MagneticWindow(TargetHWND: HWND; SlideIN: Boolean);
var
  OtherRect: TRect;
  NewTop, NewLeft, OtherWidth, OtherHeight: Integer;
  wa: TRect;
  TargetLeft, TargetTop: Integer;
begin
  if (TargetHWND = 0) or not IsWindow(TargetHWND) then Exit;
  if Application.Terminated or (csDestroying in ComponentState) then Exit;
  // Bug 6: a maximized browser/Explorer ignores MoveWindow (its size is pinned
  // to the work area by the window manager). Restore it to a normal size first
  // so the slide animation can actually move it.
  if IsZoomed(TargetHWND) then
    ShowWindow(TargetHWND, SW_RESTORE);
  wa := CurrentWorkArea;
  GetWindowRect(TargetHWND, OtherRect);
  OtherWidth := OtherRect.Right - OtherRect.Left;
  OtherHeight := OtherRect.Bottom - OtherRect.Top;
  if (OtherWidth <= 0) or (OtherHeight <= 0) then Exit;

  case FEdge of
    seRight:
      begin
        NewTop := Top;
        if SlideIN then
        begin
          NewLeft := wa.Right;
          TargetLeft := wa.Right - OtherWidth;
          MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          repeat
            Dec(NewLeft, 8);
            if NewLeft < TargetLeft then NewLeft := TargetLeft;
            Application.ProcessMessages; Update;
            if Application.Terminated or (csDestroying in ComponentState) then Break;
            MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          until NewLeft <= TargetLeft;
          MoveWindow(TargetHWND, TargetLeft, NewTop, OtherWidth, OtherHeight, True);
        end
        else
        begin
          NewLeft := OtherRect.Left;
          TargetLeft := wa.Right;
          repeat
            Inc(NewLeft, 8);
            if NewLeft > TargetLeft then NewLeft := TargetLeft;
            Application.ProcessMessages; Update;
            if Application.Terminated or (csDestroying in ComponentState) then Break;
            MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          until NewLeft >= TargetLeft;
          MoveWindow(TargetHWND, TargetLeft, NewTop, OtherWidth, OtherHeight, True);
        end;
      end;
    seLeft:
      begin
        NewTop := Top;
        if SlideIN then
        begin
          NewLeft := wa.Left - OtherWidth;
          TargetLeft := wa.Left;
          MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          repeat
            Inc(NewLeft, 8);
            if NewLeft > TargetLeft then NewLeft := TargetLeft;
            Application.ProcessMessages; Update;
            if Application.Terminated or (csDestroying in ComponentState) then Break;
            MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          until NewLeft >= TargetLeft;
          MoveWindow(TargetHWND, TargetLeft, NewTop, OtherWidth, OtherHeight, True);
        end
        else
        begin
          NewLeft := OtherRect.Left;
          TargetLeft := wa.Left - OtherWidth;
          repeat
            Dec(NewLeft, 8);
            if NewLeft < TargetLeft then NewLeft := TargetLeft;
            Application.ProcessMessages; Update;
            if Application.Terminated or (csDestroying in ComponentState) then Break;
            MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          until NewLeft <= TargetLeft;
          MoveWindow(TargetHWND, TargetLeft, NewTop, OtherWidth, OtherHeight, True);
        end;
      end;
    seTop:
      begin
        NewLeft := Left;
        if SlideIN then
        begin
          NewTop := wa.Top - OtherHeight;
          TargetTop := wa.Top;
          MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          repeat
            Inc(NewTop, 8);
            if NewTop > TargetTop then NewTop := TargetTop;
            Application.ProcessMessages; Update;
            if Application.Terminated or (csDestroying in ComponentState) then Break;
            MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          until NewTop >= TargetTop;
          MoveWindow(TargetHWND, NewLeft, TargetTop, OtherWidth, OtherHeight, True);
        end
        else
        begin
          NewTop := OtherRect.Top;
          TargetTop := wa.Top - OtherHeight;
          repeat
            Dec(NewTop, 8);
            if NewTop < TargetTop then NewTop := TargetTop;
            Application.ProcessMessages; Update;
            if Application.Terminated or (csDestroying in ComponentState) then Break;
            MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          until NewTop <= TargetTop;
          MoveWindow(TargetHWND, NewLeft, TargetTop, OtherWidth, OtherHeight, True);
        end;
      end;
    seBottom:
      begin
        NewLeft := Left;
        if SlideIN then
        begin
          NewTop := wa.Bottom;
          TargetTop := wa.Bottom - OtherHeight;
          MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          repeat
            Dec(NewTop, 8);
            if NewTop < TargetTop then NewTop := TargetTop;
            Application.ProcessMessages; Update;
            if Application.Terminated or (csDestroying in ComponentState) then Break;
            MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          until NewTop <= TargetTop;
          MoveWindow(TargetHWND, NewLeft, TargetTop, OtherWidth, OtherHeight, True);
        end
        else
        begin
          NewTop := OtherRect.Top;
          TargetTop := wa.Bottom;
          repeat
            Inc(NewTop, 8);
            if NewTop > TargetTop then NewTop := TargetTop;
            Application.ProcessMessages; Update;
            if Application.Terminated or (csDestroying in ComponentState) then Break;
            MoveWindow(TargetHWND, NewLeft, NewTop, OtherWidth, OtherHeight, True);
          until NewTop >= TargetTop;
          MoveWindow(TargetHWND, NewLeft, TargetTop, OtherWidth, OtherHeight, True);
        end;
      end;
  end;
end;

// --- Window checks & restore -----------------------------------------------

procedure TSidebarHostForm.CheckSidebarWindows;
var
  i: Integer;
  h: HWND;
  changed: Boolean;
  idx: Integer;
begin
  changed := False;
  for i := FTabs.Count - 1 downto 0 do
  begin
    h := TDockTab(FTabs[i]).Handle;
    if not IsWindow(h) then
    begin
      TDockTab(FTabs[i]).Free;
      FTabs.Delete(i);
      changed := True;
    end;
  end;
  for i := 0 to grdWindows.RowCount - 1 do
  begin
    h := HWND(grdWindows.Objects[0, i]);
    idx := FindTabIndexByHandle(h);
    if idx >= 0 then
    begin
      if grdWindows.Cells[0, i] <> 'x' then
      begin
        grdWindows.Cells[0, i] := 'x';
        changed := True;
      end;
    end
    else
    begin
      if grdWindows.Cells[0, i] = 'x' then
      begin
        grdWindows.Cells[0, i] := '';
        changed := True;
      end;
    end;
  end;
  if changed then
  begin
    SaveSidebarStatus;
    pbTabs.Invalidate;
  end;
end;

procedure TSidebarHostForm.SendAllBackToDesktop;
var
  i: Integer;
  Wnd: HWND;
  R: TRect;
  t: TDockTab;
  wa: TRect;
  Wd, Ht: Integer;
  savedHandles: array of HWND;
  k, n: Integer;
begin
  // Restore every docked window to its original (or at least visible) position
  // and clear the whole tab strip. "Restore all windows" is meant to end ALL
  // tabs and put the windows back, not just sit there doing nothing.
  if FTabs = nil then Exit;

  // Snapshot the handles first: the loop frees tabs and mutates FTabs, so we
  // cannot iterate FTabs while modifying it.
  n := FTabs.Count;
  SetLength(savedHandles, n);
  for i := 0 to n - 1 do
    savedHandles[i] := TDockTab(FTabs[i]).Handle;

  wa := CurrentWorkArea;
  for i := 0 to n - 1 do
  begin
    Wnd := savedHandles[i];
    if (Wnd = 0) or not IsWindow(Wnd) then Continue;
    try
      GetWindowRect(Wnd, R);
      Wd := R.Right - R.Left;
      Ht := R.Bottom - R.Top;
      if (Wd <= 0) or (Ht <= 0) then Continue;

      // Find the tab for this handle to read its saved original rect. The tab
      // may already be freed by an earlier iteration if duplicates existed,
      // so guard with a helper lookup against the still-living list.
      t := nil;
      k := FindTabIndexByHandle(Wnd);
      if k >= 0 then t := TDockTab(FTabs[k]);

      if (t <> nil) and ((t.OriginalRect.Right - t.OriginalRect.Left) > 0) then
        MoveWindow(Wnd, t.OriginalRect.Left, t.OriginalRect.Top,
                   t.OriginalRect.Right - t.OriginalRect.Left,
                   t.OriginalRect.Bottom - t.OriginalRect.Top, True)
      else
      begin
        case FEdge of
          seRight:
            if R.Right > wa.Right + 2 then
              MoveWindow(Wnd, wa.Right - Wd - STRIP_THICKNESS - 4, R.Top, Wd, Ht, True);
          seLeft:
            if R.Right < wa.Left - 2 then
              MoveWindow(Wnd, wa.Left + STRIP_THICKNESS + 4, R.Top, Wd, Ht, True);
          seTop:
            if R.Bottom < wa.Top - 2 then
              MoveWindow(Wnd, R.Left, wa.Top + STRIP_THICKNESS + 4, Wd, Ht, True);
          seBottom:
            if R.Top > wa.Bottom + 2 then
              MoveWindow(Wnd, R.Left, wa.Bottom - Ht - STRIP_THICKNESS - 4, Wd, Ht, True);
        end;
      end;
      ShowWindow(Wnd, SW_SHOWNOACTIVATE);
    except
      // Never let one bad window abort the whole restore.
    end;
  end;

  // Now drop every tab and clear the grid checks. Iterate backwards so
  // FTabs.Delete stays valid.
  for i := FTabs.Count - 1 downto 0 do
  begin
    TDockTab(FTabs[i]).Free;
    FTabs.Delete(i);
  end;
  FActiveTabIndex := -1;

  // Uncheck every row in the window grid.
  for i := 0 to grdWindows.RowCount - 1 do
    grdWindows.Cells[0, i] := '';

  SaveSidebarStatus;
  pbTabs.Invalidate;
end;

procedure TSidebarHostForm.TimerWindowCheckTimer(Sender: TObject);
begin
  GetAllXWindows;
  CheckSidebarWindows;
end;

// --- Status file -----------------------------------------------------------

procedure TSidebarHostForm.SaveSidebarStatus;
var
  sl: TStringList;
  i: Integer;
  t: TDockTab;
begin
  sl := TStringList.Create;
  try
    for i := 0 to FTabs.Count - 1 do
    begin
      t := TDockTab(FTabs[i]);
      sl.Add(Format('%s|%d|sidebar', [t.Caption, Integer(t.Handle)]));
    end;
    sl.SaveToFile(FStatusFile, TEncoding.UTF8);
  finally
    sl.Free;
  end;
end;

procedure TSidebarHostForm.LoadSidebarStatus;
var
  sl: TStringList;
  i: Integer;
  parts: TArray<string>;
  h: HWND;
begin
  if not FileExists(FStatusFile) then Exit;
  sl := TStringList.Create;
  try
    sl.LoadFromFile(FStatusFile, TEncoding.UTF8);
    for i := 0 to sl.Count - 1 do
    begin
      parts := sl[i].Split(['|']);
      if Length(parts) = 3 then
      begin
        h := HWND(StrToIntDef(parts[1], 0));
        if (h <> 0) and IsWindow(h) then
          AddTab(h, parts[0]);
      end;
    end;
  finally
    sl.Free;
  end;
end;

// --- Buttons ---------------------------------------------------------------

procedure TSidebarHostForm.btnRefreshClick(Sender: TObject);
begin
  GetAllXWindows;
end;

procedure TSidebarHostForm.btnCloseClick(Sender: TObject);
begin
  // Bug 4: Close alone only hides this host form; the launcher form keeps the
  // process alive in the background. Pull every docked window back to the
  // desktop first, then free the host form and quit the whole application.
  try SendAllBackToDesktop; except end;
  TrayIcon1.Visible := False;
  TimerWindowCheck.Enabled := False;
  // Deactivate via the component so FHost is freed in the right order (and not
  // freed again by Application during shutdown, since CreateFor used nil owner).
  if FOwnerComp <> nil then
    FOwnerComp.Active := False;
  Application.Terminate;
end;

// --- Tray menu -------------------------------------------------------------

procedure TSidebarHostForm.TrayPopupMenuPopup(Sender: TObject);
var
  i: Integer;
  mi, sub: TMenuItem;
begin
  TrayPopupMenu.Items.Clear;

  sub := TMenuItem.Create(TrayPopupMenu);
  sub.Caption := 'Position tabs';
  TrayPopupMenu.Items.Add(sub);
  for i := 0 to 3 do
  begin
    mi := TMenuItem.Create(sub);
    case i of
      0: begin mi.Caption := 'Top';    mi.Hint := 'seTop';    end;
      1: begin mi.Caption := 'Bottom'; mi.Hint := 'seBottom'; end;
      2: begin mi.Caption := 'Left';  mi.Hint := 'seLeft';    end;
      3: begin mi.Caption := 'Right';  mi.Hint := 'seRight';   end;
    end;
    mi.OnClick := TrayMenuTabPosClick;
    // Bug 5: the menu order (0=Oben, 1=Unten, 2=Links, 3=Rechts) does not match
    // the TSidebarEdge ordinal (seLeft=0, seRight=1, seTop=2, seBottom=3), so
    // "Ord(FEdge) = i" ticked the wrong row. Compare the Hint string directly.
    mi.Checked := False;
    if (mi.Hint = 'seTop')    and (FEdge = seTop)    then mi.Checked := True
    else if (mi.Hint = 'seBottom') and (FEdge = seBottom) then mi.Checked := True
    else if (mi.Hint = 'seLeft')  and (FEdge = seLeft)  then mi.Checked := True
    else if (mi.Hint = 'seRight') and (FEdge = seRight) then mi.Checked := True;
    sub.Add(mi);
  end;

  sub := TMenuItem.Create(TrayPopupMenu);
  sub.Caption := 'Send to screen';
  TrayPopupMenu.Items.Add(sub);
  if Screen.MonitorCount > 0 then
    for i := 0 to Screen.MonitorCount - 1 do
    begin
      mi := TMenuItem.Create(sub);
      mi.Caption := Format('Monitor %d (%dx%d)', [i + 1, Screen.Monitors[i].Width, Screen.Monitors[i].Height]);
      mi.Hint := IntToStr(i);
      mi.OnClick := TrayMenuSendToScreenClick;
      sub.Add(mi);
    end;

  TrayPopupMenu.Items.Add(NewLine);

  mi := TMenuItem.Create(TrayPopupMenu);
  mi.Caption := 'Restore all windows';
  mi.OnClick := TrayMenuRestoreAllClick;
  TrayPopupMenu.Items.Add(mi);

  mi := TMenuItem.Create(TrayPopupMenu);
  mi.Caption := 'Exit';
  mi.OnClick := TrayMenuExitClick;
  TrayPopupMenu.Items.Add(mi);
end;

procedure TSidebarHostForm.TrayMenuTabPosClick(Sender: TObject);
var
  hintStr: string;
  newEdge: TSidebarEdge;
begin
  if Sender is TMenuItem then
  begin
    hintStr := (Sender as TMenuItem).Hint;
    if hintStr = 'seTop' then       newEdge := seTop
    else if hintStr = 'seBottom' then newEdge := seBottom
    else if hintStr = 'seLeft' then  newEdge := seLeft
    else if hintStr = 'seRight' then newEdge := seRight
    else Exit;
    SetTabPositionByEdgeMenu(newEdge);
  end;
end;

procedure TSidebarHostForm.SetTabPositionByEdgeMenu(AEdge: TSidebarEdge);
begin
  ApplyEdge(AEdge);
  RepositionForEdge;
  if Assigned(FOwnerComp) then
  begin
    FOwnerComp.FEdge := AEdge;
    if Assigned(FOwnerComp.FOnEdgeChange) then
      FOwnerComp.FOnEdgeChange(FOwnerComp, AEdge);
  end;
end;

procedure TSidebarHostForm.TrayMenuSendToScreenClick(Sender: TObject);
var
  idx: Integer;
  wa: TRect;
begin
  if Sender is TMenuItem then
  begin
    idx := StrToIntDef((Sender as TMenuItem).Hint, 0);
    if (idx >= 0) and (idx < Screen.MonitorCount) then
    begin
      wa := Screen.Monitors[idx].WorkAreaRect;
      Left := wa.Left;
      Top := wa.Top;
      RepositionForEdge;
    end;
  end;
end;

procedure TSidebarHostForm.TrayMenuRestoreAllClick(Sender: TObject);
begin
  SendAllBackToDesktop;
end;

procedure TSidebarHostForm.TrayMenuExitClick(Sender: TObject);
begin
  // Bug 4: same as btnCloseClick - restore windows, free host form, quit app.
  try SendAllBackToDesktop; except end;
  TrayIcon1.Visible := False;
  TimerWindowCheck.Enabled := False;
  if FOwnerComp <> nil then
    FOwnerComp.Active := False;
  Application.Terminate;
end;

{ Register }

procedure Register;
begin
  RegisterComponents('LaMita', [TSidebarAnyApp]);
end;

end.

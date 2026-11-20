unit Unit2;

// =============================================================================
//  SidebarAnyApp - Demo / launcher form
// -----------------------------------------------------------------------------
//  Drops a single TSidebarAnyApp on the form. Setting AutoStart := True (default)
//  makes the sidebar appear on the right edge the moment the app finishes
//  loading. This form itself stays hidden - it only owns the component.
//
//  Right-click the tray icon, the tab strip, the settings panel or the grid to
//  switch edges ("Position tabs") or move the sidebar to another monitor
//  ("Send to screen"). Click the gear tab to expand/collapse the settings
//  panel. Tick a window to dock it; click its tab to slide it in/out.
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.Buttons, SidebarAnyApp;

type
  TForm2 = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FSidebar: TSidebarAnyApp;
  public
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

procedure TForm2.FormCreate(Sender: TObject);
begin
  // Keep the launcher form out of the way - the sidebar owns its own window.
  Left := -32000;
  Top := -32000;
  Width := 0;
  Height := 0;
  Show;

  FSidebar := TSidebarAnyApp.Create(Self);
  FSidebar.Edge := seRight;
  FSidebar.AutoStart := True;
  FSidebar.Active := True; // shows the sidebar immediately
  Application.ShowMainForm := False;
end;

end.

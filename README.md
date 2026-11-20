# Sidebar-Any-App
       
Dock any running Windows application into a collapsible, slide-out screen-edge sidebar — built as a standalone, reusable **pure Delphi VCL** component (`SidebarAnyApp.pas`) with zero third-party dependencies.      
    
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Sidebar-Any-App)    
      
<img width="1235" height="899" alt="Unbenannt" src="https://github.com/user-attachments/assets/7dd23893-5faf-425a-8ad4-106ce5461f14" />
      
### 💡 Origin Story
The core `MagneticWindow` engine originally came from my own media player: when running two instances side-by-side, sliding out the playlist sidebar needed to smoothly push the other instance's video window out of the way so the video stays visible. From there, the idea grew into a standalone utility — and a drop-in VCL component (`TSidebarAnyApp`) — that can dock and slide **any** Windows application on any screen edge.     
      
### ✨ Features      
* **Collapsible Edge Tab Bar:** Folds down into a slim 28px screen-edge tab strip with single-letter tabs, active slide-in indicators, and full-title hover tooltips, expanding only when you click the gear (`⚙`) tab.     
* **Dock Any Window:** Pick any running application from the window list and attach it to the sidebar.      
* **All 4 Screen Edges & Multi-Monitor:** Dock on the left, right, top, or bottom edge across multiple monitors via right-click context menu or system tray.      
* **Smooth Slide-In / Slide-Out:** Click a sidebar tab to smoothly slide the attached app into view or tuck it back off-screen.      
* **Crash & Offscreen Safety:** Automatically restores docked windows back onto the visible desktop on exit or via the right-click *"Restore all windows"* option so no window gets left stranded off-screen.      
* **Standalone Component & 100% Standard VCL:** Everything lives cleanly inside `SidebarAnyApp.pas` using only built-in Delphi VCL controls and WinAPI (`EnumWindows`, `MoveWindow`).
         
Compiled .exe and full Delphi source project included — nothing needed to install        
      
### ⚠️ Compatibility Notes & Caveats      
Since `Sidebar-Any-App` moves external windows from the outside via WinAPI, different applications can react differently:      
* **Apps that manage their own window position:** Some custom-skinned apps, media players, games, or multi-window tools actively enforce or reset their own screen coordinates and may fight against being slid off-screen.      
* **Maximized Windows:** Maximized windows are automatically restored (`SW_RESTORE`) before sliding so Windows allows moving them.      
* **Elevated (Administrator) Windows:** Due to Windows UIPI security rules, `Sidebar-Any-App` cannot move windows running as Administrator unless `Sidebar-Any-App` itself is also started as Administrator.      
* **Experimental / PoC status:** Built as a lightweight proof-of-concept, laying around since 2023 :D — if an app behaves unexpectedly, use **"Restore all windows"** from the right-click or tray menu to bring everything back immediately.      

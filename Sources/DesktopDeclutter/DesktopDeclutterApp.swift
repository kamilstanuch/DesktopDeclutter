//  DesktopDeclutterApp.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  App entry point for DesktopDeclutter. Sets up the main window and settings scenes, manages the menu bar extra for quick access, and uses an app delegate to position the window and handle window activation.
//
//  Unique characteristics
//  ----------------------
//  - Uses @NSApplicationDelegateAdaptor to bridge AppKit lifecycle for window positioning.
//  - Shares a single @StateObject DeclutterViewModel across ContentView and SettingsView.
//  - Uses hidden title bar window style and fixed default sizing.
//  - Adds MenuBarExtra with keyboard shortcuts and window reveal behavior.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  SwiftUI: https://developer.apple.com/documentation/swiftui
//  App protocol: https://developer.apple.com/documentation/swiftui/app
//  WindowGroup: https://developer.apple.com/documentation/swiftui/windowgroup
//  Settings scene: https://developer.apple.com/documentation/swiftui/app/settings
//  MenuBarExtra: https://developer.apple.com/documentation/swiftui/menubarextra
//  CommandGroup: https://developer.apple.com/documentation/swiftui/commandgroup
//  @StateObject: https://developer.apple.com/documentation/swiftui/stateobject
//  Binding.constant: https://developer.apple.com/documentation/swiftui/binding/constant(_:)
//  View.frame: https://developer.apple.com/documentation/swiftui/view/frame(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:alignment:)
//  Scene.windowStyle: https://developer.apple.com/documentation/swiftui/scene/windowstyle(_:)
//  Scene.defaultSize: https://developer.apple.com/documentation/swiftui/scene/defaultsize(width:height:)
//  Button: https://developer.apple.com/documentation/swiftui/button
//  Divider: https://developer.apple.com/documentation/swiftui/divider
//  keyboardShortcut: https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:)
//  SF Symbols HIG: https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//  Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//  AppKit: https://developer.apple.com/documentation/appkit
//  NSApplication: https://developer.apple.com/documentation/appkit/nsapplication
//  NSApplicationDelegate: https://developer.apple.com/documentation/appkit/nsapplicationdelegate
//  NSWindow: https://developer.apple.com/documentation/appkit/nswindow
//  NSScreen: https://developer.apple.com/documentation/appkit/nsscreen
//  DispatchQueue: https://developer.apple.com/documentation/dispatch/dispatchqueue
//
//  NOTE: References internal types: AppDelegate, DeclutterViewModel, ContentView, SettingsView

import SwiftUI // [Isolated] Import SwiftUI for declarative UI | [In-file] Required for SwiftUI app structure
import AppKit // [Isolated] Import AppKit for window management | [In-file] Needed for NSApplicationDelegate and window positioning

@main
struct DesktopDeclutterApp: App { // [Isolated] Entry point for the app | [In-file] Implements SwiftUI App protocol
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // [Isolated] Bridge to AppKit lifecycle | [In-file] Allows window positioning and app delegate methods
    
    @StateObject private var viewModel = DeclutterViewModel() // [Isolated] Shared app view model | [In-file] Used by ContentView and SettingsView
    
    var body: some Scene { // [Isolated] Scene builder | [In-file] Defines app windows and menu bar extra
        WindowGroup { // [Isolated] Main window group | [In-file] Primary window for app content
            ContentView(viewModel: viewModel) // [Isolated] Root content view | [In-file] Passes shared view model
                .frame(minWidth: 420, minHeight: 680) // [Isolated] Set minimum window size | [In-file] Matches default window sizing
        }
        .windowStyle(.hiddenTitleBar) // [Isolated] Hide window title bar | [In-file] Custom window appearance
        .defaultSize(width: 420, height: 680) // [Isolated] Set default window size | [In-file] Ensures consistent initial window size
        .commands { // [Isolated] Customize app commands | [In-file] Removes default new item command
            CommandGroup(replacing: .newItem) {} // [Isolated] Empty new item command | [In-file] Prevents accidental new windows
        }
        
        Settings { // [Isolated] Settings scene | [In-file] Presents settings window
            SettingsView(isPresented: Binding.constant(true), viewModel: viewModel) // [Isolated] Settings content | [In-file] Shares app view model
        }
        
        MenuBarExtra("Declutter", systemImage: "square.stack.3d.up.fill") { // [Isolated] Menu bar icon and menu | [In-file] Quick access to app actions
            Button("Show Window") { // [Isolated] Reveal main window action | [In-file] Brings all app windows to front
                for window in NSApplication.shared.windows { // [Isolated] Iterate app windows | [In-file] Show each window
                    window.makeKeyAndOrderFront(nil) // [Isolated] Bring window to front | [In-file] Ensures visibility
                }
                NSApp.activate(ignoringOtherApps: true) // [Isolated] Activate app | [In-file] Focus app after showing window
            }
            .keyboardShortcut("w", modifiers: .command) // [Isolated] Keyboard shortcut for show window | [In-file] Cmd+W triggers window reveal
            
            Divider() // [Isolated] Menu divider | [In-file] Separates menu items
            
            Button("Quit") { // [Isolated] Quit app action | [In-file] Terminates the application
                NSApplication.shared.terminate(nil) // [Isolated] Terminate app | [In-file] Exits process
            }
            .keyboardShortcut("q", modifiers: .command) // [Isolated] Keyboard shortcut for quit | [In-file] Cmd+Q triggers quit
        }
        .menuBarExtraStyle(.menu) // [Isolated] Menu bar style | [In-file] Uses menu style for menu bar extra
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate { // [Isolated] AppKit delegate for window management | [In-file] Handles window positioning and reopen behavior
    func applicationDidFinishLaunching(_ notification: Notification) { // [Isolated] App launch hook | [In-file] Positions window on main screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // [Isolated] Delay to ensure window exists | [In-file] Schedules window positioning after launch
            NSApp.setActivationPolicy(.regular) // [Isolated] Set app activation policy | [In-file] Ensures app appears in Dock
            NSApp.activate(ignoringOtherApps: true) // [Isolated] Activate app | [In-file] Focuses app window
            
            if let window = NSApplication.shared.windows.first { // [Isolated] Get first app window | [In-file] Target window for positioning
                let screen = NSScreen.main ?? NSScreen.screens.first // [Isolated] Get main screen | [In-file] Fallback to any screen if needed
                if let screen = screen { // [Isolated] Ensure screen exists | [In-file] Use for window frame calculation
                    let screenFrame = screen.visibleFrame // [Isolated] Get visible screen frame | [In-file] Excludes menu bar/dock areas
                    let windowWidth: CGFloat = 420 // [Isolated] Desired window width | [In-file] Matches default size
                    let windowHeight: CGFloat = 680 // [Isolated] Desired window height | [In-file] Matches default size
                    let x = screenFrame.midX - windowWidth / 2 // [Isolated] Calculate centered X | [In-file] Center window horizontally
                    let y = screenFrame.midY - windowHeight / 2 // [Isolated] Calculate centered Y | [In-file] Center window vertically
                    window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true) // [Isolated] Set window frame | [In-file] Center window on screen
                }
                window.makeKeyAndOrderFront(nil) // [Isolated] Bring window to front | [In-file] Ensure window is visible
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary] // [Isolated] Set window behavior | [In-file] Allow window in all spaces and full screen
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { // [Isolated] Handle dock/taskbar icon click | [In-file] Reopen windows if none visible
        if !flag { // [Isolated] No visible windows | [In-file] Need to show windows
            for window in sender.windows { // [Isolated] Iterate app windows | [In-file] Bring each window to front
                window.makeKeyAndOrderFront(nil) // [Isolated] Show window | [In-file] Make window visible
            }
        }
        return true // [Isolated] Indicate handled | [In-file] Prevents default reopen behavior
    }
}

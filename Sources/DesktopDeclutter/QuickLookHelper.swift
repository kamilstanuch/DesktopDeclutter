//  QuickLookHelper.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  Centralized helper for presenting Quick Look previews using QLPreviewPanel,
//  acting as both data source and delegate, and providing a Finder fallback
//  when no window/panel is available.
//
//  Unique characteristics
//  ----------------------
//  - Uses a singleton (shared) to ensure a single preview panel data source/delegate across the app.
//  - Stores an array of preview URLs + current index to drive multi-item preview.
//  - Ensures execution on the main thread for AppKit panel presentation.
//  - Detects when no key window exists and falls back to revealing the file(s) in Finder.
//  - Handles ESC key to close the preview panel.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  AppKit: https://developer.apple.com/documentation/appkit
//  - NSApplication (NSApp): https://developer.apple.com/documentation/appkit/nsapplication
//  - NSWindow: https://developer.apple.com/documentation/appkit/nswindow
//  - NSEvent: https://developer.apple.com/documentation/appkit/nsevent
//  - NSWorkspace: https://developer.apple.com/documentation/appkit/nsworkspace
//  - NSRect: https://developer.apple.com/documentation/foundation/nsrect
//  QuickLookUI: https://developer.apple.com/documentation/quicklookui
//  - QLPreviewPanel: https://developer.apple.com/documentation/quicklookui/qlpreviewpanel
//  - QLPreviewPanelDataSource: https://developer.apple.com/documentation/quicklookui/qlpreviewpaneldatasource
//  - QLPreviewPanelDelegate: https://developer.apple.com/documentation/quicklookui/qlpreviewpaneldelegate
//  - QLPreviewItem: https://developer.apple.com/documentation/quicklookui/qlpreviewitem
//  Dispatch:
//  - DispatchQueue.main.async: https://developer.apple.com/documentation/dispatch/dispatchqueue/2300028-async
//  Foundation:
//  - URL: https://developer.apple.com/documentation/foundation/url
//
//  NOTE: None (this file is self-contained aside from system frameworks).

import AppKit // [Isolated] Import AppKit framework for UI components and event handling. | [In-file] Required for NSApplication, NSWindow, NSEvent, NSWorkspace, NSRect.
import QuickLookUI // [Isolated] Import QuickLookUI for preview panel classes and protocols. | [In-file] Required for QLPreviewPanel and related protocols.

class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate { // [Isolated] Helper class implementing Quick Look preview panel data source and delegate protocols. | [In-file] Centralizes preview logic.
    static let shared = QuickLookHelper() // [Isolated] Singleton instance for shared access across the app. | [In-file] Ensures single data source/delegate.
    
    private var urls: [URL] = [] // [Isolated] Stored array of URLs to preview. | [In-file] Drives multi-item preview content.
    private var currentIndex: Int = 0 // [Isolated] Current item index within the urls array. | [In-file] Tracks which item is shown.
    
    func preview(urls: [URL], currentIndex: Int = 0) { // [Isolated] Starts previewing given URLs at specified index. | [In-file] Main entry point for showing previews.
        self.urls = urls // [Isolated] Store provided URLs internally. | [In-file] Updates data source content.
        self.currentIndex = currentIndex // [Isolated] Store current preview index. | [In-file] Sets initial preview item.
        
        guard !urls.isEmpty else { return } // [Isolated] Guard against empty URL list; no preview if empty. | [In-file] Prevents unnecessary work.
        
        DispatchQueue.main.async { // [Isolated] Ensure UI work happens on main thread. | [In-file] Required for AppKit interactions.
            // Check if we have a window (required for QLPreviewPanel)
            guard NSApp.keyWindow != nil || !NSApp.windows.isEmpty else { // [Isolated] Verify existence of key window or any window. | [In-file] QLPreviewPanel needs a window.
                // Fallback: open Finder if no window
                if urls.count == 1, let url = urls.first { // [Isolated] Single URL case. | [In-file] Reveal single file in Finder.
                    NSWorkspace.shared.activateFileViewerSelecting([url]) // [Isolated] Opens Finder selecting the single file. | [In-file] Finder fallback.
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting(urls) // [Isolated] Opens Finder selecting multiple files. | [In-file] Finder fallback for multiple.
                }
                return // [Isolated] Exit early since no panel can be shown. | [In-file] Prevent further execution.
            }
            
            // Get QLPreviewPanel
            guard let panel = QLPreviewPanel.shared() else { // [Isolated] Attempt to get shared preview panel instance. | [In-file] Required for preview display.
                // Fallback: open Finder if panel unavailable
                if urls.count == 1, let url = urls.first { // [Isolated] Single URL fallback. | [In-file] Reveal single file in Finder.
                    NSWorkspace.shared.activateFileViewerSelecting([url]) // [Isolated] Open Finder selecting single file. | [In-file] Finder fallback.
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting(urls) // [Isolated] Open Finder selecting multiple files. | [In-file] Finder fallback.
                }
                return // [Isolated] Exit early since panel unavailable. | [In-file] Prevent further execution.
            }
            
            // Set up data source and delegate
            panel.dataSource = self // [Isolated] Assign self as data source. | [In-file] Panel queries this for item info.
            panel.delegate = self // [Isolated] Assign self as delegate. | [In-file] Panel sends events here.
            panel.currentPreviewItemIndex = currentIndex // [Isolated] Set initial preview item index. | [In-file] Controls which item is shown.
            
            // Make sure the window can handle the preview panel
            // This is crucial for QLPreviewPanel to work
            if panel.isVisible { // [Isolated] If panel is already visible. | [In-file] Update existing panel.
                // If already visible, update and refresh
                panel.currentPreviewItemIndex = currentIndex // [Isolated] Update current index again to ensure sync. | [In-file] Refreshes preview item.
                panel.reloadData() // [Isolated] Reload panel data to reflect changes. | [In-file] Forces panel to refresh display.
            } else {
                // Show the panel
                panel.makeKeyAndOrderFront(nil) // [Isolated] Show and make panel key window. | [In-file] Presents the preview panel.
                panel.updateController() // [Isolated] Update the panel controller. | [In-file] Ensures UI is current.
            }
        }
    }
    
    func preview(url: URL) { // [Isolated] Convenience method to preview a single URL. | [In-file] Wraps array-based preview call.
        preview(urls: [url], currentIndex: 0) // [Isolated] Calls multi-URL preview with single item. | [In-file] Simplifies single preview usage.
    }
    
    // [Isolated] QLPreviewPanelDataSource conformance. | [In-file] Supplies the panel with item count and preview items backed by the stored URL list.
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { // [Isolated] Returns number of preview items. | [In-file] Required by QLPreviewPanelDataSource.
        return urls.count // [Isolated] Number of URLs stored. | [In-file] Drives total preview count.
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { // [Isolated] Returns preview item at given index. | [In-file] Supplies QLPreviewItem to the panel.
        guard index < urls.count else { return nil } // [Isolated] Bounds check to avoid invalid access. | [In-file] Safe access to stored URLs.
        return urls[index] as QLPreviewItem // [Isolated] Cast URL to QLPreviewItem protocol. | [In-file] Provides previewable item.
    }
    
    // [Isolated] QLPreviewPanelDelegate conformance. | [In-file] Handles panel events and provides positioning/transition hooks for smoother presentation.
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool { // [Isolated] Handles keyboard and other events for the panel. | [In-file] Allows custom event handling.
        // Handle keyboard events
        if event.type == .keyDown { // [Isolated] Only handle keyDown events. | [In-file] Filters event type.
            switch event.keyCode { // [Isolated] Check specific key codes. | [In-file] Respond to ESC key.
            case 53: // ESC key
                panel.close() // [Isolated] Close the preview panel on ESC. | [In-file] Allows user to dismiss preview.
                return true // [Isolated] Indicate event was handled. | [In-file] Prevent further processing.
            default:
                return false // [Isolated] Other keys not handled here. | [In-file] Pass event through.
            }
        }
        return false // [Isolated] Non-keyDown events not handled. | [In-file] Pass event through.
    }
    
    // This method is called to determine if the panel should handle events
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect { // [Isolated] Provides frame on screen for transition animations. | [In-file] Helps position preview panel.
        // Return a frame to help position the panel
        if let keyWindow = NSApp.keyWindow { // [Isolated] Use key window frame if available. | [In-file] Provides visual context for animation.
            return keyWindow.frame // [Isolated] Return key window frame. | [In-file] Used for positioning.
        }
        return .zero // [Isolated] Default zero rect if no window. | [In-file] Fallback positioning.
    }
    
    // This method is called to determine the transition image
    @objc func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect: UnsafeMutablePointer<NSRect>!) -> Any! { // [Isolated] Provides image for transition animation. | [In-file] Optional customization point.
        return nil // [Isolated] No custom transition image provided. | [In-file] Defaults to standard animation.
    }
}

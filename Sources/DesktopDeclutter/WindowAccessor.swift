//  WindowAccessor.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  A small SwiftUI/AppKit bridge that exposes the hosting `NSWindow` to SwiftUI by embedding an empty `NSView` and capturing its `window` reference asynchronously.
//
//  Unique characteristics
//  ----------------------
//  - Uses `NSViewRepresentable` to bridge AppKit into SwiftUI.
//  - Uses `@Binding` to pass the resolved `NSWindow?` back to the caller.
//  - Uses `DispatchQueue.main.async` to wait until the `NSView` is attached to a window before reading `view.window`.
//  - `updateNSView` is intentionally empty because the view is only used for window capture.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  - SwiftUI: https://developer.apple.com/documentation/swiftui
//  - NSViewRepresentable: https://developer.apple.com/documentation/swiftui/nsviewrepresentable
//  - makeNSView: https://developer.apple.com/documentation/swiftui/nsviewrepresentable/makensview(context:)
//  - updateNSView: https://developer.apple.com/documentation/swiftui/nsviewrepresentable/updatensview(_:context:)
//  - @Binding: https://developer.apple.com/documentation/swiftui/binding
//  - AppKit:
//    - NSView: https://developer.apple.com/documentation/appkit/nsview
//    - NSWindow: https://developer.apple.com/documentation/appkit/nswindow
//  - Dispatch:
//    - DispatchQueue.main.async: https://developer.apple.com/documentation/dispatch/dispatchqueue/2300028-async
//
//  NOTE: internal project types referenced:
//  - None.

import SwiftUI // [Isolated] Import SwiftUI framework for UI components | [In-file] import SwiftUI

struct WindowAccessor: NSViewRepresentable { // [Isolated] Define WindowAccessor struct conforming to NSViewRepresentable | [In-file] struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow? // [Isolated] Binding to hold and expose the NSWindow reference | [In-file] @Binding var window: NSWindow?
    
    func makeNSView(context: Context) -> NSView { // [Isolated] Create the NSView to embed in SwiftUI | [In-file] func makeNSView(context: Context) -> NSView {
        let view = NSView() // [Isolated] Create an empty NSView instance | [In-file] let view = NSView()
        DispatchQueue.main.async { // [Isolated] Schedule async capture of the NSWindow once view is attached | [In-file] DispatchQueue.main.async {
            self.window = view.window // [Isolated] Assign the hosting NSWindow to the binding | [In-file] self.window = view.window
        } // [Isolated] End of async dispatch block | [In-file] }
        return view // [Isolated] Return the created NSView | [In-file] return view
    } // [Isolated] End of makeNSView method | [In-file] }
    
    func updateNSView(_ nsView: NSView, context: Context) {} // [Isolated] Empty update method as view does not require updates | [In-file] func updateNSView(_ nsView: NSView, context: Context) {}
} // [Isolated] End of WindowAccessor struct | [In-file] }

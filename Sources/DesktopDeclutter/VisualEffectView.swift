//  VisualEffectView.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  A SwiftUI wrapper around `NSVisualEffectView` to provide macOS vibrancy/blur materials in SwiftUI layouts.
//
//  Unique characteristics
//  ----------------------
//  - Uses `NSViewRepresentable` to embed an AppKit view inside SwiftUI.
//  - Exposes `material` and `blendingMode` as immutable inputs to make the wrapper declarative.
//  - Keeps the view in `.active` state for consistent appearance.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  - SwiftUI: https://developer.apple.com/documentation/swiftui
//  - NSViewRepresentable: https://developer.apple.com/documentation/swiftui/nsviewrepresentable
//  - makeNSView/updateNSView requirements:
//    - https://developer.apple.com/documentation/swiftui/nsviewrepresentable/makensview(context:)
//    - https://developer.apple.com/documentation/swiftui/nsviewrepresentable/updatensview(_:context:)
//  - AppKit:
//    - NSVisualEffectView: https://developer.apple.com/documentation/appkit/nsvisualeffectview
//    - NSVisualEffectView.Material: https://developer.apple.com/documentation/appkit/nsvisualeffectview/material
//    - NSVisualEffectView.BlendingMode: https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode
//    - NSVisualEffectView.State: https://developer.apple.com/documentation/appkit/nsvisualeffectview/state
//
//  NOTE: Internal project types referenced
//  ---------------------------------------
//  - None.

import SwiftUI // [Isolated] Import SwiftUI framework | [In-file] Provides SwiftUI APIs

struct VisualEffectView: NSViewRepresentable { // [Isolated] SwiftUI wrapper for NSVisualEffectView | [In-file] Conforms to NSViewRepresentable to embed AppKit view
    let material: NSVisualEffectView.Material // [Isolated] Material for vibrancy/blur effect | [In-file] Immutable input property
    let blendingMode: NSVisualEffectView.BlendingMode // [Isolated] Blending mode for visual effect | [In-file] Immutable input property

    func makeNSView(context: Context) -> NSVisualEffectView { // [Isolated] Create the NSVisualEffectView instance | [In-file] Required by NSViewRepresentable
        let view = NSVisualEffectView() // [Isolated] Instantiate NSVisualEffectView | [In-file] Underlying AppKit view
        view.material = material // [Isolated] Apply material | [In-file] Configure visual effect material
        view.blendingMode = blendingMode // [Isolated] Apply blending mode | [In-file] Configure blending mode
        view.state = .active // [Isolated] Set state to active for consistent appearance | [In-file] Ensures vibrancy effect is active
        return view // [Isolated] Return configured view | [In-file] Final view to embed
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { // [Isolated] Update view when inputs change | [In-file] Required by NSViewRepresentable
        nsView.material = material // [Isolated] Update material | [In-file] Keep view in sync with inputs
        nsView.blendingMode = blendingMode // [Isolated] Update blending mode | [In-file] Keep view in sync with inputs
    }
}

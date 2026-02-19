//  SmartAction.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  Defines a lightweight action descriptor model used to render and execute “smart actions” in the group review UI, including label, explanatory text, SF Symbol icon name, and an executable closure.
//
//  Unique characteristics
//  ----------------------
//  - Simple value-type struct used as an immutable UI configuration object.
//  - Carries an escaping closure to execute the action when tapped.
//  - Uses SF Symbol name strings so UI components can map icons consistently.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  - Swift language: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/
//  - SwiftUI (imported): https://developer.apple.com/documentation/swiftui
//  - Closures (Swift book): https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/
//  - SF Symbols HIG: https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//  - Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//
//  NOTE: Internal project types referenced:
//  - None.

import SwiftUI // [Isolated] Required for SF Symbol icon usage and UI integration. | [In-file] Imports SwiftUI for system icon references.

struct SmartAction { // [Isolated] Value-type model for UI action configuration. | [In-file] Declares the SmartAction struct.
    let title: String // [Isolated] Short label for the action. | [In-file] Title displayed in the UI.
    let description: String // [Isolated] Explanatory text for the action. | [In-file] Provides context in the UI.
    let icon: String // [Isolated] SF Symbol name for the icon. | [In-file] Used with Image(systemName:) for consistent icons.
    let action: () -> Void // [Isolated] Escaping closure triggered by UI. | [In-file] Stores an executable action to be called when tapped.
}
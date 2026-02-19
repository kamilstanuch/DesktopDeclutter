//  CardView.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  This file defines the primary swipeable “card” UI used to present a single `DesktopFile` to the user,
//  including its thumbnail/icon preview, file metadata (name/size/date), optional suggestion badges, and
//  optional relocation/move destination information.
//
//  Unique characteristics
//  ----------------------
//  - Uses SwiftUI view composition to build a card with a preview area + footer.
//  - Dynamically adjusts card layout (preview + overall height) based on whether relocation info and/or
//    suggestions exist.
//  - Implements swipe (drag) interaction to trigger “Keep” (swipe right) or “Bin” (swipe left), with
//    animated overlays indicating intent.
//  - Provides an optional “Preview” button (eye icon) with hover affordance for macOS.
//  - Caps suggestion display to the first two suggestions for compactness.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  SwiftUI (core framework)
//  - https://developer.apple.com/documentation/swiftui
//
//  SwiftUI View protocol
//  - https://developer.apple.com/documentation/swiftui/view
//
//  SwiftUI state management
//  - @State: https://developer.apple.com/documentation/swiftui/state
//
//  Layout containers and primitives
//  - ZStack: https://developer.apple.com/documentation/swiftui/zstack
//  - VStack: https://developer.apple.com/documentation/swiftui/vstack
//  - HStack: https://developer.apple.com/documentation/swiftui/hstack
//  - Spacer: https://developer.apple.com/documentation/swiftui/spacer
//
//  Shapes, drawing, and styling
//  - RoundedRectangle: https://developer.apple.com/documentation/swiftui/roundedrectangle
//  - UnevenRoundedRectangle: https://developer.apple.com/documentation/swiftui/unevenroundedrectangle
//  - LinearGradient: https://developer.apple.com/documentation/swiftui/lineargradient
//  - Color: https://developer.apple.com/documentation/swiftui/color
//  - Shadow modifier: https://developer.apple.com/documentation/swiftui/view/shadow(color:radius:x:y:)
//  - Background modifier: https://developer.apple.com/documentation/swiftui/view/background(_:alignment:)
//  - Clip shape modifier: https://developer.apple.com/documentation/swiftui/view/clipshape(_:style:)
//  - Opacity modifier: https://developer.apple.com/documentation/swiftui/view/opacity(_:)
//
//  Images and text
//  - Image: https://developer.apple.com/documentation/swiftui/image
//  - Text: https://developer.apple.com/documentation/swiftui/text
//  - Font: https://developer.apple.com/documentation/swiftui/font
//  - Foreground style/color:
//    - https://developer.apple.com/documentation/swiftui/view/foregroundstyle(_:)
//    - https://developer.apple.com/documentation/swiftui/view/foregroundcolor(_:)
//
//  Interaction and animation
//  - Button: https://developer.apple.com/documentation/swiftui/button
//  - Gesture: https://developer.apple.com/documentation/swiftui/gesture
//  - DragGesture: https://developer.apple.com/documentation/swiftui/draggesture
//  - onHover (macOS): https://developer.apple.com/documentation/swiftui/view/onhover(perform:)
//  - animation(value:): https://developer.apple.com/documentation/swiftui/view/animation(_:value:)
//  - withAnimation: https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
//  - transition: https://developer.apple.com/documentation/swiftui/view/transition(_:)
//
//  System imagery (SF Symbols)
//  - https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//  - Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//
//  File system / formatting utilities (Foundation)
//  - FileManager: https://developer.apple.com/documentation/foundation/filemanager
//  - RelativeDateTimeFormatter: https://developer.apple.com/documentation/foundation/relativedatetimeformatter
//  - ByteCountFormatter: https://developer.apple.com/documentation/foundation/bytecountformatter
//
//  NOTE: The following types are referenced but are defined within this project (internal, not external libraries):
//  - DesktopFile (model describing a file on the desktop)
//  - FileSuggestion (model describing a suggestion badge and its metadata)
//

import SwiftUI // [Isolated] Imports SwiftUI types/modifiers. | [In-file] Required to build the card UI and interactions.

struct CardView: View { // [Isolated] Declares a SwiftUI view. | [In-file] Encapsulates the entire swipeable card UI.
    let file: DesktopFile // [Isolated] Immutable input model. | [In-file] Supplies name/icon/thumbnail/size/url/decision.
    let suggestions: [FileSuggestion] // [Isolated] Immutable input array. | [In-file] Drives suggestion badges shown below preview.
    let relocationLabel: String? // [Isolated] Optional label text. | [In-file] Customizes the “Moved to” label when present.
    let relocationPath: String? // [Isolated] Optional destination path. | [In-file] Shows where the file was moved (if any).
    let onKeep: () -> Void // [Isolated] Callback closure. | [In-file] Triggered when swipe-right passes threshold.
    let onBin: () -> Void // [Isolated] Callback closure. | [In-file] Triggered when swipe-left passes threshold.
    let onPreview: (() -> Void)? // [Isolated] Optional callback. | [In-file] Enables Preview button when non-nil.
    let onSuggestionTap: ((FileSuggestion) -> Void)? // [Isolated] Optional callback with parameter. | [In-file] Handles badge taps.

    @State private var offset: CGSize = .zero // [Isolated] Mutable state for drag translation. | [In-file] Drives swipe position/overlays.
    @State private var color: Color = .clear // [Isolated] Mutable state for color. | [In-file] Currently unused; reserved for future UI feedback.
    @State private var showSuggestions = false // [Isolated] Mutable state for toggling. | [In-file] Currently unused; reserved for expanding/collapsing.

    init( // [Isolated] Custom initializer. | [In-file] Provides defaults for optional/array parameters for ergonomic call sites.
        file: DesktopFile, // [Isolated] Required model input. | [In-file] The file represented by this card.
        suggestions: [FileSuggestion] = [], // [Isolated] Default empty array. | [In-file] Allows callers to omit suggestions.
        relocationLabel: String? = nil, // [Isolated] Default nil. | [In-file] Allows callers to omit relocation label.
        relocationPath: String? = nil, // [Isolated] Default nil. | [In-file] Allows callers to omit relocation path.
        onKeep: @escaping () -> Void, // [Isolated] Escaping closure parameter. | [In-file] Stored to run after swipe completes.
        onBin: @escaping () -> Void, // [Isolated] Escaping closure parameter. | [In-file] Stored to run after swipe completes.
        onPreview: (() -> Void)? = nil, // [Isolated] Optional callback with default. | [In-file] When set, shows Preview button.
        onSuggestionTap: ((FileSuggestion) -> Void)? = nil // [Isolated] Optional callback with default. | [In-file] When set, enables badge action.
    ) { // [Isolated] Begins initializer body. | [In-file] Copies init parameters into stored properties.
        self.file = file // [Isolated] Assigns stored property. | [In-file] Ensures the view displays the correct file.
        self.suggestions = suggestions // [Isolated] Assigns stored property. | [In-file] Enables rendering suggestion badges.
        self.relocationLabel = relocationLabel // [Isolated] Assigns stored property. | [In-file] Enables showing a custom relocation label.
        self.relocationPath = relocationPath // [Isolated] Assigns stored property. | [In-file] Enables showing relocation destination text.
        self.onKeep = onKeep // [Isolated] Assigns callback. | [In-file] Used when swipe right exceeds threshold.
        self.onBin = onBin // [Isolated] Assigns callback. | [In-file] Used when swipe left exceeds threshold.
        self.onPreview = onPreview // [Isolated] Assigns optional callback. | [In-file] Enables conditional Preview button.
        self.onSuggestionTap = onSuggestionTap // [Isolated] Assigns optional callback. | [In-file] Enables interactive badge taps.
    } // [Isolated] Ends initializer. | [In-file] The view is now configured with caller-provided behaviors.

    @State private var isPreviewHovered = false // [Isolated] Hover-state flag. | [In-file] Drives preview button hover styling on macOS.

    private var hasRelocationInfo: Bool { // [Isolated] Computed property. | [In-file] Centralizes “should we show relocation UI?” logic.
        if let relocationPath { // [Isolated] Optional binding. | [In-file] Only evaluate non-nil relocation path.
            return !relocationPath.isEmpty // [Isolated] Checks emptiness. | [In-file] Treats empty path as “no relocation info”.
        } // [Isolated] Ends optional binding scope. | [In-file] Falls through to false when nil.
        return false // [Isolated] Default fallback. | [In-file] Ensures stable layout when relocation data is absent.
    } // [Isolated] Ends computed property. | [In-file] Used by layout decisions below.

    private var previewHeight: CGFloat { // [Isolated] Computed layout value. | [In-file] Adjusts preview height to make room for relocation row.
        hasRelocationInfo ? 248 : 320 // [Isolated] Ternary. | [In-file] Shrinks preview when relocation info needs extra vertical space.
    } // [Isolated] Ends computed property. | [In-file] Keeps layout logic in one place.

    private var cardHeight: CGFloat { // [Isolated] Computed layout value. | [In-file] Ensures total card height fits all conditional sections.
        switch (suggestions.isEmpty, hasRelocationInfo) { // [Isolated] Switch over tuple. | [In-file] Chooses height based on suggestions + relocation.
        case (true, false): return 400 // [Isolated] Constant height. | [In-file] Base card when no suggestions and no relocation.
        case (true, true): return 430 // [Isolated] Constant height. | [In-file] Adds height for relocation row.
        case (false, false): return 450 // [Isolated] Constant height. | [In-file] Adds height for suggestion badges.
        case (false, true): return 480 // [Isolated] Constant height. | [In-file] Accounts for both badges and relocation row.
        } // [Isolated] Ends switch. | [In-file] Guarantees a value for all combinations.
    } // [Isolated] Ends computed property. | [In-file] Used by outer frame.

    private var fileDateString: String { // [Isolated] Computed string. | [In-file] Produces a user-friendly “time ago” label.
        let formatter = RelativeDateTimeFormatter() // [Isolated] Creates formatter. | [In-file] Converts a Date into “x minutes/hours/days ago”.
        formatter.unitsStyle = .full // [Isolated] Sets style. | [In-file] Uses verbose relative time strings for clarity.
        if let date = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date { // [Isolated] Reads file attributes safely. | [In-file] Pulls the file creation date from filesystem metadata.
            return formatter.localizedString(for: date, relativeTo: Date()) // [Isolated] Formats relative date. | [In-file] Anchors relative time to “now”.
        } // [Isolated] Ends conditional. | [In-file] Falls back when attributes read fails.
        return "Recently" // [Isolated] Fallback label. | [In-file] Avoids empty UI when metadata is unavailable.
    } // [Isolated] Ends computed property. | [In-file] Used in the footer metadata row.

    var body: some View { // [Isolated] SwiftUI view body. | [In-file] Defines the full card UI and interaction behavior.
        ZStack { // [Isolated] Overlays views. | [In-file] Allows background, content, and swipe overlays to stack.
            // Card background
            RoundedRectangle(cornerRadius: 20) // [Isolated] Base rounded shape. | [In-file] Defines card silhouette.
                .fill(Color(nsColor: .windowBackgroundColor)) // [Isolated] Fills with system color. | [In-file] Matches macOS window background.
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8) // [Isolated] Large drop shadow. | [In-file] Lifts card off background.
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2) // [Isolated] Small shadow. | [In-file] Adds crisp depth.

            VStack(spacing: 0) { // [Isolated] Vertical layout stack. | [In-file] Arranges preview, badges, and footer.
                // Preview area with padding
                ZStack { // [Isolated] Layers preview background + image. | [In-file] Centers preview content.
                    Color(nsColor: .controlBackgroundColor) // [Isolated] System control background. | [In-file] Provides preview backdrop.

                    Group { // [Isolated] Groups conditional views. | [In-file] Keeps modifier application unified.
                        if let thumbnail = file.thumbnail { // [Isolated] Optional binding. | [In-file] Prefer showing a file thumbnail when available.
                            Image(nsImage: thumbnail) // [Isolated] Creates SwiftUI Image from NSImage. | [In-file] Displays thumbnail for visual recognition.
                                .resizable() // [Isolated] Makes image resizable. | [In-file] Enables scaling to fit the preview box.
                                .aspectRatio(contentMode: .fit) // [Isolated] Preserves aspect ratio. | [In-file] Prevents distortion.
                        } else { // [Isolated] Fallback branch. | [In-file] Handles files with no thumbnail.
                            Image(nsImage: file.icon) // [Isolated] Builds image from icon. | [In-file] Shows generic/app icon when no thumbnail.
                                .resizable() // [Isolated] Makes image resizable. | [In-file] Enables scaling.
                                .aspectRatio(contentMode: .fit) // [Isolated] Fits while preserving ratio. | [In-file] Avoids distortion.
                                .frame(width: 120, height: 120) // [Isolated] Sets explicit size. | [In-file] Keeps icon visually consistent.
                                .foregroundColor(.secondary) // [Isolated] Tints foreground. | [In-file] De-emphasizes fallback icon.
                        } // [Isolated] Ends thumbnail conditional. | [In-file] Ensures one preview image is rendered.
                    } // [Isolated] Ends Group. | [In-file] Allows shared padding below.
                    .padding(20) // [Isolated] Adds padding. | [In-file] Prevents image from touching edges.
                } // [Isolated] Ends preview ZStack. | [In-file] All preview visuals are composed here.
                .frame(height: previewHeight) // [Isolated] Fixes height. | [In-file] Adapts height based on relocation info.
                .clipShape( // [Isolated] Clips to custom shape. | [In-file] Rounds only the top corners of the preview.
                    UnevenRoundedRectangle( // [Isolated] Shape with per-corner radii. | [In-file] Matches card rounding at top.
                        topLeadingRadius: 20, // [Isolated] Corner radius value. | [In-file] Rounds top-left.
                        bottomLeadingRadius: 0, // [Isolated] Corner radius value. | [In-file] Keeps bottom-left square to meet footer.
                        bottomTrailingRadius: 0, // [Isolated] Corner radius value. | [In-file] Keeps bottom-right square to meet footer.
                        topTrailingRadius: 20 // [Isolated] Corner radius value. | [In-file] Rounds top-right.
                    ) // [Isolated] Ends shape init. | [In-file] Defines preview clipping mask.
                ) // [Isolated] Ends clipShape. | [In-file] Ensures the preview aligns with the card silhouette.

                // Suggestions badges (if any)
                if !suggestions.isEmpty { // [Isolated] Conditional rendering. | [In-file] Only show badge stack when suggestions exist.
                    VStack(spacing: 8) { // [Isolated] Vertical stack. | [In-file] Lists up to 2 suggestion badges.
                        ForEach(Array(suggestions.prefix(2).enumerated()), id: \.offset) { _, suggestion in // [Isolated] Iterates first 2 suggestions with stable id. | [In-file] Renders compact list of badges.
                            SuggestionBadge(suggestion: suggestion) { // [Isolated] Custom badge view. | [In-file] Provides interactive affordance for suggestion.
                                onSuggestionTap?(suggestion) // [Isolated] Calls optional callback. | [In-file] Notifies parent about which suggestion was tapped.
                            } // [Isolated] Ends SuggestionBadge init. | [In-file] Badge is wired to tap callback.
                        } // [Isolated] Ends ForEach. | [In-file] Stops after rendering at most two badges.
                    } // [Isolated] Ends badges VStack. | [In-file] Badge section is now composed.
                    .padding(.horizontal, 20) // [Isolated] Horizontal padding. | [In-file] Aligns badges with footer margins.
                    .padding(.top, 12) // [Isolated] Top padding. | [In-file] Adds space between preview and badges.
                } // [Isolated] Ends suggestions conditional. | [In-file] Badge section omitted when none.

                // File info footer
                VStack(spacing: 8) { // [Isolated] Vertical stack for footer rows. | [In-file] Contains main metadata row and optional relocation row.
                    HStack(alignment: .center, spacing: 12) { // [Isolated] Horizontal stack. | [In-file] Places text block on left and preview button on right.
                        VStack(alignment: .leading, spacing: 6) { // [Isolated] Vertical stack. | [In-file] Holds filename and the sub-metadata row.
                            Text(file.name) // [Isolated] Displays a string. | [In-file] Shows the filename (primary identifier).
                                .font(.system(size: 15, weight: .semibold)) // [Isolated] Sets font. | [In-file] Establishes visual hierarchy.
                                .lineLimit(2) // [Isolated] Limits lines. | [In-file] Prevents footer from growing too tall.
                                .multilineTextAlignment(.leading) // [Isolated] Sets alignment. | [In-file] Keeps text left-aligned.
                                .foregroundColor(.primary) // [Isolated] Uses primary color. | [In-file] Matches system emphasis for title text.

                            HStack(spacing: 6) { // [Isolated] Sub-metadata row. | [In-file] Shows size • relative date.
                                Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file)) // [Isolated] Formats bytes to human readable. | [In-file] Shows file size like “1.2 MB”.
                                    .font(.system(size: 12, weight: .regular)) // [Isolated] Sets small font. | [In-file] Secondary metadata styling.
                                    .foregroundColor(.secondary) // [Isolated] Uses secondary color. | [In-file] De-emphasizes metadata.

                                Text("•") // [Isolated] Separator glyph. | [In-file] Visually separates size and date.
                                    .font(.system(size: 12)) // [Isolated] Sets font. | [In-file] Matches metadata size.
                                    .foregroundColor(.secondary.opacity(0.6)) // [Isolated] Uses faded secondary. | [In-file] Keeps separator subtle.

                                Text(fileDateString) // [Isolated] Displays computed string. | [In-file] Shows relative creation time.
                                    .font(.system(size: 12, weight: .regular)) // [Isolated] Small font. | [In-file] Consistent metadata styling.
                                    .foregroundColor(.secondary) // [Isolated] Secondary color. | [In-file] Keeps date from competing with filename.
                            } // [Isolated] Ends sub-metadata HStack. | [In-file] Size/date row complete.
                        } // [Isolated] Ends left text VStack. | [In-file] Title + metadata block complete.

                        Spacer() // [Isolated] Flexible spacer. | [In-file] Pushes preview button to the far right.

                        // Preview button
                        if onPreview != nil { // [Isolated] Conditional. | [In-file] Only show preview affordance when callback exists.
                            Button(action: { // [Isolated] Button with action closure. | [In-file] Calls onPreview when tapped.
                                onPreview?() // [Isolated] Executes optional closure. | [In-file] Triggers file preview in the parent.
                            }) { // [Isolated] Begins button label. | [In-file] Defines the visual content of the button.
                                Image(systemName: "eye.fill") // [Isolated] SF Symbol image. | [In-file] Communicates “preview”.
                                    .font(.system(size: 16, weight: .medium)) // [Isolated] Sets icon font size/weight. | [In-file] Ensures consistent icon thickness.
                                    .foregroundColor(isPreviewHovered ? .white : .blue) // [Isolated] Changes tint on hover. | [In-file] Inverts for filled circle on hover.
                                    .frame(width: 36, height: 36) // [Isolated] Sets tappable area. | [In-file] Meets comfortable hit target.
                                    .background { // [Isolated] Adds a background view. | [In-file] Creates a circular button background.
                                        Circle() // [Isolated] Circle shape. | [In-file] Used for button chrome.
                                            .fill(isPreviewHovered ? Color.blue : Color.blue.opacity(0.12)) // [Isolated] Fill changes with hover. | [In-file] Adds hover affordance.
                                    } // [Isolated] Ends background closure. | [In-file] Button background is now defined.
                            } // [Isolated] Ends button init. | [In-file] Button has both action and label.
                            .buttonStyle(.plain) // [Isolated] Removes default styling. | [In-file] Keeps custom visuals consistent.
                            .help("Preview file (Space)") // [Isolated] Adds tooltip/help. | [In-file] Communicates shortcut hint.
                            .onHover { hovering in // [Isolated] Hover handler. | [In-file] Tracks hover state to animate styling.
                                withAnimation(.easeInOut(duration: 0.2)) { // [Isolated] Animates state changes. | [In-file] Smooth hover transition.
                                    isPreviewHovered = hovering // [Isolated] Updates state. | [In-file] Drives icon/background color changes.
                                } // [Isolated] Ends withAnimation. | [In-file] Hover state update is animated.
                            } // [Isolated] Ends onHover. | [In-file] Hover behavior is configured.
                        } // [Isolated] Ends preview conditional. | [In-file] Button omitted if no preview handler.
                    } // [Isolated] Ends main footer HStack. | [In-file] Title + button row complete.

                    if let relocationPath { // [Isolated] Optional binding. | [In-file] Shows relocation row when path exists.
                        HStack(alignment: .firstTextBaseline, spacing: 8) { // [Isolated] Horizontal row aligned on baseline. | [In-file] Displays icon + label + destination path.
                            Image(systemName: (file.decision == .cloud) ? "icloud.and.arrow.up.fill" : "folder.fill") // [Isolated] Chooses symbol by decision. | [In-file] Communicates cloud vs local folder.
                                .font(.system(size: 11, weight: .semibold)) // [Isolated] Sets icon font. | [In-file] Keeps relocation row compact.
                                .foregroundColor(.blue) // [Isolated] Tints icon. | [In-file] Matches “destination” emphasis.

                            Text((relocationLabel ?? "Moved to") + ":") // [Isolated] Builds label text. | [In-file] Displays “Moved to:” (or custom label).
                                .font(.system(size: 11, weight: .semibold)) // [Isolated] Semi-bold label. | [In-file] Differentiates label from path.
                                .foregroundColor(.secondary) // [Isolated] Secondary color. | [In-file] Keeps label subtle.

                            Text(relocationPath) // [Isolated] Displays destination path. | [In-file] Shows where the file was moved.
                                .font(.system(size: 11)) // [Isolated] Small font. | [In-file] Maintains compact relocation row.
                                .foregroundColor(.secondary) // [Isolated] Secondary color. | [In-file] Prevents overpowering title.
                                .lineLimit(2) // [Isolated] Limits lines. | [In-file] Prevents footer from expanding too much.
                                .truncationMode(.middle) // [Isolated] Truncates middle. | [In-file] Preserves start/end of paths.
                        } // [Isolated] Ends relocation HStack. | [In-file] Relocation row complete.
                        .frame(maxWidth: .infinity, alignment: .leading) // [Isolated] Expands width, aligns left. | [In-file] Keeps row aligned with title.
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity)) // [Isolated] Animates appearance/disappearance. | [In-file] Makes relocation row feel polished.
                    } // [Isolated] Ends relocation conditional. | [In-file] Row omitted when relocationPath is nil.
                } // [Isolated] Ends footer VStack. | [In-file] Footer section complete.
                .padding(.horizontal, 20) // [Isolated] Horizontal padding. | [In-file] Aligns footer content with preview padding.
                .padding(.vertical, 14) // [Isolated] Vertical padding. | [In-file] Provides comfortable spacing.
                .frame(maxWidth: .infinity) // [Isolated] Expands to container width. | [In-file] Ensures background spans full card width.
                .background { // [Isolated] Background view. | [In-file] Adds subtle footer background.
                    Color(nsColor: .controlBackgroundColor) // [Isolated] System background color. | [In-file] Differentiates footer from preview.
                        .opacity(0.6) // [Isolated] Reduces opacity. | [In-file] Keeps footer light and unobtrusive.
                } // [Isolated] Ends background closure. | [In-file] Footer background defined.
                .clipShape( // [Isolated] Clips footer background. | [In-file] Rounds only bottom corners to match card.
                    UnevenRoundedRectangle( // [Isolated] Shape with per-corner radii. | [In-file] Matches card rounding at bottom.
                        topLeadingRadius: 0, // [Isolated] No rounding at top-left. | [In-file] Joins seamlessly with preview/badges above.
                        bottomLeadingRadius: 20, // [Isolated] Rounds bottom-left. | [In-file] Matches card silhouette.
                        bottomTrailingRadius: 20, // [Isolated] Rounds bottom-right. | [In-file] Matches card silhouette.
                        topTrailingRadius: 0 // [Isolated] No rounding at top-right. | [In-file] Joins seamlessly with preview/badges above.
                    ) // [Isolated] Ends shape init. | [In-file] Footer clipping mask defined.
                ) // [Isolated] Ends clipShape. | [In-file] Ensures footer background respects rounded corners.
            } // [Isolated] Ends main content VStack. | [In-file] Preview + badges + footer are now composed.
            .clipShape(RoundedRectangle(cornerRadius: 20)) // [Isolated] Clips entire content. | [In-file] Prevents overlays/content from bleeding outside card.

            // Swipe overlays with improved visuals
            HStack { // [Isolated] Horizontal container for side overlays. | [In-file] Shows Keep on left and Bin on right depending on swipe direction.
                // KEEP (Left side of card, visible when swiping right)
                if offset.width > 0 { // [Isolated] Conditional based on drag direction. | [In-file] Only show Keep overlay when swiping right.
                    ZStack { // [Isolated] Layers overlay background + label content. | [In-file] Creates polished keep overlay.
                        RoundedRectangle(cornerRadius: 20) // [Isolated] Overlay shape. | [In-file] Matches card rounding.
                            .fill( // [Isolated] Fills shape with gradient. | [In-file] Provides directional emphasis.
                                LinearGradient( // [Isolated] Linear gradient. | [In-file] Creates left-to-right green wash.
                                    colors: [ // [Isolated] Gradient stops array. | [In-file] Uses two opacities for depth.
                                        Color.green.opacity(0.25), // [Isolated] Light green. | [In-file] Outer wash.
                                        Color.green.opacity(0.15) // [Isolated] Lighter green. | [In-file] Inner fade.
                                    ], // [Isolated] Ends colors array. | [In-file] Gradient palette established.
                                    startPoint: .leading, // [Isolated] Gradient start. | [In-file] Stronger on left.
                                    endPoint: .trailing // [Isolated] Gradient end. | [In-file] Fades toward center/right.
                                ) // [Isolated] Ends gradient init. | [In-file] Gradient background complete.
                            ) // [Isolated] Ends fill. | [In-file] Overlay background is defined.

                        VStack(spacing: 8) { // [Isolated] Vertical stack for icon + text. | [In-file] Shows keep intent visuals.
                            Image(systemName: "checkmark.circle.fill") // [Isolated] SF Symbol. | [In-file] Communicates “keep”.
                                .font(.system(size: 64, weight: .semibold)) // [Isolated] Large icon. | [In-file] Makes action clear.
                                .foregroundColor(.green) // [Isolated] Green tint. | [In-file] Matches keep semantics.
                                .opacity(min(Double(offset.width / 120), 1.0)) // [Isolated] Opacity ramps with drag. | [In-file] Feels responsive to swipe distance.

                            Text("Keep") // [Isolated] Label text. | [In-file] Reinforces keep action.
                                .font(.system(size: 14, weight: .semibold)) // [Isolated] Sets font. | [In-file] Keeps label readable.
                                .foregroundColor(.green) // [Isolated] Green tint. | [In-file] Matches icon.
                                .opacity(min(Double(offset.width / 120), 1.0)) // [Isolated] Opacity ramps with drag. | [In-file] Syncs with icon fade-in.
                        } // [Isolated] Ends Keep VStack. | [In-file] Keep overlay content is complete.
                        .rotationEffect(.degrees(-min(Double(offset.width / 8), 12))) // [Isolated] Slight tilt. | [In-file] Adds playful kinetic feedback.
                    } // [Isolated] Ends Keep ZStack. | [In-file] Keep overlay composed.
                } // [Isolated] Ends Keep conditional. | [In-file] Keep overlay hidden when not swiping right.

                // BIN (Right side of card, visible when swiping left)
                if offset.width < 0 { // [Isolated] Conditional based on drag direction. | [In-file] Only show Bin overlay when swiping left.
                    ZStack { // [Isolated] Layers overlay background + label content. | [In-file] Creates polished bin overlay.
                        RoundedRectangle(cornerRadius: 20) // [Isolated] Overlay shape. | [In-file] Matches card rounding.
                            .fill( // [Isolated] Fills shape with gradient. | [In-file] Provides directional emphasis.
                                LinearGradient( // [Isolated] Linear gradient. | [In-file] Creates right-to-left red wash.
                                    colors: [ // [Isolated] Gradient stops array. | [In-file] Uses two opacities for depth.
                                        Color.red.opacity(0.25), // [Isolated] Light red. | [In-file] Outer wash.
                                        Color.red.opacity(0.15) // [Isolated] Lighter red. | [In-file] Inner fade.
                                    ], // [Isolated] Ends colors array. | [In-file] Gradient palette established.
                                    startPoint: .trailing, // [Isolated] Gradient start. | [In-file] Stronger on right.
                                    endPoint: .leading // [Isolated] Gradient end. | [In-file] Fades toward center/left.
                                ) // [Isolated] Ends gradient init. | [In-file] Gradient background complete.
                            ) // [Isolated] Ends fill. | [In-file] Overlay background is defined.

                        VStack(spacing: 8) { // [Isolated] Vertical stack for icon + text. | [In-file] Shows bin intent visuals.
                            Image(systemName: "trash.circle.fill") // [Isolated] SF Symbol. | [In-file] Communicates “bin/delete”.
                                .font(.system(size: 64, weight: .semibold)) // [Isolated] Large icon. | [In-file] Makes action clear.
                                .foregroundColor(.red) // [Isolated] Red tint. | [In-file] Matches delete semantics.
                                .opacity(min(Double(-offset.width / 120), 1.0)) // [Isolated] Opacity ramps with drag. | [In-file] Feels responsive to swipe distance.

                            Text("Bin") // [Isolated] Label text. | [In-file] Reinforces bin action.
                                .font(.system(size: 14, weight: .semibold)) // [Isolated] Sets font. | [In-file] Keeps label readable.
                                .foregroundColor(.red) // [Isolated] Red tint. | [In-file] Matches icon.
                                .opacity(min(Double(-offset.width / 120), 1.0)) // [Isolated] Opacity ramps with drag. | [In-file] Syncs with icon fade-in.
                        } // [Isolated] Ends Bin VStack. | [In-file] Bin overlay content is complete.
                        .rotationEffect(.degrees(min(Double(-offset.width / 8), 12))) // [Isolated] Slight tilt. | [In-file] Adds playful kinetic feedback.
                    } // [Isolated] Ends Bin ZStack. | [In-file] Bin overlay composed.
                } // [Isolated] Ends Bin conditional. | [In-file] Bin overlay hidden when not swiping left.
            } // [Isolated] Ends overlays HStack. | [In-file] Overlay layer complete.
            .allowsHitTesting(false) // [Isolated] Disables hit testing. | [In-file] Ensures overlays never block drag/tap interactions.
        } // [Isolated] Ends root ZStack. | [In-file] Card layers (background/content/overlays) are complete.
        .frame(width: 300, height: cardHeight) // [Isolated] Fixed size. | [In-file] Standardizes card size across the UI.
        .offset(x: offset.width, y: 0) // [Isolated] Moves view horizontally. | [In-file] Implements swipe translation.
        .rotationEffect(.degrees(Double(offset.width / 25))) // [Isolated] Rotates slightly with swipe. | [In-file] Adds tactile feedback.
        .scaleEffect(1.0 - abs(offset.width) / 1200) // [Isolated] Scales down slightly while swiping. | [In-file] Enhances depth feel.
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: hasRelocationInfo) // [Isolated] Animates layout changes. | [In-file] Smoothly resizes when relocation info appears/disappears.
        .gesture( // [Isolated] Attaches a gesture recognizer. | [In-file] Enables swipe-to-keep/bin interaction.
            DragGesture(minimumDistance: 10) // [Isolated] Drag gesture. | [In-file] Tracks horizontal swipes with a small deadzone.
                .onChanged { gesture in // [Isolated] Drag update handler. | [In-file] Updates card position live as finger/mouse drags.
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) { // [Isolated] Uses interactive spring. | [In-file] Keeps the card movement feeling responsive.
                        offset = gesture.translation // [Isolated] Stores translation. | [In-file] Drives the card offset and overlays.
                    } // [Isolated] Ends withAnimation. | [In-file] Animated state update complete.
                } // [Isolated] Ends onChanged. | [In-file] Live drag handling configured.
                .onEnded { gesture in // [Isolated] Drag end handler. | [In-file] Decides whether to commit Keep/Bin or snap back.
                    let threshold: CGFloat = 120 // [Isolated] Swipe distance threshold. | [In-file] Determines the commit distance for actions.
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { // [Isolated] Spring animation. | [In-file] Animates the card snapping/commit.
                        if offset.width > threshold { // [Isolated] Right swipe commit check. | [In-file] Triggers Keep action.
                            onKeep() // [Isolated] Executes callback. | [In-file] Notifies parent to mark file as kept.
                        } else if offset.width < -threshold { // [Isolated] Left swipe commit check. | [In-file] Triggers Bin action.
                            onBin() // [Isolated] Executes callback. | [In-file] Notifies parent to mark file as binned.
                        } else { // [Isolated] Snap-back case. | [In-file] Insufficient swipe distance.
                            offset = .zero // [Isolated] Resets translation. | [In-file] Returns card to center position.
                        } // [Isolated] Ends commit decision. | [In-file] Ensures deterministic outcome.
                    } // [Isolated] Ends withAnimation. | [In-file] End-of-drag outcome is animated.
                } // [Isolated] Ends onEnded. | [In-file] Drag completion logic configured.
        ) // [Isolated] Ends gesture modifier. | [In-file] Card is now swipe-interactive.
    } // [Isolated] Ends body. | [In-file] The card view is fully defined.
} // [Isolated] Ends CardView struct. | [In-file] Card view is ready to be used in higher-level screens.

// MARK: - Suggestion Badge

struct SuggestionBadge: View { // [Isolated] Declares a SwiftUI view. | [In-file] Renders one tappable suggestion badge row.
    let suggestion: FileSuggestion // [Isolated] Immutable suggestion input. | [In-file] Determines badge text, icon, and color.
    let onTap: () -> Void // [Isolated] Callback closure. | [In-file] Invoked when user taps the badge.

    @State private var isHovered = false // [Isolated] Hover-state flag. | [In-file] Provides subtle hover animation feedback.

    private var badgeColor: Color { // [Isolated] Computed color. | [In-file] Maps suggestion type to a consistent semantic color.
        switch suggestion.type { // [Isolated] Switch on enum. | [In-file] Produces deterministic styling by suggestion kind.
        case .duplicate, .temporaryFile: // [Isolated] Two cases. | [In-file] Warn-like suggestions.
            return .orange // [Isolated] Returns orange. | [In-file] Communicates caution.
        case .similarNames, .sameSession: // [Isolated] Two cases. | [In-file] Info-like suggestions.
            return .blue // [Isolated] Returns blue. | [In-file] Communicates informational grouping.
        case .oldFile: // [Isolated] Single case. | [In-file] Time-sensitive suggestion.
            return .red // [Isolated] Returns red. | [In-file] Communicates urgency/cleanup.
        case .largeFile: // [Isolated] Single case. | [In-file] Storage-impact suggestion.
            return .purple // [Isolated] Returns purple. | [In-file] Distinguishes storage concern.
        } // [Isolated] Ends switch. | [In-file] Guarantees a color for all types.
    } // [Isolated] Ends computed property. | [In-file] Used in background fill.

    private var badgeIcon: String { // [Isolated] Computed symbol name. | [In-file] Maps suggestion type to an SF Symbol.
        switch suggestion.type { // [Isolated] Switch on enum. | [In-file] Keeps iconography consistent.
        case .duplicate: // [Isolated] Single case. | [In-file] Duplicate file hint.
            return "doc.on.doc.fill" // [Isolated] SF Symbol name. | [In-file] Conveys duplication.
        case .similarNames: // [Isolated] Single case. | [In-file] Similar naming hint.
            return "square.stack.fill" // [Isolated] SF Symbol name. | [In-file] Conveys grouping.
        case .oldFile: // [Isolated] Single case. | [In-file] Old file hint.
            return "clock.fill" // [Isolated] SF Symbol name. | [In-file] Conveys age/time.
        case .largeFile: // [Isolated] Single case. | [In-file] Large file hint.
            return "externaldrive.fill" // [Isolated] SF Symbol name. | [In-file] Conveys storage device/space.
        case .sameSession: // [Isolated] Single case. | [In-file] Same session hint.
            return "calendar.badge.clock" // [Isolated] SF Symbol name. | [In-file] Conveys time grouping.
        case .temporaryFile: // [Isolated] Single case. | [In-file] Temporary file hint.
            return "trash.fill" // [Isolated] SF Symbol name. | [In-file] Conveys discardable.
        } // [Isolated] Ends switch. | [In-file] Guarantees an icon for all types.
    } // [Isolated] Ends computed property. | [In-file] Used by the badge leading icon.

    var body: some View { // [Isolated] SwiftUI view body. | [In-file] Defines the badge row UI and interactions.
        Button(action: onTap) { // [Isolated] Button wrapper. | [In-file] Makes entire badge tappable.
            HStack(spacing: 8) { // [Isolated] Horizontal layout. | [In-file] Arranges icon, text, spacer, chevron.
                Image(systemName: badgeIcon) // [Isolated] SF Symbol. | [In-file] Displays suggestion icon.
                    .font(.system(size: 12, weight: .semibold)) // [Isolated] Small bold icon. | [In-file] Keeps badge compact.

                VStack(alignment: .leading, spacing: 2) { // [Isolated] Vertical text stack. | [In-file] Shows message + optional hint.
                    Text(suggestion.message) // [Isolated] Primary message. | [In-file] Explains the suggestion.
                        .font(.system(size: 12, weight: .medium)) // [Isolated] Medium font. | [In-file] Maintains readability.

                    if let hint = suggestion.actionHint { // [Isolated] Optional binding. | [In-file] Shows a hint only when available.
                        Text(hint) // [Isolated] Secondary hint text. | [In-file] Explains what action is possible.
                            .font(.system(size: 10, weight: .regular)) // [Isolated] Smaller font. | [In-file] De-emphasizes hint.
                            .opacity(0.8) // [Isolated] Slight fade. | [In-file] Keeps hint subtle.
                    } // [Isolated] Ends hint conditional. | [In-file] Avoids empty hint space.
                } // [Isolated] Ends text VStack. | [In-file] Badge text block complete.

                Spacer() // [Isolated] Flexible spacer. | [In-file] Pushes chevron to trailing edge.

                Image(systemName: "chevron.right") // [Isolated] SF Symbol chevron. | [In-file] Indicates navigation/action.
                    .font(.system(size: 10, weight: .semibold)) // [Isolated] Small bold chevron. | [In-file] Matches badge scale.
                    .opacity(0.6) // [Isolated] Fades chevron. | [In-file] Keeps it secondary.
            } // [Isolated] Ends HStack. | [In-file] Badge row content complete.
            .foregroundColor(.white) // [Isolated] Sets foreground color. | [In-file] Ensures readable content on colored background.
            .padding(.horizontal, 12) // [Isolated] Horizontal padding. | [In-file] Gives badge breathing room.
            .padding(.vertical, 8) // [Isolated] Vertical padding. | [In-file] Enlarges tap target.
            .background { // [Isolated] Adds background view. | [In-file] Draws rounded colored pill.
                RoundedRectangle(cornerRadius: 8) // [Isolated] Rounded shape. | [In-file] Provides badge silhouette.
                    .fill(badgeColor.opacity(isHovered ? 0.9 : 0.85)) // [Isolated] Fill with hover-dependent opacity. | [In-file] Adds hover affordance.
            } // [Isolated] Ends background closure. | [In-file] Badge background defined.
        } // [Isolated] Ends Button. | [In-file] Entire badge is tappable.
        .buttonStyle(.plain) // [Isolated] Removes default styling. | [In-file] Preserves custom badge visuals.
        .scaleEffect(isHovered ? 1.02 : 1.0) // [Isolated] Slight scale on hover. | [In-file] Provides tactile hover feedback.
        .animation(.easeInOut(duration: 0.15), value: isHovered) // [Isolated] Animates hover scaling. | [In-file] Smooths the transition.
        .onHover { hovering in // [Isolated] Hover handler. | [In-file] Updates hover state for visual feedback.
            isHovered = hovering // [Isolated] Updates state. | [In-file] Drives scale and opacity changes.
        } // [Isolated] Ends onHover. | [In-file] Hover behavior configured.
    } // [Isolated] Ends body. | [In-file] Badge view is fully defined.
} // [Isolated] Ends SuggestionBadge struct. | [In-file] Badge component ready for reuse.

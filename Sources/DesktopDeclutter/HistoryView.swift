//  HistoryView.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  Presents the session action timeline (`DeclutterViewModel.actionHistory`) as a scrollable list with per-entry icons/colors, timestamps, and an expandable "Details" disclosure for additional metadata.
//  Shows a moving progress banner when background moves are in-flight.
//  Provides a Reset Session button that triggers undo of all actions.
//
//  Unique characteristics
//  ----------------------
//  - Uses a DateFormatter configured for time-only timestamps.
//  - Displays entries in reverse chronological order while preserving stable identity.
//  - Stores expanded disclosure state per entry using a Set<UUID> and a custom Binding helper.
//  - Uses a hover background row effect for mouse affordance.
//  - Uses VisualEffectView for macOS translucent header/footer styling.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  SwiftUI: https://developer.apple.com/documentation/swiftui
//  View: https://developer.apple.com/documentation/swiftui/view
//  @ObservedObject: https://developer.apple.com/documentation/swiftui/observedobject
//  @Binding: https://developer.apple.com/documentation/swiftui/binding
//  @State: https://developer.apple.com/documentation/swiftui/state
//  Layout:
//    VStack: https://developer.apple.com/documentation/swiftui/vstack
//    HStack: https://developer.apple.com/documentation/swiftui/hstack
//    Spacer: https://developer.apple.com/documentation/swiftui/spacer
//    Divider: https://developer.apple.com/documentation/swiftui/divider
//    ScrollView: https://developer.apple.com/documentation/swiftui/scrollview
//    LazyVStack: https://developer.apple.com/documentation/swiftui/lazyvstack
//    ForEach: https://developer.apple.com/documentation/swiftui/foreach
//    DisclosureGroup: https://developer.apple.com/documentation/swiftui/disclosuregroup
//  Controls:
//    Button: https://developer.apple.com/documentation/swiftui/button
//    ProgressView: https://developer.apple.com/documentation/swiftui/progressview
//  Text/images/styling:
//    Text: https://developer.apple.com/documentation/swiftui/text
//    Image: https://developer.apple.com/documentation/swiftui/image
//    Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//    Font: https://developer.apple.com/documentation/swiftui/font
//    Color: https://developer.apple.com/documentation/swiftui/color
//    background: https://developer.apple.com/documentation/swiftui/view/background(_:alignment:)
//    frame: https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:)
//    foregroundColor: https://developer.apple.com/documentation/swiftui/view/foregroundcolor(_:) 
//    opacity: https://developer.apple.com/documentation/swiftui/view/opacity(_:) 
//    padding: https://developer.apple.com/documentation/swiftui/view/padding(_:) 
//    lineLimit: https://developer.apple.com/documentation/swiftui/view/linelimit(_:) 
//    truncationMode: https://developer.apple.com/documentation/swiftui/view/truncationmode(_:) 
//    textSelection: https://developer.apple.com/documentation/swiftui/view/textselection(_:) 
//  Animation:
//    withAnimation: https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
//  Hover:
//    onHover: https://developer.apple.com/documentation/swiftui/view/onhover(perform:)
//  Foundation:
//    DateFormatter: https://developer.apple.com/documentation/foundation/dateformatter
//    Date: https://developer.apple.com/documentation/foundation/date
//    UUID: https://developer.apple.com/documentation/foundation/uuid
//  SF Symbols:
//    https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//
//  NOTE: Uses DeclutterViewModel, DeclutterViewModel.HistoryEntry, VisualEffectView

import SwiftUI // [Isolated] Import SwiftUI framework | [In-file] Required for all SwiftUI view code below

struct HistoryView: View { // [Isolated] Main view for displaying session history | [In-file] Presents timeline, progress, and controls
    @ObservedObject var viewModel: DeclutterViewModel // [Isolated] View model for history and session state | [In-file] Provides actionHistory, movingCount, resetSession()
    @Binding var isPresented: Bool // [Isolated] Controls visibility of this sheet | [In-file] Used for "Done" button to dismiss
    @State private var expandedRows: Set<UUID> = [] // [Isolated] Tracks which entries have their disclosure expanded | [In-file] Used with DisclosureGroup

    private let timestampFormatter: DateFormatter = { // [Isolated] Formatter for time-only display | [In-file] Used for per-entry timestamps
        let formatter = DateFormatter() // [Isolated] Create formatter | [In-file] Used below for .string(from:)
        formatter.dateStyle = .none // [Isolated] No date, only time | [In-file] Only show time
        formatter.timeStyle = .medium // [Isolated] Show medium style time | [In-file] E.g. 4:23:19 PM
        return formatter // [Isolated] Return configured formatter | [In-file] Used in body
    }() // [Isolated] Immediately-invoked closure for property | [In-file] Used throughout view
    
    var body: some View { // [Isolated] Main view body | [In-file] Contains all layout and controls
        VStack(spacing: 0) { // [Isolated] Vertical stack for all sections | [In-file] Header, divider, content, footer
            HStack { // [Isolated] Header row | [In-file] Title and Done button
                Text("Session History") // [Isolated] Header title | [In-file] Shown at top
                    .font(.headline) // [Isolated] Use headline font | [In-file] For emphasis
                Spacer() // [Isolated] Pushes Done button right | [In-file] Layout
                Button("Done") { // [Isolated] Dismisses history view | [In-file] Sets isPresented to false
                    isPresented = false // [Isolated] Set binding to false | [In-file] Dismiss sheet
                }
                .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] No border
                .foregroundColor(.blue) // [Isolated] Blue color for Done | [In-file] Matches macOS convention
            }
            .padding() // [Isolated] Header padding | [In-file] Adds space
            .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow)) // [Isolated] Translucent macOS header | [In-file] VisualEffectView used here
            
            Divider() // [Isolated] Separator below header | [In-file] Visual separation

            if viewModel.movingCount > 0 { // [Isolated] Show progress if background moves | [In-file] Only visible when movingCount > 0
                VStack(alignment: .leading, spacing: 8) { // [Isolated] Progress content | [In-file] Shows spinner and text
                    HStack(spacing: 10) { // [Isolated] Spinner and text row | [In-file] ProgressView and label
                        ProgressView() // [Isolated] Circular progress spinner | [In-file] Indicates in-flight moves
                            .progressViewStyle(.circular) // [Isolated] Use circular style | [In-file] macOS default
                        Text("Moving \(viewModel.movingCount) item\(viewModel.movingCount == 1 ? "" : "s")…") // [Isolated] Pluralizes label | [In-file] Shows number of items moving
                            .font(.system(size: 12, weight: .semibold)) // [Isolated] Smaller, bold font | [In-file] For prominence
                            .foregroundColor(.primary) // [Isolated] Uses primary color | [In-file] For readability
                        Spacer() // [Isolated] Push right | [In-file] Layout
                    }
                    ProgressView(value: 0.2) // [Isolated] Linear progress bar (static value) | [In-file] Visual indicator (progress not tracked)
                        .progressViewStyle(.linear) // [Isolated] Linear style | [In-file] Horizontal bar
                        .opacity(0.5) // [Isolated] Semi-transparent | [In-file] Not too prominent
                }
                .padding(.horizontal) // [Isolated] Horizontal padding | [In-file] Layout
                .padding(.vertical, 10) // [Isolated] Vertical padding | [In-file] Layout
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4)) // [Isolated] Faint background | [In-file] Visual grouping
                Divider() // [Isolated] Divider below progress | [In-file] Separation
            }
            
            if viewModel.actionHistory.isEmpty { // [Isolated] Show empty state if no history | [In-file] Fallback UI
                VStack(spacing: 16) { // [Isolated] Empty state content | [In-file] Icon and text
                    Image(systemName: "clock.arrow.circlepath") // [Isolated] Empty history icon | [In-file] SF Symbol
                        .font(.system(size: 48)) // [Isolated] Large icon | [In-file] For emphasis
                        .foregroundColor(.secondary.opacity(0.5)) // [Isolated] Faint color | [In-file] De-emphasize
                    Text("No actions taken yet") // [Isolated] Empty label | [In-file] Shown when no entries
                        .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] De-emphasize
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // [Isolated] Fill available space | [In-file] Centered
            } else { // [Isolated] Show history list if entries exist | [In-file] Main content
                ScrollView { // [Isolated] Scrollable area for entries | [In-file] Allows many items
                    LazyVStack(spacing: 0) { // [Isolated] Efficient vertical stack | [In-file] ForEach of entries
                        ForEach(Array(viewModel.actionHistory.reversed())) { entry in // [Isolated] Iterate reversed for newest first | [In-file] Each entry is a row
                            VStack(alignment: .leading, spacing: 8) { // [Isolated] Entry content | [In-file] Icon, title, details
                                HStack(spacing: 12) { // [Isolated] Main row: icon, title, time | [In-file] Layout
                                    Image(systemName: icon(for: entry.type)) // [Isolated] Entry icon by type | [In-file] Uses icon(for:)
                                        .foregroundColor(color(for: entry.type)) // [Isolated] Color by type | [In-file] Uses color(for:)
                                        .frame(width: 22) // [Isolated] Fixed icon width | [In-file] Aligns icons
                                    
                                    VStack(alignment: .leading, spacing: 2) { // [Isolated] Title and file name | [In-file] Stacked vertically
                                        Text(entry.title) // [Isolated] Main entry title | [In-file] Short description
                                            .font(.system(size: 13, weight: .semibold)) // [Isolated] Slightly bold | [In-file] For prominence
                                        if let fileName = entry.fileName { // [Isolated] Show file name if present | [In-file] Optional
                                            Text(fileName) // [Isolated] File name text | [In-file] Displayed below title
                                                .font(.caption) // [Isolated] Small font | [In-file] De-emphasize
                                                .foregroundColor(.secondary) // [Isolated] Faint color | [In-file] Less prominent
                                                .lineLimit(1) // [Isolated] Single line | [In-file] Prevent overflow
                                                .truncationMode(.middle) // [Isolated] Ellipsis in middle | [In-file] Show start/end
                                        }
                                    }
                                    
                                    Spacer() // [Isolated] Push timestamp right | [In-file] Layout
                                    
                                    Text(timestampFormatter.string(from: entry.timestamp)) // [Isolated] Entry timestamp | [In-file] Uses formatter above
                                        .font(.system(size: 11, weight: .medium)) // [Isolated] Small font | [In-file] For timestamps
                                        .foregroundColor(.secondary) // [Isolated] Faint color | [In-file] De-emphasize
                                }
                                
                                if hasMoreInfo(entry) { // [Isolated] Show disclosure if more info exists | [In-file] Uses hasMoreInfo(_:)
                                    DisclosureGroup(isExpanded: binding(for: entry.id)) { // [Isolated] Expandable details section | [In-file] Uses binding(for:)
                                        VStack(alignment: .leading, spacing: 4) { // [Isolated] Details content | [In-file] Details and folder
                                            if let details = entry.details, !details.isEmpty { // [Isolated] Show details if present | [In-file] Optional
                                                Text(details) // [Isolated] Details string | [In-file] User-readable info
                                                    .font(.system(size: 11)) // [Isolated] Small font | [In-file] De-emphasize
                                                    .foregroundColor(.secondary) // [Isolated] Faint color | [In-file] Less prominent
                                                    .textSelection(.enabled) // [Isolated] Allow copy | [In-file] macOS only
                                            }
                                            if let folderPath = entry.folderPath, !folderPath.isEmpty { // [Isolated] Show folder if present | [In-file] Optional
                                                Text("Folder: \(folderPath)") // [Isolated] Folder path label | [In-file] Shows full path
                                                    .font(.system(size: 11)) // [Isolated] Small font | [In-file] De-emphasize
                                                    .foregroundColor(.secondary) // [Isolated] Faint color | [In-file] Less prominent
                                                    .lineLimit(2) // [Isolated] Up to 2 lines | [In-file] Prevents overflow
                                                    .truncationMode(.middle) // [Isolated] Ellipsis in middle | [In-file] Show start/end
                                                    .textSelection(.enabled) // [Isolated] Allow copy | [In-file] macOS only
                                            }
                                        }
                                        .padding(.top, 2) // [Isolated] Top padding for details | [In-file] Layout
                                    } label: {
                                        Text("Details") // [Isolated] Disclosure label | [In-file] Shown when collapsed
                                            .font(.system(size: 11, weight: .semibold)) // [Isolated] Small bold font | [In-file] For label
                                            .foregroundColor(.secondary) // [Isolated] Faint color | [In-file] De-emphasize
                                    }
                                    .padding(.leading, 34) // [Isolated] Indent details | [In-file] Align with icons
                                }
                            }
                            .padding(.horizontal) // [Isolated] Row horizontal padding | [In-file] Layout
                            .padding(.vertical, 8) // [Isolated] Row vertical padding | [In-file] Layout
                            .background(HoverBackgroundView()) // [Isolated] Hover effect | [In-file] Uses HoverBackgroundView below
                            
                            Divider().padding(.leading, 48) // [Isolated] Divider after row, indented | [In-file] Visual separation
                        }
                    }
                    .padding(.vertical) // [Isolated] Top/bottom padding for list | [In-file] Layout
                }
            }
            
            if !viewModel.actionHistory.isEmpty { // [Isolated] Show footer if entries exist | [In-file] Reset and count
                Divider() // [Isolated] Divider above footer | [In-file] Visual separation
                HStack { // [Isolated] Footer row | [In-file] Reset button and count
                    Button(action: { // [Isolated] Reset session button | [In-file] Calls resetSession()
                        withAnimation { // [Isolated] Animate reset | [In-file] Smooth UI
                            viewModel.resetSession() // [Isolated] Undo all actions | [In-file] Calls view model
                        }
                    }) {
                        HStack { // [Isolated] Icon and label | [In-file] Trash + Reset Session
                            Image(systemName: "trash") // [Isolated] Trash icon | [In-file] SF Symbol
                            Text("Reset Session") // [Isolated] Button label | [In-file] Action
                        }
                        .foregroundColor(.red) // [Isolated] Red color for destructive | [In-file] Visual cue
                    }
                    .buttonStyle(.plain) // [Isolated] Plain style | [In-file] No border
                    
                    Spacer() // [Isolated] Push count right | [In-file] Layout
                    
                    Text("\(viewModel.actionHistory.count) log entries") // [Isolated] Entry count | [In-file] Shown at bottom right
                        .font(.caption) // [Isolated] Small font | [In-file] De-emphasize
                        .foregroundColor(.secondary) // [Isolated] Faint color | [In-file] Less prominent
                }
                .padding() // [Isolated] Footer padding | [In-file] Layout
                .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow)) // [Isolated] Translucent macOS footer | [In-file] VisualEffectView
            }
        }
        .frame(width: 360, height: 500) // [Isolated] Fixed sheet size | [In-file] Consistent sizing
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow)) // [Isolated] Popover background | [In-file] VisualEffectView
    }
    
    /// Returns a Binding<Bool> for whether the disclosure for the given entry is expanded.
    /// - Parameter id: The UUID of the history entry.
    /// - Returns: Binding<Bool> for DisclosureGroup expansion.
    private func binding(for id: UUID) -> Binding<Bool> { // [Isolated] Per-entry disclosure binding | [In-file] Used by DisclosureGroup
        Binding(
            get: { expandedRows.contains(id) }, // [Isolated] True if expandedRows contains id | [In-file] Entry is expanded
            set: { isExpanded in // [Isolated] Update expandedRows on change | [In-file] Toggle expansion
                if isExpanded {
                    expandedRows.insert(id) // [Isolated] Insert id if expanding | [In-file] Add to expandedRows
                } else {
                    expandedRows.remove(id) // [Isolated] Remove id if collapsing | [In-file] Remove from expandedRows
                }
            }
        )
    }
    
    /// Returns true if the entry has details or folderPath to show in disclosure.
    /// - Parameter entry: The history entry.
    /// - Returns: Bool indicating if disclosure should be shown.
    private func hasMoreInfo(_ entry: DeclutterViewModel.HistoryEntry) -> Bool { // [Isolated] Checks if entry has details/folder | [In-file] Used to show DisclosureGroup
        let hasDetails = !(entry.details?.isEmpty ?? true) // [Isolated] True if details exists and not empty | [In-file] For disclosure
        let hasFolder = !(entry.folderPath?.isEmpty ?? true) // [Isolated] True if folderPath exists and not empty | [In-file] For disclosure
        return hasDetails || hasFolder // [Isolated] True if either present | [In-file] Used in body
    }
    
    /// Returns the SF Symbol name for the entry type.
    /// - Parameter type: EntryType of the history entry.
    /// - Returns: SF Symbol name string.
    private func icon(for type: DeclutterViewModel.HistoryEntry.EntryType) -> String { // [Isolated] Maps entry type to SF Symbol | [In-file] Used for icon
        switch type {
        case .fileAction: return "square.and.pencil" // [Isolated] File action icon | [In-file] File operation
        case .undo: return "arrow.uturn.backward.circle.fill" // [Isolated] Undo icon | [In-file] Undo operation
        case .redo: return "arrow.uturn.forward.circle.fill" // [Isolated] Redo icon | [In-file] Redo operation
        case .ui: return "cursorarrow.click.2" // [Isolated] UI event icon | [In-file] User interaction
        }
    }
    
    /// Returns the color for the entry type.
    /// - Parameter type: EntryType of the history entry.
    /// - Returns: Color for the icon.
    private func color(for type: DeclutterViewModel.HistoryEntry.EntryType) -> Color { // [Isolated] Maps entry type to color | [In-file] Used for icon color
        switch type {
        case .fileAction: return .blue // [Isolated] Blue for file actions | [In-file] Emphasize
        case .undo: return .orange // [Isolated] Orange for undo | [In-file] Warning/caution
        case .redo: return .green // [Isolated] Green for redo | [In-file] Success
        case .ui: return .secondary // [Isolated] Secondary color for UI | [In-file] De-emphasize
        }
    }
}

struct HoverBackgroundView: View { // [Isolated] Adds hover effect background for rows | [In-file] Used in history entry rows
    @State private var isHovered = false // [Isolated] Tracks hover state | [In-file] Used to change background color
    var body: some View { // [Isolated] View body | [In-file] Returns background color
        Color(nsColor: isHovered ? .quaternaryLabelColor : .clear) // [Isolated] Faint color on hover | [In-file] macOS system color
            .onHover { isHovered = $0 } // [Isolated] Updates isHovered on mouse enter/exit | [In-file] SwiftUI onHover
    }
}



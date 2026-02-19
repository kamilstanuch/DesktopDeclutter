
//  SettingsView.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  A modal settings screen for configuring cloud destinations (add/remove/set active) and
//  general preferences (immediate trashing and scan folder).
//
//  Unique characteristics
//  ----------------------
//  - Uses `@Binding` to dismiss itself from the presenting scene.
//  - Reads/writes view model settings (immediate binning) via a computed Binding to keep
//    SettingsView decoupled from storage.
//  - Uses `CloudManager.shared` as a `@StateObject` to keep destination list reactive.
//  - Uses `NSOpenPanel` and `NSAlert` for cloud folder selection and validation.
//  - Canonicalizes cloud URLs and checks writability before adding a destination.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  - SwiftUI core: https://developer.apple.com/documentation/swiftui
//  - View protocol: https://developer.apple.com/documentation/swiftui/view
//  - @Binding: https://developer.apple.com/documentation/swiftui/binding
//  - @ObservedObject: https://developer.apple.com/documentation/swiftui/observedobject
//  - @StateObject: https://developer.apple.com/documentation/swiftui/stateobject
//  - Layout:
//      - VStack: https://developer.apple.com/documentation/swiftui/vstack
//      - HStack: https://developer.apple.com/documentation/swiftui/hstack
//      - Spacer: https://developer.apple.com/documentation/swiftui/spacer
//      - Divider: https://developer.apple.com/documentation/swiftui/divider
//      - ScrollView: https://developer.apple.com/documentation/swiftui/scrollview
//  - Text/images/styling:
//      - Text: https://developer.apple.com/documentation/swiftui/text
//      - Image: https://developer.apple.com/documentation/swiftui/image
//      - Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//      - Font: https://developer.apple.com/documentation/swiftui/font
//      - Color: https://developer.apple.com/documentation/swiftui/color
//      - background: https://developer.apple.com/documentation/swiftui/view/background(_:alignment:)
//      - overlay: https://developer.apple.com/documentation/swiftui/view/overlay(alignment:content:)
//      - cornerRadius: https://developer.apple.com/documentation/swiftui/view/cornerradius(_:antialiased:)
//      - foregroundColor: https://developer.apple.com/documentation/swiftui/view/foregroundcolor(_:)
//      - lineLimit: https://developer.apple.com/documentation/swiftui/view/linelimit(_:)
//      - truncationMode: https://developer.apple.com/documentation/swiftui/view/truncationmode(_:)
//      - frame: https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:)
//      - padding: https://developer.apple.com/documentation/swiftui/view/padding(_:)
//  - Controls:
//      - Button: https://developer.apple.com/documentation/swiftui/button
//      - Toggle: https://developer.apple.com/documentation/swiftui/toggle
//      - toggleStyle: https://developer.apple.com/documentation/swiftui/view/togglestyle(_:)
//  - List rendering:
//      - ForEach: https://developer.apple.com/documentation/swiftui/foreach
//  - UniformTypeIdentifiers (imported)
//      - https://developer.apple.com/documentation/uniformtypeidentifiers
//  - AppKit:
//      - AppKit: https://developer.apple.com/documentation/appkit
//      - NSOpenPanel: https://developer.apple.com/documentation/appkit/nsopenpanel
//      - NSAlert: https://developer.apple.com/documentation/appkit/nsalert
//      - NSApplication (NSApp.activate): https://developer.apple.com/documentation/appkit/nsapplication
//  - Foundation:
//      - FileManager: https://developer.apple.com/documentation/foundation/filemanager
//      - URL: https://developer.apple.com/documentation/foundation/url
//  - SF Symbols:
//      - https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//
//  NOTE: Uses internal types DeclutterViewModel, CloudManager, CloudDestination, CloudProvider, VisualEffectView

import SwiftUI // [Isolated] SwiftUI for UI components | [In-file] Used for all SwiftUI views and modifiers
import UniformTypeIdentifiers // [Isolated] For UTType checks | [In-file] Used for cloud provider validation
import AppKit // [Isolated] For NSOpenPanel, NSAlert | [In-file] Used for folder selection and alerts

struct SettingsView: View { // [Isolated] Main settings modal | [In-file] Root view for settings screen
    @Binding var isPresented: Bool // [Isolated] Controls modal presentation | [In-file] Bound to parent to dismiss view
    @ObservedObject var viewModel: DeclutterViewModel // [Isolated] View model for general prefs | [In-file] Provides settings state
    @StateObject private var cloudManager = CloudManager.shared // [Isolated] Shared cloud manager | [In-file] Reactive cloud destinations
    
    init(isPresented: Binding<Bool>, viewModel: DeclutterViewModel) { // [Isolated] Custom init for bindings | [In-file] Assigns _isPresented binding and viewModel
        self._isPresented = isPresented // [Isolated] Store modal binding | [In-file] Required for two-way binding
        self.viewModel = viewModel // [Isolated] Store view model | [In-file] Used for general preferences
    }
    
    var body: some View { // [Isolated] Main view body | [In-file] Lays out modal content
        VStack(spacing: 0) { // [Isolated] Vertical layout | [In-file] Stacks header and content
            headerView // [Isolated] Modal header | [In-file] Contains title and Done button
            Divider() // [Isolated] Separates header | [In-file] Visual division
            
            ScrollView { // [Isolated] Scrollable content | [In-file] Allows for overflow
                VStack(alignment: .leading, spacing: 20) { // [Isolated] Section layout | [In-file] Stacks cloud and general sections
                    cloudDestinationsSection // [Isolated] Cloud section | [In-file] List of cloud folders
                    Divider() // [Isolated] Section divider | [In-file] Separates cloud/general
                    generalPreferencesSection // [Isolated] General section | [In-file] Toggles and actions
                }
                .padding(20) // [Isolated] Section padding | [In-file] Adds space inside scroll area
            }
        }
        .frame(width: 500, height: 600) // [Isolated] Modal size | [In-file] Fixed dimensions for modal
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow)) // [Isolated] Blurred background | [In-file] macOS popover appearance
    }
    
    private var headerView: some View { // [Isolated] Header subview | [In-file] Contains modal title and Done button
        HStack { // [Isolated] Horizontal layout | [In-file] Aligns title and button
            Text("Settings") // [Isolated] Modal title | [In-file] Shown at top
                .font(.headline) // [Isolated] Title font | [In-file] Emphasizes header
            Spacer() // [Isolated] Pushes button right | [In-file] Flexible space
            Button("Done") { isPresented = false } // [Isolated] Dismiss button | [In-file] Closes modal on tap
                .buttonStyle(.borderedProminent) // [Isolated] Prominent style | [In-file] Visually distinct
        }
        .padding() // [Isolated] Header padding | [In-file] Adds space around header
        .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow)) // [Isolated] Header blur | [In-file] Distinct background for header
    }
    
    private var cloudDestinationsSection: some View { // [Isolated] Cloud destinations section | [In-file] Lists all cloud destinations and add button
        VStack(alignment: .leading, spacing: 12) { // [Isolated] Vertical list | [In-file] Cloud section content
            Text("Cloud Destinations") // [Isolated] Section label | [In-file] Describes section
                .font(.system(size: 13, weight: .semibold)) // [Isolated] Small header font | [In-file] Section emphasis
                .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Less prominent
            
            if cloudManager.destinations.isEmpty { // [Isolated] Show empty state | [In-file] No destinations message
                Text("No cloud folders connected.") // [Isolated] No destinations label | [In-file] Empty state message
                    .foregroundColor(.secondary) // [Isolated] Subtle color | [In-file] Less prominent
                    .italic() // [Isolated] Italic style | [In-file] Emphasizes empty state
                    .padding(.vertical, 8) // [Isolated] Adds vertical space | [In-file] Padding for empty state
            } else {
                ForEach(cloudManager.destinations) { dest in // [Isolated] List all destinations | [In-file] Renders each destination row
                    destinationRow(for: dest) // [Isolated] Row for destination | [In-file] Shows info and actions
                }
            }
            
            Button(action: addNewDestination) { // [Isolated] Add destination button | [In-file] Opens folder picker for new cloud folder
                HStack { // [Isolated] Button content | [In-file] Icon and label
                    Image(systemName: "plus.circle.fill") // [Isolated] Plus icon | [In-file] Visual indicator for add
                    Text("Add Destination") // [Isolated] Button text | [In-file] Describes action
                }
                .frame(maxWidth: .infinity) // [Isolated] Full width | [In-file] Expands button
                .padding(.vertical, 8) // [Isolated] Button padding | [In-file] Touch target size
                .background(Color(nsColor: .controlBackgroundColor)) // [Isolated] Button background | [In-file] Matches system controls
                .cornerRadius(8) // [Isolated] Rounded corners | [In-file] Consistent with rows
            }
            .buttonStyle(.plain) // [Isolated] No border | [In-file] Custom button appearance
        }
    }
    
    private func destinationRow(for dest: CloudDestination) -> some View { // [Isolated] Single destination row | [In-file] Shows destination info and actions
        HStack { // [Isolated] Row layout | [In-file] Icon, info, actions
            Image(systemName: dest.provider.iconName) // [Isolated] Provider icon | [In-file] SF Symbol for provider
                .foregroundColor(.blue) // [Isolated] Icon color | [In-file] Distinguishes provider
                .font(.title3) // [Isolated] Icon size | [In-file] Visual prominence
            
            VStack(alignment: .leading, spacing: 2) { // [Isolated] Info stack | [In-file] Name and path
                Text(dest.name) // [Isolated] Folder name | [In-file] Displayed as row title
                    .font(.system(size: 14, weight: .medium)) // [Isolated] Row title font | [In-file] Emphasizes name
                Text(dest.path) // [Isolated] Folder path | [In-file] Shows full path
                    .font(.caption) // [Isolated] Small font | [In-file] De-emphasized
                    .foregroundColor(.secondary) // [Isolated] Subtle color | [In-file] Less prominent
                    .lineLimit(1) // [Isolated] Truncate long paths | [In-file] Single line
                    .truncationMode(.middle) // [Isolated] Middle ellipsis | [In-file] Keeps start/end visible
            }
            
            Spacer() // [Isolated] Pushes actions right | [In-file] Flexible space
            
            if cloudManager.activeDestinationId == dest.id { // [Isolated] Active destination | [In-file] Shows checkmark if active
                Image(systemName: "checkmark.circle.fill") // [Isolated] Active indicator | [In-file] Green check for active
                    .foregroundColor(.green) // [Isolated] Success color | [In-file] Visual cue for active
            } else {
                Button("Set Active") { // [Isolated] Set active button | [In-file] Makes this destination active
                    cloudManager.setActive(dest.id) // [Isolated] Set as active | [In-file] Updates active destination
                }
                .buttonStyle(.plain) // [Isolated] No border | [In-file] Custom button style
                .foregroundColor(.blue) // [Isolated] Action color | [In-file] Indicates interactivity
            }
            
            Button(action: {
                cloudManager.removeDestination(id: dest.id) // [Isolated] Remove destination | [In-file] Deletes this cloud folder
            }) {
                Image(systemName: "trash") // [Isolated] Delete icon | [In-file] Trash symbol
                    .foregroundColor(.secondary) // [Isolated] Subtle icon | [In-file] Less prominent
            }
            .buttonStyle(.plain) // [Isolated] No border | [In-file] Custom button style
            .padding(.leading, 8) // [Isolated] Space before delete | [In-file] Separates from Set Active
        }
        .padding() // [Isolated] Row padding | [In-file] Space inside row
        .background(Color(nsColor: .controlBackgroundColor)) // [Isolated] Row background | [In-file] Matches button backgrounds
        .cornerRadius(8) // [Isolated] Rounded corners | [In-file] Consistent styling
        .overlay( // [Isolated] Row border | [In-file] Blue if active, gray otherwise
            RoundedRectangle(cornerRadius: 8)
                .stroke(cloudManager.activeDestinationId == dest.id ? Color.blue.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
        )
    }
    
    private var generalPreferencesSection: some View { // [Isolated] General preferences section | [In-file] Toggles and actions for general settings
        VStack(alignment: .leading, spacing: 12) { // [Isolated] Vertical list | [In-file] General section content
            Text("General") // [Isolated] Section label | [In-file] Describes general settings
                .font(.system(size: 13, weight: .semibold)) // [Isolated] Small header font | [In-file] Section emphasis
                .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Less prominent
            
            Toggle("Trash Immediately", isOn: Binding( // [Isolated] Trash toggle | [In-file] Controls immediate binning
                get: { viewModel.immediateBinning }, // [Isolated] Read value from viewModel | [In-file] Keeps UI in sync
                set: { viewModel.immediateBinning = $0 } // [Isolated] Write value to viewModel | [In-file] Updates setting
            ))
            .toggleStyle(.switch) // [Isolated] Switch style | [In-file] Standard toggle appearance
            
            Text("Files are moved to trash immediately instead of queued.") // [Isolated] Toggle description | [In-file] Explains toggle effect
                .font(.caption) // [Isolated] Small font | [In-file] De-emphasized
                .foregroundColor(.secondary) // [Isolated] Subtle color | [In-file] Less prominent
            
            Divider().padding(.vertical, 8) // [Isolated] Section divider | [In-file] Space before scan folder
            
            Button("Change Scan Folder...") { // [Isolated] Change folder button | [In-file] Prompts for new scan folder
                viewModel.promptForFolderAndLoad { didSelect in // [Isolated] Calls viewModel method | [In-file] Handles folder picker
                    if didSelect {
                        isPresented = false // [Isolated] Dismiss modal if changed | [In-file] Closes settings on success
                    }
                }
            }
        }
    }
    
    private func addNewDestination() { // [Isolated] Add new cloud destination | [In-file] Handles folder picker and validation
        let panel = NSOpenPanel() // [Isolated] Create open panel | [In-file] Used to select cloud folder
        panel.canChooseFiles = false // [Isolated] Only directories | [In-file] Prevents file selection
        panel.canChooseDirectories = true // [Isolated] Allow directories | [In-file] Only folders can be chosen
        panel.allowsMultipleSelection = false // [Isolated] Single selection | [In-file] Only one folder at a time
        panel.prompt = "Connect Cloud Folder" // [Isolated] Custom prompt | [In-file] Button text on panel
        panel.message = "Select a local request folder for your cloud provider (e.g. iCloud Drive, Google Drive)" // [Isolated] Panel message | [In-file] User guidance
        panel.level = .floating // [Isolated] Floating panel | [In-file] Stays above other windows
        panel.isFloatingPanel = true // [Isolated] Floating behavior | [In-file] Ensures panel stays on top
        
        NSApp.activate(ignoringOtherApps: true) // [Isolated] Bring app to front | [In-file] Ensures panel is visible
        panel.makeKeyAndOrderFront(nil) // [Isolated] Show panel | [In-file] Presents folder picker
        
        if panel.runModal() == .OK, let url = panel.url { // [Isolated] User selected folder | [In-file] Proceed if selection made
            guard let provider = cloudManager.isValidCloudDirectory(url) else { // [Isolated] Validate provider | [In-file] Only allow supported cloud folders
                let alert = NSAlert() // [Isolated] Show error alert | [In-file] Only cloud folders allowed
                alert.messageText = "Choose a cloud folder" // [Isolated] Alert title | [In-file] User feedback
                alert.informativeText = "Only cloud folders (iCloud Drive, Google Drive, or other CloudStorage providers) can be added here." // [Isolated] Alert message | [In-file] More detail
                alert.alertStyle = .warning // [Isolated] Warning style | [In-file] Visual warning
                alert.addButton(withTitle: "OK") // [Isolated] OK button | [In-file] Dismisses alert
                alert.runModal() // [Isolated] Show alert | [In-file] Blocks until dismissed
                return // [Isolated] Stop if invalid | [In-file] No further action
            }

            let canonicalURL = cloudManager.canonicalCloudURL(for: url, provider: provider) ?? url // [Isolated] Canonicalize URL | [In-file] Ensures correct folder path
            var isDirectory: ObjCBool = false // [Isolated] Directory check | [In-file] Used to verify folder
            if !FileManager.default.fileExists(atPath: canonicalURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue { // [Isolated] Ensure exists and is dir | [In-file] Only writable folders allowed
                let alert = NSAlert() // [Isolated] Show error alert | [In-file] Folder not writable or not a directory
                alert.messageText = "Choose a writable cloud folder" // [Isolated] Alert title | [In-file] User feedback
                alert.informativeText = "Google Drive requires a writable folder like “My Drive”. Please choose a folder you can write to." // [Isolated] Alert message | [In-file] More detail
                alert.alertStyle = .warning // [Isolated] Warning style | [In-file] Visual warning
                alert.addButton(withTitle: "OK") // [Isolated] OK button | [In-file] Dismisses alert
                alert.runModal() // [Isolated] Show alert | [In-file] Blocks until dismissed
                return // [Isolated] Stop if not writable | [In-file] No further action
            }

            let confirm = NSAlert() // [Isolated] Confirmation dialog | [In-file] Ask user to confirm setup
            confirm.messageText = "Set up this cloud folder?" // [Isolated] Confirm title | [In-file] User prompt
            confirm.informativeText = "DesktopDeclutter will create a “DesktopDeclutter” folder inside this location and move files into it." // [Isolated] Confirm message | [In-file] Explains action
            confirm.alertStyle = .informational // [Isolated] Info style | [In-file] Less alarming
            confirm.addButton(withTitle: "Set Up") // [Isolated] Confirm button | [In-file] Accept action
            confirm.addButton(withTitle: "Cancel") // [Isolated] Cancel button | [In-file] Abort action

            if confirm.runModal() == .alertFirstButtonReturn { // [Isolated] User confirmed setup | [In-file] Proceed to validate writability
                switch cloudManager.validateDestinationWritable(canonicalURL) { // [Isolated] Check folder writable | [In-file] Ensures can write files
                case .success:
                    break // [Isolated] Folder is writable | [In-file] Continue to add
                case .failure:
                    let alert = NSAlert() // [Isolated] Show error alert | [In-file] Folder not writable
                    alert.messageText = "This folder isn’t writable" // [Isolated] Alert title | [In-file] User feedback
                    alert.informativeText = "Google Drive requires a writable folder like “My Drive”. Please choose a folder you can write to." // [Isolated] Alert message | [In-file] More detail
                    alert.alertStyle = .warning // [Isolated] Warning style | [In-file] Visual warning
                    alert.addButton(withTitle: "OK") // [Isolated] OK button | [In-file] Dismisses alert
                    alert.runModal() // [Isolated] Show alert | [In-file] Blocks until dismissed
                    return // [Isolated] Stop if not writable | [In-file] No further action
                }
                let name = canonicalURL.lastPathComponent // [Isolated] Use folder name | [In-file] For destination display
                cloudManager.addDestination(name: name, url: canonicalURL, provider: provider) // [Isolated] Add destination | [In-file] Registers new cloud folder
            }
        }
    }
}



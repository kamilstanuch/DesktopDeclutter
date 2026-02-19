
//  GalleryGridView.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  A grid-based browsing mode for `filteredFiles` that supports multi-select, hover affordances, Quick Look previews, and bulk actions (Keep/Cloud/Move/Bin).
//
//  Unique characteristics
//  ----------------------
//  - Maintains a Set<UUID> selection model with Select All / Deselect All.
//  - ScrollViewReader keeps the current file centered when viewModel.currentFile changes.
//  - Uses FileGridCard for each item and forwards hover/shake state.
//  - Provides a bottom action bar that conditionally appears when selection is non-empty.
//  - Cloud action adapts to 0/1/many destinations using Button vs Menu vs Settings prompt.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  - SwiftUI: https://developer.apple.com/documentation/swiftui
//  - View: https://developer.apple.com/documentation/swiftui/view
//  - @ObservedObject: https://developer.apple.com/documentation/swiftui/observedobject
//  - @StateObject: https://developer.apple.com/documentation/swiftui/stateobject
//  - @State: https://developer.apple.com/documentation/swiftui/state
//  - Layout:
//      - VStack: https://developer.apple.com/documentation/swiftui/vstack
//      - HStack: https://developer.apple.com/documentation/swiftui/hstack
//      - Spacer: https://developer.apple.com/documentation/swiftui/spacer
//      - Divider: https://developer.apple.com/documentation/swiftui/divider
//      - ScrollView: https://developer.apple.com/documentation/swiftui/scrollview
//      - ScrollViewReader: https://developer.apple.com/documentation/swiftui/scrollviewreader
//      - ScrollViewProxy: https://developer.apple.com/documentation/swiftui/scrollviewproxy
//      - LazyVGrid: https://developer.apple.com/documentation/swiftui/lazyvgrid
//      - GridItem: https://developer.apple.com/documentation/swiftui/griditem
//      - ForEach: https://developer.apple.com/documentation/swiftui/foreach
//  - Controls:
//      - Button: https://developer.apple.com/documentation/swiftui/button
//      - Menu: https://developer.apple.com/documentation/swiftui/menu
//      - buttonStyle: https://developer.apple.com/documentation/swiftui/view/buttonstyle(_:)
//      - disabled: https://developer.apple.com/documentation/swiftui/view/disabled(_:)
//      - help: https://developer.apple.com/documentation/swiftui/view/help(_:)
//  - Text/images:
//      - Text: https://developer.apple.com/documentation/swiftui/text
//      - Image: https://developer.apple.com/documentation/swiftui/image
//      - Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//      - Font: https://developer.apple.com/documentation/swiftui/font
//  - Styling:
//      - Color: https://developer.apple.com/documentation/swiftui/color
//      - Capsule: https://developer.apple.com/documentation/swiftui/capsule
//      - background: https://developer.apple.com/documentation/swiftui/view/background(_:alignment:)
//      - foregroundColor: https://developer.apple.com/documentation/swiftui/view/foregroundcolor(_:)
//      - opacity: https://developer.apple.com/documentation/swiftui/view/opacity(_:)
//      - padding: https://developer.apple.com/documentation/swiftui/view/padding(_:)
//  - Animation/gesture:
//      - withAnimation: https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
//      - onChange: https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:)
//      - simultaneousGesture: https://developer.apple.com/documentation/swiftui/view/simultaneousgesture(_:)
//      - TapGesture: https://developer.apple.com/documentation/swiftui/tapgesture
//  - AppKit:
//      - AppKit: https://developer.apple.com/documentation/appkit
//      - NSAlert: https://developer.apple.com/documentation/appkit/nsalert
//  - SF Symbols:
//      - https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//
//  NOTE: Uses internal types:
//  - DeclutterViewModel, DesktopFile
//  - CloudManager, CloudDestination
//  - FileGridCard
//  - VisualEffectView
//  - QuickLookHelper

import SwiftUI // [Isolated] Import SwiftUI for declarative UI | [In-file] Used throughout for all UI elements
import AppKit // [Isolated] Import AppKit for macOS alerts | [In-file] Used in promptToConfigureCloud()


struct GalleryGridView: View { // [Isolated] Main view struct | [In-file] Declares GalleryGridView
    @ObservedObject var viewModel: DeclutterViewModel // [Isolated] View model for state and actions | [In-file] Required for file data and selection
    let onRequestOpenSettings: () -> Void // [Isolated] Callback to open settings | [In-file] Used by cloud config prompt
    @StateObject private var cloudManager = CloudManager.shared // [Isolated] Shared cloud manager instance | [In-file] Used for cloud destinations and actions
    @State private var selectedFiles: Set<UUID> = [] // [Isolated] Set of selected file UUIDs | [In-file] Used for multi-selection model
    @State private var hoveredFileId: UUID? = nil // [Isolated] Hovered file UUID | [In-file] Used to show hover state in grid

    private func promptToConfigureCloud() { // [Isolated] Prompts user to configure cloud | [In-file] Used when no cloud destinations exist
        let alert = NSAlert() // [Isolated] Create alert | [In-file] AppKit modal dialog
        alert.messageText = "Cloud destination not set up" // [Isolated] Set alert title | [In-file] Informs user of missing config
        alert.informativeText = "Would you like to open Settings and connect a cloud folder now?" // [Isolated] Set alert message | [In-file] Prompts user to open settings
        alert.alertStyle = .informational // [Isolated] Set style to informational | [In-file] Standard info dialog
        alert.addButton(withTitle: "Open Settings") // [Isolated] Add positive button | [In-file] Triggers settings callback
        alert.addButton(withTitle: "Not Now") // [Isolated] Add cancel button | [In-file] Dismisses dialog
        let response = alert.runModal() // [Isolated] Run modal and get response | [In-file] Blocks until user responds
        if response == .alertFirstButtonReturn { // [Isolated] Check if user chose "Open Settings" | [In-file] Only trigger callback if first button pressed
            onRequestOpenSettings() // [Isolated] Call settings callback | [In-file] Opens app settings for cloud config
        }
    }
    
    var body: some View { // [Isolated] Main view body | [In-file] Declares all UI
        VStack(spacing: 0) { // [Isolated] Vertical stack for layout | [In-file] Contains header, grid, and footer
            HStack { // [Isolated] Header row | [In-file] Shows title and selection controls
                VStack(alignment: .leading, spacing: 4) { // [Isolated] Title and subtitle stack | [In-file] Shows view name and item count
                    Text("Gallery View") // [Isolated] Section title | [In-file] Static label
                        .font(.system(size: 18, weight: .semibold)) // [Isolated] Large font for title | [In-file] Styling
                    Text("\(viewModel.filteredFiles.count) items in current folder") // [Isolated] Item count label | [In-file] Shows number of filtered files
                        .font(.system(size: 12)) // [Isolated] Smaller font | [In-file] Styling
                        .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Styling
                }
                
                Spacer() // [Isolated] Push controls right | [In-file] Layout
                
                Button(action: { // [Isolated] Select All / Deselect All | [In-file] Toggles all selection state
                    if selectedFiles.count == viewModel.filteredFiles.count { // [Isolated] If all selected | [In-file] Deselect all
                        selectedFiles.removeAll() // [Isolated] Clear selection set | [In-file] Deselect all files
                    } else { // [Isolated] Not all selected | [In-file] Select all
                        selectedFiles = Set(viewModel.filteredFiles.map { $0.id }) // [Isolated] Select all IDs | [In-file] Bulk select
                    }
                }) {
                    Text(selectedFiles.count == viewModel.filteredFiles.count && !viewModel.filteredFiles.isEmpty ? "Deselect All" : "Select All") // [Isolated] Button label adapts to selection | [In-file] Shows correct label
                        .font(.system(size: 12, weight: .medium)) // [Isolated] Button font | [In-file] Styling
                        .foregroundColor(.blue) // [Isolated] Button color | [In-file] Styling
                }
                .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] No border
                .disabled(viewModel.filteredFiles.isEmpty) // [Isolated] Disable if no files | [In-file] Prevents action
            }
            .padding() // [Isolated] Header padding | [In-file] Spacing
            .background { // [Isolated] Header background | [In-file] VisualEffectView for macOS blur
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow) // [Isolated] Sidebar material | [In-file] Consistent with app theme
            }
            
            Divider().opacity(0.2) // [Isolated] Divider below header | [In-file] Subtle separation
            
            ScrollViewReader { proxy in // [Isolated] Enables programmatic scroll | [In-file] Used to focus current file
                ScrollView { // [Isolated] Main scrollable area | [In-file] Contains file grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) { // [Isolated] Adaptive grid layout | [In-file] Responsive grid of file cards
                        ForEach(viewModel.filteredFiles) { file in // [Isolated] Iterate filtered files | [In-file] Render each file as card
                            FileGridCard( // [Isolated] File card view | [In-file] Shows file thumbnail, selection, hover, shake
                                file: file, // [Isolated] Pass file data | [In-file] Used by card
                                isSelected: selectedFiles.contains(file.id), // [Isolated] Pass selection state | [In-file] Highlights card if selected
                                isHovered: hoveredFileId == file.id, // [Isolated] Pass hover state | [In-file] Shows affordance on hover
                                isShaking: viewModel.shakingFileId == file.id, // [Isolated] Pass shake state | [In-file] Animates card if shaking
                                onToggle: { // [Isolated] Toggle selection handler | [In-file] Updates selection set
                                    if selectedFiles.contains(file.id) { // [Isolated] If already selected | [In-file] Deselect
                                        selectedFiles.remove(file.id) // [Isolated] Remove from selection | [In-file] Deselect file
                                    } else { // [Isolated] Not selected | [In-file] Select file
                                        selectedFiles.insert(file.id) // [Isolated] Add to selection | [In-file] Select file
                                    }
                                    viewModel.stopShake() // [Isolated] Stop shaking on interaction | [In-file] Resets shake state
                                },
                                onPreview: { // [Isolated] Quick Look preview handler | [In-file] Triggers Quick Look for file
                                    QuickLookHelper.shared.preview(url: file.url) // [Isolated] Show preview | [In-file] Uses shared helper
                                },
                                onHover: { hovering in // [Isolated] Hover handler | [In-file] Sets hovered file ID
                                    hoveredFileId = hovering ? file.id : nil // [Isolated] Set or clear hover | [In-file] Used for hover affordance
                                }
                            )
                            .id(file.id) // [Isolated] Set ID for scroll | [In-file] Enables scrollTo
                        }
                    }
                    .padding() // [Isolated] Grid padding | [In-file] Spacing around grid
                }
                .onChange(of: viewModel.currentFile?.id) { _ in // [Isolated] React to current file change | [In-file] Scrolls to focused file
                    if let file = viewModel.currentFile { // [Isolated] If there's a current file | [In-file] Only scroll if exists
                        withAnimation { // [Isolated] Animate scroll | [In-file] Smooth transition
                            proxy.scrollTo(file.id, anchor: .center) // [Isolated] Center current file | [In-file] Focuses file in view
                        }
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded { _ in // [Isolated] Tap gesture to stop shake | [In-file] Resets shake state on background tap
                viewModel.stopShake() // [Isolated] Call stopShake | [In-file] Resets state
            })
            
            if !selectedFiles.isEmpty { // [Isolated] Show footer actions if selection exists | [In-file] Conditional bottom bar
                VStack(spacing: 0) { // [Isolated] Footer stack | [In-file] Contains divider and action bar
                    Divider().opacity(0.2) // [Isolated] Divider above actions | [In-file] Subtle separation
                    HStack(spacing: 16) { // [Isolated] Action button row | [In-file] Contains all bulk actions
                        Button(action: { // [Isolated] Keep selected files | [In-file] Calls VM keepGroupFiles
                            let filesToKeep = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) } // [Isolated] Filter selected files | [In-file] Get DesktopFile objects
                            viewModel.logInterfaceEvent("Gallery keep selected button clicked", details: "\(filesToKeep.count) selected") // [Isolated] Log event | [In-file] Analytics
                            viewModel.keepGroupFiles(filesToKeep) // [Isolated] Call VM keep | [In-file] Keep group action
                            selectedFiles.removeAll() // [Isolated] Clear selection | [In-file] Reset after action
                        }) {
                            HStack(spacing: 6) { // [Isolated] Button label | [In-file] Icon + text
                                Image(systemName: "checkmark.circle.fill") // [Isolated] Keep icon | [In-file] SF Symbol
                                Text("Keep Selected (\(selectedFiles.count))") // [Isolated] Show count | [In-file] Dynamic label
                            }
                            .font(.system(size: 13, weight: .semibold)) // [Isolated] Button font | [In-file] Styling
                            .foregroundColor(.white) // [Isolated] Button text color | [In-file] Styling
                            .padding(.horizontal, 16) // [Isolated] Button padding | [In-file] Spacing
                            .padding(.vertical, 8) // [Isolated] Button padding | [In-file] Spacing
                            .background(Capsule().fill(Color.green)) // [Isolated] Green capsule background | [In-file] Styling
                        }
                        .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] No border
                        
                        Spacer() // [Isolated] Push next buttons apart | [In-file] Layout

                        if cloudManager.destinations.count > 1 { // [Isolated] Multiple cloud destinations | [In-file] Use Menu for selection
                            Menu { // [Isolated] Cloud destination menu | [In-file] Allows picking destination
                                ForEach(cloudManager.destinations) { dest in // [Isolated] List all destinations | [In-file] One button per destination
                                    Button(cloudManager.destinationDisplayName(dest)) { // [Isolated] Destination button | [In-file] Label with name
                                        let filesToMove = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) } // [Isolated] Get selected files | [In-file] Prepare for move
                                        viewModel.logInterfaceEvent("Gallery cloud destination picked", details: cloudManager.destinationDisplayName(dest)) // [Isolated] Log pick event | [In-file] Analytics
                                        viewModel.moveGroupToCloud(filesToMove, destination: dest) // [Isolated] Move files to dest | [In-file] Bulk move
                                        selectedFiles.removeAll() // [Isolated] Clear selection | [In-file] Reset after action
                                    }
                                }
                            } label: { // [Isolated] Menu label | [In-file] Icon + text
                                HStack(spacing: 6) {
                                    Image(systemName: "icloud.and.arrow.up.fill") // [Isolated] Cloud icon | [In-file] SF Symbol
                                    Text("Cloud (\(selectedFiles.count))") // [Isolated] Show count | [In-file] Dynamic label
                                }
                                .font(.system(size: 13, weight: .semibold)) // [Isolated] Button font | [In-file] Styling
                                .foregroundColor(.white) // [Isolated] Button text color | [In-file] Styling
                                .padding(.horizontal, 16) // [Isolated] Button padding | [In-file] Spacing
                                .padding(.vertical, 8) // [Isolated] Button padding | [In-file] Spacing
                                .background(Capsule().fill(Color.blue)) // [Isolated] Blue capsule background | [In-file] Styling
                            }
                            .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] No border
                        } else if cloudManager.destinations.count == 1 { // [Isolated] Single cloud destination | [In-file] Use Button for direct move
                            Button(action: { // [Isolated] Move to default cloud | [In-file] Calls moveGroupToCloud
                                let filesToMove = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) } // [Isolated] Get selected files | [In-file] Prepare for move
                                viewModel.logInterfaceEvent("Gallery cloud button clicked") // [Isolated] Log event | [In-file] Analytics
                                viewModel.moveGroupToCloud(filesToMove) // [Isolated] Move to default cloud | [In-file] Bulk move
                                selectedFiles.removeAll() // [Isolated] Clear selection | [In-file] Reset after action
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "icloud.and.arrow.up.fill") // [Isolated] Cloud icon | [In-file] SF Symbol
                                    Text("Cloud (\(selectedFiles.count))") // [Isolated] Show count | [In-file] Dynamic label
                                }
                                .font(.system(size: 13, weight: .semibold)) // [Isolated] Button font | [In-file] Styling
                                .foregroundColor(.white) // [Isolated] Button text color | [In-file] Styling
                                .padding(.horizontal, 16) // [Isolated] Button padding | [In-file] Spacing
                                .padding(.vertical, 8) // [Isolated] Button padding | [In-file] Spacing
                                .background(Capsule().fill(Color.blue)) // [Isolated] Blue capsule background | [In-file] Styling
                            }
                            .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] No border
                        } else { // [Isolated] No cloud destinations | [In-file] Show prompt to configure
                            Button(action: { // [Isolated] Prompt to configure cloud | [In-file] Calls promptToConfigureCloud
                                promptToConfigureCloud() // [Isolated] Show NSAlert | [In-file] User can open settings
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "icloud.and.arrow.up.fill") // [Isolated] Cloud icon | [In-file] SF Symbol
                                    Text("Cloud (\(selectedFiles.count))") // [Isolated] Show count | [In-file] Dynamic label
                                }
                                .font(.system(size: 13, weight: .semibold)) // [Isolated] Button font | [In-file] Styling
                                .foregroundColor(.white.opacity(0.8)) // [Isolated] Dimmed color | [In-file] Disabled look
                                .padding(.horizontal, 16) // [Isolated] Button padding | [In-file] Spacing
                                .padding(.vertical, 8) // [Isolated] Button padding | [In-file] Spacing
                                .background(Capsule().fill(Color.gray)) // [Isolated] Gray capsule background | [In-file] Styling
                            }
                            .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] No border
                            .help("Cloud is not configured. Click to open Settings.") // [Isolated] Tooltip | [In-file] User guidance
                        }

                        Button(action: { // [Isolated] Move selected files | [In-file] Calls VM promptForMoveDestination
                            let filesToMove = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) } // [Isolated] Get selected files | [In-file] Prepare for move
                            viewModel.logInterfaceEvent("Gallery move button clicked") // [Isolated] Log event | [In-file] Analytics
                            viewModel.promptForMoveDestination(files: filesToMove) // [Isolated] Prompt for move destination | [In-file] Bulk move
                            selectedFiles.removeAll() // [Isolated] Clear selection | [In-file] Reset after action
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill") // [Isolated] Move icon | [In-file] SF Symbol
                                Text("Move (\(selectedFiles.count))") // [Isolated] Show count | [In-file] Dynamic label
                            }
                            .font(.system(size: 13, weight: .semibold)) // [Isolated] Button font | [In-file] Styling
                            .foregroundColor(.white) // [Isolated] Button text color | [In-file] Styling
                            .padding(.horizontal, 16) // [Isolated] Button padding | [In-file] Spacing
                            .padding(.vertical, 8) // [Isolated] Button padding | [In-file] Spacing
                            .background(Capsule().fill(Color.teal)) // [Isolated] Teal capsule background | [In-file] Styling
                        }
                        .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] No border
                        
                        Spacer() // [Isolated] Push bin button to right | [In-file] Layout
                        
                        Button(action: { // [Isolated] Bin selected files | [In-file] Calls VM binGroupFiles
                            let filesToBin = viewModel.filteredFiles.filter { selectedFiles.contains($0.id) } // [Isolated] Get selected files | [In-file] Prepare for bin
                            viewModel.logInterfaceEvent("Gallery bin selected button clicked", details: "\(filesToBin.count) selected") // [Isolated] Log event | [In-file] Analytics
                            viewModel.binGroupFiles(filesToBin) // [Isolated] Call VM bin | [In-file] Bin group action
                            selectedFiles.removeAll() // [Isolated] Clear selection | [In-file] Reset after action
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill") // [Isolated] Bin icon | [In-file] SF Symbol
                                Text("Bin Selected (\(selectedFiles.count))") // [Isolated] Show count | [In-file] Dynamic label
                            }
                            .font(.system(size: 13, weight: .semibold)) // [Isolated] Button font | [In-file] Styling
                            .foregroundColor(.white) // [Isolated] Button text color | [In-file] Styling
                            .padding(.horizontal, 16) // [Isolated] Button padding | [In-file] Spacing
                            .padding(.vertical, 8) // [Isolated] Button padding | [In-file] Spacing
                            .background(Capsule().fill(Color.red)) // [Isolated] Red capsule background | [In-file] Styling
                        }
                        .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] No border
                    }
                    .padding() // [Isolated] Footer padding | [In-file] Spacing
                    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow)) // [Isolated] Footer background | [In-file] VisualEffectView for macOS blur
                }
            }
        }
    }
}

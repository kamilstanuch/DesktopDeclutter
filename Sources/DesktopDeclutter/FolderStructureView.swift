//  FolderStructureView.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  Sidebar view that shows the current folder breadcrumb/location, an optional back button when in a subfolder, and a scrollable list of the current folder’s files/folders with status icons, inline undo, and navigation gestures.
//
//  Unique characteristics
//  ----------------------
//  - Uses ScrollViewReader to keep the current file centered as selection changes.
//  - Single-tap jumps to a file and triggers thumbnail preloading + shake feedback.
//  - Double-tap on folders enters them via the view model’s folder stack.
//  - Dims viewed/processed files and highlights the current file row.
//  - Includes a footer button to toggle between swipe (card) mode and gallery (grid) mode.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  - SwiftUI: https://developer.apple.com/documentation/swiftui
//  - View: https://developer.apple.com/documentation/swiftui/view
//  - @ObservedObject: https://developer.apple.com/documentation/swiftui/observedobject
//  - Layout: VStack/HStack/LazyVStack/ZStack/Spacer/Divider/ScrollView/ScrollViewReader
//    - VStack: https://developer.apple.com/documentation/swiftui/vstack
//    - HStack: https://developer.apple.com/documentation/swiftui/hstack
//    - LazyVStack: https://developer.apple.com/documentation/swiftui/lazyvstack
//    - ZStack: https://developer.apple.com/documentation/swiftui/zstack
//    - Spacer: https://developer.apple.com/documentation/swiftui/spacer
//    - Divider: https://developer.apple.com/documentation/swiftui/divider
//    - ScrollView: https://developer.apple.com/documentation/swiftui/scrollview
//    - ScrollViewReader: https://developer.apple.com/documentation/swiftui/scrollviewreader
//    - ScrollViewProxy: https://developer.apple.com/documentation/swiftui/scrollviewproxy
//  - Text/Images:
//    - Text: https://developer.apple.com/documentation/swiftui/text
//    - Image: https://developer.apple.com/documentation/swiftui/image
//    - Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//    - Image(nsImage:): https://developer.apple.com/documentation/swiftui/image/init(nsimage:)
//    - Font: https://developer.apple.com/documentation/swiftui/font
//  - Shapes/styling:
//    - RoundedRectangle: https://developer.apple.com/documentation/swiftui/roundedrectangle
//    - Circle: https://developer.apple.com/documentation/swiftui/circle
//    - Rectangle: https://developer.apple.com/documentation/swiftui/rectangle
//    - Color: https://developer.apple.com/documentation/swiftui/color
//    - background: https://developer.apple.com/documentation/swiftui/view/background(_:alignment:)
//    - opacity: https://developer.apple.com/documentation/swiftui/view/opacity(_:) 
//    - foregroundColor: https://developer.apple.com/documentation/swiftui/view/foregroundcolor(_:) 
//    - contentShape: https://developer.apple.com/documentation/swiftui/view/contentshape(_:eoFill:)
//    - frame: https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:)
//  - Interaction/gesture/animation:
//    - Button: https://developer.apple.com/documentation/swiftui/button
//    - buttonStyle: https://developer.apple.com/documentation/swiftui/view/buttonstyle(_:) 
//    - onTapGesture: https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:perform:)
//    - Gesture: https://developer.apple.com/documentation/swiftui/gesture
//    - TapGesture: https://developer.apple.com/documentation/swiftui/tapgesture
//    - gesture: https://developer.apple.com/documentation/swiftui/view/gesture(_:including:)
//    - onAppear: https://developer.apple.com/documentation/swiftui/view/onappear(perform:)
//    - onChange: https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:)
//    - withAnimation: https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
//  - SF Symbols:
//    - https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//
//  NOTE: Internal project types referenced:
//  - DeclutterViewModel, DesktopFile, FileType, FileDecision
//  - VisualEffectView

import SwiftUI // [Isolated] Import SwiftUI framework for UI components | [In-file] Foundation for all SwiftUI views and modifiers

struct FolderStructureView: View { // [Isolated] Main view struct for the folder sidebar | [In-file] Displays folder location, navigation, and file list
    @ObservedObject var viewModel: DeclutterViewModel // [Isolated] Observes the view model for data/state changes | [In-file] Drives UI with current folder and file info
    
    var body: some View { // [Isolated] Main view body | [In-file] Composes the sidebar layout vertically
        VStack(alignment: .leading, spacing: 16) { // [Isolated] Vertical stack container with spacing and leading alignment | [In-file] Holds header, file list, footer toggle
            
            VStack(alignment: .leading, spacing: 4) { // [Isolated] Breadcrumb location header container | [In-file] Shows "Location" label and current path text
                Text("Location") // [Isolated] Static label for location section | [In-file] Uppercase small font
                    .font(.system(size: 10, weight: .bold)) // [Isolated] Small bold font for label | [In-file] Styling
                    .foregroundColor(.secondary) // [Isolated] Secondary color for label | [In-file] Subdued text color
                    .textCase(.uppercase) // [Isolated] Uppercase text transform | [In-file] Visual style
                
                Text(viewModel.breadcrumbText.isEmpty ? "Root" : viewModel.breadcrumbText) // [Isolated] Shows breadcrumb or "Root" if empty | [In-file] Current folder path display
                    .font(.system(size: 13)) // [Isolated] Regular font size for path text | [In-file] Readable text
                    .foregroundColor(.primary) // [Isolated] Primary color for path text | [In-file] Emphasized text color
                    .lineLimit(2) // [Isolated] Limit to two lines max | [In-file] Prevent overly long path overflow
            } // [Isolated] End breadcrumb header VStack | [In-file] Location header styling
            .padding(.horizontal) // [Isolated] Horizontal padding around header | [In-file] Spacing from edges
            .padding(.top, 20) // [Isolated] Top padding for breathing room | [In-file] Visual spacing
            
            if viewModel.isInSubfolder { // [Isolated] Conditionally show back button if inside subfolder | [In-file] Enables navigation back up folder stack
                Button(action: { // [Isolated] Back button action triggers return to parent folder | [In-file] Navigation interaction
                    withAnimation { // [Isolated] Animate folder return transition | [In-file] Smooth UI update
                        viewModel.returnToParentFolder() // [Isolated] ViewModel method to move up folder stack | [In-file] Folder navigation logic
                    }
                }) {
                    HStack(spacing: 6) { // [Isolated] Horizontal layout for back icon and folder name | [In-file] Button content
                        Image(systemName: "chevron.left") // [Isolated] SF Symbol back arrow | [In-file] Visual indicator for back
                            .font(.system(size: 12, weight: .semibold)) // [Isolated] Styling for icon | [In-file] Consistent icon size
                        Text(viewModel.parentFolderName) // [Isolated] Displays parent folder name | [In-file] Context for back button
                            .font(.system(size: 13, weight: .medium)) // [Isolated] Medium weight font | [In-file] Button label style
                        Spacer() // [Isolated] Push content to left | [In-file] Layout spacing
                    }
                    .foregroundColor(.blue) // [Isolated] Blue tint for button content | [In-file] Indicates interactivity
                    .padding(.horizontal) // [Isolated] Horizontal padding inside button | [In-file] Touch target spacing
                    .padding(.bottom, 2) // [Isolated] Bottom padding for visual alignment | [In-file] Button layout
                    .contentShape(Rectangle()) // [Isolated] Expand tappable area | [In-file] Better hit testing
                }
                .buttonStyle(.plain) // [Isolated] Remove default button styles | [In-file] Custom button appearance
            }
            
            Divider() // [Isolated] Visual divider line | [In-file] Separates header/back button from file list
            
            Text("In this folder") // [Isolated] Section label for file list | [In-file] Inform user of current folder contents
                .font(.caption) // [Isolated] Caption font style | [In-file] Subtle text emphasis
                .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Less prominent text
                .padding(.horizontal) // [Isolated] Horizontal padding | [In-file] Align with other content
            
            ScrollViewReader { proxy in // [Isolated] Enables programmatic scrolling | [In-file] Keeps current file visible
                ScrollView { // [Isolated] Vertical scroll container for file list | [In-file] Allows scrolling through contents
                    LazyVStack(spacing: 4) { // [Isolated] Efficient vertical stack for many items | [In-file] File/folder rows with spacing
                        ForEach(viewModel.filteredFiles) { file in // [Isolated] Iterate over filtered files to display | [In-file] List data source
                            HStack(spacing: 8) { // [Isolated] Horizontal layout for icon, text, and status | [In-file] File row content
                                Image(nsImage: file.icon) // [Isolated] File icon from NSImage | [In-file] Visual file type indicator
                                    .resizable() // [Isolated] Make icon scalable | [In-file] Fit frame size
                                    .frame(width: 16, height: 16) // [Isolated] Fixed icon size | [In-file] Consistent icon dimension
                                
                                Text(file.name) // [Isolated] File/folder name text | [In-file] Main label
                                    .font(.system(size: 13)) // [Isolated] Regular font size | [In-file] Readable text
                                    .lineLimit(1) // [Isolated] Single line limit | [In-file] Prevent multiline overflow
                                    .truncationMode(.middle) // [Isolated] Truncate middle of text if too long | [In-file] Show start and end parts
                                    .truncationMode(.middle) // [Isolated] Duplicate truncationMode call (redundant) | [In-file] Preserves original behavior
                                    .foregroundColor(file.decision != nil || viewModel.viewedFileIds.contains(file.id) ? .secondary : (file.id == viewModel.currentFile?.id ? .primary : .secondary)) // [Isolated] Dim color if processed/viewed, highlight if current | [In-file] Visual file status
            
                                Spacer() // [Isolated] Push trailing icons to right | [In-file] Layout spacing
                                
                                if file.decision != nil { // [Isolated] Show inline undo button if file has a decision | [In-file] Undo interaction for processed files
                                    Button(action: { // [Isolated] Undo decision action | [In-file] Restore file to undecided state
                                        withAnimation { viewModel.undoDecision(for: file) } // [Isolated] Animate undo change | [In-file] Smooth UI update
                                    }) {
                                        Image(systemName: "arrow.uturn.backward") // [Isolated] Undo icon | [In-file] Visual undo affordance
                                            .font(.system(size: 10)) // [Isolated] Small icon size | [In-file] Fits inline button
                                            .foregroundColor(.secondary) // [Isolated] Subdued icon color | [In-file] Less prominent
                                            .frame(width: 16, height: 16) // [Isolated] Fixed button size | [In-file] Consistent tap target
                                            .background(Circle().fill(Color.gray.opacity(0.1))) // [Isolated] Circular background with opacity | [In-file] Visual button shape
                                    }
                                    .buttonStyle(.plain) // [Isolated] Remove default button styles | [In-file] Custom inline button look
                                }
                                
                                if let decision = file.decision { // [Isolated] Show status icon for file decision | [In-file] Visual feedback on file state
                                    Image(systemName: decision == .kept ? "checkmark.circle.fill" : (decision == .binned ? "trash.circle.fill" : (decision == .cloud ? "icloud.and.arrow.up.fill" : (decision == .moved ? "folder.fill" : "square.stack.3d.up.fill")))) // [Isolated] SF Symbol based on decision enum | [In-file] Status icon selection
                                        .font(.system(size: 12)) // [Isolated] Icon size | [In-file] Consistent icon dimension
                                        .foregroundColor(decision == .kept ? .green : (decision == .binned ? .red : .blue)) // [Isolated] Color code for decision | [In-file] Green=kept, Red=binned, Blue=others
                                }
                                
                                if file.id == viewModel.currentFile?.id { // [Isolated] Show indicator if this is the current file | [In-file] Highlight current selection
                                    Image(systemName: "chevron.right") // [Isolated] Right chevron icon | [In-file] Visual current file marker
                                        .font(.system(size: 10, weight: .bold)) // [Isolated] Bold small icon | [In-file] Emphasize current file
                                        .foregroundColor(.blue) // [Isolated] Blue color | [In-file] Matches selection highlight
                                }
                            } // [Isolated] End HStack for file row | [In-file] Layout file row content
                            .opacity(file.decision != nil || viewModel.viewedFileIds.contains(file.id) ? 0.6 : 1.0) // [Isolated] Dim processed or viewed files | [In-file] Visual state feedback
                            .padding(.horizontal, 12) // [Isolated] Horizontal padding inside row | [In-file] Layout spacing
                            .padding(.vertical, 8) // [Isolated] Vertical padding inside row | [In-file] Touch target size
                            .background( // [Isolated] Background highlight for current file | [In-file] Visual selection cue
                                RoundedRectangle(cornerRadius: 6) // [Isolated] Rounded rectangle shape | [In-file] Row background shape
                                    .fill(file.id == viewModel.currentFile?.id ? Color.blue.opacity(0.1) : Color.clear) // [Isolated] Light blue fill if current, clear otherwise | [In-file] Subtle highlight
                            )
                            .contentShape(Rectangle()) // [Isolated] Expand tappable area to full row | [In-file] Better hit testing
                            .onTapGesture { // [Isolated] Single tap gesture handler | [In-file] Select file and trigger actions
                                if let index = viewModel.filteredFiles.firstIndex(where: { $0.id == file.id }) { // [Isolated] Find index of tapped file | [In-file] Needed for selection
                                    withAnimation { // [Isolated] Animate selection change | [In-file] Smooth UI update
                                        viewModel.currentFileIndex = index // [Isolated] Update current file index | [In-file] Selection state
                                        viewModel.generateThumbnails(for: index) // [Isolated] Preload thumbnails for file | [In-file] Performance optimization
                                        viewModel.triggerShake(for: file.id) // [Isolated] Trigger shake feedback animation | [In-file] User feedback
                                    }
                                }
                            }
                            .gesture( // [Isolated] Double tap gesture handler | [In-file] Folder navigation
                                TapGesture(count: 2).onEnded { // [Isolated] Detect double tap | [In-file] Enter folder on double tap
                                    if file.fileType == .folder { // [Isolated] Only enter if file is folder | [In-file] Navigation condition
                                        withAnimation { // [Isolated] Animate folder entry | [In-file] Smooth transition
                                            viewModel.enterFolder(file) // [Isolated] ViewModel method to enter folder | [In-file] Folder stack update
                                        }
                                    }
                                }
                            )
                            .id(file.id) // [Isolated] Assign unique id for scroll-to | [In-file] Enables ScrollViewReader functionality
                        }
                    }
                    .padding(.horizontal, 8) // [Isolated] Horizontal padding for list | [In-file] Align with other content
                }
                .id(viewModel.selectedFolderURL) // [Isolated] Refresh scroll view when folder changes | [In-file] Forces list reload on folder change
                .onAppear { // [Isolated] Scroll to current file when view appears | [In-file] Initial scroll positioning
                    scrollToCurrent(proxy: proxy) // [Isolated] Call helper to scroll | [In-file] Center current file
                }
                .onChange(of: viewModel.currentFile?.id) { _ in // [Isolated] Scroll when current file changes | [In-file] Maintain visible selection
                    scrollToCurrent(proxy: proxy) // [Isolated] Call helper to scroll | [In-file] Center current file
                }
            }
            
            VStack(spacing: 8) { // [Isolated] Footer container for gallery toggle button | [In-file] Bottom toggle UI
                Divider() // [Isolated] Visual divider above footer | [In-file] Separate from file list
                Button(action: { // [Isolated] Toggle between grid and swipe modes | [In-file] Switch gallery display mode
                    withAnimation { // [Isolated] Animate mode toggle | [In-file] Smooth UI transition
                        viewModel.isGridMode.toggle() // [Isolated] Toggle grid mode boolean | [In-file] Mode state update
                    }
                }) {
                    HStack { // [Isolated] Horizontal layout for icon and label | [In-file] Button content
                        Image(systemName: viewModel.isGridMode ? "square.grid.2x2.fill" : "square.grid.2x2") // [Isolated] Icon changes based on mode | [In-file] Visual mode indicator
                        Text(viewModel.isGridMode ? "Back to Swipe View" : "Switch to Gallery") // [Isolated] Button label changes | [In-file] User guidance text
                            .font(.system(size: 12, weight: .medium)) // [Isolated] Medium font style | [In-file] Button label styling
                        Spacer() // [Isolated] Push content to left | [In-file] Layout spacing
                    }
                    .padding(.horizontal) // [Isolated] Horizontal padding inside button | [In-file] Touch target spacing
                    .padding(.vertical, 8) // [Isolated] Vertical padding inside button | [In-file] Touch target size
                    .contentShape(Rectangle()) // [Isolated] Expand tappable area | [In-file] Better hit testing
                }
                .buttonStyle(.plain) // [Isolated] Remove default button styles | [In-file] Custom appearance
            }
            .padding(.bottom, 8) // [Isolated] Bottom padding for footer | [In-file] Visual spacing
        }
        .frame(width: 260) // [Isolated] Fixed width for sidebar | [In-file] Consistent layout width
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5)) // [Isolated] Semi-transparent background color | [In-file] Visual styling
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow)) // [Isolated] Visual effect blur for sidebar | [In-file] macOS style background
    }
    
    private func scrollToCurrent(proxy: ScrollViewProxy) { // [Isolated] Helper to scroll to current file row | [In-file] Keeps current selection visible and centered
        if let currentId = viewModel.currentFile?.id { // [Isolated] Check if current file exists | [In-file] Valid scroll target
            withAnimation { // [Isolated] Animate scroll action | [In-file] Smooth scroll transition
                proxy.scrollTo(currentId, anchor: .center) // [Isolated] Scroll to current file by id, centered vertically | [In-file] Focus user view on selection
            }
        }
    }
}

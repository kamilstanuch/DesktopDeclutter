//  ContentView.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  Main user interface for DesktopDeclutter. Handles top-level layout, folder selection, toolbars, content switching, and keyboard shortcuts.
//
//  Unique characteristics
//  ----------------------
//  - Integrates multiple subviews (sidebar, grid, card, history, settings, etc.) into a cohesive window
//  - Manages keyboard shortcuts and window resizing logic
//  - Handles QuickLook preview panel responder
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  SwiftUI core: https://developer.apple.com/documentation/swiftui
//  SwiftUI View: https://developer.apple.com/documentation/swiftui/view
//  @ObservedObject: https://developer.apple.com/documentation/swiftui/observedobject
//  @StateObject: https://developer.apple.com/documentation/swiftui/stateobject
//  @State: https://developer.apple.com/documentation/swiftui/state
//  Group: https://developer.apple.com/documentation/swiftui/group
//  VStack: https://developer.apple.com/documentation/swiftui/vstack
//  HStack: https://developer.apple.com/documentation/swiftui/hstack
//  ZStack: https://developer.apple.com/documentation/swiftui/zstack
//  Spacer: https://developer.apple.com/documentation/swiftui/spacer
//  Divider: https://developer.apple.com/documentation/swiftui/divider
//  ScrollView: https://developer.apple.com/documentation/swiftui/scrollview
//  LazyVGrid: https://developer.apple.com/documentation/swiftui/lazyvgrid
//  ProgressView: https://developer.apple.com/documentation/swiftui/progressview
//  Image: https://developer.apple.com/documentation/swiftui/image
//  Text: https://developer.apple.com/documentation/swiftui/text
//  Button: https://developer.apple.com/documentation/swiftui/button
//  Menu: https://developer.apple.com/documentation/swiftui/menu
//  Capsule: https://developer.apple.com/documentation/swiftui/capsule
//  Circle: https://developer.apple.com/documentation/swiftui/circle
//  RoundedRectangle: https://developer.apple.com/documentation/swiftui/roundedrectangle
//  Color: https://developer.apple.com/documentation/swiftui/color
//  LinearGradient: https://developer.apple.com/documentation/swiftui/lineargradient
//  overlay: https://developer.apple.com/documentation/swiftui/view/overlay(alignment:content:)
//  background: https://developer.apple.com/documentation/swiftui/view/background(_:alignment:)
//  sheet: https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)
//  popover: https://developer.apple.com/documentation/swiftui/view/popover(ispresented:attachmentanchor:arrowedge:content:)
//  onAppear: https://developer.apple.com/documentation/swiftui/view/onappear(perform:)
//  onChange: https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:)
//  onHover: https://developer.apple.com/documentation/swiftui/view/onhover(perform:)
//  transition: https://developer.apple.com/documentation/swiftui/view/transition(_:) 
//  animation(value:): https://developer.apple.com/documentation/swiftui/view/animation(_:value:)
//  withAnimation: https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
//  SF Symbols HIG: https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//  Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//  QuickLookUI: https://developer.apple.com/documentation/quicklookui
//  QLPreviewPanel: https://developer.apple.com/documentation/quicklookui/qlpreviewpanel
//  AppKit: https://developer.apple.com/documentation/appkit
//  NSAlert: https://developer.apple.com/documentation/appkit/nsalert
//  NSWindow: https://developer.apple.com/documentation/appkit/nswindow
//  NSEvent: https://developer.apple.com/documentation/appkit/nsevent
//  Foundation ByteCountFormatter: https://developer.apple.com/documentation/foundation/bytecountformatter
//
//  NOTE: References internal types:
//  - DeclutterViewModel, CloudManager, CloudDestination
//  - FolderStructureView, VisualEffectView, HistoryView, SettingsView, FilterView
//  - GalleryGridView, GroupReviewView, StackedFilesView, BinnedFilesView, FolderActionView
//  - CardView, ActionDockPanel, ActionDockButton, ActionDockButtonLabel
//  - WindowAccessor, QuickLookHelper, QuickLookResponder/QuickLookResponderView
//  - DesktopFile, FileType, FileGridCard, SmartAction, SmartActionCard

import SwiftUI // [Isolated] SwiftUI core import | [In-file] Required for all UI views
import QuickLookUI // [Isolated] QuickLookUI for preview panel | [In-file] Used for Quick Look integration
import AppKit // [Isolated] AppKit import | [In-file] Used for window and alerts

struct ContentView: View { // [Isolated] Root view struct | [In-file] Main entry for all app UI
    @ObservedObject var viewModel: DeclutterViewModel // [Isolated] View model | [In-file] App-wide state and logic
    @StateObject private var cloudManager = CloudManager.shared // [Isolated] Cloud manager singleton | [In-file] For cloud actions
    
    @State private var showSettings = false // [Isolated] Sheet toggle | [In-file] Settings modal visibility
    @State private var showHistory = false // [Isolated] Popover toggle | [In-file] History popover visibility
    @State private var showStackedFiles = false // [Isolated] Toggle | [In-file] Stacked files panel visibility
    @State private var showBinnedFiles = false // [Isolated] Toggle | [In-file] Binned files panel visibility
    @State private var showFilters = false // [Isolated] Toggle | [In-file] Filter popover visibility
    @State private var window: NSWindow? // [Isolated] NSWindow reference | [In-file] For resizing and access
    @State private var showWelcomeOverlay = false // [Isolated] Toggle | [In-file] Welcome splash visibility
    @State private var welcomeContentVisible = false // [Isolated] Toggle | [In-file] Welcome text/icon fade and scale
    @State private var welcomePulse = false // [Isolated] Toggle | [In-file] Welcome icon pulse animation
    @State private var welcomeAnimationTask: Task<Void, Never>? = nil // [Isolated] Task ref | [In-file] Cancel/restart welcome animation sequence
    
    // Returns the SF Symbol name for the current cloud provider
    private var cloudActionIcon: String { // [Isolated] Computed property | [In-file] Cloud action button icon
        switch cloudManager.activeDestination?.provider {
        case .googleDrive:
            return "externaldrive.fill" // [Isolated] Google Drive icon | [In-file] For Google Drive
        case .iCloud:
            return "icloud.and.arrow.up.fill" // [Isolated] iCloud icon | [In-file] For iCloud
        default:
            return "icloud.and.arrow.up.fill" // [Isolated] Default icon | [In-file] Fallback
        }
    }

    // Shows an NSAlert prompting the user to configure a cloud destination
    private func promptToConfigureCloud() { // [Isolated] Helper function | [In-file] Alert for missing cloud
        let alert = NSAlert() // [Isolated] NSAlert instance | [In-file] Modal dialog
        alert.messageText = "Cloud destination not set up" // [Isolated] Alert title | [In-file] Prompt text
        alert.informativeText = "Would you like to open Settings and connect a cloud folder now?" // [Isolated] Alert body | [In-file] Prompt details
        alert.alertStyle = .informational // [Isolated] Info style | [In-file] Alert appearance
        alert.addButton(withTitle: "Open Settings") // [Isolated] Primary button | [In-file] Settings action
        alert.addButton(withTitle: "Not Now") // [Isolated] Secondary button | [In-file] Dismiss action
        let response = alert.runModal() // [Isolated] User response | [In-file] Wait for selection
        if response == .alertFirstButtonReturn { // [Isolated] If user chooses settings | [In-file] Show settings
            showHistory = false // [Isolated] Hide history | [In-file] Only show settings
            showFilters = false // [Isolated] Hide filters | [In-file] Only show settings
            showSettings = true // [Isolated] Show settings | [In-file] Open settings sheet
        }
    }

    var body: some View { // [Isolated] Main view body | [In-file] App UI hierarchy
        Group { // [Isolated] Group view | [In-file] Conditional main content
            if viewModel.selectedFolderURL == nil { // [Isolated] No folder selected | [In-file] Show folder picker
                VStack(spacing: 16) { // [Isolated] Centered stack | [In-file] Folder picker UI
                    Image(systemName: "folder.fill") // [Isolated] Folder icon | [In-file] Visual cue
                        .font(.system(size: 44, weight: .semibold)) // [Isolated] Large icon | [In-file] Emphasis
                        .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Subdued
                    
                    Text("Choose a folder to begin") // [Isolated] Headline | [In-file] Main prompt
                        .font(.system(size: 18, weight: .semibold)) // [Isolated] Font styling | [In-file] Emphasis
                    
                    Text("Desktop Declutter needs a folder to scan. Please select one to continue.") // [Isolated] Description | [In-file] Guidance
                        .font(.system(size: 12)) // [Isolated] Small font | [In-file] Less prominent
                        .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Subdued
                        .multilineTextAlignment(.center) // [Isolated] Centered text | [In-file] Better appearance
                        .frame(maxWidth: 260) // [Isolated] Max width | [In-file] Prevents wide lines
                    
                    Button(action: { // [Isolated] Choose folder button | [In-file] Triggers folder picker
                        viewModel.promptForFolderAndLoad() // [Isolated] Calls view model | [In-file] Folder selection
                    }) {
                        Text("Choose Folder") // [Isolated] Button label | [In-file] Action text
                            .font(.system(size: 13, weight: .semibold)) // [Isolated] Button font | [In-file] Emphasis
                            .padding(.horizontal, 16) // [Isolated] X padding | [In-file] Button shape
                            .padding(.vertical, 8) // [Isolated] Y padding | [In-file] Button shape
                            .background {
                                Capsule().fill(Color.blue.opacity(0.15)) // [Isolated] Capsule background | [In-file] Button style
                            }
                    }
                    .buttonStyle(.plain) // [Isolated] Plain style | [In-file] Removes default button look
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // [Isolated] Center in window | [In-file] Fills space
                .background {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow) // [Isolated] Sidebar blur | [In-file] Visual style
                }
            } else { // [Isolated] Folder selected | [In-file] Show main UI
                // MAIN SPLIT VIEW LAYOUT
                HStack(spacing: 0) { // [Isolated] Main split view | [In-file] Sidebar + content
                    FolderStructureView(viewModel: viewModel) // [Isolated] Sidebar | [In-file] Folder navigation
                    
                    Divider() // [Isolated] Divider | [In-file] Separates sidebar/content
                        .ignoresSafeArea() // [Isolated] Ignore safe area | [In-file] Full height
                    
                    ZStack { // [Isolated] Content area | [In-file] Main dynamic content
                        VisualEffectView(material: .contentBackground, blendingMode: .behindWindow) // [Isolated] Background blur | [In-file] Content area style
                            .ignoresSafeArea() // [Isolated] Ignore safe area | [In-file] Full background
                        
                        VStack(spacing: 0) { // [Isolated] Main vertical stack | [In-file] Toolbar + content + footer
                            HStack(spacing: 12) { // [Isolated] Toolbar | [In-file] Top of right pane
                                if viewModel.canUndo { // [Isolated] Undo button visible | [In-file] If undo available
                                    Button(action: {
                                        viewModel.logInterfaceEvent("Undo button clicked") // [Isolated] Log event | [In-file] Analytics
                                        _ = viewModel.undoLastAction() // [Isolated] Undo action | [In-file] Undo logic
                                    }) {
                                        Image(systemName: "arrow.uturn.backward") // [Isolated] Undo icon | [In-file] Button icon
                                            .font(.system(size: 13, weight: .medium)) // [Isolated] Icon font | [In-file] Styling
                                            .foregroundColor(.secondary) // [Isolated] Icon color | [In-file] Subdued
                                            .frame(width: 28, height: 28) // [Isolated] Button size | [In-file] Layout
                                            .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) } // [Isolated] Circle background | [In-file] Button style
                                    }
                                    .buttonStyle(.plain) // [Isolated] Plain style | [In-file] Removes default look
                                    .help("Undo (⌘Z)") // [Isolated] Tooltip | [In-file] Keyboard shortcut hint
                                }
                                
                                if viewModel.canUndo || viewModel.canRedo { // [Isolated] Redo button visible | [In-file] If redo available
                                    Button(action: {
                                        viewModel.logInterfaceEvent("Redo button clicked") // [Isolated] Log event | [In-file] Analytics
                                        _ = viewModel.redoLastAction() // [Isolated] Redo action | [In-file] Redo logic
                                    }) {
                                        Image(systemName: "arrow.uturn.forward") // [Isolated] Redo icon | [In-file] Button icon
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 28, height: 28)
                                            .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canRedo)
                                    .opacity(viewModel.canRedo ? 1.0 : 0.35)
                                    .help("Redo (⌘⇧Z)")
                                }
                                
                                Button(action: { // [Isolated] History button | [In-file] Shows history popover
                                    viewModel.logInterfaceEvent("History button clicked")
                                    showHistory.toggle()
                                }) {
                                    ZStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 28, height: 28)
                                            .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) }
                                        if viewModel.movingCount > 0 {
                                            Circle()
                                                .fill(Color.orange)
                                                .frame(width: 8, height: 8)
                                                .offset(x: 10, y: -10)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                                    HistoryView(viewModel: viewModel, isPresented: $showHistory)
                                }
                                
                                Button(action: { // [Isolated] Settings button | [In-file] Opens settings sheet
                                    viewModel.logInterfaceEvent("Settings button clicked")
                                    showSettings.toggle()
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, height: 28)
                                        .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) }
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showSettings) {
                                    SettingsView(isPresented: $showSettings, viewModel: viewModel)
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 4) { // [Isolated] Progress bar | [In-file] Shows file progress
                                    ProgressView(value: Double(viewModel.currentFileIndex), total: Double(max(viewModel.filteredFiles.count, 1)))
                                        .progressViewStyle(.linear)
                                        .frame(width: 180)
                                    HStack(spacing: 4) {
                                        Text("\(viewModel.currentFileIndex)").font(.system(size: 11, weight: .semibold))
                                        Text("of").font(.system(size: 11)).foregroundColor(.secondary)
                                        Text("\(viewModel.filteredFiles.count)").font(.system(size: 11, weight: .semibold))
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: { showFilters.toggle() }) { // [Isolated] Filter button | [In-file] File type filters
                                    Image(systemName: viewModel.selectedFileTypeFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(viewModel.selectedFileTypeFilter != nil ? .blue : .secondary)
                                        .frame(width: 28, height: 28)
                                        .background { Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)) }
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showFilters, arrowEdge: .top) {
                                    FilterView(viewModel: viewModel).frame(width: 200).padding(12)
                                }
                                
                                if !viewModel.immediateBinning && !viewModel.binnedFiles.isEmpty { // [Isolated] Binned files toggle | [In-file] Show if files binned
                                    Button(action: { showBinnedFiles.toggle(); showStackedFiles = false }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash.fill").font(.system(size: 13, weight: .medium))
                                            Text("\(viewModel.binnedFiles.count)").font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.red.opacity(0.15)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if !viewModel.stackedFiles.isEmpty { // [Isolated] Stacked files toggle | [In-file] Show if files stacked
                                    Button(action: { showStackedFiles.toggle(); showBinnedFiles = false }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.stack.fill").font(.system(size: 13, weight: .medium))
                                            Text("\(viewModel.stackedFiles.count)").font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundColor(showStackedFiles ? .white : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(showStackedFiles ? Color.blue : Color(nsColor: .quaternaryLabelColor).opacity(0.3)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow))
                            
                            Divider().opacity(0.2)
                            
                            ZStack { // [Isolated] Main content area | [In-file] Shows error, grid, card, etc.
                                if let error = viewModel.errorMessage { // [Isolated] Error state | [In-file] Show error UI
                                    VStack(spacing: 20) {
                                        Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
                                        Text(error).multilineTextAlignment(.center)
                                        Button("Retry") { viewModel.loadFiles() }
                                    }
                                } else if showStackedFiles { // [Isolated] Show stacked files panel | [In-file] If toggled
                                    StackedFilesView(viewModel: viewModel)
                                } else if showBinnedFiles { // [Isolated] Show binned files panel | [In-file] If toggled
                                    BinnedFilesView(viewModel: viewModel)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else if viewModel.showGroupReview { // [Isolated] Group review mode | [In-file] Show group review UI
                                    GroupReviewView(viewModel: viewModel)
                                } else if !viewModel.isFinished { // [Isolated] Not finished | [In-file] Show grid or card
                                    if viewModel.isGridMode { // [Isolated] Gallery/grid mode | [In-file] Show grid
                                        GalleryGridView(
                                            viewModel: viewModel,
                                            onRequestOpenSettings: {
                                                showHistory = false
                                                showFilters = false
                                                showSettings = true
                                            }
                                        )
                                    } else if let file = viewModel.currentFile { // [Isolated] Single file mode | [In-file] Show card or folder
                                        if file.fileType == .folder { // [Isolated] Folder action | [In-file] Special folder UI
                                            FolderActionView(
                                                viewModel: viewModel,
                                                onRequestOpenSettings: {
                                                    showHistory = false
                                                    showFilters = false
                                                    showSettings = true
                                                },
                                                folder: file
                                            )
                                                .id(file.id)
                                        } else {
                                            let movedTo = viewModel.relocationDestination(for: file)
                                            ZStack { // [Isolated] File card | [In-file] Main card view
                                                CardView(
                                                    file: file,
                                                    suggestions: viewModel.currentFileSuggestions,
                                                    relocationLabel: file.decision == .cloud ? "Moved to Cloud" : "Moved to",
                                                    relocationPath: movedTo?.path,
                                                    onKeep: { withAnimation { viewModel.keepCurrentFile() } },
                                                    onBin: { withAnimation { viewModel.binCurrentFile() } },
                                                    onPreview: { QuickLookHelper.shared.preview(url: file.url) },
                                                    onSuggestionTap: { viewModel.startGroupReview(for: $0) }
                                                )
                                                .rotationEffect(.degrees(viewModel.shakingFileId == file.id ? 2 : 0))
                                                .animation(viewModel.shakingFileId == file.id ? .easeInOut(duration: 0.1).repeatForever(autoreverses: true) : .default, value: viewModel.shakingFileId)
                                                .onHover { isHovered in
                                                    if isHovered && viewModel.shakingFileId == file.id {
                                                        viewModel.stopShake()
                                                    }
                                                }
                                                .overlay {
                                                    if let decision = file.decision {
                                                        ZStack {
                                                            Color.black.opacity(0.3)
                                                                .cornerRadius(16)
                                                            Image(systemName: decision == .kept ? "checkmark.circle.fill" : (decision == .binned ? "trash.circle.fill" : (decision == .cloud ? "icloud.and.arrow.up.fill" : (decision == .moved ? "folder.fill" : "square.stack.3d.up.fill"))))
                                                                .font(.system(size: 80))
                                                                .foregroundColor(.white)
                                                                .shadow(radius: 10)
                                                        }
                                                        .allowsHitTesting(false)
                                                    }
                                                    if viewModel.movingItemIds.contains(file.id) {
                                                        ZStack {
                                                            Color.black.opacity(0.35)
                                                                .cornerRadius(16)
                                                            VStack(spacing: 12) {
                                                                ProgressView()
                                                                    .progressViewStyle(.circular)
                                                                Text("Moving…")
                                                                    .font(.system(size: 14, weight: .semibold))
                                                                    .foregroundColor(.white)
                                                            }
                                                        }
                                                        .allowsHitTesting(false)
                                                    }
                                                }
                                                .padding(.bottom, 180) // [Isolated] Space for dock | [In-file] Prevents overlap
                                                
                                                if !viewModel.showGroupReview { // [Isolated] Show action dock | [In-file] Only if not in group review
                                                    VStack {
                                                        Spacer()
                                                        ActionDockPanel(
                                                            canUndo: viewModel.canUndo,
                                                            canForward: viewModel.canGoForward,
                                                            hasDecision: file.decision != nil,
                                                            cloudIcon: cloudActionIcon,
                                                            cloudDestinations: cloudManager.destinations,
                                                            cloudDestinationName: { cloudManager.destinationDisplayName($0) },
                                                            onUndo: {
                                                                withAnimation {
                                                                    viewModel.logInterfaceEvent("Undo button clicked", file: file)
                                                                    _ = viewModel.undoLastAction()
                                                                }
                                                            },
                                                            onBin: {
                                                                withAnimation {
                                                                    viewModel.logInterfaceEvent("Bin button clicked", file: file)
                                                                    viewModel.binCurrentFile()
                                                                }
                                                            },
                                                            onKeep: {
                                                                withAnimation {
                                                                    viewModel.logInterfaceEvent("Keep button clicked", file: file)
                                                                    viewModel.keepCurrentFile()
                                                                }
                                                            },
                                                            onCloud: {
                                                                withAnimation {
                                                                    viewModel.logInterfaceEvent("Cloud button clicked", file: file)
                                                                    if cloudManager.destinations.isEmpty {
                                                                        promptToConfigureCloud()
                                                                    } else {
                                                                        viewModel.moveToCloud(file)
                                                                    }
                                                                }
                                                            },
                                                            onCloudPick: { dest in
                                                                withAnimation {
                                                                    viewModel.logInterfaceEvent("Cloud destination picked", details: cloudManager.destinationDisplayName(dest), file: file)
                                                                    viewModel.moveToCloud(file, destination: dest)
                                                                }
                                                            },
                                                            onMove: {
                                                                viewModel.logInterfaceEvent("Move button clicked", file: file)
                                                                viewModel.promptForMoveDestination(files: [file])
                                                            },
                                                            onForward: {
                                                                withAnimation {
                                                                    viewModel.logInterfaceEvent("Next button clicked", file: file)
                                                                    viewModel.goForward()
                                                                }
                                                            }
                                                        )
                                                        .padding(.bottom, 22)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else { // [Isolated] Finished | [In-file] Show summary or binned files
                                    VStack(spacing: 24) {
                                        if viewModel.binnedFiles.isEmpty {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 64, weight: .light))
                                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            Text("All Clean!").font(.title2).fontWeight(.semibold)
                                        } else {
                                            BinnedFilesView(viewModel: viewModel)
                                        }
                                        
                                        if viewModel.binnedFiles.isEmpty {
                                            HStack(spacing: 24) {
                                                Button("Rescan Folder") { viewModel.loadFiles() }.buttonStyle(.plain).foregroundColor(.secondary)
                                                Button(action: { viewModel.promptForFolderAndLoad() }) {
                                                    HStack { Text("Scan Next Folder"); Image(systemName: "arrow.right") }
                                                        .padding(.horizontal, 20).padding(.vertical, 10)
                                                        .background(Capsule().fill(Color.blue))
                                                        .foregroundColor(.white)
                                                }.buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            if !viewModel.isFinished { // [Isolated] Footer stats | [In-file] Only if not finished
                                HStack {
                                    HStack(spacing: 16) {
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.red).frame(width: 6, height: 6)
                                            Text("Binned: \(viewModel.binnedCount)").font(.caption)
                                        }
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.green).frame(width: 6, height: 6)
                                            Text("Kept: \(viewModel.keptCount)").font(.caption)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow))
                            }
                        }
                    }
                    .frame(minWidth: 600, minHeight: 600)
                }
                .frame(minWidth: 900, minHeight: 600) // [Isolated] Main window min size | [In-file] Forces larger window
            }
        }
        .frame(minWidth: 420, minHeight: 680) // [Isolated] Enforced min window | [In-file] Prevents too small
        .background(WindowAccessor(window: $window)) // [Isolated] Window accessor | [In-file] For window reference
        .background(QuickLookResponder()) // [Isolated] QuickLook responder | [In-file] Handles preview panel
        .overlay(alignment: .top) { // [Isolated] Toast overlay | [In-file] Shows toast messages
            if let toast = viewModel.toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(toast)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay { // [Isolated] Full-screen welcome overlay | [In-file] Shows startup/refocus branded intro
            if showWelcomeOverlay {
                WelcomeOverlayView(
                    contentVisible: welcomeContentVisible,
                    pulse: welcomePulse
                )
                .transition(.opacity)
                .zIndex(50)
            }
        }
        .onChange(of: viewModel.selectedFolderURL) { _ in // [Isolated] Folder changed | [In-file] Adjusts window size
            DispatchQueue.main.async {
                if let window = window {
                    let currentFrame = window.frame
                    let newWidth = max(currentFrame.width, 1000)
                    let newHeight = max(currentFrame.height, 700)
                    if newWidth > currentFrame.width || newHeight > currentFrame.height {
                        window.setFrame(NSRect(x: currentFrame.minX, y: currentFrame.minY - (newHeight - currentFrame.height), width: newWidth, height: newHeight), display: true, animate: true)
                    }
                }
            }
        }
        .onAppear { // [Isolated] On appear | [In-file] Setup keyboard and prompt
            setupKeyboardShortcuts()
            viewModel.promptForFolderIfNeeded()
            runWelcomeSequence()
        }
        .onChange(of: viewModel.currentFile?.id) { _ in
            // [Isolated] File changed | [In-file] Logic handled elsewhere
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            runWelcomeSequence()
        }
    }

    private func runWelcomeSequence() {
        if showWelcomeOverlay { return }

        welcomeAnimationTask?.cancel()
        showWelcomeOverlay = true
        welcomeContentVisible = false
        welcomePulse = false

        withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
            welcomeContentVisible = true
        }

        welcomeAnimationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.easeInOut(duration: 1.2).repeatCount(2, autoreverses: true)) {
                welcomePulse = true
            }

            try? await Task.sleep(nanoseconds: 2_100_000_000)
            withAnimation(.easeInOut(duration: 0.35)) {
                welcomeContentVisible = false
            }

            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.easeInOut(duration: 0.28)) {
                showWelcomeOverlay = false
            }
            welcomePulse = false
        }
    }
    
    // Registers keyboard shortcuts for undo/redo and file actions
    private func setupKeyboardShortcuts() { // [Isolated] Keyboard shortcut handler | [In-file] Registers local monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                if event.keyCode == 6 { // Z key
                    if event.modifierFlags.contains(.shift) {
                        if viewModel.canRedo {
                            viewModel.logInterfaceEvent("Redo keyboard shortcut")
                            _ = viewModel.redoLastAction()
                            return nil
                        }
                    } else if viewModel.canUndo {
                        viewModel.logInterfaceEvent("Undo keyboard shortcut")
                        _ = viewModel.undoLastAction()
                        return nil
                    }
                }
                return nil // Let system handle other Cmd+key shortcuts
            }
            
            switch event.keyCode {
            case 123: // Left arrow
                if !viewModel.isFinished {
                    viewModel.logInterfaceEvent("Bin keyboard shortcut", file: viewModel.currentFile)
                    viewModel.binCurrentFile()
                    return nil
                }
            case 124: // Right arrow
                if !viewModel.isFinished {
                    viewModel.logInterfaceEvent("Keep keyboard shortcut", file: viewModel.currentFile)
                    viewModel.keepCurrentFile()
                    return nil
                }
            case 3: // F key
                if !viewModel.isFinished {
                    viewModel.logInterfaceEvent("Next keyboard shortcut", file: viewModel.currentFile)
                    viewModel.goForward()
                    return nil
                }
            case 49: // Spacebar
                if !viewModel.isFinished, let file = viewModel.currentFile {
                    viewModel.logInterfaceEvent("Preview keyboard shortcut", file: file)
                    QuickLookHelper.shared.preview(url: file.url)
                    return nil
                }
            case 1: // S key
                if !viewModel.isFinished {
                    viewModel.logInterfaceEvent("Stack keyboard shortcut", file: viewModel.currentFile)
                    viewModel.stackCurrentFile()
                    return nil
                }
            case 8: // C key
                if !viewModel.isFinished, let file = viewModel.currentFile {
                    viewModel.logInterfaceEvent("Cloud keyboard shortcut", file: file)
                    if cloudManager.destinations.isEmpty {
                        promptToConfigureCloud()
                    } else {
                        viewModel.moveToCloud(file)
                    }
                    return nil
                }
            case 46: // M key
                if !viewModel.isFinished, let file = viewModel.currentFile {
                    viewModel.logInterfaceEvent("Move keyboard shortcut", file: file)
                    viewModel.promptForMoveDestination(files: [file])
                    return nil
                }
            case 36: // Return
                if let file = viewModel.currentFile, file.fileType == .folder {
                    viewModel.logInterfaceEvent("Enter folder keyboard shortcut", file: file)
                    viewModel.enterFolder(file)
                    return nil
                }
            default:
                break
            }
            
            return event
        }
    }
}

struct WelcomeOverlayView: View {
    let contentVisible: Bool
    let pulse: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.10, blue: 0.19),
                    Color(red: 0.06, green: 0.28, blue: 0.45),
                    Color(red: 0.04, green: 0.48, blue: 0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    .padding(16)
            }
            .overlay {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 430, height: 430)
                    .blur(radius: 16)
                    .offset(x: 190, y: -220)
            }
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(pulse ? 1.06 : 1.0)

                Text("DesktopDeclutter")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Declutter your workspace quickly with intelligent file actions and review.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)

                Text("Open source project")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            .padding(.horizontal, 30)
            .scaleEffect(contentVisible ? 1.0 : 0.95)
            .opacity(contentVisible ? 1.0 : 0.0)
        }
    }
}

// MARK: - Quick Look Responder Helper

struct QuickLookResponder: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = QuickLookResponderView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update if needed
    }
}

class QuickLookResponderView: NSView {
    override var acceptsFirstResponder: Bool { true }
    
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = QuickLookHelper.shared
        panel.delegate = QuickLookHelper.shared
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}

// MARK: - Visual Effect View (Material Blur)

// VisualEffectView moved to its own file



// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let shortcut: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Blur background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Colored circle overlay
                Circle()
                    .fill(color.opacity(isHovered ? 0.9 : 0.85))
                    .frame(width: 64, height: 64)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                
                // Keyboard shortcut hint
                VStack {
                    Spacer()
                    Text(shortcut)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct FloatingActionButtonLabel: View {
    let icon: String
    let shortcut: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            Circle()
                .fill(color.opacity(isHovered ? 0.9 : 0.85))
                .frame(width: 64, height: 64)

            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)

            VStack {
                Spacer()
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 4)
            }
        }
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ActionDockPanel: View {
    let canUndo: Bool
    let canForward: Bool
    let hasDecision: Bool
    let cloudIcon: String
    let cloudDestinations: [CloudDestination]
    let cloudDestinationName: (CloudDestination) -> String
    let onUndo: () -> Void
    let onBin: () -> Void
    let onKeep: () -> Void
    let onCloud: () -> Void
    let onCloudPick: (CloudDestination) -> Void
    let onMove: () -> Void
    let onForward: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                ActionDockButton(
                    icon: "trash.fill",
                    label: "Bin",
                    shortcut: "←",
                    color: .red,
                    isPrimary: true,
                    isEnabled: !hasDecision,
                    action: onBin
                )

                ActionDockButton(
                    icon: "checkmark.circle.fill",
                    label: "Keep",
                    shortcut: "→",
                    color: .green,
                    isPrimary: true,
                    isEnabled: !hasDecision,
                    action: onKeep
                )
            }

            HStack(spacing: 12) {
                ActionDockButton(
                    icon: "arrow.uturn.backward",
                    label: "Undo",
                    shortcut: "⌘Z",
                    color: .orange,
                    isPrimary: false,
                    isEnabled: canUndo,
                    action: onUndo
                )

                if cloudDestinations.isEmpty {
                    ActionDockButton(
                        icon: cloudIcon,
                        label: "Cloud",
                        shortcut: "C",
                        color: .gray,
                        isPrimary: false,
                        isEnabled: !hasDecision,
                        action: onCloud
                    )
                    .help("Cloud is not configured. Click to open Settings.")
                } else if cloudDestinations.count > 1 {
                    Menu {
                        ForEach(cloudDestinations) { dest in
                            Button(cloudDestinationName(dest)) {
                                onCloudPick(dest)
                            }
                        }
                    } label: {
                        ActionDockButtonLabel(
                            icon: cloudIcon,
                            label: "Cloud",
                            shortcut: "C",
                            color: .blue,
                            isPrimary: false,
                            isEnabled: !hasDecision
                        )
                    }
                    .disabled(hasDecision)
                    .buttonStyle(.plain)
                } else {
                    ActionDockButton(
                        icon: cloudIcon,
                        label: "Cloud",
                        shortcut: "C",
                        color: .blue,
                        isPrimary: false,
                        isEnabled: !hasDecision,
                        action: onCloud
                    )
                }

                ActionDockButton(
                    icon: "folder.fill",
                    label: "Move",
                    shortcut: "M",
                    color: .teal,
                    isPrimary: false,
                    isEnabled: !hasDecision,
                    action: onMove
                )

                ActionDockButton(
                    icon: "arrow.right",
                    label: "Next",
                    shortcut: "F",
                    color: .blue,
                    isPrimary: false,
                    isEnabled: canForward,
                    action: onForward
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
    }
}

struct ActionDockButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let color: Color
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ActionDockButtonLabel(
                icon: icon,
                label: label,
                shortcut: shortcut,
                color: color,
                isPrimary: isPrimary,
                isEnabled: isEnabled
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.35)
        .scaleEffect(isHovered && isEnabled ? 1.03 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ActionDockButtonLabel: View {
    let icon: String
    let label: String
    let shortcut: String
    let color: Color
    let isPrimary: Bool
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(isEnabled ? 0.9 : 0.4))
                    .frame(width: isPrimary ? 36 : 28, height: isPrimary ? 36 : 28)
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 16 : 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: isPrimary ? 14 : 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, isPrimary ? 12 : 8)
        .padding(.horizontal, isPrimary ? 16 : 12)
        .frame(width: isPrimary ? 170 : 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(isPrimary ? 0.35 : 0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Binned Files View

struct BinnedFilesView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Binned Files")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(viewModel.binnedFiles.count) file\(viewModel.binnedFiles.count == 1 ? "" : "s") pending review")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.emptyBin()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Move All to Trash")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(Color.red)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            Divider()
                .opacity(0.2)
            
            // File list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.binnedFiles) { file in
                        HStack(spacing: 12) {
                            // Thumbnail
                            Group {
                                if let thumb = file.thumbnail {
                                    Image(nsImage: thumb)
                                        .resizable()
                                } else {
                                    Image(nsImage: file.icon)
                                        .resizable()
                                }
                            }
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                            }
                            
                            // File info
                            VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Actions
                            HStack(spacing: 8) {
                                Button(action: {
                                    QuickLookHelper.shared.preview(url: file.url)
                                }) {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                        }
                                }
                                .buttonStyle(.plain)
                                .help("Preview")
                                
                                Button(action: {
                                    viewModel.restoreFromBin(file)
                                }) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                        }
                                }
                                .buttonStyle(.plain)
                                .help("Restore to review")
                                
                                Button(action: {
                                    viewModel.removeFromBin(file)
                                }) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.red)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            Circle()
                                                .fill(Color.red.opacity(0.1))
                                        }
                                }
                                .buttonStyle(.plain)
                                .help("Move to trash now")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Stacked Files View

struct StackedFilesView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @State private var selectedFiles: Set<UUID> = []
    @State private var hoveredFileId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stacked Files")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(viewModel.stackedFiles.count) files waiting")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Select All / Deselect All
                Button(action: {
                    if selectedFiles.count == viewModel.stackedFiles.count {
                        selectedFiles.removeAll()
                    } else {
                        selectedFiles = Set(viewModel.stackedFiles.map { $0.id })
                    }
                }) {
                    Text(selectedFiles.count == viewModel.stackedFiles.count && !viewModel.stackedFiles.isEmpty ? "Deselect All" : "Select All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.stackedFiles.isEmpty)
            }
            .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            Divider()
                .opacity(0.2)
            
            // File grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.stackedFiles) { file in
                        FileGridCard(
                            file: file,
                            isSelected: selectedFiles.contains(file.id),
                            isHovered: hoveredFileId == file.id,
                            isShaking: false,
                            onToggle: {
                                if selectedFiles.contains(file.id) {
                                    selectedFiles.remove(file.id)
                                } else {
                                    selectedFiles.insert(file.id)
                                }
                            },
                            onPreview: {
                                QuickLookHelper.shared.preview(url: file.url)
                            },
                            onHover: { hovering in
                                hoveredFileId = hovering ? file.id : nil
                            }
                        )
                    }
                }
                .padding()
            }
            
            // Footer Actions
            if !selectedFiles.isEmpty {
                VStack(spacing: 0) {
                    Divider().opacity(0.2)
                    HStack(spacing: 16) {
                        Button(action: {
                            let files = viewModel.stackedFiles.filter { selectedFiles.contains($0.id) }
                            viewModel.keepStackedFiles(files)
                            selectedFiles.removeAll()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Keep Selected (\(selectedFiles.count))")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.green))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: {
                            let files = viewModel.stackedFiles.filter { selectedFiles.contains($0.id) }
                            viewModel.binStackedFiles(files)
                            selectedFiles.removeAll()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("Bin Selected (\(selectedFiles.count))")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.red))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                }
            }
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by Type")
                .font(.system(size: 13, weight: .semibold))
            
            // All files option
            Button(action: {
                viewModel.setFileTypeFilter(nil)
            }) {
                HStack {
                    Image(systemName: viewModel.selectedFileTypeFilter == nil ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(viewModel.selectedFileTypeFilter == nil ? .blue : .secondary)
                    Text("All Files")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(viewModel.totalFilesCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // File type filters
            ForEach(FileType.allCases, id: \.self) { fileType in
                Button(action: {
                    viewModel.setFileTypeFilter(fileType)
                }) {
                    HStack {
                        Image(systemName: fileType.icon)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Image(systemName: viewModel.selectedFileTypeFilter == fileType ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedFileTypeFilter == fileType ? .blue : .secondary)
                        Text(fileType.displayName)
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(viewModel.files.filter { $0.fileType == fileType }.count)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Group Review View

// SmartAction moved to its own file

struct GroupReviewView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @State private var selectedFiles: Set<UUID> = []
    @State private var hoveredFileId: UUID? = nil
    
    private var groupStats: (totalSize: Int64, dateRange: String?) {
        viewModel.getGroupStats()
    }
    
    private var smartActions: [SmartAction] {
        viewModel.getSmartActions()
    }
    
    private var groupTitle: String {
        guard let suggestion = viewModel.groupReviewSuggestion else {
            return "Review Group"
        }
        
        switch suggestion.type {
        case .duplicate(let count, _):
            return "\(count) Duplicate Files"
        case .similarNames(let pattern, let count, _):
            return "\(count) \(pattern)"
        case .sameSession(let count, _):
            return "\(count) Files from Same Session"
        default:
            return "Review Group"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with context
            VStack(spacing: 8) {
                HStack {
                    Button(action: {
                        viewModel.showGroupReview = false
                        viewModel.groupReviewFiles = []
                        viewModel.groupReviewSuggestion = nil
                        selectedFiles.removeAll()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(groupTitle)
                            .font(.system(size: 16, weight: .semibold))
                        
                        if let dateRange = groupStats.dateRange {
                            Text(dateRange)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(viewModel.groupReviewFiles.count) files")
                            .font(.system(size: 12, weight: .medium))
                        Text(ByteCountFormatter.string(fromByteCount: groupStats.totalSize, countStyle: .file))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            Divider()
                .opacity(0.2)
            
            // Smart Actions (if available)
            if !smartActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(smartActions.enumerated()), id: \.offset) { _, action in
                            SmartActionCard(action: action)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background {
                    VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                }
                
                Divider()
                    .opacity(0.2)
            }
            
            // File grid with larger thumbnails
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(Array(viewModel.groupReviewFiles.enumerated()), id: \.element.id) { index, file in
                        FileGridCard(
                            file: file,
                            isSelected: selectedFiles.contains(file.id),
                            isHovered: hoveredFileId == file.id,
                            isShaking: false,
                            onToggle: {
                                if selectedFiles.contains(file.id) {
                                    selectedFiles.remove(file.id)
                                } else {
                                    selectedFiles.insert(file.id)
                                }
                            },
                            onPreview: {
                                // Preview all files in group, starting with this one
                                let urls = viewModel.groupReviewFiles.map { $0.url }
                                QuickLookHelper.shared.preview(urls: urls, currentIndex: index)
                            },
                            onHover: { hovering in
                                hoveredFileId = hovering ? file.id : nil
                            }
                        )
                    }
                }
                .padding()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    selectedFiles = Set(viewModel.groupReviewFiles.map { $0.id })
                }) {
                    Text("Select All")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    let filesToBin = viewModel.groupReviewFiles.filter { selectedFiles.contains($0.id) }
                    viewModel.binGroupFiles(filesToBin)
                    selectedFiles.removeAll()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Bin Selected (\(selectedFiles.count))")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(Color.red)
                    }
                }
                .buttonStyle(.plain)
                .disabled(selectedFiles.isEmpty)
                
                Button(action: {
                    let filesToKeep = viewModel.groupReviewFiles.filter { selectedFiles.contains($0.id) }
                    viewModel.keepGroupFiles(filesToKeep)
                    selectedFiles.removeAll()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Keep Selected (\(selectedFiles.count))")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(Color.green)
                    }
                }
                .buttonStyle(.plain)
                .disabled(selectedFiles.isEmpty)
                    }
                    .padding()
            .background {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
        }
    }
}

// MARK: - Smart Action Card

struct SmartActionCard: View {
    let action: SmartAction
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action.action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: action.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text(action.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text(action.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(width: 200)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(isHovered ? 0.15 : 0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// FileGridCard moved to its own file

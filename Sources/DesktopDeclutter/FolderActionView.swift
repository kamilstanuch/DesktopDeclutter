//  FolderActionView.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  A detail/action screen for a single folder `DesktopFile`, showing folder icon/info, a lightweight preview of its contents (top 5 children), relocation status, and actions (Dive/Keep/Cloud/Move/Bin/Undo).
//
//  Unique characteristics
//  ----------------------
//  - Maintains a "live" reference to the folder by resolving the latest copy from viewModel.files to keep relocation status accurate.
//  - Uses background scanning of folder contents with URLResourceValues to build a small preview list.
//  - Adapts UI and disables actions when the folder has already been relocated.
//  - Cloud action supports multiple destinations via Menu and shows a settings prompt if none configured.
//  - Refreshes preview on appear, when folder changes, and when undoableActionCount changes.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  - SwiftUI core: https://developer.apple.com/documentation/swiftui
//  - View protocol: https://developer.apple.com/documentation/swiftui/view
//  - @ObservedObject: https://developer.apple.com/documentation/swiftui/observedobject
//  - @StateObject: https://developer.apple.com/documentation/swiftui/stateobject
//  - @State: https://developer.apple.com/documentation/swiftui/state
//  - Layout containers and primitives:
//    - VStack: https://developer.apple.com/documentation/swiftui/vstack
//    - HStack: https://developer.apple.com/documentation/swiftui/hstack
//    - ZStack: https://developer.apple.com/documentation/swiftui/zstack
//    - Spacer: https://developer.apple.com/documentation/swiftui/spacer
//  - Shapes and styling:
//    - Circle: https://developer.apple.com/documentation/swiftui/circle
//    - RoundedRectangle: https://developer.apple.com/documentation/swiftui/roundedrectangle
//    - Capsule: https://developer.apple.com/documentation/swiftui/capsule
//    - Color: https://developer.apple.com/documentation/swiftui/color
//    - shadow: https://developer.apple.com/documentation/swiftui/view/shadow(color:radius:x:y:)
//    - background: https://developer.apple.com/documentation/swiftui/view/background(_:alignment:)
//    - overlay: https://developer.apple.com/documentation/swiftui/view/overlay(alignment:content:)
//    - clipShape: https://developer.apple.com/documentation/swiftui/view/clipshape(_:style:)
//    - opacity: https://developer.apple.com/documentation/swiftui/view/opacity(_:) 
//    - help: https://developer.apple.com/documentation/swiftui/view/help(_:) 
//  - Text/images:
//    - Text: https://developer.apple.com/documentation/swiftui/text
//    - Image: https://developer.apple.com/documentation/swiftui/image
//    - Image(nsImage:): https://developer.apple.com/documentation/swiftui/image/init(nsimage:)
//    - Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//    - Font: https://developer.apple.com/documentation/swiftui/font
//  - Controls:
//    - Button: https://developer.apple.com/documentation/swiftui/button
//    - Menu: https://developer.apple.com/documentation/swiftui/menu
//    - ButtonStyle: https://developer.apple.com/documentation/swiftui/buttonstyle
//  - View lifecycle and animation:
//    - onAppear: https://developer.apple.com/documentation/swiftui/view/onappear(perform:)
//    - onChange: https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:)
//    - withAnimation: https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
//  - AppKit:
//    - AppKit: https://developer.apple.com/documentation/appkit
//    - NSAlert: https://developer.apple.com/documentation/appkit/nsalert
//  - Foundation / Dispatch:
//    - URL: https://developer.apple.com/documentation/foundation/url
//    - FileManager.contentsOfDirectory: https://developer.apple.com/documentation/foundation/filemanager/1412776-contentsofdirectory
//    - URLResourceKey: https://developer.apple.com/documentation/foundation/urlresourcekey
//    - URLResourceValues: https://developer.apple.com/documentation/foundation/urlresourcevalues
//    - DispatchQueue: https://developer.apple.com/documentation/dispatch/dispatchqueue
//  - System imagery (SF Symbols)
//    - https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//
//  NOTE: Internal types referenced:
//  - DeclutterViewModel, DesktopFile, FileDecision
//  - CloudManager, CloudDestination
//  - VisualEffectView

import SwiftUI // [Isolated] Import SwiftUI framework | [In-file] SwiftUI framework imported
import AppKit // [Isolated] Import AppKit framework | [In-file] AppKit framework imported

private struct FolderPreviewItem: Identifiable, Hashable { // [Isolated] Folder preview item struct for list | [In-file] FolderPreviewItem struct start
    let id = UUID() // [Isolated] Unique identifier | [In-file] id property
    let name: String // [Isolated] Item name | [In-file] name property
    let isDirectory: Bool // [Isolated] Directory flag | [In-file] isDirectory property
} // [Isolated] End FolderPreviewItem struct | [In-file] FolderPreviewItem struct end

struct FolderActionView: View { // [Isolated] Main view for folder detail and actions | [In-file] FolderActionView struct start
    @ObservedObject var viewModel: DeclutterViewModel // [Isolated] Observed view model | [In-file] DeclutterViewModel observed
    let onRequestOpenSettings: () -> Void // [Isolated] Callback to open settings | [In-file] Settings callback
    @StateObject private var cloudManager = CloudManager.shared // [Isolated] Shared cloud manager state object | [In-file] CloudManager singleton state
    @State private var folderContents: [FolderPreviewItem] = [] // [Isolated] Folder contents preview list state | [In-file] folderContents state
    @State private var childCount: Int = 0 // [Isolated] Number of items in folder state | [In-file] childCount state
    let folder: DesktopFile // [Isolated] Folder model passed in | [In-file] folder property

    private var liveFolder: DesktopFile { // [Isolated] Resolves latest folder copy from viewModel | [In-file] liveFolder computed property
        viewModel.files.first(where: { $0.id == folder.id }) ?? folder // [Isolated] Find matching folder or fallback | [In-file] liveFolder resolution
    } // [Isolated] End liveFolder computed property | [In-file] liveFolder computed end

    private var isRelocated: Bool { // [Isolated] Checks if folder is relocated | [In-file] isRelocated computed property
        viewModel.isRelocated(liveFolder) // [Isolated] Query viewModel relocation status | [In-file] isRelocated check
    } // [Isolated] End isRelocated computed property | [In-file] isRelocated computed end
    
    private var relocatedDestinationPath: String? { // [Isolated] Optional relocated destination path | [In-file] relocatedDestinationPath computed property
        viewModel.relocationDestination(for: folder)?.path // [Isolated] Query relocation destination path | [In-file] relocatedDestinationPath retrieval
    } // [Isolated] End relocatedDestinationPath computed property | [In-file] relocatedDestinationPath computed end

    private func promptToConfigureCloud() { // [Isolated] Show alert prompting cloud setup | [In-file] promptToConfigureCloud function start
        let alert = NSAlert() // [Isolated] Create NSAlert instance | [In-file] NSAlert creation
        alert.messageText = "Cloud destination not set up" // [Isolated] Alert title | [In-file] Alert message text
        alert.informativeText = "Would you like to open Settings and connect a cloud folder now?" // [Isolated] Alert informative text | [In-file] Alert informative text
        alert.alertStyle = .informational // [Isolated] Alert style set | [In-file] Alert style set
        alert.addButton(withTitle: "Open Settings") // [Isolated] Add primary button | [In-file] Add button "Open Settings"
        alert.addButton(withTitle: "Not Now") // [Isolated] Add secondary button | [In-file] Add button "Not Now"
        let response = alert.runModal() // [Isolated] Run alert modally | [In-file] Show alert and get response
        if response == .alertFirstButtonReturn { // [Isolated] If user chooses to open settings | [In-file] Check response
            onRequestOpenSettings() // [Isolated] Invoke settings callback | [In-file] Call onRequestOpenSettings
        } // [Isolated] End if response check | [In-file] End if
    } // [Isolated] End promptToConfigureCloud function | [In-file] promptToConfigureCloud function end
    
    var body: some View { // [Isolated] Main view body | [In-file] body property start
        VStack(spacing: 24) { // [Isolated] Vertical stack with spacing | [In-file] VStack container start
            Spacer() // [Isolated] Top spacer | [In-file] Spacer top

            VStack(spacing: 16) { // [Isolated] Folder icon and info container | [In-file] Folder icon/info VStack start
                ZStack { // [Isolated] Icon background and image overlay | [In-file] ZStack for folder icon start
                    Circle() // [Isolated] Circular background shape | [In-file] Circle background start
                        .fill(Color.blue.opacity(0.1)) // [Isolated] Fill with translucent blue | [In-file] Circle fill
                        .frame(width: 120, height: 120) // [Isolated] Fixed size frame | [In-file] Circle frame
                    Image(nsImage: folder.icon) // [Isolated] Folder icon image from NSImage | [In-file] Folder icon image
                        .resizable() // [Isolated] Make image resizable | [In-file] Image resizable
                        .frame(width: 80, height: 80) // [Isolated] Fixed icon size | [In-file] Image frame
                } // [Isolated] End ZStack for folder icon | [In-file] ZStack end
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5) // [Isolated] Apply subtle shadow | [In-file] Icon shadow

                VStack(spacing: 8) { // [Isolated] Folder name and status text | [In-file] Folder info VStack start
                    Text(folder.name) // [Isolated] Folder name text | [In-file] Folder name Text
                        .font(.system(size: 28, weight: .semibold)) // [Isolated] Large semibold font | [In-file] Folder name font
                        .multilineTextAlignment(.center) // [Isolated] Center text alignment | [In-file] Folder name alignment

                    if isRelocated { // [Isolated] Show relocation status if relocated | [In-file] Conditional relocation status start
                        Text(folder.decision == .cloud ? "Moved to Cloud" : "Moved") // [Isolated] Relocation status text | [In-file] Relocation status Text
                            .font(.system(size: 16, weight: .semibold)) // [Isolated] Medium semibold font | [In-file] Status font
                            .foregroundColor(.blue) // [Isolated] Blue text color | [In-file] Status color
                        if let relocatedDestinationPath { // [Isolated] Show relocated path if available | [In-file] Optional relocated path start
                            Text(relocatedDestinationPath) // [Isolated] Relocated destination path text | [In-file] Relocated path Text
                                .font(.system(size: 12)) // [Isolated] Small font | [In-file] Path font
                                .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Path color
                                .lineLimit(2) // [Isolated] Limit lines to 2 | [In-file] Path line limit
                                .multilineTextAlignment(.center) // [Isolated] Center alignment | [In-file] Path alignment
                                .frame(maxWidth: 320) // [Isolated] Max width constraint | [In-file] Path frame max width
                        } else { // [Isolated] Fallback text if no path | [In-file] Else relocated path
                            Text("This item has been moved from the current folder.") // [Isolated] Fallback relocation message | [In-file] Fallback relocation Text
                                .font(.system(size: 12)) // [Isolated] Small font | [In-file] Fallback font
                                .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Fallback color
                                .multilineTextAlignment(.center) // [Isolated] Center alignment | [In-file] Fallback alignment
                                .frame(maxWidth: 320) // [Isolated] Max width constraint | [In-file] Fallback frame max width
                        } // [Isolated] End optional relocated path else | [In-file] End else
                    } else { // [Isolated] Show child count if not relocated | [In-file] Else not relocated
                        Text("\(childCount) items inside") // [Isolated] Child count text | [In-file] Child count Text
                            .font(.system(size: 16)) // [Isolated] Medium font | [In-file] Child count font
                            .foregroundColor(.secondary) // [Isolated] Secondary text color | [In-file] Child count color
                    } // [Isolated] End isRelocated conditional | [In-file] End if
                } // [Isolated] End folder info VStack | [In-file] Folder info VStack end

                if !folderContents.isEmpty && !isRelocated { // [Isolated] Show preview list if contents available and not relocated | [In-file] Conditional preview list start
                    VStack(alignment: .leading, spacing: 8) { // [Isolated] Preview items vertical list | [In-file] Preview VStack start
                        ForEach(folderContents) { item in // [Isolated] Iterate preview items | [In-file] ForEach folderContents
                            HStack { // [Isolated] Single preview item horizontal stack | [In-file] Preview item HStack start
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc") // [Isolated] Icon for folder or file | [In-file] Preview icon Image
                                    .font(.system(size: 11)) // [Isolated] Small font for icon | [In-file] Icon font
                                    .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Icon color
                                Text(item.name) // [Isolated] Item name text | [In-file] Preview item Text
                                    .font(.system(size: 13)) // [Isolated] Small font | [In-file] Preview item font
                                    .lineLimit(1) // [Isolated] Single line limit | [In-file] Preview item line limit
                            } // [Isolated] End preview item HStack | [In-file] Preview item HStack end
                        } // [Isolated] End ForEach preview items | [In-file] ForEach end
                        if childCount > folderContents.count { // [Isolated] Show count of additional items | [In-file] Additional items count start
                            Text("+ \(childCount - folderContents.count) more") // [Isolated] Additional items text | [In-file] Additional items Text
                                .font(.caption) // [Isolated] Caption font | [In-file] Additional items font
                                .foregroundColor(.secondary) // [Isolated] Secondary color | [In-file] Additional items color
                                .padding(.top, 4) // [Isolated] Top padding | [In-file] Additional items padding
                        } // [Isolated] End additional items count | [In-file] End if additional items
                    } // [Isolated] End preview VStack | [In-file] Preview VStack end
                    .padding(16) // [Isolated] Padding around preview list | [In-file] Preview padding
                    .background( // [Isolated] Background with rounded rectangle and shadow | [In-file] Preview background start
                        RoundedRectangle(cornerRadius: 12) // [Isolated] Rounded rectangle shape | [In-file] RoundedRectangle shape
                            .fill(Color(nsColor: .controlBackgroundColor)) // [Isolated] Fill with control background color | [In-file] Background fill
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2) // [Isolated] Subtle shadow | [In-file] Background shadow
                    ) // [Isolated] End background modifier | [In-file] Background end
                    .frame(maxWidth: 320) // [Isolated] Max width constraint | [In-file] Preview frame max width
                } // [Isolated] End preview list conditional | [In-file] End if preview list
            } // [Isolated] End folder icon/info VStack | [In-file] Folder icon/info VStack end

            Spacer() // [Isolated] Bottom spacer | [In-file] Spacer bottom

            VStack(spacing: 16) { // [Isolated] Actions buttons container | [In-file] Actions VStack start
                Button(action: { // [Isolated] Dive into Folder button action | [In-file] Dive button start
                    viewModel.logInterfaceEvent("Dive into Folder button clicked", file: liveFolder) // [Isolated] Log event | [In-file] Log dive button
                    withAnimation { // [Isolated] Animate folder enter | [In-file] Animate enterFolder
                        viewModel.enterFolder(liveFolder) // [Isolated] Enter folder action | [In-file] viewModel enterFolder call
                    } // [Isolated] End animation block | [In-file] End withAnimation
                }) { // [Isolated] Dive button label | [In-file] Dive button label start
                    HStack { // [Isolated] Icon and text horizontal stack | [In-file] Dive button HStack start
                        Image(systemName: "arrow.turn.down.right") // [Isolated] Arrow icon | [In-file] Dive button icon
                        Text("Dive into Folder") // [Isolated] Button text | [In-file] Dive button text
                    } // [Isolated] End HStack | [In-file] Dive button HStack end
                    .font(.system(size: 15, weight: .semibold)) // [Isolated] Font style | [In-file] Dive button font
                    .frame(maxWidth: 240) // [Isolated] Max width constraint | [In-file] Dive button frame max width
                    .padding(.vertical, 14) // [Isolated] Vertical padding | [In-file] Dive button vertical padding
                    .background(Color.blue) // [Isolated] Blue background color | [In-file] Dive button background
                    .foregroundColor(.white) // [Isolated] White text color | [In-file] Dive button foreground
                    .clipShape(Capsule()) // [Isolated] Capsule shape clipping | [In-file] Dive button clipShape
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4) // [Isolated] Blue shadow | [In-file] Dive button shadow
                } // [Isolated] End Dive button label | [In-file] Dive button label end
                .buttonStyle(.plain) // [Isolated] Plain button style | [In-file] Dive button style
                .disabled(isRelocated) // [Isolated] Disable if relocated | [In-file] Dive button disabled
                .opacity(isRelocated ? 0.35 : 1.0) // [Isolated] Reduced opacity if disabled | [In-file] Dive button opacity
                
                HStack(spacing: 20) { // [Isolated] Horizontal stack for other action buttons | [In-file] Actions HStack start
                    Button("Keep/Skip") { // [Isolated] Keep/Skip button action | [In-file] Keep/Skip button start
                        viewModel.logInterfaceEvent("Keep/Skip button clicked", file: liveFolder) // [Isolated] Log event | [In-file] Log Keep/Skip button
                        withAnimation { // [Isolated] Animate skip folder | [In-file] Animate skipFolder call
                            viewModel.skipFolder(liveFolder) // [Isolated] Skip folder action | [In-file] viewModel skipFolder call
                        } // [Isolated] End animation block | [In-file] End withAnimation
                    } // [Isolated] End Keep/Skip button action | [In-file] Keep/Skip button end
                    .buttonStyle(StandardButtonStyle()) // [Isolated] Apply standard button style | [In-file] Keep/Skip button style
                    .disabled(isRelocated) // [Isolated] Disable if relocated | [In-file] Keep/Skip button disabled
                    .opacity(isRelocated ? 0.35 : 1.0) // [Isolated] Reduced opacity if disabled | [In-file] Keep/Skip button opacity

                    if cloudManager.destinations.count > 1 { // [Isolated] Multiple cloud destinations condition | [In-file] Cloud destinations > 1 start
                        Menu { // [Isolated] Cloud destinations menu | [In-file] Cloud menu start
                            ForEach(cloudManager.destinations) { dest in // [Isolated] Iterate cloud destinations | [In-file] ForEach cloud destinations
                                Button(cloudManager.destinationDisplayName(dest)) { // [Isolated] Destination selection button | [In-file] Destination button start
                                    viewModel.logInterfaceEvent("Cloud destination picked", details: cloudManager.destinationDisplayName(dest), file: liveFolder) // [Isolated] Log selection | [In-file] Log cloud destination pick
                                    withAnimation { viewModel.moveToCloud(liveFolder, destination: dest) } // [Isolated] Animate move to cloud | [In-file] Animate moveToCloud call
                                } // [Isolated] End destination button | [In-file] Destination button end
                            } // [Isolated] End ForEach cloud destinations | [In-file] ForEach end
                        } label: { // [Isolated] Menu label | [In-file] Cloud menu label
                            Text("Cloud") // [Isolated] Cloud button label | [In-file] Cloud menu label Text
                        } // [Isolated] End Menu label | [In-file] Cloud menu label end
                        .buttonStyle(StandardButtonStyle()) // [Isolated] Standard button style | [In-file] Cloud menu style
                        .disabled(isRelocated) // [Isolated] Disable if relocated | [In-file] Cloud menu disabled
                        .opacity(isRelocated ? 0.35 : 1.0) // [Isolated] Reduced opacity if disabled | [In-file] Cloud menu opacity
                    } else if cloudManager.destinations.count == 1 { // [Isolated] Single cloud destination condition | [In-file] Cloud destinations == 1
                        Button("Cloud") { // [Isolated] Single cloud destination button | [In-file] Cloud button start
                            viewModel.logInterfaceEvent("Cloud button clicked", file: liveFolder) // [Isolated] Log cloud button click | [In-file] Log cloud button click
                            withAnimation { viewModel.moveToCloud(liveFolder) } // [Isolated] Animate move to cloud | [In-file] Animate moveToCloud call
                        } // [Isolated] End cloud button action | [In-file] Cloud button end
                        .buttonStyle(StandardButtonStyle()) // [Isolated] Standard button style | [In-file] Cloud button style
                        .disabled(isRelocated) // [Isolated] Disable if relocated | [In-file] Cloud button disabled
                        .opacity(isRelocated ? 0.35 : 1.0) // [Isolated] Reduced opacity if disabled | [In-file] Cloud button opacity
                    } else { // [Isolated] No cloud destinations configured | [In-file] Cloud destinations == 0 else
                        Button("Cloud") { // [Isolated] Cloud button triggers setup prompt | [In-file] Cloud button start
                            viewModel.logInterfaceEvent("Cloud button clicked", file: liveFolder) // [Isolated] Log cloud button click | [In-file] Log cloud button click
                            promptToConfigureCloud() // [Isolated] Show cloud setup prompt | [In-file] Call promptToConfigureCloud
                        } // [Isolated] End cloud button action | [In-file] Cloud button end
                        .buttonStyle(StandardButtonStyle(isMuted: true)) // [Isolated] Muted button style | [In-file] Cloud button muted style
                        .disabled(isRelocated) // [Isolated] Disable if relocated | [In-file] Cloud button disabled
                        .opacity(isRelocated ? 0.35 : 1.0) // [Isolated] Reduced opacity if disabled | [In-file] Cloud button opacity
                        .help("Cloud is not configured. Click to open Settings.") // [Isolated] Tooltip help text | [In-file] Cloud button help
                    } // [Isolated] End cloud destinations conditional | [In-file] End else

                    Button("Move") { // [Isolated] Move button action | [In-file] Move button start
                        viewModel.logInterfaceEvent("Move button clicked", file: liveFolder) // [Isolated] Log move button click | [In-file] Log move button click
                        viewModel.promptForMoveDestination(files: [liveFolder]) // [Isolated] Prompt move destination | [In-file] viewModel promptForMoveDestination call
                    } // [Isolated] End move button action | [In-file] Move button end
                    .buttonStyle(StandardButtonStyle()) // [Isolated] Standard button style | [In-file] Move button style
                    .disabled(isRelocated) // [Isolated] Disable if relocated | [In-file] Move button disabled
                    .opacity(isRelocated ? 0.35 : 1.0) // [Isolated] Reduced opacity if disabled | [In-file] Move button opacity
                    
                    Button("Bin") { // [Isolated] Bin button action | [In-file] Bin button start
                        viewModel.logInterfaceEvent("Bin button clicked", file: liveFolder) // [Isolated] Log bin button click | [In-file] Log bin button click
                        withAnimation { // [Isolated] Animate bin action | [In-file] Animate binCurrentFile call
                            viewModel.binCurrentFile() // [Isolated] Bin current file action | [In-file] viewModel binCurrentFile call
                        } // [Isolated] End animation block | [In-file] End withAnimation
                    } // [Isolated] End bin button action | [In-file] Bin button end
                    .buttonStyle(StandardButtonStyle(isDestructive: true)) // [Isolated] Destructive button style | [In-file] Bin button destructive style
                    .disabled(isRelocated) // [Isolated] Disable if relocated | [In-file] Bin button disabled
                    .opacity(isRelocated ? 0.35 : 1.0) // [Isolated] Reduced opacity if disabled | [In-file] Bin button opacity
                } // [Isolated] End actions HStack | [In-file] Actions HStack end

                if isRelocated { // [Isolated] Show Undo button if relocated | [In-file] Undo button conditional start
                    Button("Undo") { // [Isolated] Undo button action | [In-file] Undo button start
                        viewModel.logInterfaceEvent("Undo button clicked", file: liveFolder) // [Isolated] Log undo button click | [In-file] Log undo button click
                        withAnimation { // [Isolated] Animate undo decision | [In-file] Animate undoDecision call
                            viewModel.undoDecision(for: liveFolder) // [Isolated] Undo decision action | [In-file] viewModel undoDecision call
                        } // [Isolated] End animation block | [In-file] End withAnimation
                    } // [Isolated] End undo button action | [In-file] Undo button end
                    .buttonStyle(StandardButtonStyle()) // [Isolated] Standard button style | [In-file] Undo button style
                } // [Isolated] End undo button conditional | [In-file] End if Undo button
            } // [Isolated] End actions VStack | [In-file] Actions VStack end
            .padding(.bottom, 60) // [Isolated] Bottom padding for actions | [In-file] Actions padding bottom
        } // [Isolated] End main VStack | [In-file] VStack end
        .frame(maxWidth: .infinity, maxHeight: .infinity) // [Isolated] Expand to fill available space | [In-file] Frame max size
        .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)) // [Isolated] Background blur effect | [In-file] VisualEffectView background
        .onAppear { // [Isolated] Load preview on appear | [In-file] onAppear modifier start
            loadFolderPreview(url: liveFolder.url) // [Isolated] Load folder preview | [In-file] Call loadFolderPreview
        } // [Isolated] End onAppear | [In-file] onAppear end
        .onChange(of: folder.id) { _ in // [Isolated] Reload preview on folder id change | [In-file] onChange folder.id start
            loadFolderPreview(url: liveFolder.url) // [Isolated] Load folder preview | [In-file] Call loadFolderPreview
        } // [Isolated] End onChange folder.id | [In-file] onChange end
        .onChange(of: viewModel.undoableActionCount) { _ in // [Isolated] Reload preview on undoable action count change | [In-file] onChange undoableActionCount start
            if !isRelocated { // [Isolated] Only if not relocated | [In-file] Conditional isRelocated
                loadFolderPreview(url: liveFolder.url) // [Isolated] Load folder preview | [In-file] Call loadFolderPreview
            } // [Isolated] End conditional | [In-file] End if
        } // [Isolated] End onChange undoableActionCount | [In-file] onChange end
    } // [Isolated] End body property | [In-file] body end
    
    private func loadFolderPreview(url: URL) { // [Isolated] Load folder preview contents asynchronously | [In-file] loadFolderPreview function start
        let requestedURL = url // [Isolated] Capture requested URL for validation | [In-file] requestedURL assignment
        DispatchQueue.main.async { // [Isolated] Clear preview on main thread | [In-file] Clear preview state
            self.childCount = 0 // [Isolated] Reset child count | [In-file] Reset childCount
            self.folderContents = [] // [Isolated] Reset folder contents | [In-file] Reset folderContents
        } // [Isolated] End main thread clear | [In-file] End DispatchQueue.main.async
        DispatchQueue.global(qos: .userInitiated).async { // [Isolated] Background scan folder contents | [In-file] DispatchQueue background start
            do { // [Isolated] Try to read directory contents | [In-file] Do-catch start
                let keys: [URLResourceKey] = [.isDirectoryKey] // [Isolated] Resource keys to fetch | [In-file] URLResourceKey array
                let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) // [Isolated] Read directory contents | [In-file] FileManager contentsOfDirectory call
                let sortedItems = items.prefix(5).map { item -> FolderPreviewItem in // [Isolated] Take first 5 items and map | [In-file] Map to FolderPreviewItem
                    let isDirectory = (try? item.resourceValues(forKeys: Set(keys)).isDirectory) ?? false // [Isolated] Check if directory | [In-file] isDirectory retrieval
                    return FolderPreviewItem(name: item.lastPathComponent, isDirectory: isDirectory) // [Isolated] Create preview item | [In-file] FolderPreviewItem init
                } // [Isolated] End map | [In-file] End map closure
                
                DispatchQueue.main.async { // [Isolated] Update UI on main thread | [In-file] DispatchQueue main update start
                    guard self.folder.url == requestedURL else { return } // [Isolated] Verify folder URL unchanged | [In-file] Guard URL match
                    self.childCount = items.count // [Isolated] Update child count | [In-file] Update childCount
                    self.folderContents = Array(sortedItems) // [Isolated] Update preview contents | [In-file] Update folderContents
                } // [Isolated] End main thread update | [In-file] End DispatchQueue.main.async
            } catch { // [Isolated] Handle errors reading directory | [In-file] Catch error start
                print("Error scanning folder preview: \(error)") // [Isolated] Log error | [In-file] Print error
                DispatchQueue.main.async { // [Isolated] Clear preview on error | [In-file] DispatchQueue main clear start
                    guard self.folder.url == requestedURL else { return } // [Isolated] Verify folder URL unchanged | [In-file] Guard URL match
                    self.childCount = 0 // [Isolated] Reset child count | [In-file] Reset childCount
                    self.folderContents = [] // [Isolated] Reset preview contents | [In-file] Reset folderContents
                } // [Isolated] End main thread clear | [In-file] End DispatchQueue.main.async
            } // [Isolated] End catch | [In-file] End catch block
        } // [Isolated] End background scan | [In-file] End DispatchQueue.global.async
    } // [Isolated] End loadFolderPreview function | [In-file] loadFolderPreview end
} // [Isolated] End FolderActionView struct | [In-file] FolderActionView end

struct StandardButtonStyle: ButtonStyle { // [Isolated] Custom standard button style conforming to ButtonStyle | [In-file] StandardButtonStyle struct start
    var isDestructive: Bool = false // [Isolated] Flag for destructive style | [In-file] isDestructive property
    var isMuted: Bool = false // [Isolated] Flag for muted style | [In-file] isMuted property
    
    func makeBody(configuration: Configuration) -> some View { // [Isolated] Required ButtonStyle method | [In-file] makeBody method start
        configuration.label // [Isolated] Button label view | [In-file] Configuration label
            .font(.system(size: 13, weight: .medium)) // [Isolated] Medium weight font size 13 | [In-file] Font modifier
            .foregroundColor(isDestructive ? .red : (isMuted ? .secondary : .primary)) // [Isolated] Foreground color by style flags | [In-file] ForegroundColor modifier
            .padding(.horizontal, 16) // [Isolated] Horizontal padding | [In-file] Padding horizontal
            .padding(.vertical, 8) // [Isolated] Vertical padding | [In-file] Padding vertical
            .background( // [Isolated] Background with capsule shape and fill | [In-file] Background modifier start
                Capsule() // [Isolated] Capsule shape | [In-file] Capsule shape start
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(isMuted ? 0.8 : 1.0)) // [Isolated] Fill with control background color and opacity | [In-file] Capsule fill
                    .overlay( // [Isolated] Outline overlay | [In-file] Overlay modifier start
                        Capsule() // [Isolated] Capsule shape for stroke | [In-file] Capsule overlay shape
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1) // [Isolated] Light stroke | [In-file] Stroke modifier
                    ) // [Isolated] End overlay | [In-file] Overlay end
            ) // [Isolated] End background | [In-file] Background end
            .opacity(configuration.isPressed ? 0.8 : 1.0) // [Isolated] Pressed opacity effect | [In-file] Opacity modifier
    } // [Isolated] End makeBody method | [In-file] makeBody end
} // [Isolated] End StandardButtonStyle struct | [In-file] StandardButtonStyle end

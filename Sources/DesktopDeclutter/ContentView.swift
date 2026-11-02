import SwiftUI
import QuickLookUI

struct ContentView: View {
    @StateObject private var viewModel = DeclutterViewModel()
    
    @State private var keyboardMonitor: Any? = nil
    @State private var showSettings = false
    @State private var showStackedFiles = false
    @State private var showBinnedFiles = false
    @State private var showFilters = false
    
    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            // Unified Toolbar with Material Effect
            HStack(spacing: 12) {
                Button(action: { viewModel.chooseFolder() }) {
                    Label("Choose Folder", systemImage: "folder")
                }
                .help(viewModel.selectedFolder?.path ?? "Choose a folder to review")
                // Undo button (only visible when undo is available)
                if viewModel.canUndo {
                    Button(action: {
                        _ = viewModel.undoLastAction()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle()
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                            }
                    }
                    .buttonStyle(.plain)
                    .help("Undo last action (↑ or ⌘Z)")
                }
                
                // Settings button
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettings, arrowEdge: .top) {
                    SettingsView(viewModel: viewModel)
                        .frame(width: 220)
                        .padding(16)
                }
                
                Spacer()
                
                // Progress Bar (Center)
                VStack(spacing: 4) {
                    ProgressView(value: Double(viewModel.currentFileIndex), total: Double(max(viewModel.filteredFiles.count, 1)))
                        .progressViewStyle(.linear)
                        .frame(width: 180)
                    
                    HStack(spacing: 4) {
                        Text("\(viewModel.currentFileIndex)")
                            .font(.system(size: 11, weight: .semibold))
                        Text("of")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                        Text("\(viewModel.filteredFiles.count)")
                            .font(.system(size: 11, weight: .semibold))
                        if viewModel.selectedFileTypeFilter != nil {
                            Text("(\(viewModel.totalFilesCount) total)")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Filter button
                Button(action: {
                    showFilters.toggle()
                }) {
                    Image(systemName: viewModel.selectedFileTypeFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(viewModel.selectedFileTypeFilter != nil ? .blue : .secondary)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showFilters, arrowEdge: .top) {
                    FilterView(viewModel: viewModel)
                        .frame(width: 200)
                        .padding(12)
                }
                
                // Binned files button (only show if immediate binning is OFF and there are binned files)
                if !viewModel.immediateBinning && viewModel.binnedFiles.count > 0 {
                    Button(action: {
                        showBinnedFiles.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13, weight: .medium))
                            Text("\(viewModel.binnedFiles.count)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(Color.red.opacity(0.15))
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showBinnedFiles, arrowEdge: .top) {
                        BinnedFilesView(viewModel: viewModel)
                            .frame(width: 350, height: 500)
                    }
                }
                
                // Stacked files button
                if viewModel.stackedFiles.count > 0 {
                    Button(action: {
                        showStackedFiles.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 13, weight: .medium))
                            Text("\(viewModel.stackedFiles.count)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showStackedFiles, arrowEdge: .top) {
                        StackedFilesView(viewModel: viewModel)
                            .frame(width: 350, height: 500)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                // Material blur effect (unified toolbar)
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
            
            if let folder = viewModel.selectedFolder {
                Text(folder.path).font(.caption).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle).padding(.horizontal).padding(.vertical, 4)
            }
            Divider()
                .opacity(0.2)
            
            ZStack {
                // Material background for main content
                VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                
                if viewModel.selectedFolder == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "folder").font(.system(size: 60))
                        Text("Choose a folder to start").font(.title2)
                        Text("Review files in this folder. Subfolders are left untouched.")
                        Button("Choose Folder…") { viewModel.chooseFolder() }
                    }
                } else if let error = viewModel.errorMessage {
                     VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Access Issue")
                            .font(.headline)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .font(.callout)
                        
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        
                        Button("Retry") {
                            viewModel.loadFiles()
                        }
                    }
                    .padding()
                } else if viewModel.showGroupReview {
                    // Group Review Mode
                    GroupReviewView(viewModel: viewModel)
                } else if !viewModel.isFinished {
                    ZStack {
                    VStack {
                        Spacer()
                        
                        if let file = viewModel.currentFile {
                            CardView(
                                file: file,
                                cardSize: CGSize(width: max(300, geometry.size.width - 200), height: max(400, geometry.size.height - 180)),
                                suggestions: viewModel.currentFileSuggestions,
                                onKeep: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    viewModel.keepCurrentFile()
                                    }
                                },
                                onBin: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    viewModel.binCurrentFile()
                                    }
                                },
                                onPreview: {
                                    QuickLookHelper.shared.preview(url: file.url)
                                },
                                onSuggestionTap: { suggestion in
                                    viewModel.startGroupReview(for: suggestion)
                                }
                            )
                            .id(file.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                            
                            Spacer()
                        }
                        
                        // Floating Action Buttons (overlaying bottom corners)
                        if viewModel.currentFile != nil {
                            HStack {
                                // Bin button (left)
                                FloatingActionButton(
                                    icon: "xmark.circle.fill",
                                    shortcut: "←",
                                    color: Color(red: 1.0, green: 0.27, blue: 0.23), // System red
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.binCurrentFile()
                                        }
                                    }
                                )
                        
                        Spacer()
                        
                                // Stack button (center)
                                FloatingActionButton(
                                    icon: "square.stack.fill",
                                    shortcut: "S",
                                    color: Color(red: 0.0, green: 0.48, blue: 1.0), // System blue
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.stackCurrentFile()
                                        }
                                    }
                                )
                                
                                Spacer()
                                
                                // Keep button (right)
                                FloatingActionButton(
                                    icon: "checkmark.circle.fill",
                                    shortcut: "→",
                                    color: Color(red: 0.20, green: 0.82, blue: 0.35), // System green
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.keepCurrentFile()
                                        }
                                    }
                                )
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 32)
                        }
                    }
                } else {
                    // Summary / Review State
                    ScrollView {
                        VStack(spacing: 24) {
                        if viewModel.binnedFiles.isEmpty {
                                VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                        .font(.system(size: 64, weight: .light))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.yellow, .orange],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    VStack(spacing: 8) {
                            Text("All Clean!")
                                            .font(.system(size: 24, weight: .semibold))
                            Text("No files to bin.")
                                            .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.top, 40)
                        } else {
                                VStack(spacing: 20) {
                                    // Header
                                    VStack(spacing: 8) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 48, weight: .medium))
                                .foregroundColor(.red)
                                        
                            Text("Review Bin")
                                            .font(.system(size: 22, weight: .semibold))
                            
                                        HStack(spacing: 6) {
                                Text("Total Size:")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                Text(viewModel.formattedReclaimedSpace)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background {
                                            Capsule()
                                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                                        }
                                    }
                                    
                                    // File list
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
                                                .frame(width: 36, height: 36)
                                                .cornerRadius(6)
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 6)
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
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                            }
                                        }
                                    }
                                    
                                    // Action button
                                    Button(action: {
                                        viewModel.emptyBin()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("Move to Trash")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background {
                                            Capsule()
                                                .fill(Color.red)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .help("Permanently delete all binned files")
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Rescan button
                            Button(action: {
                                viewModel.loadFiles()
                            }) {
                                Text("Rescan Folder")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            // Subtle footer with stats
            if !viewModel.isFinished {
                HStack {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.27, blue: 0.23))
                                .frame(width: 6, height: 6)
                            Text("Binned: \(viewModel.binnedCount)")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0.20, green: 0.82, blue: 0.35))
                                .frame(width: 6, height: 6)
                            Text("Kept: \(viewModel.keptCount)")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                }
            }
        }
        }
        .frame(minWidth: 720, minHeight: 680)
        .background(QuickLookResponder())
        .task(id: viewModel.currentFile?.id) {
            viewModel.refreshCurrentSuggestions()
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
        .onDisappear {
            if let monitor = keyboardMonitor { NSEvent.removeMonitor(monitor) }
            keyboardMonitor = nil
        }
    }
    
    private func setupKeyboardShortcuts() {
        guard keyboardMonitor == nil else { return }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let window = event.window ?? NSApp.keyWindow else { return event }
            // Exclude actual dialogs and Quick Look, rather than every NSPanel subclass.
            guard !(window is NSOpenPanel), !(window is NSSavePanel),
                  !(window is QLPreviewPanel), window.attachedSheet == nil,
                  !showSettings, !showFilters, !showBinnedFiles, !showStackedFiles,
                  !viewModel.showGroupReview else { return event }
            if let editor = window.firstResponder as? NSTextView, editor.isEditable { return event }
            if event.modifierFlags.intersection([.option, .control]).isEmpty == false { return event }
            // Handle Cmd+Z for undo
            if event.modifierFlags.contains(.command) {
                if event.keyCode == 6 { // Z key
                    if viewModel.canUndo {
                        _ = viewModel.undoLastAction()
                        return nil
                    }
                }
                return event // Let system handle other Cmd+key shortcuts
            }
            
            switch event.keyCode {
            case 126: // Up arrow: undo the previous decision
                if viewModel.canUndo {
                    _ = viewModel.undoLastAction()
                }
                return nil
            case 123: // Left arrow
                if !viewModel.isFinished {
                    viewModel.binCurrentFile()
                    return nil
                }
            case 124: // Right arrow
                if !viewModel.isFinished {
                    viewModel.keepCurrentFile()
                    return nil
                }
            case 49: // Spacebar
                if !viewModel.isFinished, let file = viewModel.currentFile {
                    QuickLookHelper.shared.preview(url: file.url)
                    return nil
                }
            case 1: // S key
                if !viewModel.isFinished {
                    viewModel.stackCurrentFile()
                    return nil
                }
            default:
                break
            }
            
            return event
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

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))
            
            Divider()
                .opacity(0.3)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Trash Immediately", isOn: Binding(
                    get: { viewModel.immediateBinning },
                    set: { newValue in
                        viewModel.immediateBinning = newValue
                    }
                ))
                .font(.system(size: 13, weight: .medium))
                .toggleStyle(.switch)
                .controlSize(.regular)
                
                Text("When enabled, files are moved to Trash immediately. When disabled, files are collected for review.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stacked Files")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(viewModel.stackedFiles.count) file\(viewModel.stackedFiles.count == 1 ? "" : "s") ready for removal")
                        .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                
                Spacer()
                
                Button(action: {
                    viewModel.emptyStack()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Remove All")
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
                    ForEach(viewModel.stackedFiles) { file in
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
                                    viewModel.removeFromStack(file)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.red)
                                        .frame(width: 28, height: 28)
                                        .background {
                                            Circle()
                                                .fill(Color.red.opacity(0.1))
                                        }
                                }
                                .buttonStyle(.plain)
                                .help("Remove from stack")
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

struct SmartAction {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
}

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
                        GroupReviewFileCard(
                            file: file,
                            isSelected: selectedFiles.contains(file.id),
                            isHovered: hoveredFileId == file.id,
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

struct GroupReviewFileCard: View {
    let file: DesktopFile
    let isSelected: Bool
    let isHovered: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void
    let onHover: (Bool) -> Void
    
    @State private var hoveredPreview = false
    
    private var fileDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        if let date = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date {
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return "Recently"
    }
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail - larger and better quality
                Group {
                    if let thumb = file.thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(nsImage: file.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 160, height: 160)
                .cornerRadius(12)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : (isHovered ? Color.blue.opacity(0.3) : Color.clear), lineWidth: isSelected ? 3 : 2)
                }
                .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 8 : 4)
                .scaleEffect(hoveredPreview ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: hoveredPreview)
                
                // Selection checkbox
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(isSelected ? .blue : .white)
                        .background {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 32, height: 32)
                        }
                }
                .buttonStyle(.plain)
                .padding(6)
                
                // Preview overlay on hover
                if isHovered {
                    Button(action: onPreview) {
                        VStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Preview")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            
            // File info
            VStack(spacing: 4) {
                Text(file.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
                
                HStack(spacing: 4) {
                    Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(fileDateString)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 160)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.7 : 0.5))
        }
        .onHover { hovering in
            onHover(hovering)
            hoveredPreview = hovering
        }
        .onTapGesture {
            // Single click toggles selection
            onToggle()
        }
        .gesture(
            TapGesture(count: 2)
                .onEnded { _ in
                    // Double-click opens preview
                    onPreview()
                }
        )
    }
}

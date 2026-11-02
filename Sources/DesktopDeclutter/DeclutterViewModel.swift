import SwiftUI

@MainActor
class DeclutterViewModel: ObservableObject {
    @Published var files: [DesktopFile] = []
    @Published var currentFileIndex: Int = 0
    @Published var binnedFiles: [DesktopFile] = []
    @Published var errorMessage: String? = nil
    
    @Published var reclaimedSpace: Int64 = 0
    
    // Stats
    @Published var keptCount: Int = 0
    @Published var binnedCount: Int = 0
    @Published var totalFilesCount: Int = 0
    
    // Modes
    @Published var immediateBinning: Bool = false
    
    // Stacked files (for later review)
    @Published var stackedFiles: [DesktopFile] = []
    
    // Preview
    @Published var previewUrl: URL? = nil
    
    // Filters
    @Published var selectedFileTypeFilter: FileType? = nil
    
    // Suggestions
    @Published var currentFileSuggestions: [FileSuggestion] = []
    @Published var showGroupReview = false
    @Published var groupReviewFiles: [DesktopFile] = []
    @Published var groupReviewSuggestion: FileSuggestion? = nil
    private var suggestionCache: [UUID: [FileSuggestion]] = [:]
    
    var filteredFiles: [DesktopFile] {
        if let filter = selectedFileTypeFilter {
            return files.filter { $0.fileType == filter }
        }
        return files
    }
    
    private var lastSuggestionFileId: UUID? = nil
    private var suggestionTask: Task<Void, Never>? = nil
    
    var currentFile: DesktopFile? {
        let visible = filteredFiles
        guard visible.indices.contains(currentFileIndex) else { return nil }
        return visible[currentFileIndex]
    }

    func refreshCurrentSuggestions() {
        guard let file = currentFile else {
            suggestionTask?.cancel()
            currentFileSuggestions = []
            lastSuggestionFileId = nil
            return
        }
        guard lastSuggestionFileId != file.id else { return }
        lastSuggestionFileId = file.id
        updateSuggestionsAsync(for: file)
    }

    private func updateSuggestionsAsync(for file: DesktopFile) {
        // Check cache first
        if let cached = suggestionCache[file.id] {
            currentFileSuggestions = cached
            return
        }
        
        // Show empty suggestions immediately (will update when ready)
        currentFileSuggestions = []
        
        // Cancel any existing task
        suggestionTask?.cancel()
        
        // Run detection on background thread with cancellation support
        suggestionTask = Task {
            // Limit files to compare against (only check first 100 files for performance)
            // This prevents slowdowns with large desktop collections
            let filesToCheck = Array(files.prefix(100))
            
            // Small delay to debounce rapid file changes
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            guard !Task.isCancelled else { return }
            
            let suggestions = await SuggestionDetector.shared.detectSuggestionsAsync(for: file, in: filesToCheck)
            
            guard !Task.isCancelled else { return }
            
            // Update on main thread
            await MainActor.run {
                // Only update if this file is still current
                if lastSuggestionFileId == file.id && suggestionCache[file.id] == nil {
                    currentFileSuggestions = suggestions
                    suggestionCache.removeAll()
                    suggestionCache[file.id] = suggestions
                }
            }
        }
    }
    
    var isFinished: Bool {
        currentFileIndex >= filteredFiles.count
    }
    
    // Undo/Redo
    private struct Action: Equatable {
        let type: ActionType
        let file: DesktopFile
        let previousIndex: Int
        let fileOriginalIndex: Int? // Original position in files array
        
        enum ActionType: Equatable {
            case keep
            case bin
            case stack
        }
    }
    
    private var actionHistory: [Action] = []
    private var maxHistorySize = 50
    
    @Published var selectedFolder: URL? = nil

    func chooseFolder() {
        if !binnedFiles.isEmpty || !stackedFiles.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Switch folders?"
            alert.informativeText = "Pending deletion and later-review decisions will be cleared. No files will be deleted."
            alert.addButton(withTitle: "Switch Folder")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Review Folder"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        selectedFolder = folder
        loadFiles()
    }

    func loadFiles() {
        self.errorMessage = nil
        do {
            guard let folder = selectedFolder else { return }
            let loadedFiles = try FileScanner.shared.scanFolder(folder)
            actionHistory.removeAll()
            suggestionTask?.cancel()
            showGroupReview = false
            groupReviewFiles = []
            groupReviewSuggestion = nil
            self.files = loadedFiles
            self.currentFileIndex = 0
            self.binnedFiles = []
            self.stackedFiles = []
            self.reclaimedSpace = 0
            self.keptCount = 0
            self.binnedCount = 0
            self.totalFilesCount = loadedFiles.count
            self.selectedFileTypeFilter = nil // Reset filter
            self.suggestionCache.removeAll() // Clear suggestion cache
            self.currentFileSuggestions = []
            self.lastSuggestionFileId = nil
            self.thumbnailGenerationInProgress.removeAll()
            
            // Trigger thumbnail generation for the first file only (lazy load others)
            generateThumbnails(for: 0)
        } catch {
            self.errorMessage = error.localizedDescription
            self.files = []
            self.totalFilesCount = 0
        }
    }
    
    func setFileTypeFilter(_ type: FileType?) {
        selectedFileTypeFilter = type
        currentFileIndex = 0 // Reset to start of filtered list
        generateThumbnails(for: 0)
    }
    
    private var thumbnailGenerationInProgress = Set<UUID>()
    
    func generateThumbnails(for index: Int) {
        let visible = filteredFiles
        guard visible.indices.contains(index) else { return }
        let nearby = Array(visible[index..<min(index + 2, visible.count)])
        let retained = Set(nearby.map(\.id))
        for i in files.indices where files[i].thumbnail != nil && !retained.contains(files[i].id) {
            files[i].thumbnail = nil
        }
        for file in nearby {
            guard file.thumbnail == nil, !thumbnailGenerationInProgress.contains(file.id) else { continue }
            thumbnailGenerationInProgress.insert(file.id)
            FileScanner.shared.generateThumbnail(for: file) { [weak self] image in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.thumbnailGenerationInProgress.remove(file.id)
                    let visible = self.filteredFiles
                    let start = min(max(0, self.currentFileIndex), visible.count)
                    let wanted = visible[start..<min(start + 2, visible.count)].contains { $0.id == file.id }
                    if wanted, let position = self.files.firstIndex(where: { $0.id == file.id }) {
                        self.files[position].thumbnail = image
                    }
                }
            }
        }
    }

    // Note: currentFile and isFinished are now computed properties above
    
    func keepCurrentFile() {
        guard let file = currentFile else { return }
        
        // Find original index in files array
        let originalIndex = files.firstIndex(where: { $0.id == file.id })
        
        // Record action for undo
        recordAction(.keep, file: file, originalIndex: originalIndex)
        
        // Remove from files array
        files.removeAll { $0.id == file.id }
        
        keptCount += 1
        moveToNext()
    }
    
    func binCurrentFile() {
        guard let file = currentFile else { return }
        
        // Find original index in files array
        let originalIndex = files.firstIndex(where: { $0.id == file.id })
        
        // Record action for undo
        recordAction(.bin, file: file, originalIndex: originalIndex)
        
        // Remove from files array
        files.removeAll { $0.id == file.id }
        
        if immediateBinning {
            // Immediately move to trash
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                binnedCount += 1
                reclaimedSpace += file.fileSize
                print("Immediately moved to trash: \(file.name)")
            } catch {
                print("Failed to trash file \(file.name): \(error)")
                // Still count it as binned even if trash failed
                binnedCount += 1
                reclaimedSpace += file.fileSize
            }
        } else {
            // Collect for later review
        binnedFiles.append(withoutThumbnail(file))
            binnedCount += 1
        reclaimedSpace += file.fileSize
        }
        
        moveToNext()
    }
    
    func stackCurrentFile() {
        guard let file = currentFile else { return }
        
        // Find original index in files array
        let originalIndex = files.firstIndex(where: { $0.id == file.id })
        
        // Record action for undo
        recordAction(.stack, file: file, originalIndex: originalIndex)
        
        // Remove from files array
        files.removeAll { $0.id == file.id }
        
        stackedFiles.append(withoutThumbnail(file))
        moveToNext()
    }
    
    private func withoutThumbnail(_ file: DesktopFile) -> DesktopFile {
        var result = file
        result.thumbnail = nil
        return result
    }

    private func recordAction(_ type: Action.ActionType, file: DesktopFile, originalIndex: Int?) {
        let action = Action(
            type: type,
            file: withoutThumbnail(file),
            previousIndex: currentFileIndex,
            fileOriginalIndex: originalIndex
        )
        actionHistory.append(action)
        
        // Limit history size
        if actionHistory.count > maxHistorySize {
            actionHistory.removeFirst()
        }
    }
    
    func undoLastAction() -> Bool {
        guard let lastAction = actionHistory.popLast() else {
            return false
        }
        
        // Re-insert the file back into the files array
        if let originalIndex = lastAction.fileOriginalIndex, originalIndex <= files.count {
            // Insert at original position if possible
            files.insert(lastAction.file, at: min(originalIndex, files.count))
        } else {
            // If we don't have original index, insert at the previous position
            let insertIndex = min(lastAction.previousIndex, files.count)
            files.insert(lastAction.file, at: insertIndex)
        }
        
        // Undo the action and restore counters
        switch lastAction.type {
        case .keep:
            keptCount = max(0, keptCount - 1)
            
        case .bin:
            binnedCount = max(0, binnedCount - 1)
            reclaimedSpace = max(0, reclaimedSpace - lastAction.file.fileSize)
            
            // Remove from binned files if it was collected for review
            if !immediateBinning {
                binnedFiles.removeAll { $0.id == lastAction.file.id }
            }
            // Note: If immediate binning was used, file is already in trash
            // We can't restore it from trash, but we've added it back to the list
            // User would need to manually restore from trash if they want the actual file
            
        case .stack:
            stackedFiles.removeAll { $0.id == lastAction.file.id }
        }
        
        // Restore file index to point to the file we were looking at
        // Find the file in the filtered list
        let filtered = filteredFiles
        if let newIndex = filtered.firstIndex(where: { $0.id == lastAction.file.id }) {
            withAnimation {
                currentFileIndex = newIndex
            }
        } else {
            // If file doesn't match current filter, restore to previous index
            withAnimation {
                currentFileIndex = min(lastAction.previousIndex, filtered.count)
            }
        }
        
        // Regenerate thumbnails for current position
        generateThumbnails(for: currentFileIndex)
        
        return true
    }
    
    var canUndo: Bool {
        !actionHistory.isEmpty
    }
    
    func removeFromStack(_ file: DesktopFile) {
        stackedFiles.removeAll { $0.id == file.id }
    }
    
    func emptyStack() {
        for file in stackedFiles {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                print("Moved to trash: \(file.name)")
            } catch {
                print("Failed to trash file \(file.name): \(error)")
            }
        }
        stackedFiles.removeAll()
        // Don't reset session - just clear the stack
    }
    
    private func moveToNext() {
        // Decisions remove the current file, so its successor occupies the same index.
        currentFileIndex = min(max(0, currentFileIndex), filteredFiles.count)
        generateThumbnails(for: currentFileIndex)
    }

    func emptyBin() {
        for file in binnedFiles {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                print("Moved to trash: \(file.name)")
            } catch {
                print("Failed to trash file \(file.name): \(error)")
            }
        }
        binnedFiles.removeAll()
        reclaimedSpace = 0 // Reset reclaimed space since files are now in trash
        // Don't reset session - just clear the bin
    }
    
    func restoreFromBin(_ file: DesktopFile) {
        // Remove from bin
        binnedFiles.removeAll { $0.id == file.id }
        
        // Restore counters
        binnedCount = max(0, binnedCount - 1)
        reclaimedSpace = max(0, reclaimedSpace - file.fileSize)
        
        // Add back to files array at the beginning (so user can review it)
        files.insert(file, at: 0)
        
        // If we're at the end, go back to review this file
        if currentFileIndex >= filteredFiles.count {
            currentFileIndex = 0
        }
        
        // Regenerate thumbnails
        generateThumbnails(for: currentFileIndex)
    }
    
    func removeFromBin(_ file: DesktopFile) {
        // Remove from bin
        binnedFiles.removeAll { $0.id == file.id }
        
        // Restore counters
        binnedCount = max(0, binnedCount - 1)
        reclaimedSpace = max(0, reclaimedSpace - file.fileSize)
        
        // Move to trash immediately
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            print("Moved to trash: \(file.name)")
        } catch {
            print("Failed to trash file \(file.name): \(error)")
        }
    }
    
    var formattedReclaimedSpace: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: reclaimedSpace)
    }
    
    // MARK: - Group Review
    
    func startGroupReview(for suggestion: FileSuggestion) {
        let groupFiles: [DesktopFile]
        
        switch suggestion.type {
        case .duplicate(_, let files),
             .similarNames(_, _, let files),
             .sameSession(_, let files):
            groupFiles = files
        default:
            return
        }
        
        // Sync thumbnails from main files array and generate missing ones
        var syncedFiles: [DesktopFile] = []
        for var file in groupFiles {
            // Look up the file in the main files array to get its thumbnail if it exists
            if let mainFileIndex = files.firstIndex(where: { $0.id == file.id }),
               let thumbnail = files[mainFileIndex].thumbnail {
                file.thumbnail = thumbnail
            }
            syncedFiles.append(file)
        }
        
        groupReviewFiles = syncedFiles
        groupReviewSuggestion = suggestion
        showGroupReview = true
        
        // Generate thumbnails for any files in the group that don't have them yet
        generateThumbnailsForGroupReview()
    }
    
    private func generateThumbnailsForGroupReview() {
        for (index, file) in groupReviewFiles.enumerated() {
            // Skip if already generating or already has thumbnail
            guard !thumbnailGenerationInProgress.contains(file.id),
                  file.thumbnail == nil else {
                continue
            }
            
            // Mark as in progress
            thumbnailGenerationInProgress.insert(file.id)
            
            FileScanner.shared.generateThumbnail(for: file, maxDimension: 320) { [weak self] image in
                guard let self = self else { return }
                
                // Update on main thread
                Task { @MainActor in
                    // Update the thumbnail in groupReviewFiles (reassign array to trigger SwiftUI update)
                    if index < self.groupReviewFiles.count,
                       self.groupReviewFiles[index].id == file.id {
                        var updatedFiles = self.groupReviewFiles
                        updatedFiles[index].thumbnail = image
                        self.groupReviewFiles = updatedFiles
                    }
                    
                    // Also update in main files array if it exists there
                    if let mainFileIndex = self.files.firstIndex(where: { $0.id == file.id }) {
                        var updatedMainFiles = self.files
                        updatedMainFiles[mainFileIndex].thumbnail = image
                        self.files = updatedMainFiles
                    }
                    
                    self.thumbnailGenerationInProgress.remove(file.id)
                }
            }
        }
    }
    
    func getGroupStats() -> (totalSize: Int64, dateRange: String?) {
        let totalSize = groupReviewFiles.reduce(0) { $0 + $1.fileSize }
        
        // Get date range
        let dates = groupReviewFiles.compactMap { file -> Date? in
            try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date
        }
        
        guard let earliest = dates.min(), let latest = dates.max() else {
            return (totalSize, nil)
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if Calendar.current.isDate(earliest, inSameDayAs: latest) {
            formatter.dateStyle = .none
            return (totalSize, "Today \(formatter.string(from: earliest)) - \(formatter.string(from: latest))")
        } else {
            return (totalSize, "\(formatter.string(from: earliest)) - \(formatter.string(from: latest))")
        }
    }
    
    func getSmartActions() -> [SmartAction] {
        guard let suggestion = groupReviewSuggestion else { return [] }
        
        var actions: [SmartAction] = []
        let totalSize = groupReviewFiles.reduce(0) { $0 + $1.fileSize }
        let sizeMB = Double(totalSize) / (1024 * 1024)
        
        switch suggestion.type {
        case .duplicate(let count, _):
            // Sort by date (newest first)
            let sorted = groupReviewFiles.sorted { file1, file2 in
                let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.url.path)[.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.url.path)[.creationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            }
            
            actions.append(SmartAction(
                title: "Keep newest, delete others",
                description: "Keep 1 file, delete \(count - 1)",
                icon: "clock.fill",
                action: {
                    let toKeep = [sorted.first!]
                    let toBin = Array(sorted.dropFirst())
                    self.keepGroupFiles(toKeep)
                    self.binGroupFiles(toBin)
                }
            ))
            
        case .similarNames(_, let count, _):
            // For screenshots, suggest keeping recent ones
            let sorted = groupReviewFiles.sorted { file1, file2 in
                let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.url.path)[.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.url.path)[.creationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            }
            
            let keepCount = min(5, count)
            actions.append(SmartAction(
                title: "Keep newest \(keepCount), delete rest",
                description: "Free \(String(format: "%.1f", sizeMB * Double(count - keepCount) / Double(count))) MB",
                icon: "sparkles",
                action: {
                    let toKeep = Array(sorted.prefix(keepCount))
                    let toBin = Array(sorted.dropFirst(keepCount))
                    self.keepGroupFiles(toKeep)
                    self.binGroupFiles(toBin)
                }
            ))
            
            // Delete all older than 1 week
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let oldFiles = groupReviewFiles.filter { file in
                guard let date = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
                    return false
                }
                return date < oneWeekAgo
            }
            
            if !oldFiles.isEmpty {
                let oldSizeMB = Double(oldFiles.reduce(0) { $0 + $1.fileSize }) / (1024 * 1024)
                actions.append(SmartAction(
                    title: "Delete files older than 1 week",
                    description: "\(oldFiles.count) files, \(String(format: "%.1f", oldSizeMB)) MB",
                    icon: "calendar.badge.clock",
                    action: {
                        self.binGroupFiles(oldFiles)
                    }
                ))
            }
            
        case .sameSession(_, _):
            actions.append(SmartAction(
                title: "Keep all (created together)",
                description: "These files are related",
                icon: "checkmark.circle.fill",
                action: {
                    self.keepGroupFiles(self.groupReviewFiles)
                }
            ))
            
            actions.append(SmartAction(
                title: "Delete all",
                description: "Free \(String(format: "%.1f", sizeMB)) MB",
                icon: "trash.fill",
                action: {
                    self.binGroupFiles(self.groupReviewFiles)
                }
            ))
            
        default:
            break
        }
        
        return actions
    }
    
    func binGroupFiles(_ filesToBin: [DesktopFile]) {
        guard !filesToBin.isEmpty else { return }
        
        for file in filesToBin {
            if files.contains(where: { $0.id == file.id }) {
                // Remove from files and bin
                files.removeAll { $0.id == file.id }
                
                if immediateBinning {
                    do {
                        try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                        binnedCount += 1
                        reclaimedSpace += file.fileSize
                    } catch {
                        binnedCount += 1
                        reclaimedSpace += file.fileSize
                    }
                } else {
                    binnedFiles.append(withoutThumbnail(file))
                    binnedCount += 1
                    reclaimedSpace += file.fileSize
                }
            }
        }
        
        // Clear suggestion cache for removed files
        for file in filesToBin {
            suggestionCache.removeValue(forKey: file.id)
        }
        
        // Remove binned files from group review
        groupReviewFiles.removeAll { file in filesToBin.contains { $0.id == file.id } }
        
        // If all files processed, exit group review
        if groupReviewFiles.isEmpty {
            showGroupReview = false
            groupReviewSuggestion = nil
        }
    }
    
    func keepGroupFiles(_ filesToKeep: [DesktopFile]) {
        guard !filesToKeep.isEmpty else { return }
        
        for file in filesToKeep {
            files.removeAll { $0.id == file.id }
            keptCount += 1
            suggestionCache.removeValue(forKey: file.id)
        }
        
        // Remove kept files from group review
        groupReviewFiles.removeAll { file in filesToKeep.contains { $0.id == file.id } }
        
        // If all files processed, exit group review
        if groupReviewFiles.isEmpty {
            showGroupReview = false
            groupReviewSuggestion = nil
        }
    }
}

//  DeclutterViewModel.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  This file defines the primary session orchestration view model for DesktopDeclutter.
//  It is responsible for loading/scanning files from the selected folder, tracking the user’s
//  progress through those files, applying decisions (Keep/Bin/Stack/Move/Cloud), and coordinating
//  related UI state such as previews, progress indicators, toasts, and navigation.
//
//  Unique characteristics
//  ----------------------
//  - Annotated with @MainActor to ensure all published UI state is mutated safely on the main thread.
//  - Maintains a “session timeline” of file decisions with undo/redo stacks and a bounded history log.
//  - Implements debounced async suggestion detection with cancellation + caching to avoid stale updates.
//  - Generates thumbnails lazily for the current file and a small lookahead window, tracking in-flight work.
//  - Supports folder navigation via a stack of “folder contexts” (enter folder / return to parent) and
//    maintains breadcrumb text for UI display.
//  - Handles cloud moves via CloudManager (including provider-specific destination logic) and folder moves
//    via security-scoped access, using safe fallback strategies when moves fail.
//  - Protects against moving application bundles from system directories to reduce risky operations.
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  Swift (language)
//  - https://docs.swift.org/swift-book/documentation/the-swift-programming-language/
//
//  Swift Concurrency
//  - Task: https://developer.apple.com/documentation/swift/task
//  - MainActor: https://developer.apple.com/documentation/swift/mainactor
//
//  SwiftUI / Combine state propagation
//  - SwiftUI: https://developer.apple.com/documentation/swiftui
//  - ObservableObject: https://developer.apple.com/documentation/swiftui/observableobject
//  - @Published: https://developer.apple.com/documentation/combine/published
//  - withAnimation: https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
//
//  Foundation (filesystem + formatting)
//  - Foundation: https://developer.apple.com/documentation/foundation
//  - FileManager (including file attributes): https://developer.apple.com/documentation/foundation/filemanager
//  - ByteCountFormatter: https://developer.apple.com/documentation/foundation/bytecountformatter
//  - Date: https://developer.apple.com/documentation/foundation/date
//  - DateFormatter: https://developer.apple.com/documentation/foundation/dateformatter
//  - Calendar: https://developer.apple.com/documentation/foundation/calendar
//  - URL: https://developer.apple.com/documentation/foundation/url
//  - NSError: https://developer.apple.com/documentation/foundation/nserror
//
//  Dispatch (thread hopping)
//  - DispatchQueue: https://developer.apple.com/documentation/dispatch/dispatchqueue
//
//  AppKit (folder picking + alerts)
//  - AppKit: https://developer.apple.com/documentation/appkit
//  - NSOpenPanel: https://developer.apple.com/documentation/appkit/nsopenpanel
//  - NSAlert: https://developer.apple.com/documentation/appkit/nsalert
//  - NSApplication (NSApp.activate): https://developer.apple.com/documentation/appkit/nsapplication
//
//  Security-scoped resources (macOS sandbox)
//  - startAccessingSecurityScopedResource():
//    https://developer.apple.com/documentation/foundation/url/1415005-startaccessingsecurityscopedr
//  - stopAccessingSecurityScopedResource():
//    https://developer.apple.com/documentation/foundation/url/1415006-stopaccessingsecurityscopedre
//
//  NOTE: The following types are referenced but are defined within this project (internal, not external libraries):
//  - DesktopFile (model for an item being decluttered; includes URL, size, type, thumbnail, etc.)
//  - FileDecision (enum tracking Keep/Bin/Stack/Move/Cloud decisions)
//  - FileType (enum used for filtering and folder/file classification)
//  - FileScanner (scanner + thumbnail generator)
//  - CloudManager / CloudDestination / CloudProvider (cloud destination management + moves)
//  - FileSuggestion / SuggestionDetector (suggestion generation and group review inputs)
//  - SmartAction (prebaked group review actions)
//

import AppKit // [Isolated] Imports AppKit types. | [In-file] Required for NSOpenPanel/NSAlert/NSApp activation behaviors.
import SwiftUI // [Isolated] Imports SwiftUI/Combine bridging. | [In-file] Provides ObservableObject/@Published and animation helpers.

@MainActor // [Isolated] Constrains to main actor. | [In-file] Ensures all state changes happen safely for UI consumption.
class DeclutterViewModel: ObservableObject { // [Isolated] Declares observable view model. | [In-file] Central coordinator for session state, actions, and navigation.
    @Published var files: [DesktopFile] = [] // [Isolated] Published array of files. | [In-file] The primary dataset for the declutter session.
    @Published var currentFileIndex: Int = 0 // [Isolated] Published index pointer. | [In-file] Determines which file is “current” in card mode and navigation.
    @Published var binnedFiles: [DesktopFile] = [] // [Isolated] Published bin collection. | [In-file] Holds items awaiting review when immediate binning is disabled.
    @Published var errorMessage: String? = nil // [Isolated] Published optional error text. | [In-file] Surfaces operational failures to UI.
    @Published var selectedFolderURL: URL? = nil // [Isolated] Published optional URL. | [In-file] Tracks the user-chosen folder being scanned.
    @Published var breadcrumbText: String = "" // [Isolated] Published breadcrumb string. | [In-file] Provides navigation context (folder stack → breadcrumb display).
    
    @Published var reclaimedSpace: Int64 = 0 // [Isolated] Published byte count. | [In-file] Tracks total size of binned items for “space reclaimed” UI.
    
    @Published var keptCount: Int = 0 // [Isolated] Published counter. | [In-file] Tracks how many files were marked kept in this session.
    @Published var binnedCount: Int = 0 // [Isolated] Published counter. | [In-file] Tracks how many files were marked binned in this session.
    @Published var totalFilesCount: Int = 0 // [Isolated] Published counter. | [In-file] Tracks the total scanned files for progress and summary.
    
    @Published var immediateBinning: Bool = true // [Isolated] Published mode flag. | [In-file] Controls whether binning moves to Trash immediately or queues for review.
    @Published var isGridMode: Bool = false // [Isolated] Published mode flag. | [In-file] Switches between grid browsing and single-card flow.
    
    @Published var stackedFiles: [DesktopFile] = [] // [Isolated] Published stack collection. | [In-file] Tracks “stacked” items for later grouped review/processing.
    
    @Published var shakingFileId: UUID? = nil // [Isolated] Published optional id. | [In-file] Drives shake animation targeting a specific file in the UI.
    @Published var viewedFileIds: Set<UUID> = [] // [Isolated] Published set of ids. | [In-file] Tracks which files have been previewed/seen to support UI hints.
    private var shakeTask: Task<Void, Never>? = nil // [Isolated] Holds async task reference. | [In-file] Allows cancelling auto-stop logic for shake animation.
    
    @Published var previewUrl: URL? = nil // [Isolated] Published optional URL. | [In-file] Drives preview presentation (e.g., Quick Look) for a selected file.

    @Published var movingItemIds: Set<UUID> = [] // [Isolated] Published in-flight set. | [In-file] Tracks which files are currently moving to show progress UI.
    @Published var toastMessage: String? = nil // [Isolated] Published toast string. | [In-file] Displays transient user feedback messages.
    private var toastTask: Task<Void, Never>? = nil // [Isolated] Holds async task reference. | [In-file] Cancels/controls toast auto-dismiss behavior.
    
    @Published var selectedFileTypeFilter: FileType? = nil // [Isolated] Published optional filter. | [In-file] Filters session view to a file type subset.
    
    private let cloudManager = CloudManager.shared // [Isolated] Stores CloudManager singleton. | [In-file] Handles cloud destinations and “move to cloud” operations.
    private let fileManager = FileManager.default // [Isolated] Stores FileManager singleton. | [In-file] Performs filesystem operations (move/copy/remove/trash/attributes).
    
    @Published var currentFileSuggestions: [FileSuggestion] = [] // [Isolated] Published suggestions array. | [In-file] Drives suggestion badge UI for the current file.
    @Published var showGroupReview = false // [Isolated] Published modal flag. | [In-file] Controls presentation of group review UI.
    @Published var groupReviewFiles: [DesktopFile] = [] // [Isolated] Published group array. | [In-file] Holds files participating in the current group review session.
    @Published var groupReviewSuggestion: FileSuggestion? = nil // [Isolated] Published optional suggestion. | [In-file] Stores the suggestion that initiated group review.
    private var suggestionCache: [UUID: [FileSuggestion]] = [:] // [Isolated] Private cache dictionary. | [In-file] Avoids recomputing suggestions for the same file repeatedly.
    
    var filteredFiles: [DesktopFile] { // [Isolated] Computed filtered array. | [In-file] Applies selectedFileTypeFilter to drive UI and navigation.
        if let filter = selectedFileTypeFilter { // [Isolated] Optional binding. | [In-file] Only filters when user has an active selection.
            return files.filter { $0.fileType == filter } // [Isolated] Filters array by predicate. | [In-file] Restricts the working set to matching file types.
        } // [Isolated] Ends filter conditional. | [In-file] Falls back to returning all files when no filter set.
        return files // [Isolated] Returns unfiltered set. | [In-file] Keeps default behavior as “show everything.”
    } // [Isolated] Ends computed property. | [In-file] Used widely as the authoritative working list.

var movingCount: Int { // [Isolated] Computed property for in-flight move count. | [In-file] Exposes number of files currently being moved for UI indication.
    movingItemIds.count // [Isolated] Returns count of movingItemIds. | [In-file] Used by UI to show move progress.
}

private var lastSuggestionFileId: UUID? = nil // [Isolated] Tracks last file id for suggestions. | [In-file] Used to dedupe suggestion updates for current file.
private var suggestionTask: Task<Void, Never>? = nil // [Isolated] Holds async suggestion task. | [In-file] Enables cancellation of in-flight suggestion detection.

var currentFile: DesktopFile? { // [Isolated] Computed property for current file. | [In-file] Returns the file at the current index, manages suggestion logic.
    guard currentFileIndex < filteredFiles.count else { // [Isolated] Guard against out-of-bounds. | [In-file] Prevents access when there are no more files.
        if !currentFileSuggestions.isEmpty { // [Isolated] Clears suggestions if present. | [In-file] Ensures UI is cleared when no file is selected.
            currentFileSuggestions = [] // [Isolated] Clear out old suggestions. | [In-file] Keeps UI consistent when file list is empty.
        }
        return nil // [Isolated] Return nil for no current file. | [In-file] Signals end of session or empty state.
    }
    let file = filteredFiles[currentFileIndex] // [Isolated] Get the current file. | [In-file] Main entry point for UI to display file details.

    if !viewedFileIds.contains(file.id) { // [Isolated] Mark file as viewed. | [In-file] Used for UI hints and analytics.
        viewedFileIds.insert(file.id) // [Isolated] Add to viewed set. | [In-file] Ensures user has seen this file.
    }

    if lastSuggestionFileId != file.id { // [Isolated] Detect file id change. | [In-file] Only update suggestions if the file has changed.
        lastSuggestionFileId = file.id // [Isolated] Update tracked id. | [In-file] Ensures suggestion logic is only triggered on new file.
        suggestionTask?.cancel() // [Isolated] Cancel previous suggestion task. | [In-file] Prevents overlapping/crossed suggestion updates.
        updateSuggestionsAsync(for: file) // [Isolated] Start async suggestion detection. | [In-file] Triggers background suggestion computation for new file.
    }

    return file // [Isolated] Return the current file. | [In-file] Used by UI to display file info and suggestions.
}

private func updateSuggestionsAsync(for file: DesktopFile) { // [Isolated] Async suggestion updater. | [In-file] Handles debounced, cancellable suggestion computation.
    if let cached = suggestionCache[file.id] { // [Isolated] Use cache if available. | [In-file] Avoids recomputation for already-processed files.
        currentFileSuggestions = cached // [Isolated] Show cached suggestions immediately. | [In-file] Provides instant UI response when possible.
        return // [Isolated] Short-circuit if cached. | [In-file] No need to recompute.
    }

    currentFileSuggestions = [] // [Isolated] Clear UI suggestions immediately. | [In-file] Ensures UI doesn't show stale suggestions while loading.
    suggestionTask?.cancel() // [Isolated] Cancel any previous suggestion task. | [In-file] Prevents race conditions and redundant computation.

    suggestionTask = Task { // [Isolated] Start new async suggestion task. | [In-file] Runs suggestion detection in a cancellable context.
        try? await Task.sleep(nanoseconds: 100_000_000) // [Isolated] Debounce rapid file changes. | [In-file] Reduces wasted computation during fast navigation.
        let filesToCheck = Array(files.prefix(100)) // [Isolated] Limit compare set to 100 files. | [In-file] Prevents performance issues with large collections.
        guard !Task.isCancelled else { return } // [Isolated] Check for cancellation before detection. | [In-file] Ensures no wasted work if user switched files.
        let suggestions = await SuggestionDetector.shared.detectSuggestionsAsync(for: file, in: filesToCheck) // [Isolated] Run async suggestion detector. | [In-file] Computes suggestions for current file in limited set.
        guard !Task.isCancelled else { return } // [Isolated] Check for cancellation after detection. | [In-file] Avoids updating UI if user navigated away.
        await MainActor.run { // [Isolated] Update UI on main actor. | [In-file] Ensures thread-safe mutation of published properties.
            if lastSuggestionFileId == file.id && suggestionCache[file.id] == nil { // [Isolated] Only update if still current file and not already cached. | [In-file] Prevents stale or duplicate UI updates.
                currentFileSuggestions = suggestions // [Isolated] Publish new suggestions. | [In-file] Triggers UI refresh for badges and group review.
                suggestionCache[file.id] = suggestions // [Isolated] Store in cache for future use. | [In-file] Enables instant updates if user returns to this file.
            }
        }
    }
}

var isFinished: Bool { // [Isolated] Indicates end-of-session. | [In-file] Used to determine if navigation should proceed or session is complete.
    currentFileIndex >= filteredFiles.count // [Isolated] True if past end of filtered files. | [In-file] Drives navigation and summary UI.
}

private var isPresentingFolderPicker = false // [Isolated] Prevent duplicate folder-picker presentation. | [In-file] Ensures only one NSOpenPanel is shown at a time.
private var hasPromptedForFolder = false // [Isolated] Ensure we only prompt once per app launch. | [In-file] Prevents repeated folder prompt on startup.

private struct FolderContext { // [Isolated] Snapshot of folder navigation context. | [In-file] Used as stack element for folder navigation/history.
    let url: URL // [Isolated] Folder URL. | [In-file] The folder being snapshotted.
    let files: [DesktopFile] // [Isolated] Files at snapshot time. | [In-file] Restores file list on return.
    let currentFileIndex: Int // [Isolated] Index of current file. | [In-file] Restores navigation position.
    let selectedFileTypeFilter: FileType? // [Isolated] Active file type filter. | [In-file] Restores filtering state.
    let totalFilesCount: Int // [Isolated] Total file count at snapshot. | [In-file] Used for progress and summary.
    let suggestionCache: [UUID: [FileSuggestion]] // [Isolated] Suggestion cache at snapshot. | [In-file] Restores deduped suggestion results.
    let lastSuggestionFileId: UUID? // [Isolated] Last suggestion file id at snapshot. | [In-file] Restores suggestion context.
    let currentFileSuggestions: [FileSuggestion] // [Isolated] Current file suggestions at snapshot. | [In-file] Restores suggestion UI state.
    let thumbnailGenerationInProgress: Set<UUID> // [Isolated] In-progress thumbnail ids. | [In-file] Restores thumbnail generation state.
}

private var folderStack: [FolderContext] = [] // [Isolated] Stack of FolderContext for navigation. | [In-file] Enables enter/return to subfolders and UI breadcrumbs.

init() { // [Isolated] Default initializer. | [In-file] No custom init logic; all state is set by property defaults and hooks occur in prompt/load methods.
    // [Isolated] Intentionally empty. | [In-file] All state is initialized via property wrappers or default values.
}

// [Isolated] Prompts the user to choose a folder to scan on launch. | [In-file] Called from App start or when folder is unset.
// [Isolated] Uses NSOpenPanel.begin for non-blocking presentation. | [In-file] Ensures the UI remains responsive.
@MainActor // [Isolated] MainActor annotation. | [In-file] Ensures folder prompt/presentation occurs on main thread for AppKit UI.
func promptForFolderIfNeeded() {
    // [Isolated] Prevents repeated prompt on startup. | [In-file] Ensures user is only prompted once per launch.
    guard !hasPromptedForFolder else { return }
    hasPromptedForFolder = true // [Isolated] Set flag so prompt only occurs once. | [In-file] Avoids repeated dialogs.

    // [Isolated] If no folder is selected, prompt the user. | [In-file] Otherwise, do nothing.
    if selectedFolderURL == nil {
        promptForFolderAndLoad()
    }
}

@MainActor // [Isolated] MainActor annotation. | [In-file] Ensures NSOpenPanel and related UI is presented on the main thread.
func promptForFolderAndLoad(onComplete: ((Bool) -> Void)? = nil) {
    // [Isolated] Prevents presenting multiple folder pickers at once. | [In-file] Guard for in-flight presentation.
    guard !isPresentingFolderPicker else { return }
    isPresentingFolderPicker = true // [Isolated] Set in-flight flag. | [In-file] Will be reset after user interaction.

    // [Isolated] Bring app window to front so the panel is visible. | [In-file] Ensures folder picker isn't hidden behind other apps.
    NSApp.activate(ignoringOtherApps: true)

    let panel = NSOpenPanel()
    panel.title = "Choose a folder to declutter" // [Isolated] Panel window title. | [In-file] User guidance.
    panel.prompt = "Use Folder" // [Isolated] Button label. | [In-file] Clarifies action to user.
    panel.canChooseFiles = false // [Isolated] Only allow folder selection. | [In-file] Prevents file picking.
    panel.canChooseDirectories = true // [Isolated] Allow picking directories. | [In-file] Required for folder declutter.
    panel.allowsMultipleSelection = false // [Isolated] Only one folder at a time. | [In-file] Simpler session logic.
    panel.level = .floating // [Isolated] Keep panel above other windows. | [In-file] Ensures visibility.
    panel.isFloatingPanel = true // [Isolated] Floating window mode. | [In-file] UX improvement.
    panel.makeKeyAndOrderFront(nil) // [Isolated] Show panel immediately. | [In-file] Ensures user sees the dialog.

    // [Isolated] Begin panel presentation asynchronously. | [In-file] Handles result via closure.
    panel.begin { [weak self] response in
        guard let self else { return }
        // [Isolated] Use Task on MainActor to ensure state updates are UI-safe. | [In-file] Handles panel result.
        Task { @MainActor in
            self.isPresentingFolderPicker = false // [Isolated] Reset in-flight flag. | [In-file] Allows future prompts.

            if response == .OK, let url = panel.url {
                // [Isolated] User selected a folder. | [In-file] Store folder, update FileScanner, and load files.
                self.selectedFolderURL = url
                FileScanner.shared.useCustomURL(url)
                self.loadFiles()
                onComplete?(true)
            } else {
                // [Isolated] User cancelled or closed the panel. | [In-file] Call completion with false.
                onComplete?(false)
            }
        }
    }
}
    
// [Isolated] Loads files from the currently selected folder. | [In-file] Resets session state and prepares new file list.
func loadFiles() {
    self.errorMessage = nil // [Isolated] Clear error messages. | [In-file] Ensures fresh state.
    do {
        let loadedFiles = try FileScanner.shared.scanCurrentFolder()
        self.files = loadedFiles // [Isolated] Set the new file list. | [In-file] Main session dataset.
        self.currentFileIndex = 0 // [Isolated] Reset navigation pointer. | [In-file] Start from first file.
        self.binnedFiles = [] // [Isolated] Clear bin. | [In-file] Remove any previously binned files.
        self.stackedFiles = [] // [Isolated] Clear stack. | [In-file] Remove any previously stacked files.
        self.reclaimedSpace = 0 // [Isolated] Reset reclaimed space counter. | [In-file] For stats UI.
        self.keptCount = 0 // [Isolated] Reset kept counter. | [In-file] For stats UI.
        self.binnedCount = 0 // [Isolated] Reset binned counter. | [In-file] For stats UI.
        self.totalFilesCount = loadedFiles.count // [Isolated] Update total file count. | [In-file] For progress UI.
        self.selectedFileTypeFilter = nil // [Isolated] Reset file type filter. | [In-file] Show all files.
        self.suggestionCache.removeAll() // [Isolated] Clear suggestion cache. | [In-file] Avoids stale suggestions.
        self.currentFileSuggestions = [] // [Isolated] Clear UI suggestions. | [In-file] Avoids leftover badges.
        self.lastSuggestionFileId = nil // [Isolated] Reset suggestion tracking. | [In-file] Prepares for new session.
        self.thumbnailGenerationInProgress.removeAll() // [Isolated] Clear thumbnail in-progress set. | [In-file] Avoids stale in-flight tracking.
        self.totalFilesCount = loadedFiles.count // [Isolated] Set again for redundancy. | [In-file] Defensive.
        updateBreadcrumbs() // [Isolated] Update breadcrumb navigation. | [In-file] Reflects new folder context.
        
        // [Isolated] Trigger thumbnail generation for first file only (lazy load others). | [In-file] Improves perceived performance.
        generateThumbnails(for: 0)
        
        // [Isolated] If no files are found, prompt for another folder or return to parent. | [In-file] Handles empty folder edge cases.
        if loadedFiles.isEmpty {
            if folderStack.isEmpty {
                // [Isolated] At top level, prompt for another folder. | [In-file] User must pick a folder with files.
                promptForFolderAndLoad()
            } else {
                // [Isolated] In subfolder, return to parent context. | [In-file] Prevents user from getting stuck.
                returnToParentFolder()
            }
        }
    } catch {
        // [Isolated] On error, show message and clear file list/count. | [In-file] Defensive error handling.
        self.errorMessage = error.localizedDescription
        self.files = []
        self.totalFilesCount = 0
    }
}
    
// [Isolated] Updates the file type filter for the session. | [In-file] Used for filtering UI.
func setFileTypeFilter(_ type: FileType?) {
    selectedFileTypeFilter = type // [Isolated] Update current filter. | [In-file] UI will reactively update.
    currentFileIndex = 0 // [Isolated] Reset navigation index to start. | [In-file] Ensures user sees first filtered file.
    generateThumbnails(for: 0) // [Isolated] Preload thumbnails for new set. | [In-file] Keeps UI responsive.
}
    
private var thumbnailGenerationInProgress = Set<UUID>() // [Isolated] Tracks which thumbnails are being generated. | [In-file] Avoids duplicate work and race conditions.
    
// [Isolated] Generates thumbnails for the current file and a lookahead window. | [In-file] Called on navigation or filter change.
func generateThumbnails(for index: Int) {
    // [Isolated] Only preload thumbnails for current and next item (limit concurrency). | [In-file] Prevents excessive resource use.
    let filesToProcess = filteredFiles
    let range = index..<min(index + 2, filesToProcess.count) // [Isolated] Range is current + next file only. | [In-file] Expand for more aggressive preloading.
    
    for i in range {
        let file = filesToProcess[i]
        
        // [Isolated] Guard: skip if already generating or already has thumbnail. | [In-file] Prevents redundant work and races.
        guard !thumbnailGenerationInProgress.contains(file.id),
              let fileIndex = files.firstIndex(where: { $0.id == file.id }),
              files[fileIndex].thumbnail == nil else {
            continue
        }
        
        // [Isolated] Insert file id into in-progress set. | [In-file] Used to prevent duplicate thumbnail generation.
        thumbnailGenerationInProgress.insert(file.id)
        
        FileScanner.shared.generateThumbnail(for: file) { [weak self] image in
            guard let self = self else { return }
            
            // [Isolated] Update thumbnail on main actor for UI. | [In-file] Ensures thread safety.
            Task { @MainActor in
                if fileIndex < self.files.count {
                    self.files[fileIndex].thumbnail = image
                }
                // [Isolated] Remove from in-progress set when done. | [In-file] Allows future requests.
                self.thumbnailGenerationInProgress.remove(file.id)
            }
        }
    }
}
    
    // Note: currentFile and isFinished are now computed properties above
    
    func keepCurrentFile() {
        guard let file = currentFile else { return } // [Isolated] Guard: ensure there is a current file. | [In-file] Prevents nil access and only keeps valid files.
        if let index = files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures we update the canonical file, not a stale copy.
            files[index].decision = .kept // [Isolated] Assign .kept decision to file. | [In-file] Marks file as kept for session state.
            keptCount += 1 // [Isolated] Increment kept counter. | [In-file] Updates UI stats and progress.
            recordAction(.keep, file: file, decision: .kept) // [Isolated] Log keep action to history. | [In-file] Enables undo/redo and session timeline.
        }
    }

    func binCurrentFile() {
        guard let file = currentFile else { return } // [Isolated] Guard: ensure there is a current file. | [In-file] Prevents nil access and only bins valid files.
        if let index = files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures we update the canonical file.
            files[index].decision = .binned // [Isolated] Assign .binned decision to file. | [In-file] Marks file as binned for session state.
            binnedCount += 1 // [Isolated] Increment binned counter. | [In-file] Updates UI stats and progress.
            reclaimedSpace += file.fileSize // [Isolated] Add file size to reclaimed space. | [In-file] Updates "space saved" UI.
            if immediateBinning { // [Isolated] Branch: immediate binning mode. | [In-file] Determines if file is trashed now or queued for review.
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil) // [Isolated] Move file to Trash. | [In-file] Effectuates immediate deletion for user.
                    print("Immediately moved to trash: \(file.name)") // [Isolated] Debug: log trash success. | [In-file] Developer feedback for ops.
                } catch {
                    print("Failed to trash file \(file.name): \(error)") // [Isolated] Debug: log trash failure. | [In-file] For troubleshooting permission or fs errors.
                    // [Isolated] Failure to trash does not revert decision. | [In-file] Still considered binned for session logic.
                }
            } else {
                binnedFiles.append(file) // [Isolated] Queue for later review. | [In-file] Defers trashing until explicit bin empty.
            }
            recordAction(.bin, file: file, decision: .binned) // [Isolated] Log bin action to history. | [In-file] Enables undo/redo and session timeline.
        }
    }

    func stackCurrentFile() {
        guard let file = currentFile else { return } // [Isolated] Guard: ensure there is a current file. | [In-file] Prevents nil access and only stacks valid files.
        if let index = files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures we update the canonical file.
            files[index].decision = .stacked // [Isolated] Assign .stacked decision to file. | [In-file] Marks file as stacked for group review.
        }
        stackedFiles.append(file) // [Isolated] Add file to stackedFiles array. | [In-file] Collects for later group actions.
        recordAction(.stack, file: file) // [Isolated] Log stack action to history. | [In-file] Enables undo/redo and session timeline.
    }

    func moveToCloud(_ file: DesktopFile, destination: CloudDestination? = nil) {
        if isProtectedApplicationBundle(file) { // [Isolated] Guard: prevent moving protected app bundles. | [In-file] Avoids risky system operations.
            showToast("Applications in system directories cannot be moved here. Use Finder or official installer/uninstaller.") // [Isolated] Show user-facing error toast. | [In-file] Guides user toward safe workflow.
            return
        }
        let sourceFolderName = selectedFolderURL?.lastPathComponent // [Isolated] Derive source folder name for cloud move. | [In-file] Used in cloudManager for context.
        cloudManager.moveFileToCloud(file, sourceFolderName: sourceFolderName, destination: destination) { [weak self] result in // [Isolated] Initiate async cloud move. | [In-file] Moves file and calls back with result.
            DispatchQueue.main.async { // [Isolated] Hop to main queue for UI updates. | [In-file] Ensures thread-safe state mutation.
                guard let self = self else { return } // [Isolated] Capture self weakly to avoid retain cycles. | [In-file] Defensive callback design.
                switch result {
                case .success(let movedToURL):
                    if let index = self.files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures canonical update.
                        self.files[index].decision = .cloud // [Isolated] Assign .cloud decision to file. | [In-file] Marks file as moved to cloud.
                    }
                    self.recordAction(.cloud, file: file, decision: .cloud, movedToURL: movedToURL, destinationId: destination?.id ?? self.cloudManager.activeDestinationId) // [Isolated] Log cloud move action to history (with destination fallback). | [In-file] Enables undo/redo and session timeline.
                case .failure(let error):
                    print("Failed to move to cloud: \(error)") // [Isolated] Debug: log cloud move failure. | [In-file] Developer feedback for troubleshooting.
                    let nsError = error as NSError // [Isolated] Cast error for domain/code inspection. | [In-file] Enables special-case error messaging.
                    if nsError.domain == NSCocoaErrorDomain && nsError.code == 513 { // [Isolated] Special-case: permission denied for cloud. | [In-file] Guides user to re-add destination.
                        self.errorMessage = "Permission denied. Please re-add the cloud destination and choose a writable folder (e.g., Google Drive → My Drive)." // [Isolated] User-facing error guidance. | [In-file] Improves clarity for common cloud errors.
                    } else {
                        self.errorMessage = "Failed to move to Cloud: \(error.localizedDescription)" // [Isolated] Generic error fallback. | [In-file] Surfaces error to UI.
                    }
                }
            }
        }
    }

    func moveGroupToCloud(_ filesToMove: [DesktopFile], destination: CloudDestination? = nil) {
        for file in filesToMove { // [Isolated] Loop over files to move. | [In-file] Fire-and-forget parallel move style.
            if isProtectedApplicationBundle(file) { // [Isolated] Guard: skip protected app bundles. | [In-file] Avoids risky system operations.
                showToast("Applications in system directories cannot be moved here. Use Finder or official installer/uninstaller.") // [Isolated] Show user-facing error toast. | [In-file] Guides user toward safe workflow.
                continue
            }
            let sourceFolderName = selectedFolderURL?.lastPathComponent // [Isolated] Derive source folder name for cloud move. | [In-file] Used in cloudManager for context.
            cloudManager.moveFileToCloud(file, sourceFolderName: sourceFolderName, destination: destination) { [weak self] result in // [Isolated] Initiate async cloud move for each file. | [In-file] Moves file and calls back with result.
                DispatchQueue.main.async { // [Isolated] Hop to main queue for UI updates. | [In-file] Ensures thread-safe state mutation.
                    guard let self = self else { return } // [Isolated] Capture self weakly to avoid retain cycles. | [In-file] Defensive callback design.
                    switch result {
                    case .success(let movedToURL):
                        if let index = self.files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures canonical update.
                            self.files[index].decision = .cloud // [Isolated] Assign .cloud decision to file. | [In-file] Marks file as moved to cloud.
                        }
                        self.recordAction(.cloud, file: file, decision: .cloud, movedToURL: movedToURL, destinationId: destination?.id ?? self.cloudManager.activeDestinationId) // [Isolated] Log cloud move action to history (with destination fallback). | [In-file] Enables undo/redo and session timeline.
                    case .failure(let error):
                        print("Failed to move \(file.name): \(error)") // [Isolated] Debug: log cloud move failure. | [In-file] Developer feedback for troubleshooting.
                        let nsError = error as NSError // [Isolated] Cast error for domain/code inspection. | [In-file] Enables special-case error messaging.
                        if nsError.domain == NSCocoaErrorDomain && nsError.code == 513 { // [Isolated] Special-case: permission denied for cloud. | [In-file] Guides user to re-add destination.
                            self.errorMessage = "Permission denied. Please re-add the cloud destination and choose a writable folder (e.g., Google Drive → My Drive)." // [Isolated] User-facing error guidance. | [In-file] Improves clarity for common cloud errors.
                        }
                    }
                }
            }
        }
    }

    private func uniqueURL(for url: URL, fileManager: FileManager) -> URL {
        if !fileManager.fileExists(atPath: url.path) { // [Isolated] Check if file does not exist at URL. | [In-file] Use original URL if available.
            return url // [Isolated] Return original URL if unique. | [In-file] No collision, so use as-is.
        }
        let ext = url.pathExtension // [Isolated] Extract file extension. | [In-file] Needed for candidate name generation.
        let base = url.deletingPathExtension().lastPathComponent // [Isolated] Extract base name. | [In-file] Needed for candidate name generation.
        let parent = url.deletingLastPathComponent() // [Isolated] Extract parent directory. | [In-file] Needed for candidate name generation.
        var counter = 2 // [Isolated] Initialize counter for suffix. | [In-file] Used to generate unique names.
        while true { // [Isolated] Loop until unique filename found. | [In-file] Ensures no collision.
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)" // [Isolated] Build candidate name with suffix. | [In-file] Handles both with and without extension.
            let candidate = parent.appendingPathComponent(name) // [Isolated] Build candidate URL. | [In-file] Test for uniqueness.
            if !fileManager.fileExists(atPath: candidate.path) { // [Isolated] Check if candidate does not exist. | [In-file] Use this name if unique.
                return candidate // [Isolated] Return unique candidate URL. | [In-file] Found a safe destination.
            }
            counter += 1 // [Isolated] Increment counter for next candidate. | [In-file] Try next suffix.
        }
    }

    func moveToFolder(_ file: DesktopFile, destinationURL: URL) {
        if isProtectedApplicationBundle(file) { // [Isolated] Guard: prevent moving protected app bundles. | [In-file] Avoids risky system operations.
            showToast("Applications in system directories cannot be moved here. Use Finder or official installer/uninstaller.") // [Isolated] Show user-facing error toast. | [In-file] Guides user toward safe workflow.
            return
        }
        Task { @MainActor in
            movingItemIds.insert(file.id) // [Isolated] Insert file id into movingItemIds. | [In-file] Triggers move progress UI.
        }
        Task.detached { [file, destinationURL] in // [Isolated] Detach background task for move. | [In-file] Avoids blocking main thread.
            let fileManager = FileManager.default // [Isolated] Get FileManager reference. | [In-file] Used for all file ops.
            func uniqueURL(for url: URL) -> URL { // [Isolated] Helper: generate unique URL in destination. | [In-file] Avoids collisions.
                if !fileManager.fileExists(atPath: url.path) { // [Isolated] Check if file does not exist at URL. | [In-file] Use original URL if available.
                    return url // [Isolated] Return original URL if unique. | [In-file] No collision, so use as-is.
                }
                let ext = url.pathExtension // [Isolated] Extract file extension. | [In-file] Needed for candidate name generation.
                let base = url.deletingPathExtension().lastPathComponent // [Isolated] Extract base name. | [In-file] Needed for candidate name generation.
                let parent = url.deletingLastPathComponent() // [Isolated] Extract parent directory. | [In-file] Needed for candidate name generation.
                var counter = 2 // [Isolated] Initialize counter for suffix. | [In-file] Used to generate unique names.
                while true { // [Isolated] Loop until unique filename found. | [In-file] Ensures no collision.
                    let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)" // [Isolated] Build candidate name with suffix. | [In-file] Handles both with and without extension.
                    let candidate = parent.appendingPathComponent(name) // [Isolated] Build candidate URL. | [In-file] Test for uniqueness.
                    if !fileManager.fileExists(atPath: candidate.path) { // [Isolated] Check if candidate does not exist. | [In-file] Use this name if unique.
                        return candidate // [Isolated] Return unique candidate URL. | [In-file] Found a safe destination.
                    }
                    counter += 1 // [Isolated] Increment counter for next candidate. | [In-file] Try next suffix.
                }
            }
            let targetURL = uniqueURL(for: destinationURL.appendingPathComponent(file.name)) // [Isolated] Build unique target URL in destination. | [In-file] Ensures safe move.
            let accessing = destinationURL.startAccessingSecurityScopedResource() // [Isolated] Start security-scoped access for destination. | [In-file] Required for sandboxed folder moves.
            defer { if accessing { destinationURL.stopAccessingSecurityScopedResource() } } // [Isolated] End security-scoped access after move. | [In-file] Prevents resource leaks.
            do {
                do {
                    try fileManager.moveItem(at: file.url, to: targetURL) // [Isolated] Attempt to move file directly. | [In-file] Fast path.
                } catch {
                    if !fileManager.fileExists(atPath: file.url.path),
                       fileManager.fileExists(atPath: targetURL.path) {
                        // [Isolated] Already moved by background? Treat as success. | [In-file] Defensive: don't double-move.
                    } else {
                        try fileManager.copyItem(at: file.url, to: targetURL) // [Isolated] Fallback: try copy if move fails. | [In-file] Handles cross-volume/copy-only scenarios.
                        try fileManager.removeItem(at: file.url) // [Isolated] Remove original after copy. | [In-file] Ensures file is only at destination.
                    }
                }
                await MainActor.run {
                    if let index = self.files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures canonical update.
                        self.files[index].decision = .moved // [Isolated] Assign .moved decision to file. | [In-file] Marks file as moved for session.
                    }
                    self.recordAction(.move, file: file, decision: .moved, movedToURL: targetURL) // [Isolated] Log move action to history. | [In-file] Enables undo/redo and session timeline.
                    self.movingItemIds.remove(file.id) // [Isolated] Remove file id from movingItemIds. | [In-file] Updates move progress UI.
                }
            } catch {
                print("Move Error: \(error)") // [Isolated] Debug: log move failure. | [In-file] Developer feedback for troubleshooting.
                await MainActor.run {
                    self.movingItemIds.remove(file.id) // [Isolated] Remove file id from movingItemIds on error. | [In-file] Updates move progress UI.
                    self.errorMessage = "Failed to move: \(error.localizedDescription)" // [Isolated] Show error message in UI. | [In-file] Surfaces move error to user.
                }
            }
        }
    }

    func moveGroupToFolder(_ filesToMove: [DesktopFile], destinationURL: URL) {
        Task { @MainActor in
            for file in filesToMove { // [Isolated] Loop over files to move. | [In-file] Batch insert to movingItemIds for progress UI.
                if isProtectedApplicationBundle(file) { continue } // [Isolated] Guard: skip protected app bundles. | [In-file] Avoids risky system operations.
                movingItemIds.insert(file.id) // [Isolated] Insert file id into movingItemIds. | [In-file] Triggers move progress UI.
            }
        }
        Task.detached { [filesToMove, destinationURL] in // [Isolated] Detach background task for group move. | [In-file] Avoids blocking main thread.
            let fileManager = FileManager.default // [Isolated] Get FileManager reference. | [In-file] Used for all file ops.
            func uniqueURL(for url: URL) -> URL { // [Isolated] Helper: generate unique URL in destination. | [In-file] Avoids collisions.
                if !fileManager.fileExists(atPath: url.path) { // [Isolated] Check if file does not exist at URL. | [In-file] Use original URL if available.
                    return url // [Isolated] Return original URL if unique. | [In-file] No collision, so use as-is.
                }
                let ext = url.pathExtension // [Isolated] Extract file extension. | [In-file] Needed for candidate name generation.
                let base = url.deletingPathExtension().lastPathComponent // [Isolated] Extract base name. | [In-file] Needed for candidate name generation.
                let parent = url.deletingLastPathComponent() // [Isolated] Extract parent directory. | [In-file] Needed for candidate name generation.
                var counter = 2 // [Isolated] Initialize counter for suffix. | [In-file] Used to generate unique names.
                while true { // [Isolated] Loop until unique filename found. | [In-file] Ensures no collision.
                    let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)" // [Isolated] Build candidate name with suffix. | [In-file] Handles both with and without extension.
                    let candidate = parent.appendingPathComponent(name) // [Isolated] Build candidate URL. | [In-file] Test for uniqueness.
                    if !fileManager.fileExists(atPath: candidate.path) { // [Isolated] Check if candidate does not exist. | [In-file] Use this name if unique.
                        return candidate // [Isolated] Return unique candidate URL. | [In-file] Found a safe destination.
                    }
                    counter += 1 // [Isolated] Increment counter for next candidate. | [In-file] Try next suffix.
                }
            }

            let accessing = destinationURL.startAccessingSecurityScopedResource() // [Isolated] Start security-scoped access for destination. | [In-file] Required for sandboxed folder moves.
            defer { if accessing { destinationURL.stopAccessingSecurityScopedResource() } } // [Isolated] End security-scoped access after move. | [In-file] Prevents resource leaks.

            for file in filesToMove { // [Isolated] Loop over each file to move. | [In-file] Handles group move with error handling and protection.
                if self.isProtectedApplicationBundle(file) { // [Isolated] Guard: skip protected app bundles. | [In-file] Avoids risky system operations.
                    _ = await MainActor.run { // [Isolated] Show error toast on main actor. | [In-file] Ensures UI update for protected bundle skip.
                        self.showToast("Applications in system directories cannot be moved here. Use Finder or official installer/uninstaller.") // [Isolated] Show user-facing error toast. | [In-file] Guides user toward safe workflow.
                    }
                    continue // [Isolated] Skip moving this file. | [In-file] Only safe files are moved.
                }
                let targetURL = uniqueURL(for: destinationURL.appendingPathComponent(file.name)) // [Isolated] Build unique target URL in destination. | [In-file] Ensures safe move without collision.
                do {
                    do {
                        try fileManager.moveItem(at: file.url, to: targetURL) // [Isolated] Attempt to move file directly. | [In-file] Fast path for move.
                    } catch {
                        if !fileManager.fileExists(atPath: file.url.path),
                           fileManager.fileExists(atPath: targetURL.path) {
                            // [Isolated] Already moved by background? Treat as success. | [In-file] Defensive: don't double-move.
                        } else {
                            try fileManager.copyItem(at: file.url, to: targetURL) // [Isolated] Fallback: try copy if move fails. | [In-file] Handles cross-volume/copy-only scenarios.
                            try fileManager.removeItem(at: file.url) // [Isolated] Remove original after copy. | [In-file] Ensures file is only at destination.
                        }
                    }

                    await MainActor.run {
                        if let index = self.files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures canonical update after move.
                            self.files[index].decision = .moved // [Isolated] Assign .moved decision to file. | [In-file] Marks file as moved for session.
                        }
                        self.recordAction(.move, file: file, decision: .moved, movedToURL: targetURL) // [Isolated] Log move action to history. | [In-file] Enables undo/redo and session timeline.
                        self.movingItemIds.remove(file.id) // [Isolated] Remove file id from movingItemIds. | [In-file] Updates move progress UI after success.
                    }
                } catch {
                    print("Move Error for \(file.name): \(error)") // [Isolated] Debug: log move failure. | [In-file] Developer feedback for troubleshooting.
                    _ = await MainActor.run {
                        self.movingItemIds.remove(file.id) // [Isolated] Remove file id from movingItemIds on error. | [In-file] Updates move progress UI after failure.
                    }
                }
            }
        }
    }

    @MainActor // [Isolated] MainActor annotation for UI operations. | [In-file] Ensures all AppKit/SwiftUI changes are safe.
    func promptForMoveDestination(files: [DesktopFile]) {
        let panel = NSOpenPanel() // [Isolated] Create open panel. | [In-file] Used for picking move destination.
        panel.canChooseFiles = false // [Isolated] Disallow file selection. | [In-file] Only allow directories.
        panel.canChooseDirectories = true // [Isolated] Allow picking directories. | [In-file] Required for folder moves.
        panel.allowsMultipleSelection = false // [Isolated] Only allow one selection. | [In-file] Simpler logic for destination.
        panel.prompt = "Move Here" // [Isolated] Set button label. | [In-file] Clarifies action for user.
        panel.message = "Choose a folder to move the selected items into." // [Isolated] Set panel message. | [In-file] User guidance.
        panel.level = .floating // [Isolated] Keep panel above other windows. | [In-file] Ensures visibility.
        panel.isFloatingPanel = true // [Isolated] Floating window mode. | [In-file] UX improvement.

        NSApp.activate(ignoringOtherApps: true) // [Isolated] Bring app to front. | [In-file] Ensures panel is visible.
        panel.makeKeyAndOrderFront(nil) // [Isolated] Show panel immediately. | [In-file] Ensures user sees the dialog.

        panel.begin { [weak self] response in // [Isolated] Begin async panel with weak self capture. | [In-file] Prevents retain cycles and handles result.
            guard let self else { return }
            if response == .OK, let url = panel.url { // [Isolated] User confirmed and picked a folder. | [In-file] Proceed with move logic.
                if let provider = self.cloudManager.isValidCloudDirectory(url) { // [Isolated] Check if folder is cloud directory. | [In-file] Enables cloud move workflow.
                    let canonicalURL = self.cloudManager.canonicalCloudURL(for: url, provider: provider) ?? url // [Isolated] Canonicalize cloud URL. | [In-file] Ensures correct destination path.
                    let alert = NSAlert() // [Isolated] Create alert for cloud destination. | [In-file] Informs user about safer cloud move.
                    alert.messageText = "Destination is a cloud folder" // [Isolated] Set alert title. | [In-file] User guidance.
                    alert.informativeText = "The destination you chose is a cloud directory. Cloud moves are safer and keep your files organized under DesktopDeclutter." // [Isolated] Set alert informative text. | [In-file] Explain benefit.
                    alert.alertStyle = .informational // [Isolated] Set alert style. | [In-file] Visual cue for info.
                    alert.addButton(withTitle: "Use Cloud") // [Isolated] Add cloud move option. | [In-file] Preferred option.
                    alert.addButton(withTitle: "Move Anyway") // [Isolated] Add direct move option. | [In-file] For advanced users.
                    alert.addButton(withTitle: "Cancel") // [Isolated] Add cancel option. | [In-file] Allows aborting.

                    let choice = alert.runModal() // [Isolated] Show alert and get user choice. | [In-file] Synchronous.
                    if choice == .alertFirstButtonReturn { // [Isolated] "Use Cloud" selected. | [In-file] Proceed with cloud move.
                        let dest = self.cloudManager.findDestination(matching: canonicalURL)
                            ?? CloudDestination(name: canonicalURL.lastPathComponent, path: canonicalURL.path, bookmarkData: nil, provider: provider) // [Isolated] Lookup or create cloud destination. | [In-file] Ensures destination exists.

                        if self.cloudManager.findDestination(matching: canonicalURL) == nil { // [Isolated] Add destination if not already present. | [In-file] Keeps cloudManager in sync.
                            self.cloudManager.addDestination(name: dest.name, url: canonicalURL, provider: provider) // [Isolated] Register new cloud destination. | [In-file] Enables future cloud moves.
                        }

                        if files.count == 1, let file = files.first { // [Isolated] Single file cloud move. | [In-file] Use moveToCloud for one file.
                            self.moveToCloud(file, destination: self.cloudManager.findDestination(matching: canonicalURL))
                        } else { // [Isolated] Multiple files: group cloud move. | [In-file] Use moveGroupToCloud for batch.
                            let destination = self.cloudManager.findDestination(matching: canonicalURL)
                            self.moveGroupToCloud(files, destination: destination)
                        }
                        return // [Isolated] Done with cloud move. | [In-file] No further processing needed.
                    } else if choice == .alertThirdButtonReturn { // [Isolated] "Cancel" selected. | [In-file] Abort move.
                        return // [Isolated] Early return on cancel. | [In-file] Do not proceed.
                    }
                    // [Isolated] "Move Anyway" falls through to non-cloud move below. | [In-file] User wants direct move.
                }

                if files.count == 1, let file = files.first { // [Isolated] Single file direct move. | [In-file] Use moveToFolder for one file.
                    self.moveToFolder(file, destinationURL: url)
                } else { // [Isolated] Multiple files: group direct move. | [In-file] Use moveGroupToFolder for batch.
                    self.moveGroupToFolder(files, destinationURL: url)
                }
            }
        }
    }

    nonisolated private func isProtectedApplicationBundle(_ file: DesktopFile) -> Bool { // [Isolated] nonisolated and private for cross-actor use. | [In-file] Used to check if file is a protected app bundle.
        guard file.url.pathExtension.lowercased() == "app" else { return false } // [Isolated] Check for .app extension. | [In-file] Only .app bundles are protected.
        let path = file.url.path // [Isolated] Extract file path. | [In-file] Needed for prefix check.
        return path.hasPrefix("/Applications/") || path.hasPrefix("/System/Applications/") // [Isolated] Check for protected system locations. | [In-file] Only allow moving user apps.
    }

    @MainActor // [Isolated] MainActor annotation for UI update. | [In-file] Ensures safe state change for toast.
    func showToast(_ message: String, duration: UInt64 = 3_000_000_000) {
        toastTask?.cancel() // [Isolated] Cancel any previous toast task. | [In-file] Prevents overlapping toasts.
        toastMessage = message // [Isolated] Set the toast message. | [In-file] Triggers UI display.
        toastTask = Task { @MainActor in // [Isolated] Start new async task for auto-dismiss. | [In-file] Allows timed hiding of toast.
            try? await Task.sleep(nanoseconds: duration) // [Isolated] Wait for specified duration. | [In-file] Controls toast lifetime.
            if !Task.isCancelled { // [Isolated] Only clear if task wasn't cancelled. | [In-file] Prevents race with new toasts.
                withAnimation { // [Isolated] Animate toast dismissal. | [In-file] Smooth UI transition.
                    toastMessage = nil // [Isolated] Clear toast message. | [In-file] Hides toast in UI.
                }
            }
        }
    }
    
    // [Isolated] History tracking section. | [In-file] Stores file actions and UI events for undo/redo and auditing.
    
    struct Action: Equatable, Identifiable { // [Isolated] Represents a single file action for undo/redo. | [In-file] Used in action history and undo stack.
        let id = UUID() // [Isolated] Unique identifier for action. | [In-file] Enables Identifiable conformance.
        enum ActionType: String, Equatable { // [Isolated] Enum for action type. | [In-file] Distinguishes keep/bin/stack/cloud/move.
            case keep // [Isolated] Action for keeping a file. | [In-file] User chose to keep file.
            case bin // [Isolated] Action for binning a file. | [In-file] User chose to bin file.
            case stack // [Isolated] Action for stacking a file. | [In-file] User chose to stack file.
            case cloud // [Isolated] Action for moving to cloud. | [In-file] User chose cloud destination.
            case move // [Isolated] Action for moving to folder. | [In-file] User chose folder destination.
        }
        let type: ActionType // [Isolated] The type of action performed. | [In-file] Used for undo/redo logic.
        let file: DesktopFile // [Isolated] The file the action was performed on. | [In-file] Needed to revert/apply action.
        let previousIndex: Int // [Isolated] Index before action. | [In-file] Allows restoring navigation state.
        let fileOriginalIndex: Int? // [Isolated] Original index of file (optional). | [In-file] Used for history/auditing.
        let decision: FileDecision? // [Isolated] The file decision at action time. | [In-file] Allows restoring file state.
        let movedToURL: URL? // [Isolated] Target URL for move/cloud. | [In-file] Used to revert/apply moves.
        let destinationId: UUID? // [Isolated] Cloud destination id (optional). | [In-file] Used for cloud undo/redo.
        let folderPath: String // [Isolated] Path of folder at action time. | [In-file] Used for history context.
        let timestamp: Date // [Isolated] When action occurred. | [In-file] Used for sorting/history.
    }
    
    struct HistoryEntry: Equatable, Identifiable { // [Isolated] Represents a user-visible history event. | [In-file] Used in UI timeline.
        let id = UUID() // [Isolated] Unique identifier for entry. | [In-file] Enables Identifiable conformance.
        enum EntryType: String, Equatable { // [Isolated] Enum for entry type. | [In-file] Distinguishes fileAction/undo/redo/ui.
            case fileAction // [Isolated] File action (keep/bin/etc). | [In-file] User made a file decision.
            case undo // [Isolated] Undo event. | [In-file] User undid an action.
            case redo // [Isolated] Redo event. | [In-file] User redid an action.
            case ui // [Isolated] UI event (navigation, etc). | [In-file] For logging non-file actions.
        }
        let type: EntryType // [Isolated] The type of history entry. | [In-file] Used for UI filtering.
        let title: String // [Isolated] User-visible title. | [In-file] Short description for UI.
        let details: String? // [Isolated] Optional details string. | [In-file] Additional context for UI.
        let fileName: String? // [Isolated] Optional file name. | [In-file] Used for display.
        let folderPath: String? // [Isolated] Optional folder path. | [In-file] Used for context display.
        let timestamp: Date // [Isolated] When event occurred. | [In-file] Used for sorting/history.
    }
    
    @Published var actionHistory: [HistoryEntry] = [] // [Isolated] Published array of history entries. | [In-file] Drives UI timeline.
    @Published private(set) var undoableActionCount: Int = 0 // [Isolated] Published count of undoable actions. | [In-file] Used for UI state.
    private let maxHistorySize = 300 // [Isolated] Maximum number of history entries. | [In-file] Prevents unbounded memory growth.
    private let maxUndoStackSize = 120 // [Isolated] Maximum undo stack size. | [In-file] Limits undo memory usage.
    private var undoStack: [Action] = [] // [Isolated] Stack of undoable actions. | [In-file] Used for undo logic.
    private var redoStack: [Action] = [] // [Isolated] Stack of redoable actions. | [In-file] Used for redo logic.
    
private func recordAction(_ type: Action.ActionType, file: DesktopFile, originalIndex: Int? = nil, decision: FileDecision? = nil, movedToURL: URL? = nil, destinationId: UUID? = nil) {
    // [Isolated] Records a file action to the undo stack and history. | [In-file] Used for undo/redo and timeline.
    // Parameters:
    //   - type: ActionType (.keep, .bin, .stack, .cloud, .move). | [In-file] Determines what action is recorded.
    //   - file: DesktopFile affected by the action. | [In-file] Used for identification and state.
    //   - originalIndex: File's index before action (optional). | [In-file] Used for restoring navigation.
    //   - decision: FileDecision at action time (optional). | [In-file] Used for reverting file state.
    //   - movedToURL: Target URL for move/cloud (optional). | [In-file] Used for undoing moves.
    //   - destinationId: Cloud destination id (optional). | [In-file] Used for cloud undo/redo.
    let action = Action(
        type: type, // [Isolated] Action type (.keep, .bin, etc). | [In-file] Sets Action.type.
        file: file, // [Isolated] File being acted on. | [In-file] Sets Action.file.
        previousIndex: currentFileIndex, // [Isolated] Current index before action. | [In-file] Sets Action.previousIndex.
        fileOriginalIndex: originalIndex, // [Isolated] File's original index. | [In-file] Sets Action.fileOriginalIndex.
        decision: decision, // [Isolated] File decision at action time. | [In-file] Sets Action.decision.
        movedToURL: movedToURL, // [Isolated] URL file was moved to (if any). | [In-file] Sets Action.movedToURL.
        destinationId: destinationId, // [Isolated] Cloud destination id (if any). | [In-file] Sets Action.destinationId.
        folderPath: selectedFolderURL?.path ?? "", // [Isolated] Path of folder at action. | [In-file] Sets Action.folderPath.
        timestamp: Date() // [Isolated] Timestamp of action. | [In-file] Sets Action.timestamp.
    )

    undoStack.append(action) // [Isolated] Push action onto undo stack. | [In-file] Enables undo functionality.
    if undoStack.count > maxUndoStackSize { // [Isolated] Trim undo stack if over max size. | [In-file] Prevents unbounded growth.
        undoStack.removeFirst() // [Isolated] Remove oldest action if needed. | [In-file] Keeps stack within memory limits.
    }
    redoStack.removeAll() // [Isolated] Clear redo stack on new action. | [In-file] Prevents redo after new action.
    undoableActionCount = undoStack.count // [Isolated] Update published undoable count. | [In-file] Keeps UI in sync.

    appendHistoryEntry(
        type: .fileAction, // [Isolated] HistoryEntry type is fileAction. | [In-file] Shows in timeline as file event.
        title: title(for: type), // [Isolated] User-visible title for action. | [In-file] "Keep", "Bin", etc.
        details: details(for: action), // [Isolated] Details string for action. | [In-file] Folder and destination if present.
        fileName: file.name, // [Isolated] File name for display. | [In-file] Shows which file was affected.
        folderPath: action.folderPath // [Isolated] Folder path at action time. | [In-file] Provides context in timeline.
    )
}

func logInterfaceEvent(_ title: String, details: String? = nil, file: DesktopFile? = nil) {
    // [Isolated] Logs a non-file interface event to the history timeline. | [In-file] Used for navigation, UI, or other events.
    // folderPath: Uses selectedFolderURL?.path for context. | [In-file] Shows where UI event occurred.
    appendHistoryEntry(
        type: .ui, // [Isolated] Entry type is .ui for interface/log event. | [In-file] Not a file action.
        title: title, // [Isolated] User-visible event title. | [In-file] E.g., "Jumped to file", "Changed filter".
        details: details, // [Isolated] Optional event details. | [In-file] E.g., new filter value.
        fileName: file?.name, // [Isolated] Optional file name. | [In-file] Shows file if relevant.
        folderPath: selectedFolderURL?.path // [Isolated] Current folder path. | [In-file] For context in timeline.
    )
}

private func appendHistoryEntry(type: HistoryEntry.EntryType, title: String, details: String?, fileName: String?, folderPath: String?) {
    // [Isolated] Appends a HistoryEntry to the actionHistory array. | [In-file] Used for timeline UI.
    actionHistory.append(
        HistoryEntry(
            type: type, // [Isolated] Entry type (fileAction, undo, redo, ui). | [In-file] Determines display/icon.
            title: title, // [Isolated] Short title for entry. | [In-file] Shown in timeline.
            details: details, // [Isolated] Optional details string. | [In-file] Folder, destination, etc.
            fileName: fileName, // [Isolated] Optional file name. | [In-file] For display context.
            folderPath: folderPath, // [Isolated] Optional folder path. | [In-file] For context display.
            timestamp: Date() // [Isolated] Timestamp of entry. | [In-file] Used for sorting/history.
        )
    )
    if actionHistory.count > maxHistorySize { // [Isolated] Trim history if over max size. | [In-file] Prevents unbounded growth.
        actionHistory.removeFirst() // [Isolated] Remove oldest entry. | [In-file] Keeps timeline within memory limits.
    }
}

private func title(for type: Action.ActionType) -> String {
    // [Isolated] Maps ActionType to user-visible title. | [In-file] Used in timeline and undo/redo.
    switch type {
    case .keep: return "Keep" // [Isolated] Keep decision. | [In-file] User chose to keep file.
    case .bin: return "Bin" // [Isolated] Bin decision. | [In-file] User chose to bin file.
    case .stack: return "Stack" // [Isolated] Stack decision. | [In-file] User chose to stack file.
    case .cloud: return "Move to Cloud" // [Isolated] Cloud move. | [In-file] User moved file to cloud.
    case .move: return "Move" // [Isolated] Folder move. | [In-file] User moved file to folder.
    }
}

private func details(for action: Action) -> String {
    // [Isolated] Builds a details string for a history entry. | [In-file] Used for folder and destination info.
    // Details are chunked and joined with newlines for readability.
    var chunks: [String] = []
    if !action.folderPath.isEmpty {
        chunks.append("Folder: \(action.folderPath)") // [Isolated] Show folder path if present. | [In-file] For context.
    }
    if let movedToURL = action.movedToURL {
        chunks.append("Destination: \(movedToURL.path)") // [Isolated] Show move/cloud destination if present. | [In-file] For context.
    }
    return chunks.joined(separator: "\n") // [Isolated] Join all details with newline. | [In-file] Improves readability in UI.
}

func relocationDestination(for file: DesktopFile) -> URL? {
    // [Isolated] Returns last movedToURL for given file from undoStack. | [In-file] Used to show move/cloud destination in UI.
    undoStack.last(where: { $0.file.id == file.id && ($0.type == .move || $0.type == .cloud) })?.movedToURL
}

func currentDecision(for file: DesktopFile) -> FileDecision? {
    // [Isolated] Resolves file's current decision. | [In-file] Prefers latest from files array, falls back to file.decision.
    files.first(where: { $0.id == file.id })?.decision ?? file.decision
}

func isRelocated(_ file: DesktopFile) -> Bool {
    // [Isolated] Returns true if file is .moved or .cloud. | [In-file] Used to show "relocated" state in UI.
    let decision = currentDecision(for: file)
    return decision == .moved || decision == .cloud
}

// Undo/Redo section

@discardableResult
private func revertAction(_ action: Action) -> Bool {
    // [Isolated] Reverts the effects of an action. | [In-file] Used for undo logic.
    if let index = files.firstIndex(where: { $0.id == action.file.id }) {
        files[index].decision = nil // [Isolated] Reset file decision to nil. | [In-file] Removes keep/bin/stack/move/cloud mark.
    }
    viewedFileIds.remove(action.file.id) // [Isolated] Mark file as unviewed. | [In-file] Used for UI hints and analytics.

    switch action.type {
    case .keep:
        keptCount = max(0, keptCount - 1) // [Isolated] Decrement kept counter. | [In-file] Updates stats.
    case .bin:
        binnedCount = max(0, binnedCount - 1) // [Isolated] Decrement binned counter. | [In-file] Updates stats.
        reclaimedSpace = max(0, reclaimedSpace - action.file.fileSize) // [Isolated] Subtract file size from reclaimed space. | [In-file] Updates stats.
        if !immediateBinning {
            binnedFiles.removeAll { $0.id == action.file.id } // [Isolated] Remove file from binnedFiles if not immediately binned. | [In-file] Restores to unbinned state.
        }
    case .stack:
        stackedFiles.removeAll { $0.id == action.file.id } // [Isolated] Remove file from stackedFiles. | [In-file] Restores to unstacked state.
    case .cloud:
        // [Isolated] Undo cloud move by moving file back from movedToURL to original URL. | [In-file] Handles security scope for cloud.
        guard let movedURL = action.movedToURL else { break }
        let destURL = cloudManager.resolvedURL(for: action.destinationId)
        let accessing = destURL?.startAccessingSecurityScopedResource() ?? false // [Isolated] Start security scope if needed. | [In-file] Required for sandboxed cloud locations.
        defer { if accessing { destURL?.stopAccessingSecurityScopedResource() } } // [Isolated] End security scope after move. | [In-file] Prevents leaks.
        do {
            try moveItemSafely(from: movedURL, to: action.file.url) // [Isolated] Move file back to original location. | [In-file] Undoes the cloud move.
        } catch {
            errorMessage = "Undo failed for \(action.file.name): \(error.localizedDescription)" // [Isolated] Show error if move fails. | [In-file] Surfaces error to UI.
            return false // [Isolated] Abort undo. | [In-file] Keeps action on stack.
        }
    case .move:
        // [Isolated] Undo folder move by moving file back from movedToURL to original URL. | [In-file] No security scope needed.
        guard let movedURL = action.movedToURL else { break }
        do {
            try moveItemSafely(from: movedURL, to: action.file.url) // [Isolated] Move file back to original location. | [In-file] Undoes the move.
        } catch {
            errorMessage = "Undo failed for \(action.file.name): \(error.localizedDescription)" // [Isolated] Show error if move fails. | [In-file] Surfaces error to UI.
            return false // [Isolated] Abort undo. | [In-file] Keeps action on stack.
        }
    }

    return true // [Isolated] Undo succeeded. | [In-file] Action is now reverted.
}

@discardableResult
private func applyAction(_ action: Action) -> Bool {
    // [Isolated] Re-applies the effects of an action for redo. | [In-file] Used for redo logic.
    guard let index = files.firstIndex(where: { $0.id == action.file.id }) else {
        return false // [Isolated] File not found, abort redo. | [In-file] Defensive.
    }

    switch action.type {
    case .keep:
        files[index].decision = .kept // [Isolated] Mark file as kept. | [In-file] Redoes keep.
        keptCount += 1 // [Isolated] Increment kept counter. | [In-file] Updates stats.
    case .bin:
        files[index].decision = .binned // [Isolated] Mark file as binned. | [In-file] Redoes bin.
        binnedCount += 1 // [Isolated] Increment binned counter. | [In-file] Updates stats.
        reclaimedSpace += action.file.fileSize // [Isolated] Add file size to reclaimed space. | [In-file] Updates stats.
        if !immediateBinning {
            if !binnedFiles.contains(where: { $0.id == action.file.id }) {
                binnedFiles.append(action.file) // [Isolated] Add file back to binnedFiles if not already present. | [In-file] Restores to binned state.
            }
        }
    case .stack:
        files[index].decision = .stacked // [Isolated] Mark file as stacked. | [In-file] Redoes stack.
        if !stackedFiles.contains(where: { $0.id == action.file.id }) {
            stackedFiles.append(action.file) // [Isolated] Add file back to stackedFiles if not already present. | [In-file] Restores to stacked state.
        }
    case .cloud:
        files[index].decision = .cloud // [Isolated] Mark file as cloud. | [In-file] Redoes cloud move.
        // [Isolated] Redo cloud move by moving file from original URL to movedToURL. | [In-file] Handles security scope for cloud.
        guard let movedURL = action.movedToURL else { break }
        let destURL = cloudManager.resolvedURL(for: action.destinationId)
        let accessing = destURL?.startAccessingSecurityScopedResource() ?? false // [Isolated] Start security scope if needed. | [In-file] Required for sandboxed cloud locations.
        defer { if accessing { destURL?.stopAccessingSecurityScopedResource() } } // [Isolated] End security scope after move. | [In-file] Prevents leaks.
        do {
            try moveItemSafely(from: action.file.url, to: movedURL) // [Isolated] Move file to cloud destination. | [In-file] Redoes the move.
        } catch {
            errorMessage = "Redo failed for \(action.file.name): \(error.localizedDescription)" // [Isolated] Show error if move fails. | [In-file] Surfaces error to UI.
            return false // [Isolated] Abort redo. | [In-file] Keeps action on stack.
        }
    case .move:
        files[index].decision = .moved // [Isolated] Mark file as moved. | [In-file] Redoes folder move.
        // [Isolated] Redo folder move by moving file from original URL to movedToURL. | [In-file] No security scope needed.
        guard let movedURL = action.movedToURL else { break }
        do {
            try moveItemSafely(from: action.file.url, to: movedURL) // [Isolated] Move file to folder destination. | [In-file] Redoes the move.
        } catch {
            errorMessage = "Redo failed for \(action.file.name): \(error.localizedDescription)" // [Isolated] Show error if move fails. | [In-file] Surfaces error to UI.
            return false // [Isolated] Abort redo. | [In-file] Keeps action on stack.
        }
    }

    return true // [Isolated] Redo succeeded. | [In-file] Action is now reapplied.
}

private func moveItemSafely(from sourceURL: URL, to destinationURL: URL) throws {
    // [Isolated] Moves file from sourceURL to destinationURL, handling errors and fallback. | [In-file] Used by undo/redo logic.
    if !fileManager.fileExists(atPath: sourceURL.path) {
        if fileManager.fileExists(atPath: destinationURL.path) {
            return // [Isolated] Already moved, treat as success. | [In-file] Defensive.
        }
        throw NSError(domain: "DeclutterViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source item no longer exists"]) // [Isolated] Source missing error. | [In-file] Surfaces error to UI.
    }

    if fileManager.fileExists(atPath: destinationURL.path) {
        throw NSError(domain: "DeclutterViewModel", code: 409, userInfo: [NSLocalizedDescriptionKey: "Destination already exists"]) // [Isolated] Destination exists error. | [In-file] Surfaces error to UI.
    }

    do {
        try fileManager.moveItem(at: sourceURL, to: destinationURL) // [Isolated] Attempt direct move. | [In-file] Fast path.
    } catch {
        try fileManager.copyItem(at: sourceURL, to: destinationURL) // [Isolated] Fallback: copy then remove original. | [In-file] Handles cross-volume moves.
        try fileManager.removeItem(at: sourceURL) // [Isolated] Remove original after copy. | [In-file] Ensures only one file remains.
    }
}

func undoLastAction() -> Bool {
    // [Isolated] Pops last action from undo stack and reverts it. | [In-file] Used for user-initiated undo.
    guard let lastAction = undoStack.popLast() else {
        return false // [Isolated] No action to undo. | [In-file] Defensive.
    }
    guard revertAction(lastAction) else {
        undoStack.append(lastAction) // [Isolated] Revert failed, restore action to stack. | [In-file] Prevents lost action.
        return false // [Isolated] Undo failed, abort. | [In-file] UI can show error.
    }

    redoStack.append(lastAction) // [Isolated] Push reverted action onto redo stack. | [In-file] Enables redo.
    undoableActionCount = undoStack.count // [Isolated] Update published undoable count. | [In-file] Keeps UI in sync.

    appendHistoryEntry(
        type: .undo, // [Isolated] Entry type is .undo. | [In-file] Shows in timeline.
        title: "Undo \(title(for: lastAction.type))", // [Isolated] Title for undo event. | [In-file] E.g., "Undo Bin".
        details: details(for: lastAction), // [Isolated] Details string for event. | [In-file] Folder/destination info.
        fileName: lastAction.file.name, // [Isolated] File name for display. | [In-file] Shows which file was affected.
        folderPath: lastAction.folderPath // [Isolated] Folder path for context. | [In-file] Timeline details.
    )

    if let newIndex = filteredFiles.firstIndex(where: { $0.id == lastAction.file.id }) {
        withAnimation {
            currentFileIndex = newIndex // [Isolated] Seek to affected file in UI. | [In-file] Keeps navigation in sync.
        }
    }
    generateThumbnails(for: currentFileIndex) // [Isolated] Regenerate thumbnails for current index. | [In-file] Ensures UI is up to date.
    return true // [Isolated] Undo succeeded. | [In-file] UI can update state.
}
    
/// Redoes the last undone action, if available. | [In-file] Pops from redoStack, reapplies, and updates UI/history.
func redoLastAction() -> Bool {
    guard let action = redoStack.popLast() else { // [Isolated] Pop last action from redoStack. | [In-file] Returns false if none.
        return false // [Isolated] No action to redo. | [In-file] UI can ignore.
    }
    guard applyAction(action) else { // [Isolated] Try to re-apply the action. | [In-file] Handles move/decision redo.
        redoStack.append(action) // [Isolated] If failed, restore action to redoStack. | [In-file] Prevents loss.
        return false // [Isolated] Redo failed, abort. | [In-file] UI can show error.
    }
    undoStack.append(action) // [Isolated] Push redone action onto undoStack. | [In-file] Enables subsequent undo.
    if undoStack.count > maxUndoStackSize { // [Isolated] Trim undoStack if over max size. | [In-file] Prevents memory growth.
        undoStack.removeFirst() // [Isolated] Remove oldest action if needed. | [In-file] Stack size control.
    }
    undoableActionCount = undoStack.count // [Isolated] Update published undoable count. | [In-file] Keeps UI in sync.

    appendHistoryEntry(
        type: .redo, // [Isolated] History type is .redo. | [In-file] Timeline shows as redo event.
        title: "Redo \(title(for: action.type))", // [Isolated] Title includes action type. | [In-file] E.g., "Redo Bin".
        details: details(for: action), // [Isolated] Show folder/destination info. | [In-file] UI context.
        fileName: action.file.name, // [Isolated] File name for display. | [In-file] Which file was affected.
        folderPath: action.folderPath // [Isolated] Folder path for context. | [In-file] Timeline details.
    )

    if let newIndex = filteredFiles.firstIndex(where: { $0.id == action.file.id }) { // [Isolated] Seek to affected file. | [In-file] Keeps navigation in sync.
        withAnimation {
            currentFileIndex = newIndex // [Isolated] Animate index change. | [In-file] UI feedback.
        }
    }
    generateThumbnails(for: currentFileIndex) // [Isolated] Regenerate thumbnails for new index. | [In-file] Ensures UI is up to date.
    return true // [Isolated] Redo succeeded. | [In-file] UI can update state.
}

/// Resets the session by undoing all actions. | [In-file] Used for "start over" or "reset" UI.
func resetSession() {
    while canUndo { // [Isolated] Loop while there are undoable actions. | [In-file] Ensures all actions are reverted.
        _ = undoLastAction() // [Isolated] Undo last action each time. | [In-file] Restores initial state.
    }
}

/// Removes the last action for a specific file and reverts it. | [In-file] Used for per-file undo in UI.
func undoDecision(for file: DesktopFile) {
    guard let actionIndex = undoStack.lastIndex(where: { $0.file.id == file.id }) else { // [Isolated] Find last action for file. | [In-file] Only proceeds if found.
        return // [Isolated] No action to undo for file. | [In-file] Defensive.
    }
    let action = undoStack.remove(at: actionIndex) // [Isolated] Remove action from undoStack. | [In-file] Prepares for revert.
    guard revertAction(action) else { // [Isolated] Try to revert action. | [In-file] Handles move/decision undo.
        undoStack.insert(action, at: actionIndex) // [Isolated] If failed, restore to stack. | [In-file] Prevents loss.
        return // [Isolated] Undo failed, abort. | [In-file] UI can show error.
    }
    redoStack.append(action) // [Isolated] Push reverted action onto redoStack. | [In-file] Enables redo.
    undoableActionCount = undoStack.count // [Isolated] Update published undoable count. | [In-file] Keeps UI in sync.
    appendHistoryEntry(
        type: .undo, // [Isolated] History type is .undo. | [In-file] Timeline shows as undo event.
        title: "Undo \(title(for: action.type))", // [Isolated] Title includes action type. | [In-file] E.g., "Undo Bin".
        details: details(for: action), // [Isolated] Folder/destination info. | [In-file] Timeline context.
        fileName: action.file.name, // [Isolated] File name for display. | [In-file] Which file was affected.
        folderPath: action.folderPath // [Isolated] Folder path for context. | [In-file] Timeline details.
    )
}

/// True if there are actions available to redo. | [In-file] Used to enable/disable redo UI.
var canRedo: Bool {
    !redoStack.isEmpty // [Isolated] True if redoStack is not empty. | [In-file] UI uses for button state.
}

/// True if the user can go forward in the filtered file list. | [In-file] Used for next navigation button.
var canGoForward: Bool {
    currentFileIndex < filteredFiles.count - 1 // [Isolated] True if not at last file. | [In-file] UI uses for next button.
}

/// Advances to the next file in the filtered list, if possible. | [In-file] Used for navigation UI.
func goForward() {
    if currentFileIndex < filteredFiles.count - 1 { // [Isolated] Guard: only if not at end. | [In-file] Prevents out-of-bounds.
        withAnimation {
            currentFileIndex += 1 // [Isolated] Move to next file. | [In-file] UI animation.
        }
        generateThumbnails(for: currentFileIndex) // [Isolated] Preload thumbnails for new index. | [In-file] Keeps UI fast.
    }
}

/// Moves to the previous file in the filtered list, if possible. | [In-file] Used for navigation UI.
func goBack() {
    if currentFileIndex > 0 { // [Isolated] Guard: only if not at first file. | [In-file] Prevents out-of-bounds.
        withAnimation {
            currentFileIndex -= 1 // [Isolated] Move to previous file. | [In-file] UI animation.
        }
        generateThumbnails(for: currentFileIndex) // [Isolated] Preload thumbnails for new index. | [In-file] Keeps UI fast.
    }
}

/// True if there are actions available to undo. | [In-file] Used to enable/disable undo UI.
var canUndo: Bool {
    !undoStack.isEmpty // [Isolated] True if undoStack is not empty. | [In-file] UI uses for button state.
}

/// Removes a file from the stackedFiles array. | [In-file] Used to unstack a file after review.
func removeFromStack(_ file: DesktopFile) {
    stackedFiles.removeAll { $0.id == file.id } // [Isolated] Remove file by id. | [In-file] Keeps stack current.
}

/// Trashes all stacked files and clears the stack. | [In-file] Used for "Empty Stack" UI action.
func emptyStack() {
    for file in stackedFiles { // [Isolated] Loop over stacked files. | [In-file] Trash each one.
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil) // [Isolated] Move file to trash. | [In-file] Effectuates deletion.
            print("Moved to trash: \(file.name)") // [Isolated] Debug print. | [In-file] Developer feedback.
        } catch {
            print("Failed to trash file \(file.name): \(error)") // [Isolated] Debug print on failure. | [In-file] Troubleshooting.
        }
    }
    stackedFiles.removeAll() // [Isolated] Clear the stack. | [In-file] Prepares for new group.
    // [Isolated] Don't reset session - just clear the stack. | [In-file] Session state remains, only stack emptied.
}

/// Moves to the next file, advancing index and preloading thumbnails. | [In-file] Used for programmatic navigation.
private func moveToNext() {
    withAnimation {
        if currentFileIndex < filteredFiles.count { // [Isolated] Guard: only increment if not past end. | [In-file] Prevents out-of-bounds.
            currentFileIndex += 1 // [Isolated] Advance index. | [In-file] UI animation.
        }
    }
    generateThumbnails(for: currentFileIndex) // [Isolated] Preload thumbnails for new index. | [In-file] Keeps UI fast.
    if isFinished && !folderStack.isEmpty { // [Isolated] If finished and in subfolder, return to parent. | [In-file] Handles subfolder navigation.
        returnToParentFolder() // [Isolated] Return to parent folder context. | [In-file] Prevents user from getting stuck.
    }
}

/// True if currently in a subfolder (folderStack is not empty). | [In-file] Used for navigation UI.
var isInSubfolder: Bool {
    !folderStack.isEmpty // [Isolated] True if folderStack has entries. | [In-file] UI shows "Back" button.
}

/// The display name of the parent folder for navigation. | [In-file] Used for "Back" button label.
var parentFolderName: String {
    folderStack.last?.url.lastPathComponent ?? "Back" // [Isolated] Show last folder name or fallback. | [In-file] UI context.
}

/// Skips the specified folder/file, removing it from the session and updating navigation. | [In-file] Used for "Skip Folder" UI.
func skipFolder(_ file: DesktopFile) {
    if let removedIndex = filteredFiles.firstIndex(where: { $0.id == file.id }) { // [Isolated] Find file in filtered list. | [In-file] Only proceed if found.
        files.removeAll { $0.id == file.id } // [Isolated] Remove from files array. | [In-file] Removes from session.
        if filteredFiles.isEmpty { // [Isolated] If no files left after removal. | [In-file] Handle empty folder edge case.
            if folderStack.isEmpty { // [Isolated] If at top level, prompt for new folder. | [In-file] UI fallback.
                promptForFolderAndLoad()
            } else {
                returnToParentFolder() // [Isolated] If in subfolder, return to parent. | [In-file] Avoids user getting stuck.
            }
            return // [Isolated] Done handling empty case. | [In-file] Prevents further processing.
        }
        currentFileIndex = min(removedIndex, filteredFiles.count - 1) // [Isolated] Adjust index after removal. | [In-file] Keeps navigation valid.
        generateThumbnails(for: currentFileIndex) // [Isolated] Preload thumbnails for new index. | [In-file] UI update.
    } else {
        moveToNext() // [Isolated] If file not found, just move to next. | [In-file] Defensive fallback.
    }
}

/// Enters a folder, saving current session state and loading new files. | [In-file] Used for folder navigation.
func enterFolder(_ file: DesktopFile) {
    guard file.fileType == .folder else { return } // [Isolated] Guard: only folders. | [In-file] Prevents invalid navigation.
    let context = FolderContext(
        url: selectedFolderURL ?? file.url, // [Isolated] Save current folder URL. | [In-file] For restoration.
        files: files, // [Isolated] Save current files list. | [In-file] For restoration.
        currentFileIndex: currentFileIndex, // [Isolated] Save current index. | [In-file] For navigation restore.
        selectedFileTypeFilter: selectedFileTypeFilter, // [Isolated] Save filter. | [In-file] UI context.
        totalFilesCount: totalFilesCount, // [Isolated] Save file count. | [In-file] For stats restore.
        suggestionCache: suggestionCache, // [Isolated] Save suggestion cache. | [In-file] For AI restore.
        lastSuggestionFileId: lastSuggestionFileId, // [Isolated] Save last suggestion. | [In-file] For AI restore.
        currentFileSuggestions: currentFileSuggestions, // [Isolated] Save file suggestions. | [In-file] UI restore.
        thumbnailGenerationInProgress: thumbnailGenerationInProgress // [Isolated] Save in-progress thumbnails. | [In-file] For concurrency restore.
    )
    folderStack.append(context) // [Isolated] Push context to folderStack. | [In-file] Enables return to parent.
    selectedFolderURL = file.url // [Isolated] Set new folder URL. | [In-file] For FileScanner and UI.
    FileScanner.shared.useCustomURL(file.url) // [Isolated] Update FileScanner with new URL. | [In-file] Loads new folder.
    loadFiles() // [Isolated] Load files from new folder. | [In-file] Starts new navigation context.
}

/// Returns to the parent folder, restoring previous session state. | [In-file] Used for "Back" navigation.
func returnToParentFolder() {
    guard let context = folderStack.popLast() else { return } // [Isolated] Pop previous context. | [In-file] Defensive: only if exists.
    selectedFolderURL = context.url // [Isolated] Restore previous folder URL. | [In-file] For FileScanner and UI.
    FileScanner.shared.useCustomURL(context.url) // [Isolated] Update FileScanner with restored URL. | [In-file] Ensures correct folder.
    files = context.files // [Isolated] Restore previous files list. | [In-file] Session state.
    currentFileIndex = min(context.currentFileIndex, files.count) // [Isolated] Restore navigation index, clamp to count. | [In-file] Prevents out-of-bounds.
    selectedFileTypeFilter = context.selectedFileTypeFilter // [Isolated] Restore file type filter. | [In-file] UI context.
    totalFilesCount = context.totalFilesCount // [Isolated] Restore total files count. | [In-file] UI/statistics.
    suggestionCache = context.suggestionCache // [Isolated] Restore AI suggestion cache. | [In-file] For suggestion UI.
    lastSuggestionFileId = context.lastSuggestionFileId // [Isolated] Restore last suggestion tracking. | [In-file] For AI UI.
    currentFileSuggestions = context.currentFileSuggestions // [Isolated] Restore current suggestions. | [In-file] UI badges.
    thumbnailGenerationInProgress = context.thumbnailGenerationInProgress // [Isolated] Restore in-progress thumbnails. | [In-file] For concurrency.
    updateBreadcrumbs() // [Isolated] Update breadcrumb navigation UI. | [In-file] Reflects restored context.
    generateThumbnails(for: currentFileIndex) // [Isolated] Regenerate thumbnails for restored index. | [In-file] Ensures UI is up to date.
}

private func updateBreadcrumbs() { // [Isolated] Updates breadcrumbText for current navigation. | [In-file] Shows folder stack path in UI.
    let crumbs = folderStack.map { $0.url.lastPathComponent } + [selectedFolderURL?.lastPathComponent ?? "Folder"] // [Isolated] Build array of folder names from stack and current. | [In-file] Each crumb is a folder name or fallback.
    breadcrumbText = crumbs.joined(separator: " > ") // [Isolated] Join crumbs with " > " for display. | [In-file] Updates published breadcrumbText for UI.
}

func emptyBin() { // [Isolated] Trashes all files in binnedFiles and clears bin. | [In-file] Used for "Empty Bin" UI action.
    for file in binnedFiles { // [Isolated] Loop over each file in bin. | [In-file] Attempt to trash each file.
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil) // [Isolated] Move file to Trash. | [In-file] Effectuates deletion.
            print("Moved to trash: \(file.name)") // [Isolated] Debug print for success. | [In-file] Developer feedback.
        } catch {
            print("Failed to trash file \(file.name): \(error)") // [Isolated] Debug print for failure. | [In-file] Troubleshooting.
        }
    }
    binnedFiles.removeAll() // [Isolated] Clear all files from bin. | [In-file] Prepares for new session.
    reclaimedSpace = 0 // [Isolated] Reset reclaimed space since files are now in trash. | [In-file] UI stat reset.
    // [Isolated] Don't reset session - just clear the bin. | [In-file] Session state remains, only bin emptied.
}

func restoreFromBin(_ file: DesktopFile) { // [Isolated] Restores a file from bin to files list and updates counters. | [In-file] Used for "Restore" UI action.
    binnedFiles.removeAll { $0.id == file.id } // [Isolated] Remove file from binnedFiles. | [In-file] Bin state update.
    binnedCount = max(0, binnedCount - 1) // [Isolated] Decrement binned counter, clamp at 0. | [In-file] UI stats.
    reclaimedSpace = max(0, reclaimedSpace - file.fileSize) // [Isolated] Subtract file size from reclaimed space, clamp at 0. | [In-file] UI stats.
    files.insert(file, at: 0) // [Isolated] Insert restored file at beginning of files. | [In-file] User can review it.
    if currentFileIndex >= filteredFiles.count { // [Isolated] If at end, reset index to review restored file. | [In-file] Navigation fix.
        currentFileIndex = 0 // [Isolated] Go to first file. | [In-file] UI update.
    }
    generateThumbnails(for: currentFileIndex) // [Isolated] Regenerate thumbnails for current index. | [In-file] UI update.
}

func removeFromBin(_ file: DesktopFile) { // [Isolated] Permanently trashes file from bin and updates counters. | [In-file] Used for "Delete" UI action.
    binnedFiles.removeAll { $0.id == file.id } // [Isolated] Remove file from binnedFiles. | [In-file] Bin state update.
    binnedCount = max(0, binnedCount - 1) // [Isolated] Decrement binned counter, clamp at 0. | [In-file] UI stats.
    reclaimedSpace = max(0, reclaimedSpace - file.fileSize) // [Isolated] Subtract file size from reclaimed space, clamp at 0. | [In-file] UI stats.
    do {
        try FileManager.default.trashItem(at: file.url, resultingItemURL: nil) // [Isolated] Move file to Trash immediately. | [In-file] Final deletion.
        print("Moved to trash: \(file.name)") // [Isolated] Debug print for success. | [In-file] Developer feedback.
    } catch {
        print("Failed to trash file \(file.name): \(error)") // [Isolated] Debug print for failure. | [In-file] Troubleshooting.
    }
}

var formattedReclaimedSpace: String { // [Isolated] Returns reclaimedSpace as a formatted string. | [In-file] Used for UI display.
    let formatter = ByteCountFormatter() // [Isolated] Create byte count formatter. | [In-file] For human-readable sizes.
    formatter.allowedUnits = [.useMB, .useGB, .useKB] // [Isolated] Limit units to MB, GB, KB. | [In-file] Avoids bytes.
    formatter.countStyle = .file // [Isolated] Use file style for sizes. | [In-file] Matches Finder display.
    return formatter.string(fromByteCount: reclaimedSpace) // [Isolated] Format reclaimedSpace as string. | [In-file] UI display.
}

func triggerShake(for fileId: UUID) { // [Isolated] Triggers shake animation for a file by id. | [In-file] Used for UI feedback.
    shakeTask?.cancel() // [Isolated] Cancel any previous shake task. | [In-file] Prevents overlap.
    withAnimation {
        shakingFileId = fileId // [Isolated] Set file id to trigger shake. | [In-file] UI effect.
    }
    shakeTask = Task { @MainActor in // [Isolated] Start async task to auto-stop shake. | [In-file] 3 second timeout.
        try? await Task.sleep(nanoseconds: 3 * 1_000_000_000) // [Isolated] Wait 3 seconds. | [In-file] Shake duration.
        if !Task.isCancelled && shakingFileId == fileId { // [Isolated] Only clear if not cancelled and id matches. | [In-file] UI state check.
            withAnimation {
                shakingFileId = nil // [Isolated] Clear shaking id. | [In-file] Stop shake effect.
            }
        }
    }
}

func stopShake() { // [Isolated] Immediately stops any ongoing shake animation. | [In-file] Used for UI state reset.
    shakeTask?.cancel() // [Isolated] Cancel shake task. | [In-file] Prevents auto-clear.
    withAnimation {
        shakingFileId = nil // [Isolated] Clear shaking id. | [In-file] UI state reset.
    }
}

// [Isolated] Group review section. | [In-file] Supports reviewing suggestion-derived file groups with thumbnails and smart actions.

func startGroupReview(for suggestion: FileSuggestion) { // [Isolated] Begins group review for a suggestion. | [In-file] Sets up groupReviewFiles and UI state.
    let groupFiles: [DesktopFile] // [Isolated] Will hold files for group review. | [In-file] Derived from suggestion type.
    switch suggestion.type { // [Isolated] Map suggestion type to files. | [In-file] Only certain types supported.
    case .duplicate(_, let files),
         .similarNames(_, _, let files),
         .sameSession(_, let files):
        groupFiles = files // [Isolated] Use files array from suggestion. | [In-file] Prepares for review.
    default:
        return // [Isolated] Only proceed for supported suggestion types. | [In-file] Defensive.
    }
    var syncedFiles: [DesktopFile] = [] // [Isolated] Will hold files with synced thumbnails. | [In-file] Ensures UI consistency.
    for var file in groupFiles { // [Isolated] Loop to sync thumbnails from main files array. | [In-file] Avoids duplicate generation.
        if let mainFileIndex = files.firstIndex(where: { $0.id == file.id }),
           let thumbnail = files[mainFileIndex].thumbnail { // [Isolated] Lookup thumbnail in main files array. | [In-file] Use if exists.
            file.thumbnail = thumbnail // [Isolated] Assign existing thumbnail. | [In-file] Avoids extra work.
        }
        syncedFiles.append(file) // [Isolated] Add file (with possibly updated thumbnail) to group. | [In-file] Prepare for UI.
    }
    groupReviewFiles = syncedFiles // [Isolated] Set groupReviewFiles for UI. | [In-file] Drives group review sheet.
    groupReviewSuggestion = suggestion // [Isolated] Set current group review suggestion. | [In-file] Needed for actions.
    showGroupReview = true // [Isolated] Show group review UI. | [In-file] Triggers UI sheet.
    generateThumbnailsForGroupReview() // [Isolated] Generate missing thumbnails for group. | [In-file] Ensures all images shown.
}

private func generateThumbnailsForGroupReview() { // [Isolated] Generates thumbnails for groupReviewFiles, tracking in-flight. | [In-file] Avoids duplicate work.
    for (index, file) in groupReviewFiles.enumerated() { // [Isolated] Enumerate files for thumbnail generation. | [In-file] Needed for array update.
        guard !thumbnailGenerationInProgress.contains(file.id),
              file.thumbnail == nil else {
            continue // [Isolated] Skip if thumbnail already exists or is in progress. | [In-file] Idempotent.
        }
        thumbnailGenerationInProgress.insert(file.id) // [Isolated] Mark file as in-progress. | [In-file] Tracks concurrency.
        FileScanner.shared.generateThumbnail(for: file) { [weak self] image in // [Isolated] Generate thumbnail asynchronously. | [In-file] Calls back on completion.
            guard let self = self else { return }
            Task { @MainActor in // [Isolated] Ensure UI updates on main thread. | [In-file] Safe for SwiftUI.
                if index < self.groupReviewFiles.count,
                   self.groupReviewFiles[index].id == file.id {
                    var updatedFiles = self.groupReviewFiles // [Isolated] Copy array for mutation. | [In-file] Triggers SwiftUI update.
                    updatedFiles[index].thumbnail = image // [Isolated] Assign generated thumbnail. | [In-file] UI image update.
                    self.groupReviewFiles = updatedFiles // [Isolated] Publish updated array. | [In-file] UI refresh.
                }
                if let mainFileIndex = self.files.firstIndex(where: { $0.id == file.id }) {
                    var updatedMainFiles = self.files // [Isolated] Copy main files array. | [In-file] For canonical cache.
                    updatedMainFiles[mainFileIndex].thumbnail = image // [Isolated] Assign thumbnail to main file. | [In-file] Caches for future.
                    self.files = updatedMainFiles // [Isolated] Publish updated files. | [In-file] Keeps arrays in sync.
                }
                self.thumbnailGenerationInProgress.remove(file.id) // [Isolated] Remove id from in-progress set. | [In-file] Allows future generation.
            }
        }
    }
}

func getGroupStats() -> (totalSize: Int64, dateRange: String?) { // [Isolated] Computes total size and date range for groupReviewFiles. | [In-file] Used for group review UI stats.
    let totalSize = groupReviewFiles.reduce(0) { $0 + $1.fileSize } // [Isolated] Sum file sizes in group. | [In-file] For MB display.
    let dates = groupReviewFiles.compactMap { file -> Date? in // [Isolated] Extract creation dates for files. | [In-file] Needed for range.
        try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date // [Isolated] Read creationDate attr. | [In-file] Defensive optional.
    }
    guard let earliest = dates.min(), let latest = dates.max() else {
        return (totalSize, nil) // [Isolated] If no dates, return nil for range. | [In-file] Defensive.
    }
    let formatter = DateFormatter() // [Isolated] Date formatter for display. | [In-file] For range string.
    formatter.dateStyle = .medium // [Isolated] Use medium date style. | [In-file] UI readability.
    formatter.timeStyle = .short // [Isolated] Use short time style. | [In-file] UI readability.
    if Calendar.current.isDate(earliest, inSameDayAs: latest) { // [Isolated] If all files same day, show time range. | [In-file] Compact UI.
        formatter.dateStyle = .none
        return (totalSize, "Today \(formatter.string(from: earliest)) - \(formatter.string(from: latest))") // [Isolated] Show time range for today. | [In-file] UI display.
    } else {
        return (totalSize, "\(formatter.string(from: earliest)) - \(formatter.string(from: latest))") // [Isolated] Show date range. | [In-file] UI display.
    }
}

func getSmartActions() -> [SmartAction] { // [Isolated] Returns array of SmartAction for current groupReviewSuggestion. | [In-file] Used for group action UI.
    guard let suggestion = groupReviewSuggestion else { return [] } // [Isolated] Only proceed if suggestion exists. | [In-file] Defensive.
    var actions: [SmartAction] = [] // [Isolated] Will hold generated smart actions. | [In-file] For UI buttons.
    let totalSize = groupReviewFiles.reduce(0) { $0 + $1.fileSize } // [Isolated] Sum file sizes for group. | [In-file] MB calculations.
    let sizeMB = Double(totalSize) / (1024 * 1024) // [Isolated] Convert size to MB. | [In-file] For display.
    switch suggestion.type { // [Isolated] Generate actions based on suggestion type. | [In-file] Handles duplicates, similar, same session.
    case .duplicate(let count, _):
        let sorted = groupReviewFiles.sorted { file1, file2 in // [Isolated] Sort files by creation date, newest first. | [In-file] For "keep newest" action.
            let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.url.path)[.creationDate] as? Date) ?? Date.distantPast
            let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.url.path)[.creationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }
        actions.append(SmartAction(
            title: "Keep newest, delete others", // [Isolated] Action to keep one, bin rest. | [In-file] For duplicate groups.
            description: "Keep 1 file, delete \(count - 1)", // [Isolated] Action description. | [In-file] Shows counts.
            icon: "clock.fill", // [Isolated] Clock icon for recency. | [In-file] UI.
            action: {
                let currentFiles = self.groupReviewFiles.filter { f in sorted.contains(where: { $0.id == f.id }) } // [Isolated] Filter files still present. | [In-file] Defensive.
                let currentSorted = currentFiles.sorted { file1, file2 in
                     let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.url.path)[.creationDate] as? Date) ?? Date.distantPast
                     let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.url.path)[.creationDate] as? Date) ?? Date.distantPast
                     return date1 > date2
                 }
                guard let newest = currentSorted.first else { return } // [Isolated] Defensive: must have one file. | [In-file] Avoid crash.
                let toKeep = [newest] // [Isolated] Keep newest file. | [In-file] User intent.
                let toBin = Array(currentSorted.dropFirst()) // [Isolated] Bin the rest. | [In-file] Bulk action.
                self.keepGroupFiles(toKeep) // [Isolated] Mark files as kept. | [In-file] State update.
                self.binGroupFiles(toBin) // [Isolated] Mark files as binned. | [In-file] State update.
            }
        ))
    case .similarNames(_, let count, _):
        let sorted = groupReviewFiles.sorted { file1, file2 in // [Isolated] Sort by creation date, newest first. | [In-file] For "keep newest N" action.
            let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.url.path)[.creationDate] as? Date) ?? Date.distantPast
            let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.url.path)[.creationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }
        let keepCount = min(5, count) // [Isolated] Suggest keeping up to 5. | [In-file] User convenience.
        actions.append(SmartAction(
            title: "Keep newest \(keepCount), delete rest", // [Isolated] Action title for partial keep. | [In-file] UI.
            description: "Free \(String(format: "%.1f", sizeMB * Double(count - keepCount) / Double(count))) MB", // [Isolated] Estimate space saved. | [In-file] UI.
            icon: "sparkles", // [Isolated] Sparkles icon for cleanup. | [In-file] UI.
            action: {
                let toKeep = Array(sorted.prefix(keepCount)) // [Isolated] Keep N newest files. | [In-file] Partial keep.
                let toBin = Array(sorted.dropFirst(keepCount)) // [Isolated] Bin rest. | [In-file] Bulk action.
                self.keepGroupFiles(toKeep) // [Isolated] Mark as kept. | [In-file] State update.
                self.binGroupFiles(toBin) // [Isolated] Mark as binned. | [In-file] State update.
            }
        ))
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60) // [Isolated] Compute date for 1 week ago. | [In-file] For old file action.
        let oldFiles = groupReviewFiles.filter { file in // [Isolated] Filter files older than 1 week. | [In-file] Smart delete.
            guard let date = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
                return false
            }
            return date < oneWeekAgo
        }
        if !oldFiles.isEmpty {
            let oldSizeMB = Double(oldFiles.reduce(0) { $0 + $1.fileSize }) / (1024 * 1024) // [Isolated] Calculate size of old files. | [In-file] UI stat.
            actions.append(SmartAction(
                title: "Delete files older than 1 week", // [Isolated] Action title. | [In-file] Bulk old file delete.
                description: "\(oldFiles.count) files, \(String(format: "%.1f", oldSizeMB)) MB", // [Isolated] Show count and size. | [In-file] UI.
                icon: "calendar.badge.clock", // [Isolated] Calendar icon for age. | [In-file] UI.
                action: {
                    self.binGroupFiles(oldFiles) // [Isolated] Bin old files. | [In-file] State update.
                }
            ))
        }
    case .sameSession(_, _):
        actions.append(SmartAction(
            title: "Keep all (created together)", // [Isolated] Action to keep all files. | [In-file] For related files.
            description: "These files are related", // [Isolated] Description for context. | [In-file] UI.
            icon: "checkmark.circle.fill", // [Isolated] Checkmark icon. | [In-file] UI.
            action: {
                self.keepGroupFiles(self.groupReviewFiles) // [Isolated] Keep all files. | [In-file] State update.
            }
        ))
        actions.append(SmartAction(
            title: "Delete all", // [Isolated] Action to bin all files. | [In-file] Bulk action.
            description: "Free \(String(format: "%.1f", sizeMB)) MB", // [Isolated] Show total size. | [In-file] UI.
            icon: "trash.fill", // [Isolated] Trash icon. | [In-file] UI.
            action: {
                self.binGroupFiles(self.groupReviewFiles) // [Isolated] Bin all files. | [In-file] State update.
            }
        ))
    default:
        break // [Isolated] No smart actions for other types. | [In-file] Defensive.
    }
    return actions // [Isolated] Return generated smart actions. | [In-file] Used in group review UI.
}
    
func binStackedFiles(_ filesToBin: [DesktopFile]) { // [Isolated] Bins (trashes) all files in the provided stacked files list. | [In-file] Used for stack group bin action.
    for file in filesToBin { // [Isolated] Loop over each file to bin. | [In-file] Processes each stacked file.
        stackedFiles.removeAll { $0.id == file.id } // [Isolated] Remove file from stackedFiles array. | [In-file] Updates stack state.
        do { // [Isolated] Attempt to trash file using FileManager. | [In-file] Moves file to Trash.
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil) // [Isolated] Trash file via system call. | [In-file] Effectuates deletion.
            binnedCount += 1 // [Isolated] Increment binned count for each file. | [In-file] Updates stats.
            reclaimedSpace += filesToBin.reduce(0) { $0 + $1.fileSize } // [Isolated] Add total size of all input files to reclaimedSpace each iteration (may overcount in current form). | [In-file] Tracks reclaimed disk space.
            print("Stacked file moved to trash: \(file.name)") // [Isolated] Debug print for successful trash. | [In-file] Developer feedback.
        } catch { // [Isolated] Handle errors from trash operation. | [In-file] Defensive.
            print("Failed to trash stacked file \(file.name): \(error)") // [Isolated] Debug print on failure. | [In-file] Troubleshooting.
        }
    }
}

func keepStackedFiles(_ filesToKeep: [DesktopFile]) { // [Isolated] Marks files in the stack as kept and removes them from the stack. | [In-file] Used for stack group keep action.
    for file in filesToKeep { // [Isolated] Loop over each file to keep. | [In-file] Processes each stacked file.
        stackedFiles.removeAll { $0.id == file.id } // [Isolated] Remove file from stackedFiles array. | [In-file] Updates stack state.
        if let index = files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Find file in main files array. | [In-file] Ensures canonical update.
            files[index].decision = .kept // [Isolated] Mark file as kept in main array. | [In-file] Updates file decision.
            keptCount += 1 // [Isolated] Increment kept count. | [In-file] Updates stats.
        }
    }
}

func keepGroupFiles(_ filesToKeep: [DesktopFile]) { // [Isolated] Marks files as kept in group review and updates all state. | [In-file] Used for group keep action.
    guard !filesToKeep.isEmpty else { return } // [Isolated] Guard: do nothing if input is empty. | [In-file] Defensive.
    for file in filesToKeep { // [Isolated] Loop over each file to keep. | [In-file] Processes group files.
        if let index = files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures canonical update.
            files[index].decision = .kept // [Isolated] Mark file as kept. | [In-file] Updates file decision.
            keptCount += 1 // [Isolated] Increment kept count. | [In-file] Updates stats.
            recordAction(.keep, file: file, decision: .kept) // [Isolated] Record keep action for undo/redo/history. | [In-file] Enables session timeline.
        }
        suggestionCache.removeValue(forKey: file.id) // [Isolated] Invalidate suggestion cache for file. | [In-file] Ensures up-to-date suggestions.
    }
    groupReviewFiles.removeAll { file in filesToKeep.contains { $0.id == file.id } } // [Isolated] Remove kept files from group review list. | [In-file] Updates group UI.
    if groupReviewFiles.isEmpty { // [Isolated] If all files processed, exit group review. | [In-file] UI sheet dismiss logic.
        showGroupReview = false // [Isolated] Dismiss group review UI. | [In-file] UI update.
        groupReviewSuggestion = nil // [Isolated] Clear current group review suggestion. | [In-file] State reset.
    }
}

func binGroupFiles(_ filesToBin: [DesktopFile]) { // [Isolated] Bins (trashes or stages) files in group review and updates all state. | [In-file] Used for group bin action.
    guard !filesToBin.isEmpty else { return } // [Isolated] Guard: do nothing if input is empty. | [In-file] Defensive.
    for file in filesToBin { // [Isolated] Loop over each file to bin. | [In-file] Processes group files.
        if let index = files.firstIndex(where: { $0.id == file.id }) { // [Isolated] Lookup file in main files array. | [In-file] Ensures canonical update.
            files[index].decision = .binned // [Isolated] Mark file as binned. | [In-file] Updates file decision.
            binnedCount += 1 // [Isolated] Increment binned count. | [In-file] Updates stats.
            reclaimedSpace += file.fileSize // [Isolated] Add file size to reclaimed space. | [In-file] Tracks disk space.
            if immediateBinning { // [Isolated] If immediate binning is enabled, trash file now. | [In-file] Immediate deletion branch.
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil) // [Isolated] Trash file via system call. | [In-file] Effectuates deletion.
                } catch {
                    print("Failed to trash from group: \(error)") // [Isolated] Debug print on failure to trash. | [In-file] Troubleshooting.
                }
            } else {
                binnedFiles.append(file) // [Isolated] If not immediate, append to binnedFiles for later. | [In-file] Stages for batch bin.
            }
            recordAction(.bin, file: file, decision: .binned) // [Isolated] Record bin action for undo/redo/history. | [In-file] Enables session timeline.
        }
        suggestionCache.removeValue(forKey: file.id) // [Isolated] Invalidate suggestion cache for file. | [In-file] Ensures up-to-date suggestions.
    }
    groupReviewFiles.removeAll { file in filesToBin.contains { $0.id == file.id } } // [Isolated] Remove binned files from group review list. | [In-file] Updates group UI.
    if groupReviewFiles.isEmpty { // [Isolated] If all files processed, exit group review. | [In-file] UI sheet dismiss logic.
        showGroupReview = false // [Isolated] Dismiss group review UI. | [In-file] UI update.
        groupReviewSuggestion = nil // [Isolated] Clear current group review suggestion. | [In-file] State reset.
    }
}
}

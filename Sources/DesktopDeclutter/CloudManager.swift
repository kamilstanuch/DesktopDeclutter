//  CloudManager.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  This file centralizes management of user-selected “cloud destinations” for DesktopDeclutter, including:
//  - Classifying supported providers (iCloud Drive, Google Drive, Custom folders).
//  - Persisting destinations and the currently active destination across launches.
//  - Creating/resolving security-scoped bookmarks to retain sandboxed access to user-picked folders.
//  - Normalizing Google Drive selections so choosing an account root resolves to “My Drive” when present.
//  - Providing safe utilities for validating destination writability and moving files into destination subfolders.
//
//  Unique characteristics
//  ----------------------
//  - Persists destinations in UserDefaults as JSON-encoded `[CloudDestination]` plus an active destination UUID.
//  - Uses security-scoped bookmarks for sandboxed folder access across launches, including stale refresh and
//    defensive sanitization for invalid/legacy bookmark payloads.
//  - Applies Google Drive–specific normalization: if a user selects a `GoogleDrive-*` account root, the
//    destination is redirected to the “My Drive” folder when it exists.
//  - Moves files using a safer Copy + Remove strategy (instead of a direct move) to reduce cross-volume/provider
//    issues.
//  - Organizes moved files under a per-destination app root folder named `DesktopDeclutter`, and optionally
//    subfolders by “source folder name” (fallbacking to `Unsorted`).
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  Swift (language)
//  - https://docs.swift.org/swift-book/documentation/the-swift-programming-language/
//
//  SwiftUI (ObservableObject, @Published)
//  - https://developer.apple.com/documentation/swiftui
//  - ObservableObject: https://developer.apple.com/documentation/swiftui/observableobject
//  - @Published: https://developer.apple.com/documentation/combine/published
//
//  Foundation (persistence + filesystem)
//  - https://developer.apple.com/documentation/foundation
//  - UserDefaults: https://developer.apple.com/documentation/foundation/userdefaults
//  - JSONEncoder: https://developer.apple.com/documentation/foundation/jsonencoder
//  - JSONDecoder: https://developer.apple.com/documentation/foundation/jsondecoder
//  - URL: https://developer.apple.com/documentation/foundation/url
//  - FileManager: https://developer.apple.com/documentation/foundation/filemanager
//  - NSError: https://developer.apple.com/documentation/foundation/nserror
//  - UUID: https://developer.apple.com/documentation/foundation/uuid
//
//  Security-scoped bookmarks + resources (macOS sandbox)
//  - URL.bookmarkData(options:includingResourceValuesForKeys:relativeTo:):
//    https://developer.apple.com/documentation/foundation/url/1410317-bookmarkdata
//  - URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:):
//    https://developer.apple.com/documentation/foundation/url/1408035-init
//  - NSURLBookmarkCreationOptions: https://developer.apple.com/documentation/foundation/nsurlbookmarkcreationoptions
//  - NSURLBookmarkResolutionOptions: https://developer.apple.com/documentation/foundation/nsurlbookmarkresolutionoptions
//  - startAccessingSecurityScopedResource():
//    https://developer.apple.com/documentation/foundation/url/1415005-startaccessingsecurityscopedr
//  - stopAccessingSecurityScopedResource():
//    https://developer.apple.com/documentation/foundation/url/1415006-stopaccessingsecurityscopedre
//
//  System imagery (SF Symbols)
//  - https://developer.apple.com/design/human-interface-guidelines/sf-symbols
//  - Image(systemName:): https://developer.apple.com/documentation/swiftui/image/init(systemname:)
//
//  NOTE: The following types are referenced but are defined within this project (internal, not external libraries):
//  - DesktopFile (model describing a file on the desktop; used as the input to move operations)
//

import Foundation // [Isolated] Imports Foundation types/services. | [In-file] Enables URL/Data/UserDefaults/JSON/FileManager/bookmark APIs.
import SwiftUI // [Isolated] Imports SwiftUI/Combine interoperability. | [In-file] Enables ObservableObject + @Published state for UI binding.

enum CloudProvider: String, CaseIterable, Identifiable, Codable { // [Isolated] Declares provider enum. | [In-file] Labels destinations for UI + provider-specific logic.
    case iCloud = "iCloud Drive" // [Isolated] iCloud provider case. | [In-file] Used to classify iCloud Drive destinations.
    case googleDrive = "Google Drive" // [Isolated] Google Drive provider case. | [In-file] Enables Google Drive–specific normalization and display.
    case custom = "Custom" // [Isolated] Custom provider case. | [In-file] Represents other user-selected folders (often under CloudStorage).

    var id: String { self.rawValue } // [Isolated] Identifiable id. | [In-file] Provides stable identity for SwiftUI lists/pickers.

    var iconName: String { // [Isolated] Computed SF Symbol name. | [In-file] Maps provider to a display icon for destination UI.
        switch self { // [Isolated] Switch on provider. | [In-file] Selects a deterministic symbol per provider.
        case .iCloud: return "icloud.fill" // [Isolated] Returns iCloud symbol. | [In-file] Used to visually denote iCloud Drive.
        case .googleDrive: return "externaldrive.fill" // [Isolated] Returns drive symbol. | [In-file] Used to visually denote Google Drive.
        case .custom: return "folder.fill" // [Isolated] Returns folder symbol. | [In-file] Used to visually denote custom folder destinations.
        } // [Isolated] Ends switch. | [In-file] Guarantees an icon name for each provider.
    } // [Isolated] Ends iconName. | [In-file] Consumed by destination rows/labels.
} // [Isolated] Ends CloudProvider enum. | [In-file] Provider classification is now defined.

struct CloudDestination: Identifiable, Codable, Equatable { // [Isolated] Declares destination model struct. | [In-file] Represents a persisted destination directory with optional bookmark.
    var id = UUID() // [Isolated] Creates UUID identifier. | [In-file] Uniquely identifies the destination across edits and persistence.
    var name: String // [Isolated] Display name string. | [In-file] Used for destination UI labels.
    var path: String // [Isolated] Filesystem path string. | [In-file] Persists the destination directory path across launches.
    var bookmarkData: Data? // [Isolated] Optional bookmark payload. | [In-file] Enables sandboxed access to user-selected folders.
    var provider: CloudProvider // [Isolated] Provider classification. | [In-file] Drives display + normalization rules.
} // [Isolated] Ends CloudDestination. | [In-file] Destination persistence schema is established.

class CloudManager: ObservableObject { // [Isolated] Declares observable manager class. | [In-file] Owns destination state, persistence, bookmarks, and move logic.
    static let shared = CloudManager() // Singleton for easy access if needed, but we'll inject via VM // [Isolated] Shared singleton instance. | [In-file] Provides convenient access where DI is not yet wired.

    @Published var destinations: [CloudDestination] = [] // [Isolated] Published destinations array. | [In-file] Drives destination lists and selection UI.
    @Published var activeDestinationId: UUID? // [Isolated] Published active destination id. | [In-file] Tracks which destination is currently selected.

    private let destinationsKey = "savedCloudDestinations" // [Isolated] UserDefaults key string. | [In-file] Stores encoded destinations under a stable key.
    private let activeDestKey = "activeCloudDestinationId" // [Isolated] UserDefaults key string. | [In-file] Stores active destination UUID string under a stable key.
    private let appFolderName = "DesktopDeclutter" // [Isolated] App root folder name constant. | [In-file] Names the per-destination app-managed folder.

    init() { // [Isolated] Initializer. | [In-file] Loads persisted destinations immediately so UI has state.
        loadDestinations() // [Isolated] Calls load routine. | [In-file] Hydrates destinations + active selection from persistence.
    } // [Isolated] Ends init. | [In-file] Manager is ready for use.

    var activeDestination: CloudDestination? { // [Isolated] Computed destination. | [In-file] Returns currently selected destination or a safe fallback.
        guard let id = activeDestinationId else { return destinations.first } // [Isolated] Optional binding with fallback. | [In-file] Defaults to first destination when none selected.
        return destinations.first(where: { $0.id == id }) // [Isolated] Searches by UUID. | [In-file] Resolves active destination model from stored id.
    } // [Isolated] Ends activeDestination. | [In-file] Used by move operations and UI.

    func loadDestinations() { // [Isolated] Loads persisted state. | [In-file] Decodes destinations, applies migrations, and restores active selection.
        if let data = UserDefaults.standard.data(forKey: destinationsKey), // [Isolated] Reads Data from UserDefaults. | [In-file] Retrieves persisted destinations payload.
           let decoded = try? JSONDecoder().decode([CloudDestination].self, from: data) { // [Isolated] Decodes JSON to model array. | [In-file] Reconstructs destinations state.
            destinations = decoded.map { dest in // [Isolated] Maps decoded destinations. | [In-file] Applies provider-specific normalization/migration.
                guard dest.provider == .googleDrive else { return dest } // [Isolated] Early return for non-Google providers. | [In-file] Ensures only Google Drive destinations are normalized.
                if URL(fileURLWithPath: dest.path).lastPathComponent.hasPrefix("GoogleDrive-") { // [Isolated] Detects GoogleDrive account root. | [In-file] Triggers “My Drive” normalization when user picked the account root.
                    let myDrive = URL(fileURLWithPath: dest.path).appendingPathComponent("My Drive", isDirectory: true) // [Isolated] Builds My Drive URL. | [In-file] Redirects operations into the primary drive folder.
                    if FileManager.default.fileExists(atPath: myDrive.path) { // [Isolated] Checks for folder existence. | [In-file] Only normalizes when “My Drive” actually exists.
                        var updated = dest // [Isolated] Creates mutable copy. | [In-file] Allows updating name/path/bookmark while preserving id.
                        updated.name = myDrive.lastPathComponent // [Isolated] Updates display name. | [In-file] Ensures UI reflects the normalized folder.
                        updated.path = myDrive.path // [Isolated] Updates stored path. | [In-file] Makes persistence point at the normalized folder.
                        updated.bookmarkData = createBookmark(for: myDrive) // [Isolated] Recreates bookmark. | [In-file] Ensures bookmark matches the new canonical destination.
                        return updated // [Isolated] Returns migrated destination. | [In-file] Persists normalization result into in-memory list.
                    } // [Isolated] Ends existence check. | [In-file] Falls through when “My Drive” not found.
                } // [Isolated] Ends account-root check. | [In-file] Returns dest unchanged when not an account root.
                return dest // [Isolated] Default return. | [In-file] Keeps destination unchanged when normalization is not applicable.
            }.map { sanitizeBookmarkIfNeeded(for: $0) } // [Isolated] Sanitizes each destination bookmark. | [In-file] Prevents repeated failures from invalid/legacy bookmark data.
        } // [Isolated] Ends decode block. | [In-file] Destinations state restored when data exists.

        if let idString = UserDefaults.standard.string(forKey: activeDestKey), // [Isolated] Reads UUID string. | [In-file] Retrieves persisted active destination selection.
           let id = UUID(uuidString: idString) { // [Isolated] Parses UUID from string. | [In-file] Converts persisted selection back into a UUID.
            activeDestinationId = id // [Isolated] Assigns active id. | [In-file] Restores active destination selection for UI + moves.
        } // [Isolated] Ends active id restore. | [In-file] Leaves nil when no persisted selection.

        saveDestinations() // [Isolated] Persists current state. | [In-file] Writes back after migrations/sanitization to keep stored data clean.
    } // [Isolated] Ends loadDestinations. | [In-file] State hydration complete.

    func saveDestinations() { // [Isolated] Saves current state. | [In-file] Encodes destinations + active selection into UserDefaults.
        if let encoded = try? JSONEncoder().encode(destinations) { // [Isolated] Encodes model array to JSON Data. | [In-file] Prepares destinations for persistence.
            UserDefaults.standard.set(encoded, forKey: destinationsKey) // [Isolated] Writes data to defaults. | [In-file] Persists destinations across launches.
        } // [Isolated] Ends encode/write. | [In-file] Skips write on encoding failure.
        if let id = activeDestinationId { // [Isolated] Optional binding. | [In-file] Only persist active selection when non-nil.
            UserDefaults.standard.set(id.uuidString, forKey: activeDestKey) // [Isolated] Writes UUID string. | [In-file] Persists active selection across launches.
        } // [Isolated] Ends active selection save. | [In-file] Leaves previous value when nil.
    } // [Isolated] Ends saveDestinations. | [In-file] Persistence is updated.

    func addDestination(name: String, url: URL, provider: CloudProvider) { // [Isolated] Adds destination API. | [In-file] Called when user selects a new cloud folder.
        // Create security scoped bookmark
        let bookmark = createBookmark(for: url) // [Isolated] Creates bookmark data. | [In-file] Enables sandbox access to this destination across launches.

        let newDest = CloudDestination(name: name, path: url.path, bookmarkData: bookmark, provider: provider) // [Isolated] Constructs destination model. | [In-file] Packages destination metadata for persistence/UI.
        destinations.append(newDest) // [Isolated] Appends to array. | [In-file] Updates published state so UI lists refresh.

        if destinations.count == 1 { // [Isolated] First-item check. | [In-file] Auto-selects the first destination for convenience.
            activeDestinationId = newDest.id // [Isolated] Sets active id. | [In-file] Ensures subsequent moves have a default destination.
        } // [Isolated] Ends first-item check. | [In-file] No-op for subsequent destinations.

        saveDestinations() // [Isolated] Persists changes. | [In-file] Stores updated destinations + selection.
    } // [Isolated] Ends addDestination. | [In-file] New destination is recorded.

    func isValidCloudDirectory(_ url: URL) -> CloudProvider? { // [Isolated] Classifies a URL. | [In-file] Determines whether a chosen folder is a recognized cloud root and returns its provider.
        let path = url.path // [Isolated] Extracts path string. | [In-file] Used for substring checks against known cloud mount locations.
        let lowercased = path.lowercased() // [Isolated] Lowercases string. | [In-file] Makes path checks case-insensitive.
        if lowercased.contains("/library/mobile documents/") { // [Isolated] Checks iCloud mount substring. | [In-file] Heuristically identifies iCloud Drive paths.
            return .iCloud // [Isolated] Returns iCloud provider. | [In-file] Flags selection as iCloud Drive.
        } // [Isolated] Ends iCloud check. | [In-file] Continues to CloudStorage checks.
        if lowercased.contains("/library/cloudstorage/") { // [Isolated] Checks CloudStorage mount substring. | [In-file] Recognizes common mount root for third-party providers.
            if lowercased.contains("googledrive") || lowercased.contains("google drive") { // [Isolated] Checks Google Drive markers. | [In-file] Distinguishes Google Drive mounts from other CloudStorage providers.
                return .googleDrive // [Isolated] Returns Google Drive provider. | [In-file] Enables Google Drive–specific normalization elsewhere.
            } // [Isolated] Ends Google Drive marker check. | [In-file] Treats other CloudStorage providers as custom.
            return .custom // [Isolated] Returns custom provider. | [In-file] Allows non-Google CloudStorage folders to be used as destinations.
        } // [Isolated] Ends CloudStorage check. | [In-file] Falls through when not a recognized cloud mount.
        return nil // [Isolated] Indicates invalid/unrecognized folder. | [In-file] Prevents using unsupported locations as “cloud destinations”.
    } // [Isolated] Ends isValidCloudDirectory. | [In-file] Used as a selection validator/classifier.

    func canonicalCloudURL(for url: URL, provider: CloudProvider) -> URL? { // [Isolated] Canonicalizes a URL. | [In-file] Normalizes provider-specific selections (notably Google Drive “My Drive”).
        switch provider { // [Isolated] Switch on provider. | [In-file] Runs only the normalization rules relevant to the provider.
        case .googleDrive: // [Isolated] Google Drive branch. | [In-file] Applies account-root normalization to “My Drive” when appropriate.
            let path = url.path // [Isolated] Extracts path string. | [In-file] Supports string-based checks for known mount patterns.
            let lowercased = path.lowercased() // [Isolated] Lowercases string. | [In-file] Ensures robust comparison regardless of filesystem casing.
            if lowercased.hasSuffix("/library/cloudstorage") { // [Isolated] Detects CloudStorage root selection. | [In-file] Allows selecting the container root without modification.
                return url // [Isolated] Returns input URL. | [In-file] Leaves selection unchanged.
            } // [Isolated] Ends suffix check. | [In-file] Continues to subpath normalization.
            if lowercased.contains("/library/cloudstorage/") { // [Isolated] Detects selection under CloudStorage. | [In-file] Restricts special behavior to typical cloud mount locations.
                // If user selected the account root, force My Drive
                if url.lastPathComponent.hasPrefix("GoogleDrive-") { // [Isolated] Detects account-root folder. | [In-file] Avoids using the provider root and targets the drive content folder.
                    let myDrive = url.appendingPathComponent("My Drive", isDirectory: true) // [Isolated] Appends “My Drive”. | [In-file] Redirects to the canonical content folder.
                    return myDrive // [Isolated] Returns normalized URL. | [In-file] Ensures downstream operations act inside “My Drive”.
                } // [Isolated] Ends account-root check. | [In-file] Leaves other folders unchanged.
                return url // [Isolated] Returns input URL. | [In-file] Uses user-selected folder when it is not the account root.
            } // [Isolated] Ends CloudStorage containment check. | [In-file] Falls through to returning URL unchanged.
            return url // [Isolated] Default return. | [In-file] Keeps URL unchanged for non-standard Google Drive paths.
        default: // [Isolated] Non-Google providers. | [In-file] Currently no canonicalization is needed.
            return url // [Isolated] Returns input URL. | [In-file] Leaves iCloud/custom selections unchanged.
        } // [Isolated] Ends switch. | [In-file] Guarantees a return value.
    } // [Isolated] Ends canonicalCloudURL. | [In-file] Used when storing/normalizing selections.

    func destinationDisplayName(_ destination: CloudDestination) -> String { // [Isolated] Formats a label string. | [In-file] Produces a user-facing destination name, including Google Drive account identifier when available.
        switch destination.provider { // [Isolated] Switch on provider. | [In-file] Applies provider-specific display formatting.
        case .googleDrive: // [Isolated] Google Drive display. | [In-file] Attempts to show a stable account identifier alongside the folder name.
            let pathComponents = URL(fileURLWithPath: destination.path).pathComponents // [Isolated] Splits path into components. | [In-file] Locates the `GoogleDrive-*` component if present.
            if let accountComponent = pathComponents.first(where: { $0.hasPrefix("GoogleDrive-") }) { // [Isolated] Searches for account root component. | [In-file] Extracts an account identifier for display.
                let account = accountComponent.replacingOccurrences(of: "GoogleDrive-", with: "") // [Isolated] Strips prefix. | [In-file] Shortens the account id for UI.
                return "\(destination.name) — \(account)" // [Isolated] Builds display string. | [In-file] Shows folder name + account id in a single label.
            } // [Isolated] Ends account component check. | [In-file] Falls back when not found.
            return destination.name // [Isolated] Returns stored name. | [In-file] Uses the destination name when account id cannot be derived.
        case .iCloud: // [Isolated] iCloud display. | [In-file] Standardizes iCloud label regardless of folder naming.
            return "iCloud Drive" // [Isolated] Returns fixed label. | [In-file] Keeps UI consistent for iCloud destinations.
        case .custom: // [Isolated] Custom display. | [In-file] Uses caller-provided name for arbitrary destinations.
            return destination.name // [Isolated] Returns stored name. | [In-file] Displays the custom destination label.
        } // [Isolated] Ends switch. | [In-file] Guarantees a label for each provider.
    } // [Isolated] Ends destinationDisplayName. | [In-file] Used in destination lists and selection UI.

    func findDestination(matching url: URL) -> CloudDestination? { // [Isolated] Finds a destination for a URL. | [In-file] Maps an arbitrary URL to a saved destination by prefix matching.
        let path = url.standardizedFileURL.path // [Isolated] Standardizes URL then gets path. | [In-file] Ensures stable comparisons against stored destination paths.
        return destinations.first(where: { dest in // [Isolated] Finds first match. | [In-file] Chooses the first destination containing this path.
            let destPath = URL(fileURLWithPath: dest.path).standardizedFileURL.path // [Isolated] Standardizes destination path. | [In-file] Prevents mismatch due to path normalization differences.
            return path == destPath || path.hasPrefix(destPath + "/") // [Isolated] Exact/prefix match. | [In-file] Treats URLs inside a destination as belonging to that destination.
        }) // [Isolated] Ends search closure. | [In-file] Returns nil when no destination matches.
    } // [Isolated] Ends findDestination. | [In-file] Useful for attributing paths to saved destinations.

    func appRootURL(in destinationURL: URL) throws -> URL { // [Isolated] Computes/creates app root folder. | [In-file] Ensures `DesktopDeclutter` exists inside the destination.
        let appFolderURL = destinationURL.appendingPathComponent(appFolderName, isDirectory: true) // [Isolated] Appends app folder name. | [In-file] Targets the app-managed subfolder within destination.
        try FileManager.default.createDirectory(at: appFolderURL, withIntermediateDirectories: true) // [Isolated] Creates directory if needed. | [In-file] Ensures the app root exists for safe file placement.
        return appFolderURL // [Isolated] Returns app root URL. | [In-file] Used as the base for subsequent subfolder organization.
    } // [Isolated] Ends appRootURL. | [In-file] App root is guaranteed to exist on success.

    func validateDestinationWritable(_ url: URL) -> Result<Void, Error> { // [Isolated] Validates writability. | [In-file] Preflights sandbox access and directory creation for a destination.
        let accessing = url.startAccessingSecurityScopedResource() // [Isolated] Starts security scope access. | [In-file] Grants temporary sandbox permission for filesystem operations.
        defer { // [Isolated] Defers cleanup. | [In-file] Ensures security scope is ended no matter how the function exits.
            if accessing { // [Isolated] Checks access flag. | [In-file] Only stops access when it was successfully started.
                url.stopAccessingSecurityScopedResource() // [Isolated] Stops security scope access. | [In-file] Prevents leaking security-scoped resource usage.
            } // [Isolated] Ends access check. | [In-file] Cleanup complete.
        } // [Isolated] Ends defer. | [In-file] Cleanup is guaranteed.
        do { // [Isolated] Begins throwing work block. | [In-file] Attempts a write-capable operation to validate permissions.
            _ = try appRootURL(in: url) // [Isolated] Ensures app root directory exists. | [In-file] Fails when destination is not writable/accessible.
            return .success(()) // [Isolated] Returns success Result. | [In-file] Signals destination is usable.
        } catch { // [Isolated] Catches thrown error. | [In-file] Converts failures into a Result for caller-friendly handling.
            return .failure(error) // [Isolated] Returns failure Result. | [In-file] Surfaces filesystem/permission error to UI.
        } // [Isolated] Ends do/catch. | [In-file] Writability verdict produced.
    } // [Isolated] Ends validateDestinationWritable. | [In-file] Used to validate user-chosen destinations.

    func removeDestination(id: UUID) { // [Isolated] Removes a destination by id. | [In-file] Updates list and active selection when a destination is deleted.
        destinations.removeAll { $0.id == id } // [Isolated] Removes matching elements. | [In-file] Deletes the destination from persisted state.
        if activeDestinationId == id { // [Isolated] Checks if removed was active. | [In-file] Ensures active selection remains valid.
            activeDestinationId = destinations.first?.id // [Isolated] Falls back to first destination id. | [In-file] Keeps an active destination when possible.
        } // [Isolated] Ends active check. | [In-file] Active selection corrected if needed.
        saveDestinations() // [Isolated] Persists removal. | [In-file] Updates UserDefaults to reflect deletion.
    } // [Isolated] Ends removeDestination. | [In-file] Destination removal complete.

    func setActive(_ id: UUID) { // [Isolated] Sets active destination. | [In-file] Called when UI selects a destination.
        activeDestinationId = id // [Isolated] Assigns active id. | [In-file] Updates selection used by move operations.
        saveDestinations() // [Isolated] Persists selection. | [In-file] Stores new active destination to UserDefaults.
    } // [Isolated] Ends setActive. | [In-file] Active destination selection updated.

    private func uniqueURL(for url: URL, fileManager: FileManager) -> URL { // [Isolated] Creates non-colliding URL. | [In-file] Prevents overwriting existing files by suffixing a counter.
        if !fileManager.fileExists(atPath: url.path) { // [Isolated] Existence check. | [In-file] Uses original URL when no conflict exists.
            return url // [Isolated] Returns original URL. | [In-file] No rename needed.
        } // [Isolated] Ends conflict-free branch. | [In-file] Continues to collision resolution.

        let ext = url.pathExtension // [Isolated] Extracts extension. | [In-file] Preserves file type during renaming.
        let base = url.deletingPathExtension().lastPathComponent // [Isolated] Extracts base filename. | [In-file] Forms the stem for unique naming.
        let parent = url.deletingLastPathComponent() // [Isolated] Extracts parent directory. | [In-file] Places the renamed file alongside the target.
        var counter = 2 // [Isolated] Initializes counter. | [In-file] Starts naming at “ 2” to match common OS duplication style.

        while true { // [Isolated] Infinite loop until unique found. | [In-file] Iterates candidate names until an available filename is discovered.
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)" // [Isolated] Builds candidate filename. | [In-file] Preserves extension when present.
            let candidate = parent.appendingPathComponent(name) // [Isolated] Constructs candidate URL. | [In-file] Points to next possible unique path.
            if !fileManager.fileExists(atPath: candidate.path) { // [Isolated] Checks if candidate exists. | [In-file] Accepts the first unused name.
                return candidate // [Isolated] Returns unique URL. | [In-file] Ensures subsequent write won’t overwrite.
            } // [Isolated] Ends candidate check. | [In-file] Continues when conflict persists.
            counter += 1 // [Isolated] Increments counter. | [In-file] Tries the next suffix value.
        } // [Isolated] Ends loop. | [In-file] Always returns from inside when unique found.
    } // [Isolated] Ends uniqueURL. | [In-file] Used by move logic to avoid collisions.

    private func targetFolderURL(destinationURL: URL, sourceFolderName: String?) throws -> URL { // [Isolated] Computes/creates target folder. | [In-file] Organizes files under app root and optional source folder subfolder.
        let appRoot = try appRootURL(in: destinationURL) // [Isolated] Ensures app root exists. | [In-file] Provides base folder for app-managed placement.
        let safeSourceName = (sourceFolderName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) // [Isolated] Validates non-empty string. | [In-file] Avoids creating empty-named folders.
            ? sourceFolderName! // [Isolated] Uses unwrapped source folder name. | [In-file] Groups moved files under the source folder’s label.
            : "Unsorted" // [Isolated] Fallback folder name. | [In-file] Provides a stable default grouping.
        let targetFolder = appRoot.appendingPathComponent(safeSourceName, isDirectory: true) // [Isolated] Appends grouping folder. | [In-file] Creates per-source organization beneath app root.
        try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true) // [Isolated] Creates directory if missing. | [In-file] Ensures the grouping folder exists.
        return targetFolder // [Isolated] Returns target folder URL. | [In-file] Used as destination directory for file moves.
    } // [Isolated] Ends targetFolderURL. | [In-file] Grouping folder is guaranteed to exist on success.

    private func createBookmark(for url: URL) -> Data? { // [Isolated] Creates security-scoped bookmark data. | [In-file] Enables persistent sandbox access to a user-selected folder.
        do { // [Isolated] Begins bookmark creation attempt. | [In-file] Uses throwing API to generate bookmark payload.
            return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) // [Isolated] Generates bookmark data. | [In-file] Stores security-scoped bookmark for later resolution.
        } catch { // [Isolated] Catches errors. | [In-file] Falls back to nil when bookmark creation fails.
            print("Failed to create bookmark: \(error)") // [Isolated] Logs error. | [In-file] Helps diagnose sandbox/bookmark failures during development.
            return nil // [Isolated] Returns nil bookmark. | [In-file] Allows callers to proceed with path-only fallback.
        } // [Isolated] Ends do/catch. | [In-file] Bookmark creation result produced.
    } // [Isolated] Ends createBookmark. | [In-file] Used when adding/migrating destinations.

    private func sanitizeBookmarkIfNeeded(for destination: CloudDestination) -> CloudDestination { // [Isolated] Sanitizes bookmark payload. | [In-file] Clears invalid/legacy bookmarkData that fails resolution.
        guard let data = destination.bookmarkData else { // [Isolated] Optional binding guard. | [In-file] Skips sanitization when no bookmark exists.
            return destination // [Isolated] Returns unchanged destination. | [In-file] No bookmark means nothing to validate.
        } // [Isolated] Ends guard. | [In-file] Continues only when bookmark data exists.

        var isStale = false // [Isolated] Initializes stale flag. | [In-file] Required out-parameter for bookmark resolution API.
        do { // [Isolated] Begins resolution attempt. | [In-file] Validates that bookmark data can be resolved to a URL.
            _ = try URL( // [Isolated] Resolves bookmark into URL. | [In-file] Confirms bookmark payload is structurally valid.
                resolvingBookmarkData: data, // [Isolated] Supplies bookmark data. | [In-file] Uses persisted security-scoped token.
                options: [.withSecurityScope, .withoutUI], // [Isolated] Sets resolution options. | [In-file] Requests security scope without prompting the user.
                relativeTo: nil, // [Isolated] Uses no relative base. | [In-file] Treats bookmark as absolute.
                bookmarkDataIsStale: &isStale // [Isolated] Receives stale status. | [In-file] Allows caller to refresh stale bookmarks later.
            ) // [Isolated] Ends URL init. | [In-file] Resolution success implies bookmark is valid.
            return destination // [Isolated] Returns unchanged destination. | [In-file] Keeps bookmark data when it resolves successfully.
        } catch { // [Isolated] Catches resolution error. | [In-file] Handles invalid/legacy bookmarks (often NSCocoaErrorDomain 259).
            // Migration path for old/invalid bookmark payloads (commonly NSCocoaErrorDomain 259).
            var updated = destination // [Isolated] Creates mutable copy. | [In-file] Allows clearing the invalid bookmark while preserving other fields.
            updated.bookmarkData = nil // [Isolated] Clears bookmark. | [In-file] Prevents repeated resolution failures on future loads.
            return updated // [Isolated] Returns sanitized destination. | [In-file] Stores a clean destination back to persistence.
        } // [Isolated] Ends do/catch. | [In-file] Sanitization decision complete.
    } // [Isolated] Ends sanitizeBookmarkIfNeeded. | [In-file] Applied during load migrations.

    func resolvedURL(for destination: CloudDestination) -> URL? { // [Isolated] Resolves destination to URL. | [In-file] Converts persisted destination (path + bookmark) into an accessible URL for file operations.
        guard let index = destinations.firstIndex(where: { $0.id == destination.id }) else { // [Isolated] Finds destination index. | [In-file] Ensures we can update stored bookmark data if needed.
            return URL(fileURLWithPath: destination.path) // [Isolated] Falls back to path URL. | [In-file] Provides best-effort access when destination isn’t in current list.
        } // [Isolated] Ends guard. | [In-file] Continues only when destination is in list.

        var updatedDestination = destinations[index] // [Isolated] Copies stored destination. | [In-file] Allows mutation (stale refresh / invalid clear) before persisting.
        if let data = updatedDestination.bookmarkData { // [Isolated] Optional binding. | [In-file] Attempts bookmark resolution when bookmarkData exists.
            var isStale = false // [Isolated] Initializes stale flag. | [In-file] Receives stale status from resolution API.
            do { // [Isolated] Begins resolution attempt. | [In-file] Resolves bookmark into a security-scoped URL.
                let resolved = try URL( // [Isolated] Resolves bookmark. | [In-file] Produces URL with security scope capabilities.
                    resolvingBookmarkData: data, // [Isolated] Supplies bookmark data. | [In-file] Uses persisted access token.
                    options: [.withSecurityScope, .withoutUI], // [Isolated] Sets resolution options. | [In-file] Avoids UI prompts while requesting security scope.
                    relativeTo: nil, // [Isolated] Uses no base URL. | [In-file] Treats bookmark as absolute.
                    bookmarkDataIsStale: &isStale // [Isolated] Receives stale flag. | [In-file] Enables refreshing stale bookmarks to keep access reliable.
                ) // [Isolated] Ends resolution init. | [In-file] Bookmark resolved.
                if isStale, let refreshed = createBookmark(for: resolved) { // [Isolated] Checks staleness and refresh availability. | [In-file] Rebuilds bookmark payload so future launches resolve cleanly.
                    updatedDestination.bookmarkData = refreshed // [Isolated] Updates bookmarkData. | [In-file] Stores refreshed security token.
                    destinations[index] = updatedDestination // [Isolated] Writes updated model back. | [In-file] Keeps in-memory list consistent.
                    saveDestinations() // [Isolated] Persists refreshed bookmark. | [In-file] Saves updated bookmark to UserDefaults.
                } // [Isolated] Ends stale refresh. | [In-file] Bookmark is up-to-date after this.
                return resolved // [Isolated] Returns resolved URL. | [In-file] Caller can now access destination via security scope.
            } catch { // [Isolated] Catches resolution error. | [In-file] Clears invalid bookmark and attempts to recreate from path.
                updatedDestination.bookmarkData = nil // [Isolated] Clears bookmarkData. | [In-file] Prevents repeated failures from corrupted bookmark payload.
                let fallbackURL = URL(fileURLWithPath: updatedDestination.path) // [Isolated] Builds path-based URL. | [In-file] Uses stored filesystem path as a fallback.
                if let refreshed = createBookmark(for: fallbackURL) { // [Isolated] Attempts bookmark recreation. | [In-file] Restores security-scoped access when path remains valid.
                    updatedDestination.bookmarkData = refreshed // [Isolated] Stores recreated bookmark. | [In-file] Re-enables future security-scoped resolution.
                } // [Isolated] Ends bookmark recreation. | [In-file] Bookmark may be restored if folder is still accessible.
                destinations[index] = updatedDestination // [Isolated] Updates destinations list. | [In-file] Keeps in-memory state aligned with bookmark changes.
                saveDestinations() // [Isolated] Persists changes. | [In-file] Updates stored destinations so next launch uses sanitized/updated bookmark.
            } // [Isolated] Ends catch. | [In-file] Falls through to return below.
        } // [Isolated] Ends bookmarkData optional binding. | [In-file] Falls back when no bookmark.

        return URL(fileURLWithPath: updatedDestination.path) // [Isolated] Returns path-based URL. | [In-file] Provides access when bookmark is absent.
    } // [Isolated] Ends resolvedURL(for:). | [In-file] Central URL resolver used by move logic.

    func resolvedURL(for destinationId: UUID?) -> URL? { // [Isolated] Resolves destination by id. | [In-file] Convenience wrapper used when only an id is available.
        guard let destinationId else { return nil } // [Isolated] Nil guard. | [In-file] Avoids work when no id exists.
        guard let destination = destinations.first(where: { $0.id == destinationId }) else { return nil } // [Isolated] Looks up destination. | [In-file] Returns nil when id doesn’t match any saved destination.
        return resolvedURL(for: destination) // [Isolated] Delegates to main resolver. | [In-file] Reuses bookmark/path resolution logic.
    } // [Isolated] Ends resolvedURL(for: UUID?). | [In-file] Simplifies call sites.

    // Safer Move Logic: Copy + Remove
    func moveFileToCloud(_ file: DesktopFile, sourceFolderName: String?, destination: CloudDestination? = nil, completion: @escaping (Result<URL, Error>) -> Void) { // [Isolated] Moves a file to a destination. | [In-file] Copies the file into the destination folder then removes the original.
        let resolvedDestination = destination ?? activeDestination // [Isolated] Chooses explicit or active destination. | [In-file] Allows callers to override the active destination.
        guard let dest = resolvedDestination else { // [Isolated] Guards against missing destination. | [In-file] Prevents move attempts when no destination is selected.
            completion(.failure(NSError(domain: "CloudManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active cloud destination"]))) // [Isolated] Returns an NSError. | [In-file] Surfaces missing-destination error to caller.
            return // [Isolated] Exits early. | [In-file] Stops execution after reporting error.
        } // [Isolated] Ends destination guard. | [In-file] Continues with a valid destination.

        guard let destURL = resolvedURL(for: dest) else { // [Isolated] Guards against invalid URL. | [In-file] Ensures destination can be resolved for file operations.
            completion(.failure(NSError(domain: "CloudManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid destination URL"]))) // [Isolated] Returns an NSError. | [In-file] Reports resolution failure.
            return // [Isolated] Exits early. | [In-file] Stops execution after reporting error.
        } // [Isolated] Ends URL guard. | [In-file] Continues with resolved destination URL.

        // Start accessing security scoped resource
        let accessing = destURL.startAccessingSecurityScopedResource() // [Isolated] Starts security scope. | [In-file] Grants temporary permission to access the destination folder.
        defer { // [Isolated] Defers scope cleanup. | [In-file] Ensures we always stop accessing the security-scoped resource.
            if accessing { // [Isolated] Checks access flag. | [In-file] Only stops access when it was successfully started.
                destURL.stopAccessingSecurityScopedResource() // [Isolated] Stops security scope. | [In-file] Avoids leaking security-scoped access.
            } // [Isolated] Ends access check. | [In-file] Cleanup complete.
        } // [Isolated] Ends defer. | [In-file] Scope cleanup guaranteed.

        let fileManager = FileManager.default // [Isolated] Grabs FileManager singleton. | [In-file] Executes copy/remove and directory operations.

        do { // [Isolated] Begins throwing work block. | [In-file] Performs folder creation and file copy/remove steps.
            let targetFolder = try targetFolderURL(destinationURL: destURL, sourceFolderName: sourceFolderName) // [Isolated] Computes target folder. | [In-file] Ensures destination app root + grouping subfolder exist.
            let initialTargetURL = targetFolder.appendingPathComponent(file.name) // [Isolated] Builds initial target URL. | [In-file] Uses the file’s current name in the destination folder.
            let targetURL = uniqueURL(for: initialTargetURL, fileManager: fileManager) // [Isolated] Resolves collisions. | [In-file] Avoids overwriting by generating a unique filename when needed.

            // Try COPY then REMOVE
            try fileManager.copyItem(at: file.url, to: targetURL) // [Isolated] Copies the file. | [In-file] Places a duplicate at the destination path.
            try fileManager.removeItem(at: file.url) // [Isolated] Removes original file. | [In-file] Completes the “move” after successful copy.

            completion(.success(targetURL)) // [Isolated] Calls completion with success. | [In-file] Returns the destination URL for downstream UI/logic.
        } catch { // [Isolated] Catches thrown error. | [In-file] Reports filesystem failures to caller.
            print("Cloud Move Error: \(error)") // [Isolated] Logs error. | [In-file] Helps diagnose failures during development.
            completion(.failure(error)) // [Isolated] Calls completion with failure. | [In-file] Surfaces error so UI can present feedback.
        } // [Isolated] Ends do/catch. | [In-file] Move result determined.
    } // [Isolated] Ends moveFileToCloud. | [In-file] Primary move API for cloud destinations.
} // [Isolated] Ends CloudManager. | [In-file] Cloud destination state and operations are fully defined.

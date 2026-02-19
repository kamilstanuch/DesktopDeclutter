//  FileScanner.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  Scans the selected folder (defaulting to Desktop) to produce `[DesktopFile]` models with metadata (name, size, fileType) and an icon. // [Isolated] Purpose description | [In-file] File purpose
//  Computes folder sizes by recursively enumerating contents while skipping symlinks. // [Isolated] Purpose description | [In-file] File purpose
//  Generates thumbnails for non-folder files using QuickLookThumbnailing. // [Isolated] Purpose description | [In-file] File purpose
//
//  Unique characteristics
//  ----------------------
//  - Uses a private `folderURL` that can be overridden via `useCustomURL`. // [Isolated] Unique characteristic | [In-file] File characteristic
//  - Uses `URLResourceValues` keys to fetch size/type/name efficiently. // [Isolated] Unique characteristic | [In-file] File characteristic
//  - Computes directory size via `FileManager.enumerator` and skips hidden files and symlink descendants. // [Isolated] Unique characteristic | [In-file] File characteristic
//  - Sorts results with folders first, then case-insensitive name ordering. // [Isolated] Unique characteristic | [In-file] File characteristic
//  - Uses Quick Look thumbnail generation with error filtering for expected "thumbnail miss" cases. // [Isolated] Unique characteristic | [In-file] File characteristic
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  Foundation: https://developer.apple.com/documentation/foundation // [Isolated] External doc | [In-file] Foundation
//    - FileManager: https://developer.apple.com/documentation/foundation/filemanager // [Isolated] External doc | [In-file] FileManager
//    - URL: https://developer.apple.com/documentation/foundation/url // [Isolated] External doc | [In-file] URL
//    - URLResourceKey: https://developer.apple.com/documentation/foundation/urlresourcekey // [Isolated] External doc | [In-file] URLResourceKey
//    - URLResourceValues: https://developer.apple.com/documentation/foundation/urlresourcevalues // [Isolated] External doc | [In-file] URLResourceValues
//  AppKit: https://developer.apple.com/documentation/appkit // [Isolated] External doc | [In-file] AppKit
//    - NSWorkspace: https://developer.apple.com/documentation/appkit/nsworkspace // [Isolated] External doc | [In-file] NSWorkspace
//    - NSImage: https://developer.apple.com/documentation/appkit/nsimage // [Isolated] External doc | [In-file] NSImage
//    - NSScreen: https://developer.apple.com/documentation/appkit/nsscreen // [Isolated] External doc | [In-file] NSScreen
//  QuickLookThumbnailing: // [Isolated] External doc | [In-file] QuickLookThumbnailing
//    - https://developer.apple.com/documentation/quicklookthumbnailing // [Isolated] External doc | [In-file] QuickLookThumbnailing
//    - QLThumbnailGenerator: https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailgenerator // [Isolated] External doc | [In-file] QLThumbnailGenerator
//    - QLThumbnailGenerator.Request: https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailgenerator/request // [Isolated] External doc | [In-file] QLThumbnailGenerator.Request
//    - QLThumbnailErrorDomain (constant): https://developer.apple.com/documentation/quicklookthumbnailing // [Isolated] External doc | [In-file] QLThumbnailErrorDomain
//  CoreGraphics CGSize: // [Isolated] External doc | [In-file] CoreGraphics CGSize
//    - CGSize: https://developer.apple.com/documentation/coregraphics/cgsize // [Isolated] External doc | [In-file] CGSize
//
//  NOTE: Internal project types referenced:
//  - DesktopFile, FileType // [Isolated] Internal types | [In-file] Internal references

import AppKit // [Isolated] Import AppKit framework | [In-file] Framework import
import Foundation // [Isolated] Import Foundation framework | [In-file] Framework import
import QuickLookThumbnailing // [Isolated] Import QuickLookThumbnailing framework | [In-file] Framework import

class FileScanner { // [Isolated] FileScanner class declaration | [In-file] Class declaration
    static let shared = FileScanner() // [Isolated] Singleton instance | [In-file] Singleton pattern

    private var folderURL: URL // [Isolated] Private folder URL to scan | [In-file] Folder URL storage
    private let fileManager = FileManager.default // [Isolated] FileManager default instance | [In-file] FileManager usage

    private init() { // [Isolated] Private initializer | [In-file] Initialization
        if let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first { // [Isolated] Attempt to get Desktop directory URL | [In-file] Initialization logic
            self.folderURL = desktopURL // [Isolated] Set folderURL to Desktop | [In-file] Initialization logic
        } else {
            self.folderURL = fileManager.homeDirectoryForCurrentUser // [Isolated] Fallback to home directory | [In-file] Initialization logic
        }
    }

    func useCustomURL(_ url: URL) { // [Isolated] Method to override folderURL | [In-file] Custom URL setter
        folderURL = url // [Isolated] Set folderURL to provided URL | [In-file] Custom URL setter
    }

    func scanCurrentFolder() throws -> [DesktopFile] { // [Isolated] Scan folder and return DesktopFile array | [In-file] Scanning method
        let resourceKeys: Set<URLResourceKey> = [ // [Isolated] Define resource keys to fetch | [In-file] Resource keys
            .isDirectoryKey, // [Isolated] Directory flag | [In-file] Resource keys
            .fileSizeKey, // [Isolated] File size | [In-file] Resource keys
            .fileAllocatedSizeKey, // [Isolated] Allocated file size | [In-file] Resource keys
            .totalFileAllocatedSizeKey, // [Isolated] Total allocated size | [In-file] Resource keys
            .nameKey // [Isolated] File name | [In-file] Resource keys
        ]

        let urls = try fileManager.contentsOfDirectory( // [Isolated] Get URLs in folder | [In-file] Directory contents fetch
            at: folderURL, // [Isolated] Target folder URL | [In-file] Directory contents fetch
            includingPropertiesForKeys: Array(resourceKeys), // [Isolated] Request resource keys | [In-file] Directory contents fetch
            options: [.skipsHiddenFiles] // [Isolated] Skip hidden files | [In-file] Directory contents fetch
        )

        let files: [DesktopFile] = urls.compactMap { url in // [Isolated] Map URLs to DesktopFile objects | [In-file] Mapping to model
            do {
                let values = try url.resourceValues(forKeys: resourceKeys) // [Isolated] Fetch resource values | [In-file] Resource fetching
                let isDirectory = values.isDirectory ?? false // [Isolated] Determine if directory | [In-file] Resource processing
                let size = itemSize(for: url, values: values, isDirectory: isDirectory) // [Isolated] Calculate item size | [In-file] Size calculation
                let name = values.name ?? url.lastPathComponent // [Isolated] Get name or fallback | [In-file] Name determination
                let fileType = FileType.classify(url: url, isDirectory: isDirectory) // [Isolated] Classify file type | [In-file] FileType classification
                let icon = NSWorkspace.shared.icon(forFile: url.path) // [Isolated] Get icon for file | [In-file] Icon retrieval
                return DesktopFile(url: url, name: name, fileSize: size, fileType: fileType, icon: icon, thumbnail: nil) // [Isolated] Create DesktopFile | [In-file] Model creation
            } catch {
                return nil // [Isolated] Skip file on error | [In-file] Error handling
            }
        }

        return files.sorted { // [Isolated] Sort files with folders first then by name | [In-file] Sorting results
            if $0.fileType == .folder && $1.fileType != .folder { return true } // [Isolated] Folder before non-folder | [In-file] Sorting logic
            if $0.fileType != .folder && $1.fileType == .folder { return false } // [Isolated] Non-folder after folder | [In-file] Sorting logic
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending // [Isolated] Case-insensitive name sort | [In-file] Sorting logic
        }
    }

    private func itemSize(for url: URL, values: URLResourceValues, isDirectory: Bool) -> Int64 { // [Isolated] Calculate size for item | [In-file] Size helper
        if isDirectory { // [Isolated] If folder, compute directory size | [In-file] Size helper
            return directorySize(at: url) // [Isolated] Directory size calculation | [In-file] Size helper
        }

        if let allocated = values.totalFileAllocatedSize ?? values.fileAllocatedSize { // [Isolated] Use allocated size if available | [In-file] Size helper
            return Int64(allocated) // [Isolated] Return allocated size | [In-file] Size helper
        }

        return Int64(values.fileSize ?? 0) // [Isolated] Fallback to file size | [In-file] Size helper
    }

    private func directorySize(at directoryURL: URL) -> Int64 { // [Isolated] Recursively compute directory size | [In-file] Directory size helper
        let keys: Set<URLResourceKey> = [ // [Isolated] Resource keys for enumeration | [In-file] Enumeration keys
            .isDirectoryKey, // [Isolated] Directory flag | [In-file] Enumeration keys
            .isSymbolicLinkKey, // [Isolated] Symlink flag | [In-file] Enumeration keys
            .fileSizeKey, // [Isolated] File size | [In-file] Enumeration keys
            .fileAllocatedSizeKey, // [Isolated] Allocated size | [In-file] Enumeration keys
            .totalFileAllocatedSizeKey // [Isolated] Total allocated size | [In-file] Enumeration keys
        ]

        guard let enumerator = fileManager.enumerator( // [Isolated] Create enumerator for directory | [In-file] Directory enumeration
            at: directoryURL, // [Isolated] Target directory URL | [In-file] Directory enumeration
            includingPropertiesForKeys: Array(keys), // [Isolated] Request resource keys | [In-file] Directory enumeration
            options: [.skipsHiddenFiles], // [Isolated] Skip hidden files | [In-file] Directory enumeration
            errorHandler: { _, _ in true } // [Isolated] Continue on error | [In-file] Directory enumeration
        ) else {
            return 0 // [Isolated] Return zero if enumerator fails | [In-file] Enumeration failure
        }

        var totalSize: Int64 = 0 // [Isolated] Accumulate total size | [In-file] Size accumulation

        for case let childURL as URL in enumerator { // [Isolated] Iterate over enumerated URLs | [In-file] Enumeration loop
            guard let values = try? childURL.resourceValues(forKeys: keys) else { continue } // [Isolated] Fetch resource values, skip on failure | [In-file] Resource fetching

            if values.isSymbolicLink == true { // [Isolated] Skip symlink descendants | [In-file] Symlink handling
                if values.isDirectory == true { // [Isolated] If symlink is directory, skip descendants | [In-file] Symlink handling
                    enumerator.skipDescendants() // [Isolated] Skip descendants of symlinked directory | [In-file] Symlink handling
                }
                continue // [Isolated] Skip symlink file | [In-file] Symlink handling
            }

            if values.isDirectory == true { // [Isolated] Skip directories (size counted recursively) | [In-file] Directory handling
                continue // [Isolated] Skip directory in enumeration | [In-file] Directory handling
            }

            let fileSize = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0 // [Isolated] Get file size with fallbacks | [In-file] Size extraction
            totalSize += Int64(fileSize) // [Isolated] Add to total size | [In-file] Size accumulation
        }

        return totalSize // [Isolated] Return total directory size | [In-file] Directory size helper
    }

    func generateThumbnail(for file: DesktopFile, completion: @escaping (NSImage?) -> Void) { // [Isolated] Generate thumbnail asynchronously | [In-file] Thumbnail generation
        if file.fileType == .folder { // [Isolated] Do not generate thumbnail for folders | [In-file] Thumbnail generation
            completion(nil) // [Isolated] Return nil for folder thumbnail | [In-file] Thumbnail generation
            return // [Isolated] Early return for folder | [In-file] Thumbnail generation
        }
        let size = CGSize(width: 512, height: 512) // [Isolated] Thumbnail size | [In-file] Thumbnail generation
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0 // [Isolated] Screen scale factor | [In-file] Thumbnail generation
        let request = QLThumbnailGenerator.Request(fileAt: file.url, size: size, scale: scale, representationTypes: .all) // [Isolated] Create thumbnail request | [In-file] Thumbnail generation

        QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, _, error in // [Isolated] Generate thumbnail representations | [In-file] Thumbnail generation
            if let error { // [Isolated] Handle generation error | [In-file] Thumbnail generation error handling
                let nsError = error as NSError // [Isolated] Cast error to NSError | [In-file] Thumbnail generation error handling
                let isExpectedThumbnailMiss = nsError.domain == QLThumbnailErrorDomain && (nsError.code == 2 || nsError.code == 3) // [Isolated] Filter expected thumbnail miss errors | [In-file] Thumbnail generation error filtering
                if !isExpectedThumbnailMiss { // [Isolated] Log unexpected errors | [In-file] Thumbnail generation error filtering
                    print("Thumbnail error for \(file.name): \(error)") // [Isolated] Print error message | [In-file] Thumbnail generation error logging
                }
            }
            if let image = thumbnail?.nsImage { // [Isolated] Pass generated image | [In-file] Thumbnail generation completion
                completion(image) // [Isolated] Call completion with image | [In-file] Thumbnail generation completion
            } else {
                completion(nil) // [Isolated] Call completion with nil if no image | [In-file] Thumbnail generation completion
            }
        }
    }
}

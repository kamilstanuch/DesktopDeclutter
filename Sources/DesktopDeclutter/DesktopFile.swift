//  DesktopFile.swift  // [Isolated] File name header | [In-file] File name header
//  DesktopDeclutter  // [Isolated] Project name header | [In-file] Project name header
//  // [Isolated] Blank comment line | [In-file] Blank comment line
//  Purpose  // [Isolated] Purpose section header | [In-file] Purpose section header
//  -------  // [Isolated] Purpose section underline | [In-file] Purpose section underline
//  Defines the core model `DesktopFile` used throughout the app to represent one file/folder, including metadata (URL/name/size/type), UI imagery (icon/thumbnail), and processing state (`decision`).  // [Isolated] Purpose description | [In-file] Purpose description
//  Unique characteristics  // [Isolated] Unique characteristics section header | [In-file] Unique characteristics section header
//  ----------------------  // [Isolated] Unique characteristics section underline | [In-file] Unique characteristics section underline
//  - Conforms to Identifiable/Equatable/Hashable for SwiftUI lists and set membership.  // [Isolated] Unique characteristic bullet | [In-file] Unique characteristic bullet
//  - Stores both an AppKit `NSImage` icon and optional `thumbnail` for preview-heavy UI.  // [Isolated] Unique characteristic bullet | [In-file] Unique characteristic bullet
//  - Uses `FileType` classification externally and stores the result.  // [Isolated] Unique characteristic bullet | [In-file] Unique characteristic bullet
//  - Supports an optional `FileDecision` (nil = unprocessed) for declutter workflow.  // [Isolated] Unique characteristic bullet | [In-file] Unique characteristic bullet
//  - Contains two initializers (one without decision and one with decision) for ergonomic call sites (keep logic unchanged).  // [Isolated] Unique characteristic bullet | [In-file] Unique characteristic bullet
//  External sources / resources referenced (documentation links)  // [Isolated] External resources section header | [In-file] External resources section header
//  ------------------------------------------------------------  // [Isolated] External resources section underline | [In-file] External resources section underline
//  - Swift language: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/  // [Isolated] External resource bullet | [In-file] External resource bullet
//  - Foundation: https://developer.apple.com/documentation/foundation  // [Isolated] External resource bullet | [In-file] External resource bullet
//    - URL: https://developer.apple.com/documentation/foundation/url  // [Isolated] External resource sub-bullet | [In-file] External resource sub-bullet
//    - UUID: https://developer.apple.com/documentation/foundation/uuid  // [Isolated] External resource sub-bullet | [In-file] External resource sub-bullet
//  - AppKit: https://developer.apple.com/documentation/appkit  // [Isolated] External resource bullet | [In-file] External resource bullet
//    - NSImage: https://developer.apple.com/documentation/appkit/nsimage  // [Isolated] External resource sub-bullet | [In-file] External resource sub-bullet
//  - Swift protocols:  // [Isolated] External resource bullet | [In-file] External resource bullet
//    - Identifiable: https://developer.apple.com/documentation/swift/identifiable  // [Isolated] External resource sub-bullet | [In-file] External resource sub-bullet
//    - Equatable: https://developer.apple.com/documentation/swift/equatable  // [Isolated] External resource sub-bullet | [In-file] External resource sub-bullet
//    - Hashable: https://developer.apple.com/documentation/swift/hashable  // [Isolated] External resource sub-bullet | [In-file] External resource sub-bullet
//  NOTE:  // [Isolated] Internal note section header | [In-file] Internal note section header
//  - FileType, FileDecision  // [Isolated] Internal referenced types | [In-file] Internal referenced types

import AppKit  // [Isolated] Import AppKit for NSImage | [In-file] Import AppKit for NSImage
import Foundation  // [Isolated] Import Foundation for URL, UUID, etc. | [In-file] Import Foundation for URL, UUID, etc.

struct DesktopFile: Identifiable, Equatable, Hashable {  // [Isolated] DesktopFile struct declaration conforming to protocols | [In-file] DesktopFile struct declaration conforming to protocols
    let id: UUID  // [Isolated] Unique identifier for the file | [In-file] Unique identifier for the file
    let url: URL  // [Isolated] URL of the file or folder | [In-file] URL of the file or folder
    let name: String  // [Isolated] Name of the file or folder | [In-file] Name of the file or folder
    let fileSize: Int64  // [Isolated] Size of the file in bytes | [In-file] Size of the file in bytes
    let fileType: FileType  // [Isolated] Classified file type | [In-file] Classified file type
    let icon: NSImage  // [Isolated] Icon image for UI representation | [In-file] Icon image for UI representation
    var thumbnail: NSImage?  // [Isolated] Optional thumbnail image for preview | [In-file] Optional thumbnail image for preview

    init(id: UUID = UUID(), url: URL, name: String, fileSize: Int64, fileType: FileType, icon: NSImage, thumbnail: NSImage? = nil) {  // [Isolated] Initializer without decision parameter | [In-file] Initializer without decision parameter
        self.id = id  // [Isolated] Assign id | [In-file] Assign id
        self.url = url  // [Isolated] Assign url | [In-file] Assign url
        self.name = name  // [Isolated] Assign name | [In-file] Assign name
        self.fileSize = fileSize  // [Isolated] Assign fileSize | [In-file] Assign fileSize
        self.fileType = fileType  // [Isolated] Assign fileType | [In-file] Assign fileType
        self.icon = icon  // [Isolated] Assign icon | [In-file] Assign icon
        self.thumbnail = thumbnail  // [Isolated] Assign thumbnail | [In-file] Assign thumbnail
    }
    var decision: FileDecision? // nil = unprocessed  // [Isolated] Optional FileDecision state; nil means unprocessed | [In-file] Optional FileDecision state; nil means unprocessed

    init(id: UUID = UUID(), url: URL, name: String, fileSize: Int64, fileType: FileType, icon: NSImage, thumbnail: NSImage? = nil, decision: FileDecision? = nil) {  // [Isolated] Initializer with decision parameter | [In-file] Initializer with decision parameter
        self.id = id  // [Isolated] Assign id | [In-file] Assign id
        self.url = url  // [Isolated] Assign url | [In-file] Assign url
        self.name = name  // [Isolated] Assign name | [In-file] Assign name
        self.fileSize = fileSize  // [Isolated] Assign fileSize | [In-file] Assign fileSize
        self.fileType = fileType  // [Isolated] Assign fileType | [In-file] Assign fileType
        self.icon = icon  // [Isolated] Assign icon | [In-file] Assign icon
        self.thumbnail = thumbnail  // [Isolated] Assign thumbnail | [In-file] Assign thumbnail
        self.decision = decision  // [Isolated] Assign decision | [In-file] Assign decision
    }
}


enum FileDecision: String, Codable {  // [Isolated] Enum representing file decisions, Codable for persistence | [In-file] Enum representing file decisions, Codable for persistence
    case kept  // [Isolated] File is kept | [In-file] File is kept
    case binned  // [Isolated] File is binned (deleted) | [In-file] File is binned (deleted)
    case stacked  // [Isolated] File is stacked | [In-file] File is stacked
    case cloud  // [Isolated] File is stored in cloud | [In-file] File is stored in cloud
    case moved  // [Isolated] File is moved | [In-file] File is moved
}

enum FileType: String, CaseIterable, Hashable {  // [Isolated] Enum representing file types, iterable and hashable | [In-file] Enum representing file types, iterable and hashable
    case image  // [Isolated] Image file type | [In-file] Image file type
    case video  // [Isolated] Video file type | [In-file] Video file type
    case audio  // [Isolated] Audio file type | [In-file] Audio file type
    case document  // [Isolated] Document file type | [In-file] Document file type
    case archive  // [Isolated] Archive file type | [In-file] Archive file type
    case app  // [Isolated] Application file type | [In-file] Application file type
    case folder  // [Isolated] Folder type | [In-file] Folder type
    case other  // [Isolated] Other/unknown file type | [In-file] Other/unknown file type

    var displayName: String {  // [Isolated] Human-readable display name for the type | [In-file] Human-readable display name for the type
        switch self {  // [Isolated] Switch on self for displayName | [In-file] Switch on self for displayName
        case .image: return "Images"  // [Isolated] Display name for image | [In-file] Display name for image
        case .video: return "Videos"  // [Isolated] Display name for video | [In-file] Display name for video
        case .audio: return "Audio"  // [Isolated] Display name for audio | [In-file] Display name for audio
        case .document: return "Documents"  // [Isolated] Display name for document | [In-file] Display name for document
        case .archive: return "Archives"  // [Isolated] Display name for archive | [In-file] Display name for archive
        case .app: return "Apps"  // [Isolated] Display name for app | [In-file] Display name for app
        case .folder: return "Folders"  // [Isolated] Display name for folder | [In-file] Display name for folder
        case .other: return "Other"  // [Isolated] Display name for other | [In-file] Display name for other
        }
    }

    var icon: String {  // [Isolated] System icon name for the file type | [In-file] System icon name for the file type
        switch self {  // [Isolated] Switch on self for icon | [In-file] Switch on self for icon
        case .image: return "photo"  // [Isolated] Icon for image | [In-file] Icon for image
        case .video: return "film"  // [Isolated] Icon for video | [In-file] Icon for video
        case .audio: return "music.note"  // [Isolated] Icon for audio | [In-file] Icon for audio
        case .document: return "doc.text"  // [Isolated] Icon for document | [In-file] Icon for document
        case .archive: return "archivebox"  // [Isolated] Icon for archive | [In-file] Icon for archive
        case .app: return "app"  // [Isolated] Icon for app | [In-file] Icon for app
        case .folder: return "folder"  // [Isolated] Icon for folder | [In-file] Icon for folder
        case .other: return "doc"  // [Isolated] Icon for other | [In-file] Icon for other
        }
    }

    static func classify(url: URL, isDirectory: Bool) -> FileType {  // [Isolated] Classify file type based on URL and directory flag | [In-file] Classify file type based on URL and directory flag
        if isDirectory { return .folder }  // [Isolated] Return folder if directory | [In-file] Return folder if directory
        if url.pathExtension.lowercased() == "app" { return .app }  // [Isolated] Return app if extension is 'app' | [In-file] Return app if extension is 'app'

        let ext = url.pathExtension.lowercased()  // [Isolated] Lowercase file extension | [In-file] Lowercase file extension
        if ["png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "bmp", "webp"].contains(ext) {  // [Isolated] Check if extension is an image type | [In-file] Check if extension is an image type
            return .image  // [Isolated] Return image type | [In-file] Return image type
        }
        if ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(ext) {  // [Isolated] Check if extension is a video type | [In-file] Check if extension is a video type
            return .video  // [Isolated] Return video type | [In-file] Return video type
        }
        if ["mp3", "wav", "aiff", "m4a", "flac", "aac"].contains(ext) {  // [Isolated] Check if extension is an audio type | [In-file] Check if extension is an audio type
            return .audio  // [Isolated] Return audio type | [In-file] Return audio type
        }
        if ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "rtf", "txt", "md", "pages", "numbers", "key"].contains(ext) {  // [Isolated] Check if extension is a document type | [In-file] Check if extension is a document type
            return .document  // [Isolated] Return document type | [In-file] Return document type
        }
        if ["zip", "rar", "7z", "tar", "gz", "bz2"].contains(ext) {  // [Isolated] Check if extension is an archive type | [In-file] Check if extension is an archive type
            return .archive  // [Isolated] Return archive type | [In-file] Return archive type
        }
        return .other  // [Isolated] Return other type if no match | [In-file] Return other type if no match
    }
}

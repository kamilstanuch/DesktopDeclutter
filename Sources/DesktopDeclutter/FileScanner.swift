import Foundation
import AppKit
import QuickLookThumbnailing

enum FileType: String, CaseIterable {
    case image
    case video
    case document
    case audio
    case archive
    case code
    case other
    
    var displayName: String {
        switch self {
        case .image: return "Images"
        case .video: return "Videos"
        case .document: return "Documents"
        case .audio: return "Audio"
        case .archive: return "Archives"
        case .code: return "Code"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .document: return "doc.fill"
        case .audio: return "music.note"
        case .archive: return "archivebox.fill"
        case .code: return "curlybraces"
        case .other: return "doc.text.fill"
        }
    }
    
    static func from(url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()
        
        let imageExts = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "webp", "svg", "ico"]
        let videoExts = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "3gp"]
        let docExts = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "key"]
        let audioExts = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma"]
        let archiveExts = ["zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "iso"]
        let codeExts = ["swift", "js", "ts", "py", "java", "cpp", "c", "h", "html", "css", "json", "xml", "yaml", "yml", "sh", "md"]
        
        if imageExts.contains(ext) { return .image }
        if videoExts.contains(ext) { return .video }
        if docExts.contains(ext) { return .document }
        if audioExts.contains(ext) { return .audio }
        if archiveExts.contains(ext) { return .archive }
        if codeExts.contains(ext) { return .code }
        return .other
    }
}

struct DesktopFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let fileSize: Int64
    var thumbnail: NSImage?
    
    var fileType: FileType {
        FileType.from(url: url)
    }
    
    // Default fallback icon
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    static func == (lhs: DesktopFile, rhs: DesktopFile) -> Bool {
        lhs.id == rhs.id
    }
}

class FileScanner {
    static let shared = FileScanner()
    
    private let fileManager = FileManager.default
    
    func scanDesktop() throws -> [DesktopFile] {
        try scanFolder(FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0])
    }

    func scanFolder(_ folder: URL) throws -> [DesktopFile] {
        let fileURLs = try fileManager.contentsOfDirectory(at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles])

        var files: [DesktopFile] = []
        
        for url in fileURLs {
            let filename = url.lastPathComponent
            let flags = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if flags?.isRegularFile == true && flags?.isSymbolicLink != true && !filename.hasPrefix("$") {
                
                // Get File Size
                let resources = try? url.resourceValues(forKeys: [.fileSizeKey])
                let size = Int64(resources?.fileSize ?? 0)
                
                files.append(DesktopFile(id: UUID(), url: url, name: filename, fileSize: size, thumbnail: nil))
            }
        }
        return files
    }
    
    // Async thumbnail generation
    func generateThumbnail(for file: DesktopFile, maxDimension: CGFloat = 1400, completion: @escaping (NSImage?) -> Void) {
        let size = CGSize(width: maxDimension, height: maxDimension)
        let scale: CGFloat = 1.0
        
        let request = QLThumbnailGenerator.Request(fileAt: file.url, size: size, scale: scale, representationTypes: .thumbnail)
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { (thumbnail, error) in
            if let thumbnail = thumbnail {
                DispatchQueue.main.async {
                    completion(thumbnail.nsImage)
                }
            } else {
                // Fallback or error, return nil so UI uses icon
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

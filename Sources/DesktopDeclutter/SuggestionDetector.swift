//  SuggestionDetector.swift
//  DesktopDeclutter
//
//  Purpose
//  -------
//  Suggestion pipeline for a given `DesktopFile` that detects potential cleanup/grouping hints (duplicates, similar naming patterns, age, large size, same-session creation, temporary file heuristics) and returns them as prioritized `FileSuggestion` models.
//
//  Unique characteristics
//  ----------------------
//  - Uses `SuggestionType` enum with custom Equatable to compare suggestion semantics without comparing file arrays.
//  - Uses `FileSuggestion` with UUID identity for SwiftUI lists but explicit Equatable override.
//  - Provides both synchronous and async detection APIs; async version runs multiple checks concurrently via `withTaskGroup`.
//  - Uses background `Task.detached` for filesystem attribute reads in async checks.
//  - Applies lightweight heuristics for name patterns (CleanShot, Screenshot variants, numbered sequences, and embedded date patterns).
//
//  External sources / resources referenced (documentation links)
//  ------------------------------------------------------------
//  - Swift language: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/
//  - Swift Concurrency:
//      - Task: https://developer.apple.com/documentation/swift/task
//      - TaskGroup / withTaskGroup: https://developer.apple.com/documentation/swift/withtaskgroup(of:returning:body:)
//      - Task.sleep: https://developer.apple.com/documentation/swift/task/sleep(nanoseconds:)
//  - Foundation:
//      - Foundation: https://developer.apple.com/documentation/foundation
//      - Date: https://developer.apple.com/documentation/foundation/date
//      - FileManager: https://developer.apple.com/documentation/foundation/filemanager
//      - FileAttributeKey.creationDate: https://developer.apple.com/documentation/foundation/fileattributekey/1410452-creationdate
//      - TimeInterval: https://developer.apple.com/documentation/foundation/timeinterval
//      - RegularExpression (String range(of:options: .regularExpression)): https://developer.apple.com/documentation/foundation/nsregularexpression
//      - UUID: https://developer.apple.com/documentation/foundation/uuid
//
//  NOTE: References internal project types:
//  - DesktopFile

import Foundation
// [Isolated] SuggestionType enum defines the types of suggestions detected. | [In-file] Used as the core suggestion type for heuristics and UI.
enum SuggestionType: Equatable { // [Isolated] Enum for suggestion types. | [In-file] Each case represents a file grouping/cleanup heuristic.
    case duplicate(count: Int, files: [DesktopFile]) // [Isolated] Duplicate file suggestion. | [In-file] Holds count and involved files.
    case similarNames(pattern: String, count: Int, files: [DesktopFile]) // [Isolated] Similar name pattern suggestion. | [In-file] Stores pattern and file group.
    case oldFile(years: Double) // [Isolated] Old file suggestion. | [In-file] Stores file age in years.
    case largeFile(sizeMB: Double) // [Isolated] Large file suggestion. | [In-file] Stores file size in MB.
    case sameSession(count: Int, files: [DesktopFile]) // [Isolated] Files created in same session. | [In-file] Holds count and files.
    case temporaryFile // [Isolated] Temporary file suggestion. | [In-file] No associated value.

    static func == (lhs: SuggestionType, rhs: SuggestionType) -> Bool { // [Isolated] Custom Equatable implementation. | [In-file] Compares only suggestion semantics, not file arrays.
        switch (lhs, rhs) {
        case (.duplicate(let lCount, _), .duplicate(let rCount, _)):
            return lCount == rCount
        case (.similarNames(let lPattern, let lCount, _), .similarNames(let rPattern, let rCount, _)):
            return lPattern == rPattern && lCount == rCount
        case (.oldFile(let lYears), .oldFile(let rYears)):
            return lYears == rYears
        case (.largeFile(let lSize), .largeFile(let rSize)):
            return lSize == rSize
        case (.sameSession(let lCount, _), .sameSession(let rCount, _)):
            return lCount == rCount
        case (.temporaryFile, .temporaryFile):
            return true
        default:
            return false
        }
    }
}

// [Isolated] FileSuggestion model for UI and logic. | [In-file] Used for SwiftUI lists and sorting.
struct FileSuggestion: Identifiable, Equatable { // [Isolated] Suggestion model. | [In-file] Carries suggestion type, message, etc.
    let id = UUID() // [Isolated] Unique identity. | [In-file] Used for SwiftUI ForEach.
    let type: SuggestionType // [Isolated] Suggestion type. | [In-file] See SuggestionType.
    let priority: Int // Higher = more important // [Isolated] Priority for sorting. | [In-file] Higher value = higher importance.
    let message: String // [Isolated] Main suggestion message. | [In-file] Displayed to user.
    let actionHint: String? // [Isolated] Optional action hint. | [In-file] Displayed as subtext.

    static func == (lhs: FileSuggestion, rhs: FileSuggestion) -> Bool { // [Isolated] Explicit Equatable. | [In-file] Compares UUID.
        lhs.id == rhs.id
    }
}

// [Isolated] Main detector class for file suggestions. | [In-file] Singleton, provides sync/async APIs.
class SuggestionDetector { // [Isolated] Suggestion detection pipeline. | [In-file] Houses all detection logic.
    static let shared = SuggestionDetector() // [Isolated] Singleton instance. | [In-file] Used across app.

    // [Isolated] Async detection entry point. | [In-file] Runs multiple checks concurrently using withTaskGroup.
    func detectSuggestionsAsync(for file: DesktopFile, in allFiles: [DesktopFile]) async -> [FileSuggestion] {
        return await withTaskGroup(of: FileSuggestion?.self) { group in // [Isolated] Task group for parallel checks. | [In-file] Each check runs as a task.
            var suggestions: [FileSuggestion] = [] // [Isolated] Holds suggestions found. | [In-file] Collected from tasks.

            let otherFiles = allFiles.filter { $0.id != file.id } // [Isolated] Exclude current file. | [In-file] Used for group checks.

            group.addTask {
                await self.detectDuplicatesAsync(for: file, in: otherFiles) // [Isolated] Duplicate detection. | [In-file] Async version.
            }
            group.addTask {
                await self.detectSimilarNamesAsync(for: file, in: otherFiles) // [Isolated] Similar names detection. | [In-file] Async version.
            }
            group.addTask {
                await self.detectOldFileAsync(file) // [Isolated] Old file detection. | [In-file] Runs on background thread.
            }
            group.addTask {
                await self.detectLargeFileAsync(file) // [Isolated] Large file detection. | [In-file] Lightweight.
            }
            group.addTask {
                await self.detectSameSessionAsync(for: file, in: otherFiles) // [Isolated] Same session detection. | [In-file] Background thread.
            }
            group.addTask {
                await self.detectTemporaryFileAsync(file) // [Isolated] Temp file detection. | [In-file] Lightweight.
            }

            for await suggestion in group { // [Isolated] Collect results. | [In-file] Only non-nil suggestions added.
                if let suggestion = suggestion {
                    suggestions.append(suggestion)
                }
            }
            return suggestions.sorted { $0.priority > $1.priority } // [Isolated] Sort by priority. | [In-file] Highest first.
        }
    }

    // [Isolated] Synchronous detection entry point. | [In-file] Runs checks serially, used for compatibility.
    func detectSuggestions(for file: DesktopFile, in allFiles: [DesktopFile]) -> [FileSuggestion] {
        var suggestions: [FileSuggestion] = [] // [Isolated] Holds found suggestions. | [In-file] Appended as checks succeed.
        let otherFiles = allFiles.filter { $0.id != file.id } // [Isolated] Exclude current file. | [In-file] Used for group checks.
        if let duplicateSuggestion = detectDuplicates(for: file, in: otherFiles) { // [Isolated] Duplicate check. | [In-file] Synchronous.
            suggestions.append(duplicateSuggestion)
        }
        if let similarSuggestion = detectSimilarNames(for: file, in: otherFiles) { // [Isolated] Similar names check. | [In-file] Synchronous.
            suggestions.append(similarSuggestion)
        }
        if let oldFileSuggestion = detectOldFile(file) { // [Isolated] Old file check. | [In-file] Synchronous.
            suggestions.append(oldFileSuggestion)
        }
        if let largeFileSuggestion = detectLargeFile(file) { // [Isolated] Large file check. | [In-file] Synchronous.
            suggestions.append(largeFileSuggestion)
        }
        if let sessionSuggestion = detectSameSession(for: file, in: otherFiles) { // [Isolated] Same session check. | [In-file] Synchronous.
            suggestions.append(sessionSuggestion)
        }
        if let tempSuggestion = detectTemporaryFile(file) { // [Isolated] Temp file check. | [In-file] Synchronous.
            suggestions.append(tempSuggestion)
        }
        return suggestions.sorted { $0.priority > $1.priority } // [Isolated] Sort by priority. | [In-file] Highest first.
    }

    // [Isolated] Detection methods section. | [In-file] Houses individual heuristic checks that can be composed by sync/async entry points.

    private func detectDuplicates(for file: DesktopFile, in otherFiles: [DesktopFile]) -> FileSuggestion? { // [Isolated] Detects exact duplicates. | [In-file] Filename and size match.
        let duplicates = otherFiles.filter { otherFile in
            otherFile.name == file.name && otherFile.fileSize == file.fileSize // [Isolated] Checks name and size equality. | [In-file] Simple duplicate heuristic.
        }
        if duplicates.count > 0 {
            return FileSuggestion(
                type: .duplicate(count: duplicates.count + 1, files: [file] + duplicates),
                priority: 10,
                message: "\(duplicates.count + 1) copies of this file",
                actionHint: "Keep one, delete others?"
            )
        }
        return nil
    }

    private func detectSimilarNames(for file: DesktopFile, in otherFiles: [DesktopFile]) -> FileSuggestion? { // [Isolated] Detects similar name patterns. | [In-file] Screenshots, CleanShot, numbered, date patterns.
        let fileName = file.name.lowercased()
        var pattern: String?
        var matches: [DesktopFile] = []
        if fileName.contains("cleanshot_") { // [Isolated] CleanShot pattern. | [In-file] Group by "cleanshot_" substring.
            pattern = "CleanShot screenshots"
            matches = otherFiles.filter { $0.name.lowercased().contains("cleanshot_") }
        }
        else if fileName.contains("screen shot") || fileName.contains("screenshot") { // [Isolated] Screenshot pattern. | [In-file] Group by "screen shot" or "screenshot".
            pattern = "Screenshots"
            matches = otherFiles.filter {
                let name = $0.name.lowercased()
                return name.contains("screen shot") || name.contains("screenshot")
            }
        }
        else if let numberedPattern = detectNumberedSequence(fileName) { // [Isolated] Numbered sequence pattern. | [In-file] Finds _001, _v1, (1) forms.
            pattern = numberedPattern.pattern
            matches = otherFiles.filter { otherFile in
                detectNumberedSequence(otherFile.name.lowercased())?.base == numberedPattern.base
            }
        }
        else if let datePattern = detectDatePattern(fileName) { // [Isolated] Date pattern. | [In-file] Finds embedded date strings.
            pattern = "Files from \(datePattern)"
            matches = otherFiles.filter { otherFile in
                detectDatePattern(otherFile.name.lowercased()) == datePattern
            }
        }
        if let pattern = pattern, matches.count > 2 { // [Isolated] Only suggest if group > 2. | [In-file] Avoids noise for small groups.
            return FileSuggestion(
                type: .similarNames(pattern: pattern, count: matches.count + 1, files: [file] + matches),
                priority: 8,
                message: "\(matches.count + 1) \(pattern.lowercased())",
                actionHint: "Review together?"
            )
        }
        return nil
    }

    private func detectNumberedSequence(_ fileName: String) -> (base: String, pattern: String)? { // [Isolated] Extracts base for numbered sequence. | [In-file] Used for grouping versions/copies.
        if let match = fileName.range(of: #"_\d{3,}"#, options: .regularExpression) { // [Isolated] Pattern: _001, _002. | [In-file] Returns base and label.
            let base = String(fileName[..<match.lowerBound])
            return (base, "Numbered sequence")
        }
        if let match = fileName.range(of: #"_v\d+"#, options: .regularExpression) { // [Isolated] Pattern: _v1, _v2. | [In-file] Returns base and label.
            let base = String(fileName[..<match.lowerBound])
            return (base, "Versioned files")
        }
        if let match = fileName.range(of: #"\s\(\d+\)"#, options: .regularExpression) { // [Isolated] Pattern: (1), (2). | [In-file] Returns base and label.
            let base = String(fileName[..<match.lowerBound])
            return (base, "Numbered copies")
        }
        return nil
    }

    private func detectDatePattern(_ fileName: String) -> String? { // [Isolated] Extracts date substring if present. | [In-file] Used for grouping by date.
        let patterns = [
            #"\d{4}[-_]\d{2}[-_]\d{2}"#, // [Isolated] e.g. 2024-01-25 or 2024_01_25. | [In-file] ISO date.
            #"\d{8}"# // [Isolated] e.g. 20240125. | [In-file] Compact date.
        ]
        for pattern in patterns {
            if let range = fileName.range(of: pattern, options: .regularExpression) {
                return String(fileName[range])
            }
        }
        return nil
    }

    private func detectOldFile(_ file: DesktopFile) -> FileSuggestion? { // [Isolated] Detects old files by creation date. | [In-file] Returns suggestion if >1 year old.
        guard let creationDate = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
            return nil
        }
        let yearsAgo = Date().timeIntervalSince(creationDate) / (365.25 * 24 * 60 * 60)
        if yearsAgo >= 2 {
            let years = Int(yearsAgo)
            return FileSuggestion(
                type: .oldFile(years: yearsAgo),
                priority: 6,
                message: "Created \(years) year\(years > 1 ? "s" : "") ago",
                actionHint: "Still needed?"
            )
        } else if yearsAgo >= 1 {
            return FileSuggestion(
                type: .oldFile(years: yearsAgo),
                priority: 4,
                message: "Created over a year ago",
                actionHint: nil
            )
        }
        return nil
    }

    // [Isolated] Async versions of detection methods. | [In-file] Used by detectSuggestionsAsync.
    private func detectDuplicatesAsync(for file: DesktopFile, in otherFiles: [DesktopFile]) async -> FileSuggestion? {
        return detectDuplicates(for: file, in: otherFiles)
    }
    private func detectSimilarNamesAsync(for file: DesktopFile, in otherFiles: [DesktopFile]) async -> FileSuggestion? {
        return detectSimilarNames(for: file, in: otherFiles)
    }
    private func detectOldFileAsync(_ file: DesktopFile) async -> FileSuggestion? {
        return await Task.detached { // [Isolated] Runs on background thread. | [In-file] Prevents main thread blocking.
            guard let creationDate = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
                return nil
            }
            let yearsAgo = Date().timeIntervalSince(creationDate) / (365.25 * 24 * 60 * 60)
            if yearsAgo >= 2 {
                let years = Int(yearsAgo)
                return FileSuggestion(
                    type: .oldFile(years: yearsAgo),
                    priority: 6,
                    message: "Created \(years) year\(years > 1 ? "s" : "") ago",
                    actionHint: "Still needed?"
                )
            } else if yearsAgo >= 1 {
                return FileSuggestion(
                    type: .oldFile(years: yearsAgo),
                    priority: 4,
                    message: "Created over a year ago",
                    actionHint: nil
                )
            }
            return nil
        }.value
    }
    private func detectLargeFileAsync(_ file: DesktopFile) async -> FileSuggestion? {
        return detectLargeFile(file)
    }
    private func detectSameSessionAsync(for file: DesktopFile, in otherFiles: [DesktopFile]) async -> FileSuggestion? {
        return await Task.detached { // [Isolated] Runs on background thread. | [In-file] Prevents main thread blocking.
            guard let creationDate = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
                return nil
            }
            let sessionWindow: TimeInterval = 5 * 60 // [Isolated] 5 minute window. | [In-file] Heuristic for session grouping.
            let sessionFiles = otherFiles.filter { otherFile in
                guard let otherDate = try? FileManager.default.attributesOfItem(atPath: otherFile.url.path)[.creationDate] as? Date else {
                    return false
                }
                return abs(creationDate.timeIntervalSince(otherDate)) <= sessionWindow
            }
            if sessionFiles.count >= 3 {
                return FileSuggestion(
                    type: .sameSession(count: sessionFiles.count + 1, files: [file] + sessionFiles),
                    priority: 5,
                    message: "\(sessionFiles.count + 1) files from same session",
                    actionHint: "Created together - review together?"
                )
            }
            return nil
        }.value
    }
    private func detectTemporaryFileAsync(_ file: DesktopFile) async -> FileSuggestion? {
        return detectTemporaryFile(file)
    }

    private func detectLargeFile(_ file: DesktopFile) -> FileSuggestion? { // [Isolated] Detects large files by size. | [In-file] Suggests if >100MB.
        let sizeMB = Double(file.fileSize) / (1024 * 1024)
        if sizeMB >= 500 {
            return FileSuggestion(
                type: .largeFile(sizeMB: sizeMB),
                priority: 7,
                message: "\(String(format: "%.1f", sizeMB)) MB - Large file",
                actionHint: "Taking up significant space"
            )
        } else if sizeMB >= 100 {
            return FileSuggestion(
                type: .largeFile(sizeMB: sizeMB),
                priority: 5,
                message: "\(String(format: "%.1f", sizeMB)) MB",
                actionHint: nil
            )
        }
        return nil
    }

    private func detectSameSession(for file: DesktopFile, in otherFiles: [DesktopFile]) -> FileSuggestion? { // [Isolated] Detects files created in same session. | [In-file] Uses 5 minute window.
        guard let creationDate = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date else {
            return nil
        }
        let sessionWindow: TimeInterval = 5 * 60
        let sessionFiles = otherFiles.filter { otherFile in
            guard let otherDate = try? FileManager.default.attributesOfItem(atPath: otherFile.url.path)[.creationDate] as? Date else {
                return false
            }
            return abs(creationDate.timeIntervalSince(otherDate)) <= sessionWindow
        }
        if sessionFiles.count >= 3 {
            return FileSuggestion(
                type: .sameSession(count: sessionFiles.count + 1, files: [file] + sessionFiles),
                priority: 5,
                message: "\(sessionFiles.count + 1) files from same session",
                actionHint: "Created together - review together?"
            )
        }
        return nil
    }

    private func detectTemporaryFile(_ file: DesktopFile) -> FileSuggestion? { // [Isolated] Detects temporary files by extension/pattern. | [In-file] Suggests if matches temp heuristics.
        let fileName = file.name.lowercased()
        let tempExtensions = ["tmp", "cache", "log", "bak", "old"]
        let tempPatterns = ["temp", "cache", "backup", "~"]
        let isTempExtension = tempExtensions.contains(file.url.pathExtension.lowercased())
        let hasTempPattern = tempPatterns.contains { fileName.contains($0) }
        if isTempExtension || hasTempPattern {
            return FileSuggestion(
                type: .temporaryFile,
                priority: 9,
                message: "Looks like a temporary file",
                actionHint: "Safe to delete?"
            )
        }
        return nil
    }
}

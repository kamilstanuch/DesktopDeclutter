import SwiftUI
import QuickLookUI

struct CardView: View {
    let cardSize: CGSize
    let file: DesktopFile
    let suggestions: [FileSuggestion]
    let onKeep: () -> Void
    let onBin: () -> Void
    let onPreview: (() -> Void)?
    let onSuggestionTap: ((FileSuggestion) -> Void)?
    
    @State private var offset: CGSize = .zero
    @State private var color: Color = .clear
    @State private var showSuggestions = false
    
    init(file: DesktopFile, cardSize: CGSize = CGSize(width: 300, height: 450), suggestions: [FileSuggestion] = [], onKeep: @escaping () -> Void, onBin: @escaping () -> Void, onPreview: (() -> Void)? = nil, onSuggestionTap: ((FileSuggestion) -> Void)? = nil) {
        self.cardSize = cardSize
        self.file = file
        self.suggestions = suggestions
        self.onKeep = onKeep
        self.onBin = onBin
        self.onPreview = onPreview
        self.onSuggestionTap = onSuggestionTap
    }
    
    @State private var isPreviewHovered = false
    
    private var fileDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        if let date = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date {
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return "Recently"
    }
    
    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(spacing: 0) {
                // Preview area with padding
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    
                    if let image = file.thumbnail {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).padding(8)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc").font(.system(size: 48))
                            Text("Loading preview… · Space to open")
                        }
                    }
                }
                .frame(height: max(240, cardSize.height - (suggestions.isEmpty ? 100 : 170)))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                )
                
                // Suggestions badges (if any)
                if !suggestions.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(suggestions.prefix(2).enumerated()), id: \.offset) { _, suggestion in
                            SuggestionBadge(suggestion: suggestion) {
                                onSuggestionTap?(suggestion)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                
                // File info footer
                VStack(spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(file.name)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary.opacity(0.6))
                                
                                Text(fileDateString)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Preview button
                        if onPreview != nil {
                            Button(action: {
                                onPreview?()
                            }) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(isPreviewHovered ? .white : .blue)
                                    .frame(width: 36, height: 36)
                                    .background {
                                        Circle()
                                            .fill(isPreviewHovered ? Color.blue : Color.blue.opacity(0.12))
                                    }
                            }
                            .buttonStyle(.plain)
                            .help("Preview file (Space)")
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPreviewHovered = hovering
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background {
                    Color(nsColor: .controlBackgroundColor)
                        .opacity(0.6)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 0
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Swipe overlays with improved visuals
            HStack {
                // KEEP (Left side of card, visible when swiping right)
                if offset.width > 0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.25),
                                        Color.green.opacity(0.15)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundColor(.green)
                                .opacity(min(Double(offset.width / 120), 1.0))
                            
                            Text("Keep")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)
                                .opacity(min(Double(offset.width / 120), 1.0))
                        }
                        .rotationEffect(.degrees(-min(Double(offset.width / 8), 12)))
                    }
                }
                
                // BIN (Right side of card, visible when swiping left)
                if offset.width < 0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.25),
                                        Color.red.opacity(0.15)
                                    ],
                                    startPoint: .trailing,
                                    endPoint: .leading
                                )
                            )
                        
                        VStack(spacing: 8) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundColor(.red)
                                .opacity(min(Double(-offset.width / 120), 1.0))
                            
                            Text("Bin")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .opacity(min(Double(-offset.width / 120), 1.0))
                        }
                        .rotationEffect(.degrees(min(Double(-offset.width / 8), 12)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .offset(x: offset.width, y: 0)
        .rotationEffect(.degrees(Double(offset.width / 25)))
        .scaleEffect(1.0 - abs(offset.width) / 1200)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { gesture in
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                        offset = gesture.translation
                    }
                }
                .onEnded { gesture in
                    let threshold: CGFloat = 120
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if offset.width > threshold {
                            onKeep()
                        } else if offset.width < -threshold {
                            onBin()
                        } else {
                            offset = .zero
                        }
                    }
                }
        )
    }
}

// MARK: - Suggestion Badge

struct SuggestionBadge: View {
    let suggestion: FileSuggestion
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    private var badgeColor: Color {
        switch suggestion.type {
        case .duplicate, .temporaryFile:
            return .orange
        case .similarNames, .sameSession:
            return .blue
        case .oldFile:
            return .red
        case .largeFile:
            return .purple
        }
    }
    
    private var badgeIcon: String {
        switch suggestion.type {
        case .duplicate:
            return "doc.on.doc.fill"
        case .similarNames:
            return "square.stack.fill"
        case .oldFile:
            return "clock.fill"
        case .largeFile:
            return "externaldrive.fill"
        case .sameSession:
            return "calendar.badge.clock"
        case .temporaryFile:
            return "trash.fill"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: badgeIcon)
                    .font(.system(size: 12, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.message)
                        .font(.system(size: 12, weight: .medium))
                    
                    if let hint = suggestion.actionHint {
                        Text(hint)
                            .font(.system(size: 10, weight: .regular))
                            .opacity(0.8)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.6)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(badgeColor.opacity(isHovered ? 0.9 : 0.85))
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

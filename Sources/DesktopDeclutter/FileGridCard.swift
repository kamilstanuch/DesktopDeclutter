import SwiftUI
import QuickLookUI

struct FileGridCard: View {
    let file: DesktopFile
    let isSelected: Bool
    let isHovered: Bool
    let isShaking: Bool
    
    let onToggle: () -> Void
    let onPreview: () -> Void
    let onHover: (Bool) -> Void
    
    @State private var hoveredPreview = false
    @State private var shakeRotation: Double = 0
    
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
            ZStack {
                // Thumbnail
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
                
                // Decision Overlay
                if let decision = file.decision {
                    ZStack {
                        Color.black.opacity(0.3)
                            .cornerRadius(12)
                        Image(systemName: decision == .kept ? "checkmark.circle.fill" : (decision == .binned ? "trash.circle.fill" : (decision == .cloud ? "icloud.and.arrow.up.fill" : (decision == .moved ? "folder.fill" : "square.stack.3d.up.fill"))))
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .frame(width: 160, height: 160)
                }
                
                // Selection checkbox (Top Left)
                VStack {
                    HStack {
                        Button(action: onToggle) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.blue : Color.black.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 28, height: 28)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .opacity(isSelected || isHovered ? 1.0 : 0.6)
                        
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: 160, height: 160)
                
                // Preview overlay on hover (Bottom Right)
                if isHovered {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: onPreview) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                                    }
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .scale))
                            .padding(8)
                        }
                    }
                    .frame(width: 160, height: 160)
                }
            }
            .rotationEffect(.degrees(shakeRotation))
            .onChange(of: isShaking) { shaking in
                if shaking {
                    withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                        shakeRotation = 2
                    }
                } else {
                    withAnimation(.default) {
                        shakeRotation = 0
                    }
                }
            }
            // ... rest remains similar
            
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

import SwiftUI
import AppKit

// Color extension for hex values
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

@main
struct WallpaperManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var wallpapers: [WallpaperItem] = []
    @State private var selectedWallpaper: WallpaperItem?
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 16)
    ]
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Decor")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            
            // Wallpaper Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(wallpapers, id: \.id) { wallpaper in
                        WallpaperCard(
                            wallpaper: wallpaper,
                            isSelected: selectedWallpaper?.id == wallpaper.id,
                            onSelect: { selectWallpaper(wallpaper) }
                        )
                    }
                }
                .padding()
            }
            
            // Bottom Controls
            HStack {
                Spacer()
                
                if let selected = selectedWallpaper {
                    Button("Set as Wallpaper") {
                        setWallpaper(selected)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadDefaultWallpapers()
        }
        .alert("Wallpaper Manager", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadDefaultWallpapers() {
        // Load wallpapers from /Library/Desktop Pictures
        let desktopPicturesPath = "/Library/Desktop Pictures"
        loadWallpapersFromDirectory(desktopPicturesPath)
    }
    
    private func loadWallpapers() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Refresh wallpapers
            DispatchQueue.main.async {
                loadDefaultWallpapers()
                isLoading = false
            }
        }
    }
    
    private func loadWallpapersFromDirectory(_ path: String) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return }
        
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "tiff", "bmp"]
        var newWallpapers: [WallpaperItem] = []
        
        for filename in contents {
            let fullPath = "\(path)/\(filename)"
            let fileExtension = (filename as NSString).pathExtension.lowercased()
            
            if imageExtensions.contains(fileExtension) {
                let wallpaper = WallpaperItem(
                    id: UUID(),
                    name: (filename as NSString).deletingPathExtension,
                    path: fullPath,
                    image: nil // Don't load images immediately
                )
                newWallpapers.append(wallpaper)
            }
        }
        
        wallpapers = newWallpapers.sorted { $0.name < $1.name }
    }
    
    private func addWallpapers() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                let wallpaper = WallpaperItem(
                    id: UUID(),
                    name: url.deletingPathExtension().lastPathComponent,
                    path: url.path,
                    image: NSImage(contentsOf: url)
                )
                wallpapers.append(wallpaper)
            }
        }
    }
    
    private func selectWallpaper(_ wallpaper: WallpaperItem) {
        selectedWallpaper = wallpaper
    }
    
    private func setWallpaper(_ wallpaper: WallpaperItem) {
        guard let screen = NSScreen.main else {
            showAlert("Could not access main screen")
            return
        }
        
        let url = URL(fileURLWithPath: wallpaper.path)
        
        do {
            let workspace = NSWorkspace.shared
            try workspace.setDesktopImageURL(url, for: screen, options: [:])
            showAlert("Wallpaper set successfully!")
        } catch {
            showAlert("Failed to set wallpaper: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

struct WallpaperCard: View {
    let wallpaper: WallpaperItem
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var thumbnailImage: NSImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image Preview
            Group {
                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(16/10, contentMode: .fill)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/10, contentMode: .fill)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
            }
            .onTapGesture {
                onSelect()
            }
            .onAppear {
                loadThumbnail()
            }
            
            // Name
            Text(wallpaper.name)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(isSelected ? .blue : .primary)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(radius: isSelected ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func loadThumbnail() {
        guard thumbnailImage == nil else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let fullImage = NSImage(contentsOfFile: wallpaper.path) else { return }
            
            // Create a smaller thumbnail (max 400px wide)
            let targetSize = NSSize(width: 400, height: 250)
            let thumbnail = NSImage(size: targetSize)
            
            thumbnail.lockFocus()
            fullImage.draw(in: NSRect(origin: .zero, size: targetSize))
            thumbnail.unlockFocus()
            
            DispatchQueue.main.async {
                self.thumbnailImage = thumbnail
            }
        }
    }
}

struct WallpaperItem {
    let id: UUID
    let name: String
    let path: String
    let image: NSImage?
}

#Preview {
    ContentView()
}

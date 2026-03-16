//
//  VideoSyncView.swift
//  pleaco
//

import SwiftUI
import AVKit
import PhotosUI

struct VideoSyncView: View {
    @ObservedObject var syncManager = StashVideoSyncManager.shared
    @ObservedObject var deviceManager = DeviceManager.shared
    
    @State private var player: AVPlayer?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingPicker = false
    @State private var videoURL: URL?
    @State private var isMuted = false
    @State private var videoAspectRatio: CGFloat = 16/9
    @State private var isShowingFullscreen = false
    @State private var isShowingFileImporter = false
    @State private var alertMessage = ""
    @State private var isShowingAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Video Player Section
                videoPlayerSection
                
                // Intensity Monitors
                intensityMonitorSection
                
                // Sensitivity/Smoothing Controls (Still useful for fine-tuning)
                fineTuningSection
                
                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        .background(Color.surfacePrimary)
        .onDisappear {
            syncManager.stop()
            player?.pause()
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            NSLog("🔵 VideoSyncView: selectedItem changed")
            Task {
                do {
                    if let item = newValue {
                        NSLog("🔵 VideoSyncView: Attempting to load transferable...")
                        if let movie = try await item.loadTransferable(type: VideoMovie.self) {
                            NSLog("🔵 VideoSyncView: Video loaded successfully: \(movie.url.lastPathComponent)")
                            await MainActor.run {
                                self.videoURL = movie.url
                                setupPlayer(with: movie.url)
                            }
                        } else {
                            NSLog("⚠️ VideoSyncView: loadTransferable returned nil")
                        }
                    }
                } catch {
                    NSLog("❌ VideoSyncView: Error loading video: \(error)")
                    await MainActor.run {
                        self.alertMessage = "Could not load video: \(error.localizedDescription)"
                        self.isShowingAlert = true
                    }
                    syncManager.lastError = "Picker: \(error.localizedDescription)"
                }
                // Reset selection so the same item can be picked again if needed
                await MainActor.run {
                    self.selectedItem = nil
                }
            }
        }
        .alert("Video Error", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .fullScreenCover(isPresented: $isShowingFullscreen) {
            if let player = player {
                FullscreenPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .photosPicker(isPresented: $isShowingPicker, selection: $selectedItem, matching: .videos)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.movie, .video, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        do {
                            let localURL = try VideoMovie.copyToTemp(url: url)
                            setupPlayer(with: localURL)
                        } catch {
                            self.alertMessage = "Copy failed: \(error.localizedDescription)"
                            self.isShowingAlert = true
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                syncManager.lastError = error.localizedDescription
            }
        }
    }
    
    // MARK: - Subcomponents
    
    private var videoPlayerSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 20) {
                // Video Area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.surfaceSecondary)
                    
                    if let player = player {
                        PlayerViewController(player: player)
                            .cornerRadius(12)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(Color.appAccent.opacity(0.6))
                            
                            Text("Select Video")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Integrated Controls Row
                HStack(spacing: 12) {
                    Menu {
                        Button(action: {
                            isShowingPicker = true
                        }) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        
                        Button(action: {
                            isShowingFileImporter = true
                        }) {
                            Label("Files", systemImage: "folder")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text(player == nil ? "Choose Video" : "Change")
                        }
                        .font(.subheadline.bold())
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Capsule().fill(Color.surfaceSecondary))
                        .overlay(Capsule().strokeBorder(Color.subtleBorder, lineWidth: 0.5))
                    }
                    
                    Spacer()
                    
                    if player != nil {
                        HStack(spacing: 12) {
                            Button(action: {
                                isMuted.toggle()
                                player?.isMuted = isMuted
                            }) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isMuted ? Color.appAccent : .primary)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.surfaceSecondary))
                            }
                            
                            AirPlayView()
                                .frame(width: 40, height: 40)
                        
                            Button(action: {
                                isShowingFullscreen = true
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.surfaceSecondary))
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                            .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 24)
        }
    }
    
    private var fineTuningSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Fine-Tuning", icon: "slider.horizontal.3")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // Sensitivity
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sensitivity")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(syncManager.sensitivity * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Color.appAccent)
                    }
                    Slider(value: $syncManager.sensitivity, in: 0...1)
                        .tint(Color.appAccent)
                }
                
                // Smoothing
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Smoothing")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(syncManager.smoothing * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Color.appAccent)
                    }
                    Slider(value: $syncManager.smoothing, in: 0...1)
                        .tint(Color.appAccent)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 24)
    }
    
    private var intensityMonitorSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Intensity Monitors", icon: "waveform.path.ecg")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                IntensityBar(label: "Vertical Rhythm", value: syncManager.hipIntensity, color: .orange)
                IntensityBar(label: "Core Movement", value: syncManager.pelvisIntensity, color: .red)
                IntensityBar(label: "Shift Tempo", value: syncManager.headIntensity, color: .purple)
                IntensityBar(label: "Action Speed", value: syncManager.wristIntensity, color: .blue)
                IntensityBar(label: "Lateral Motion", value: syncManager.horzIntensity, color: .cyan)
                
                Divider()
                    .padding(.vertical, 4)
                
                IntensityBar(label: "Output Intensity", value: syncManager.currentIntensity, color: Color.appAccent, isMain: true)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Methods
    
    private func setupPlayer(with url: URL) {
        let asset = AVURLAsset(url: url)
        
        // Detect aspect ratio
        Task {
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                let transform = try? await track.load(.preferredTransform)
                if let size = size, let transform = transform {
                    let rect = CGRect(origin: .zero, size: size).applying(transform)
                    let width = abs(rect.width)
                    let height = abs(rect.height)
                    if width > 0 && height > 0 {
                        await MainActor.run {
                            self.videoAspectRatio = width / height
                        }
                    }
                }
            }
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer
        
        // Pass both item and player to sync manager
        syncManager.setup(for: playerItem, player: newPlayer)
    }
}

// MARK: - Transferable Video Model

struct VideoMovie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .item) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = try copyToTemp(url: received.file)
            return VideoMovie(url: copy)
        }
    }
    
    static func copyToTemp(url: URL) throws -> URL {
        let ext = url.pathExtension.lowercased()
        let fileName = "picker_\(UUID().uuidString).\(ext.isEmpty ? "mp4" : ext)"
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: copy.path) {
            try? FileManager.default.removeItem(at: copy)
        }
        
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }
}

// MARK: - Custom Video Player Wrapper

struct PlayerViewController: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Hide all native controls
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

struct AirPlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.activeTintColor = UIColor(Color.appAccent)
        picker.tintColor = .secondaryLabel
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct FullscreenPlayerView: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true // Enable controls in fullscreen
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - Subcomponents

struct IntensityBar: View {
    let label: String
    let value: Float
    let color: Color
    var isMain: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(isMain ? .caption.bold() : .system(size: 10, weight: .medium))
                    .foregroundColor(isMain ? .primary : .secondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.1))
                        .frame(height: isMain ? 8 : 4)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value), height: isMain ? 8 : 4)
                        .animation(.linear(duration: 0.1), value: value)
                }
            }
            .frame(height: isMain ? 8 : 4)
        }
    }
}

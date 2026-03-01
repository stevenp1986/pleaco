//
//  AudioView.swift
//  pleaco
//

import SwiftUI
import UniformTypeIdentifiers

struct AudioView: View {
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var deviceManager = DeviceManager.shared
    @State private var showingAudioPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Tracks List Area
                tracksSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
        }
        .contentMargins(.bottom, 20, for: .scrollContent)
        .background(Color.surfacePrimary)
        #if os(iOS)
        .sheet(isPresented: $showingAudioPicker) {
            AudioDocumentPicker { url in
                guard url.startAccessingSecurityScopedResource() else {
                    print("Could not access security scoped resource for audio file.")
                    return
                }
                
                let tempDir = FileManager.default.temporaryDirectory
                let targetURL = tempDir.appendingPathComponent(url.lastPathComponent)
                
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: url, to: targetURL)
                    url.stopAccessingSecurityScopedResource()
                    
                    audioManager.importTrack(from: targetURL)
                } catch {
                    print("Error copying file: \(error.localizedDescription)")
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        #endif
    }
    
    // MARK: - Subviews

    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Library", icon: "music.note.list")
                Spacer()
                Button {
                    showingAudioPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color.appAccent)
                }
            }

            if audioManager.savedTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(Color.appAccent.opacity(0.5))
                    Text("No tracks imported yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .appCardStyle()
            } else {
                VStack(spacing: 12) {
                    ForEach(audioManager.savedTracks) { track in
                        trackRow(for: track)
                    }
                }
            }
        }
    }

    private func trackRow(for track: SavedAudioTrack) -> some View {
        let isSelected = deviceManager.activeAudioTrack?.id == track.id
        
        return Button {
            deviceManager.applyAudioTrack(track)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.surfaceSecondary))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isSelected && audioManager.isPlaying ? "waveform" : "music.note")
                        .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? .white : Color.appAccent)
                }
                
                Text(track.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(12)
            .appCardStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                audioManager.deleteTrack(track)
                if deviceManager.activeAudioTrack?.id == track.id {
                    deviceManager.stop()
                    deviceManager.activeAudioTrack = nil
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Audio Document Picker

#if os(iOS)
struct AudioDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Support common audio formats
        let types: [UTType] = [.mp3, .wav, .audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: AudioDocumentPicker
        init(_ parent: AudioDocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}
#endif

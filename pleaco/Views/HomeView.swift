//
//  HomeView.swift
//  pleaco
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @ObservedObject var loveSpouseManager = LoveSpouseManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
            // 1. Manual Touch Control
            TouchControlView()
                .padding(.top, 4)

            // 2. Device Programs
            VStack(alignment: .leading, spacing: 12) {
                patternsSection
            }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .scrollClipDisabled()
        .background(Color.surfacePrimary)
    }

    


    // MARK: – Patterns

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

            // 1. Hardware Programs (LoveSpouse only)
            if deviceManager.activeDevice?.type == .lovespouse {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Device Programs", icon: "cpu")
                        .padding(.horizontal, 18)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...9, id: \.self) { index in
                            let isSpeed = index <= 3
                            let title = isSpeed ? speedLabel(index) : "Pattern \(index - 3)"
                            let icon = isSpeed ? "speedometer" : patternIcon(index)
                            
                            PatternCard(
                                title: title,
                                curvePoints: [],
                                systemIcon: icon,
                                isSelected: deviceManager.selectedLoveSpouseProgram == index
                            ) {
                                deviceManager.selectLoveSpouseProgram(index)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                }
            } else {
                // No hardware programs available - keep clean
                EmptyView()
            }

        }
    }

    private func speedLabel(_ prog: Int) -> String {
        switch prog {
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        default: return "–"
        }
    }

    private func patternIcon(_ prog: Int) -> String {
        let icons = ["waveform", "waveform.path.ecg", "waveform.path.ecg.rectangle",
                     "chart.bar.fill", "chart.line.uptrend.xyaxis", "bolt.fill"]
        if prog <= 3 { return "speedometer" }
        return icons[(prog - 4) % icons.count]
    }
}

// MARK: – Live Control Card (Keep if still needed elsewhere, or move if restricted)

struct LiveControlCard: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.22) : Color.surfaceSecondary)
                        .frame(width: 64, height: 64)
                        .shadow(color: isSelected ? Color.glowAccent : .clear, radius: 12)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(isSelected ? .white : Color.appAccent)
                }

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .appCardStyle(isSelected: isSelected)
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
    }
}

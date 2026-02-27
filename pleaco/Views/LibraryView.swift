//
//  LibraryView.swift
//  pleaco
//

import SwiftUI

struct LibraryView: View {
    @ObservedObject var deviceManager = DeviceManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                librarySections
                Spacer(minLength: 20)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .scrollClipDisabled()
        .background(Color.surfacePrimary)
    }

    private var librarySections: some View {
        VStack(alignment: .leading, spacing: 32) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

            // 1. Scripts (Custom FunScripts)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Scripts", icon: "scroll")
                    Spacer()
                    FunScriptImportButton()
                }
                .padding(.horizontal, 18)

                if deviceManager.customScripts.isEmpty {
                    Text("No scripts imported")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(deviceManager.customScripts) { script in
                            PatternCard(
                                title: script.name,
                                curvePoints: PatternEngine.sampleFunScriptCurve(script.data, pointCount: 60),
                                isSelected: deviceManager.activeFunScriptId == script.id && deviceManager.selectedLoveSpouseProgram == 0
                            ) {
                                deviceManager.applyNamedFunScript(script)
                            } onDelete: {
                                deviceManager.removeCustomScript(script)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }

            // 2. App Patterns (Software Presets)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "App Patterns", icon: "waveform")
                    .padding(.horizontal, 18)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PatternEngine.navigablePresets, id: \.self) { preset in
                        PatternCard(
                            title: preset.shortName,
                            curvePoints: PatternEngine.cachedCurves[preset] ?? [],
                            isSelected: deviceManager.selectedPreset == preset
                                && deviceManager.activeFunScript == nil
                                && deviceManager.selectedLoveSpouseProgram == 0
                        ) {
                            deviceManager.applyPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

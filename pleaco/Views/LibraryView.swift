//
//  LibraryView.swift
//  pleaco
//

import SwiftUI

struct LibraryView: View {
    @ObservedObject var deviceManager = DeviceManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                librarySections
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .scrollClipDisabled()
        .background(Color.surfacePrimary)
    }

    private var librarySections: some View {
        VStack(alignment: .leading, spacing: 24) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

            // 1. Scripts (Custom FunScripts)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Scripts", icon: "scroll")
                    Spacer()
                    FunScriptImportButton()
                }

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
                }
            }

            // 2. App Patterns (Software Presets)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "App Patterns", icon: "waveform")

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
            }
        }
    }
}

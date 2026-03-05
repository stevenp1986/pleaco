//
//  RemoteView.swift
//  pleaco
//

import SwiftUI

struct RemoteView: View {
    @StateObject private var remote = RemoteManager.shared
    @State private var joinCode: String = ""
    @State private var showServerConfig = false

    private let cardHeight: CGFloat = 72

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. Remote Session
                remoteSection

                // 2. Manual Control (only when connected)
                if remote.state == .connected {
                    TouchControlView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 60)
        }
        .background(Color.surfacePrimary)
    }

    // MARK: - Remote Section

    private var remoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Remote Session", icon: "antenna.radiowaves.left.and.right")

            switch remote.state {
            case .disconnected:
                disconnectedCard
            case .hosting:
                hostingCard
            case .joining:
                joiningCard
            case .connected:
                connectedCards
            }

            serverConfigToggle
        }
    }

    // MARK: - Disconnected
    
    private var disconnectedCard: some View {
        VStack(spacing: 12) { // Reduced spacing between row elements
            // Join Input Field (Premium Style)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundColor(Color.appAccent)
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.appAccent.opacity(0.1)))
                    
                    TextField("6-DIGIT CODE", text: $joinCode)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: joinCode) { old, newValue in
                            joinCode = String(newValue.uppercased().prefix(6))
                        }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardBackground) // Same color as normal cards
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            
            // Action Buttons Row
            HStack(spacing: 12) {
                // Create Button
                Button {
                    remote.hostSession()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(SecondaryButtonStyle())
                
                // Join Button
                Button {
                    remote.joinSession(code: joinCode)
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Join")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(ProminentButtonStyle())
                .disabled(joinCode.count != 6)
                .opacity(joinCode.count == 6 ? 1.0 : 0.5)
            }
        }
    }

    // MARK: - Hosting

    private var hostingCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("Your Code")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(remote.roomCode.isEmpty ? "..." : remote.roomCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.appAccent)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .appCardStyle()

            HStack(spacing: 8) {
                ProgressView()
                Text("Waiting for partner...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            cancelButton
        }
    }

    // MARK: - Joining

    private var joiningCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                Text("Connecting...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .appCardStyle()

            cancelButton
        }
    }

    // MARK: - Connected

    private var connectedCards: some View {
        VStack(spacing: 12) {
            // Status Indicator (Active Branding)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.white.opacity(0.5), radius: 4)
                }
                
                Text("Partner connected")
                    .font(.subheadline.bold())
                
                Spacer()
                
                Text("LIVE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color.appAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .appCardStyle(isSelected: true)
            .foregroundColor(.white)

            // Incoming Activity Card
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.subheadline)
                        .foregroundColor(Color.appAccent)
                    Text("Incoming Signal")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(remote.incomingLevel))%")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.appAccent)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .appCardStyle(isSelected: false)

            // Disconnect Button (styled like Cancel button)
            Button {
                remote.disconnect()
            } label: {
                Text("Disconnect Session")
            }
            .buttonStyle(SecondaryButtonStyle(isDestructive: true))
        }
    }

    // MARK: - Shared Components

    private var cancelButton: some View {
        Button {
            remote.disconnect()
        } label: {
            Text("Cancel")
        }
        .buttonStyle(SecondaryButtonStyle(isDestructive: true))
    }

    private var serverConfigToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Server", icon: "server.rack")
            
            TextField("wss://pleaco.shelf.am", text: $remote.serverAddress)
                .font(.system(size: 14, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .appCardStyle()
        }
        .padding(.top, 12)
    }
}

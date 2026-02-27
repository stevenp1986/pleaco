import SwiftUI
import Combine

struct DevicesView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingAddEditor = false
    @State private var deviceToEdit: SavedDevice? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    devicesSection
                }
                .padding(.top, 24)
                .padding(.bottom, 60)
            }
        }
        .background(Color.surfacePrimary)
        .sheet(isPresented: $showingAddEditor) {
            DeviceEditorSheet(deviceManager: deviceManager, editingDevice: nil)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $deviceToEdit) { device in
            DeviceEditorSheet(deviceManager: deviceManager, editingDevice: device)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: – Devices Section

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Devices", icon: "cable.connector")
                Spacer()
                Button {
                    showingAddEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(Color.appAccent)
                }
            }
            .padding(.horizontal, 18)

            DeviceCard(device: deviceManager.internalDevice, onEdit: { }) {
                dismiss()
            }

            ForEach(deviceManager.devices) { device in
                DeviceCard(device: device, onEdit: {
                    deviceToEdit = device
                }) {
                    dismiss()
                }
            }
        }
    }
}

// MARK: – Settings Section Card

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.semibold))
                .foregroundColor(Color.appAccent.opacity(0.9))
                .padding(.horizontal, 4)

            content
                .padding(16)
                .appCardStyle()
        }
        .padding(.horizontal, 18)
    }
}

// MARK: – Device Card

struct DeviceCard: View {
    @ObservedObject var device: SavedDevice
    @ObservedObject var deviceManager = DeviceManager.shared
    var onEdit: () -> Void
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 1. Selection Area (Icon & Text)
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            deviceManager.activeDeviceId == device.id
                                ? AnyShapeStyle(Color.white.opacity(0.15))
                                : AnyShapeStyle(Color.surfaceSecondary)
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: device.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : Color.appAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(device.name) (\(device.type.rawValue))")
                        .font(.subheadline.bold())
                        .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : .primary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(deviceManager.activeDeviceId == device.id ? Color.white.opacity(0.8) : (device.isConnected ? Color.appAccent.opacity(0.85) : Color.gray))
                            .frame(width: 5, height: 5)

                        Text(device.isConnected ? "Verbunden" : "Nicht verbunden")
                            .font(.system(size: 11))
                            .foregroundColor(deviceManager.activeDeviceId == device.id ? .white.opacity(0.7) : .secondary)
                    }
                }
                
                Spacer()
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    deviceManager.setActiveDevice(device)
                    onSelect()
                }
            }

            // 2. Edit Button (Pencil icon)
            if device.type != .internal {
                Button(action: onEdit) {
                    ZStack {
                        Circle()
                            .fill(deviceManager.activeDeviceId == device.id ? Color.white.opacity(0.2) : Color.surfaceSecondary)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : Color.appAccent)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .appCardStyle(isSelected: deviceManager.activeDeviceId == device.id)
        .padding(.horizontal, 18)
        .animation(.easeInOut(duration: 0.2), value: deviceManager.activeDeviceId)
        .animation(.easeInOut(duration: 0.2), value: device.isConnected)
    }
}

// MARK: – Device Editor Sheet

struct DeviceEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var deviceManager: DeviceManager

    let editingDevice: SavedDevice?

    @State private var deviceName = ""
    @State private var deviceType: DeviceType = .handy
    @State private var connectionKey = ""
    @State private var serverAddress = "ws://127.0.0.1:12345"

    init(deviceManager: DeviceManager, editingDevice: SavedDevice?) {
        self.deviceManager = deviceManager
        self.editingDevice = editingDevice

        _deviceName = State(initialValue: editingDevice?.name ?? "")
        _deviceType = State(initialValue: editingDevice?.type ?? .handy)
        _connectionKey = State(initialValue: editingDevice?.connectionKey ?? "")
        _serverAddress = State(initialValue: editingDevice?.serverAddress ?? "ws://127.0.0.1:12345")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    if editingDevice == nil {
                        Picker("Type", selection: $deviceType) {
                            ForEach([DeviceType.handy, .oh, .intiface, .lovespouse, .ossm], id: \.self) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                }
                                .tag(type)
                            }
                        }
                    } else {
                        LabeledContent("Type", value: deviceType.rawValue)
                    }

                    TextField("Device Name", text: $deviceName)
                }

                if deviceType == .handy || deviceType == .oh {
                    Section("Connection") {
                        SecureField("Connection Key", text: $connectionKey)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Here's how to find your connection key:")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("1. Open the \(deviceType.rawValue) App\n2. Go to Settings › Connection Key\n3. Copy the key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else if deviceType == .intiface {
                    Section("Server") {
                        TextField("WebSocket Address", text: $serverAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        Text("Default: ws://127.0.0.1:12345")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if deviceType == .lovespouse || deviceType == .ossm {
                    Section("Bluetooth") {
                        Label("Direct connection via BLE", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundColor(.accentColor)

                        let helpText = deviceType == .lovespouse 
                            ? "Pleaco sends BLE advertisement packets directly from the iPhone to the toy - just like the official app. No gateway needed. The app must run in the foreground."
                            : "Pleaco connects directly to your OSSM over Bluetooth Low Energy. The device must be in Bluetooth mode."

                        Text(helpText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }

                if let device = editingDevice {
                    Section {
                        Button(role: .destructive) {
                            deviceManager.removeDevice(device)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Device")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfacePrimary)
            .onAppear {
                if let device = editingDevice {
                    deviceName = device.name
                    deviceType = device.type
                    connectionKey = device.connectionKey
                    serverAddress = device.serverAddress
                }
            }
            .navigationTitle(editingDevice == nil ? "Add Device" : "Edit Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDevice()
                    }
                    .disabled((deviceType == .handy || deviceType == .oh) && connectionKey.isEmpty)
                    .tint(Color.appAccent)
                }
            }
        }
    }

    private func saveDevice() {
        if let device = editingDevice {
            device.name = deviceName.isEmpty ? device.name : deviceName
            device.connectionKey = connectionKey
            device.serverAddress = serverAddress

            deviceManager.objectWillChange.send()
            deviceManager.saveDevices()

            if deviceManager.activeDeviceId == device.id {
                deviceManager.setActiveDevice(device)
            }
        } else {
            let newDevice = SavedDevice(
                id: UUID(),
                name: deviceName.isEmpty ? "Neues \(deviceType.rawValue)" : deviceName,
                type: deviceType,
                connectionKey: connectionKey,
                serverAddress: serverAddress
            )
            deviceManager.addDevice(newDevice)
        }
        dismiss()
    }
}

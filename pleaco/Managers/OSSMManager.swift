//
//  OSSMManager.swift
//  pleaco
//
//  Controls OSSM hardware via BLE.
//

import Foundation
import CoreBluetooth
import Combine

class OSSMManager: NSObject, ObservableObject {
    static let shared = OSSMManager()

    // MARK: - Constants
    private let serviceUUID = CBUUID(string: "522b443a-4f53-534d-0001-420badbabe69")
    private let commandCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-1000-420badbabe69")
    private let stateCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-2000-420badbabe69")
    private let patternCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-3000-420badbabe69")
    private let patternDescriptionCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-3010-420badbabe69")
    private let commandKnobCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-1010-420badbabe69")

    // MARK: - Published State
    @Published var isConnected: Bool = false
    @Published var isReady: Bool = false
    @Published var deviceState: String = "idle"
    @Published var availablePatterns: [OSSMPattern] = []
    @Published var lastRequestedDescriptionIndex: Int?
    @Published var patternDescriptions: [Int: String] = [:]

    // Stroker mode: syncs depth and stroke length
    @Published var strokerMode: Bool = false

    // MARK: - Private
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var stateCharacteristic: CBCharacteristic?
    private var descriptionCharacteristic: CBCharacteristic?
    private var knobCharacteristic: CBCharacteristic?

    private var connectionCompletion: ((Bool) -> Void)?
    private var lastState: String = ""

    // Write mutex — prevents BLE command flooding (matches reference isWriting flag)
    private var isWriting: Bool = false

    // Throttling state to prevent BLE flood
    private var lastSentSpeed: Int?
    private var lastSentDepth: Int?
    private var lastSentStroke: Int?
    private var lastSentSensation: Int?

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func startScanning(completion: @escaping (Bool) -> Void) {
        self.connectionCompletion = completion

        guard centralManager.state == .poweredOn else {
            completion(false)
            return
        }

        NSLog("🔵 OSSMManager: Starting scan for OSSM...")
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)

        // Timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if let self = self, self.centralManager.isScanning {
                self.centralManager.stopScan()
                if !self.isConnected {
                    NSLog("🔵 OSSMManager: Scan timeout")
                    self.connectionCompletion?(false)
                    self.connectionCompletion = nil
                }
            }
        }
    }

    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetState()
    }

    func stop() {
        // set:speed:0 pauses the motor without leaving strokeEngine mode
        sendCommand("set:speed:0")
        lastSentSpeed = 0
    }

    func setLevel(_ level: Double) {
        let speed = Int(max(0, min(100, level)))

        if deviceState != "strokeEngine" && deviceState != "pattern" {
            // Must enter strokeEngine before sending speed
            sendCommand("go:strokeEngine")
            deviceState = "strokeEngine"
        }

        if speed != lastSentSpeed {
            sendCommand("set:speed:\(speed)")
            lastSentSpeed = speed
        }
    }

    // FunScript mode: map position (0–100) to speed (0–100)
    // The OSSM firmware uses strokeEngine mode; position is approximated via speed
    func setDirectPosition(_ position: Double) {
        setLevel(position)
    }

    // Streaming mode entry point — we use strokeEngine since firmware doesn't support streaming
    func startStreamingMode() {
        if deviceState != "strokeEngine" && deviceState != "pattern" {
            sendCommand("go:strokeEngine")
            deviceState = "strokeEngine"
        }
        NSLog("🔌 OSSMManager: FunScript mode active (strokeEngine)")
    }

    func setDepth(_ depth: Double, syncStroke: Bool = true) {
        let val = Int(max(0, min(100, depth)))

        if val != lastSentDepth {
            sendCommand("set:depth:\(val)")
            lastSentDepth = val
        }

        if strokerMode && syncStroke {
            // derivedStroke = Math.round((value - 50) * 2)
            let derivedStroke = max(0.0, min(100.0, Double((val - 50) * 2)))
            setStroke(derivedStroke, syncDepth: false)
        }
    }

    func setStroke(_ stroke: Double, syncDepth: Bool = true) {
        let val = Int(max(0, min(100, stroke)))

        if val != lastSentStroke {
            sendCommand("set:stroke:\(val)")
            lastSentStroke = val
        }

        if strokerMode && syncDepth {
            // derivedDepth = Math.round((value / 2) + 50)
            let derivedDepth = max(0.0, min(100.0, Double(val / 2 + 50)))
            setDepth(derivedDepth, syncStroke: false)
        }
    }

    func setSensation(_ sensation: Double) {
        let val = Int(max(0, min(100, sensation)))

        if val != lastSentSensation {
            sendCommand("set:sensation:\(val)")
            lastSentSensation = val
        }
    }

    func setPattern(_ patternIndex: Int) {
        let clampedIndex = max(0, min(availablePatterns.count - 1, patternIndex))

        // Use the pattern's idx field (not sequential array index) per reference implementation
        let patternIdx: Int
        if clampedIndex < availablePatterns.count {
            patternIdx = availablePatterns[clampedIndex].idx
        } else {
            patternIdx = clampedIndex
        }

        // go:strokeEngine must be active for patterns to run
        if deviceState != "strokeEngine" && deviceState != "pattern" {
            sendCommand("go:strokeEngine")
            deviceState = "strokeEngine"
        }

        sendCommand("set:pattern:\(patternIdx)")
        deviceState = "pattern"

        // Force-reset sensation throttle so value is always sent fresh after pattern change
        lastSentSensation = nil
        setSensation(50)

        // Fetch description if missing
        if patternDescriptions[clampedIndex] == nil {
            lastRequestedDescriptionIndex = clampedIndex
            fetchDescription(for: patternIdx)
        }
    }

    func fetchDescription(for idx: Int) {
        guard let characteristic = descriptionCharacteristic, let peripheral = peripheral else { return }
        lastRequestedDescriptionIndex = idx
        let indexString = String(idx)
        if let data = indexString.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            // After writing, read the result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    // MARK: - Private Methods

    private func sendCommand(_ command: String) {
        guard let peripheral = peripheral,
              let characteristic = commandCharacteristic,
              isReady else {
            NSLog("🔵 OSSMManager: Cannot send (not ready) -> \(command)")
            return
        }

        // Mutex: drop command if a write is already in flight (matches reference isWriting guard)
        guard !isWriting else {
            NSLog("🔵 OSSMManager: Dropped (writing) -> \(command)")
            return
        }

        if let data = command.data(using: .utf8) {
            isWriting = true
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            NSLog("🔵 OSSMManager: Sent -> \(command)")
        }
    }

    private func resetState() {
        peripheral = nil
        commandCharacteristic = nil
        stateCharacteristic = nil
        isConnected = false
        isReady = false
        isWriting = false
        deviceState = "idle"
        lastSentSpeed = nil
        lastSentDepth = nil
        lastSentStroke = nil
        lastSentSensation = nil
        centralManager.stopScan()
    }
}

// MARK: - CBCentralManagerDelegate

extension OSSMManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            resetState()
        }
        NSLog("🔵 OSSMManager: Central state updated to \(central.state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        NSLog("🔵 OSSMManager: Discovered OSSM: \(peripheral.name ?? "Unknown")")
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("🔵 OSSMManager: Connected to peripheral")
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("🔵 OSSMManager: Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        resetState()
        connectionCompletion?(false)
        connectionCompletion = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("🔵 OSSMManager: Disconnected")
        resetState()
    }
}

// MARK: - CBPeripheralDelegate

extension OSSMManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([
                commandCharacteristicUUID,
                stateCharacteristicUUID,
                patternCharacteristicUUID,
                patternDescriptionCharacteristicUUID,
                commandKnobCharacteristicUUID
            ], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == commandCharacteristicUUID {
                self.commandCharacteristic = characteristic
                NSLog("🔵 OSSMManager: Command characteristic ready")
            } else if characteristic.uuid == stateCharacteristicUUID {
                self.stateCharacteristic = characteristic
                NSLog("🔵 OSSMManager: State characteristic ready")
            } else if characteristic.uuid == patternCharacteristicUUID {
                // Read pattern list once
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == patternDescriptionCharacteristicUUID {
                self.descriptionCharacteristic = characteristic
                NSLog("🔵 OSSMManager: Description characteristic ready")
            } else if characteristic.uuid == commandKnobCharacteristicUUID {
                self.knobCharacteristic = characteristic
                // Give BT full control of speed knob
                if let data = "false".data(using: .utf8) {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                }
            }
        }

        // Once we have commandCharacteristic, run startup sequence
        // (patterns may still be loading — we check if command char is set)
        if commandCharacteristic != nil && !isReady {
            runStartupSequence(peripheral: peripheral)
        }
    }

    /// Startup sequence matching reference implementation:
    /// 1. Read current device state
    /// 2. If not already in strokeEngine/error, send go:strokeEngine
    private func runStartupSequence(peripheral: CBPeripheral) {
        guard let stateChar = stateCharacteristic else {
            // No state characteristic yet — mark ready and skip conditional go
            isReady = true
            connectionCompletion?(true)
            connectionCompletion = nil
            NSLog("🔵 OSSMManager: Ready (no state char for startup read)")
            return
        }

        // Read state once to decide whether to send go:strokeEngine
        peripheral.readValue(for: stateChar)
        NSLog("🔵 OSSMManager: Reading state for startup sequence...")
        // Completion handled in didUpdateValueFor — isReady set there after go command
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        if characteristic.uuid == stateCharacteristicUUID {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let state = json["state"] as? String {
                DispatchQueue.main.async {
                    self.deviceState = state
                    if state != self.lastState {
                        NSLog("🔵 OSSMManager: Device State -> \(state)")
                        self.lastState = state
                    }

                    // Startup sequence: if not ready yet, complete initialization now
                    if !self.isReady {
                        NSLog("🔵 OSSMManager: Startup state = \(state)")
                        if !state.contains("strokeEngine") && !state.contains("error") {
                            NSLog("🔵 OSSMManager: Not in strokeEngine, sending go:strokeEngine")
                            self.sendCommandDirect("go:strokeEngine")
                            self.deviceState = "strokeEngine"
                        } else {
                            NSLog("🔵 OSSMManager: Already in strokeEngine/error, skipping go command")
                        }
                        self.isReady = true
                        self.connectionCompletion?(true)
                        self.connectionCompletion = nil
                    }
                }
            }
        } else if characteristic.uuid == patternCharacteristicUUID {
            // Handle Pattern List JSON — patterns have name and idx fields
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let patterns: [OSSMPattern] = json.enumerated().compactMap { (i, obj) in
                    guard let name = obj["name"] as? String else { return nil }
                    let idx = obj["idx"] as? Int ?? i
                    return OSSMPattern(name: name, idx: idx)
                }
                DispatchQueue.main.async {
                    self.availablePatterns = patterns
                    NSLog("🔵 OSSMManager: Discovered \(patterns.count) patterns")
                }
            }
        } else if characteristic.uuid == patternDescriptionCharacteristicUUID {
            if let description = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    if let index = self.lastRequestedDescriptionIndex {
                        self.patternDescriptions[index] = description
                        NSLog("🔵 OSSMManager: Pattern [\(index)] Description -> \(description)")
                        self.lastRequestedDescriptionIndex = nil
                    }
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            NSLog("🔵 OSSMManager: Write error: \(error.localizedDescription)")
        }
        // Clear write mutex so next command can be sent
        DispatchQueue.main.async {
            self.isWriting = false
        }
    }

    // MARK: - Direct send (bypasses isWriting for startup sequence)
    private func sendCommandDirect(_ command: String) {
        guard let peripheral = peripheral,
              let characteristic = commandCharacteristic else { return }
        if let data = command.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            NSLog("🔵 OSSMManager: Direct send -> \(command)")
        }
    }
}

// MARK: - Pattern Model

struct OSSMPattern {
    let name: String
    let idx: Int
}

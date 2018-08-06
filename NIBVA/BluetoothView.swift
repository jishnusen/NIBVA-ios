//
//  ViewController.swift
//  SimpleBLE
//
//  Created by Jishnu Sen on 7/21/18.
//  Copyright © 2018 Jishnu Sen. All rights reserved.
//

import UIKit
import CoreBluetooth

var readings = [Int](repeating: Int(), count: 64)

class BluetoothView: UIViewController, UITextViewDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager?
    var peripheralTest: CBPeripheral?
    
    let serviceUUIDs = [CBUUID(string: "ec00"),
                        CBUUID(string: "ec01"),
                        CBUUID(string: "ec02"),
                        CBUUID(string: "ec03"),
                        CBUUID(string: "ec04"),
                        CBUUID(string: "ec05"),
                        CBUUID(string: "ec06"),
                        CBUUID(string: "ec07")]
    
    var characteristicUUID = [[CBUUID]](repeating: [CBUUID](repeating: CBUUID(), count: 3), count: 8)
    
    var readValues = [Int](repeating: Int(), count: 9)
    var part1 = [Int](repeating: Int(), count: 4) // Diodes 1-4
    var part2 = [Int](repeating: Int(), count: 4) // Diodes 5-8
    var part3 = [Int](repeating: Int(), count: 1) // LED Intensity
    
    public enum AppError : Error {
        case dataCharacteristicNotFound
        case enabledCharactertisticNotFound
        case updateCharactertisticNotFound
        case serviceNotFound
        case invalidState
        case resetting
        case poweredOff
        case unknown
    }
    
    @IBOutlet weak var connectedLabel: UILabel!
    @IBOutlet weak var readLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Treat this as a constructor
        let centralQueue: DispatchQueue = DispatchQueue(label: "org.jishnu.centralQueue", attributes: .concurrent)
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
        
        for i in 0..<8 {
            for j in 0..<3 {
                characteristicUUID[i][j] = CBUUID(string: "ec\(i+1)\(j)")
            }
        }
        
        DispatchQueue.main.async {
            self.readLabel.text = ""
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case .unknown:
            print("Bluetooth Status Unknown")
        case .resetting:
            print("Bluetooth status is RESETTING")
        case .unsupported:
            print("Bluetooth status is UNSUPPORTED")
        case .unauthorized:
            print("Bluetooth status is UNAUTHORIZED")
        case .poweredOff:
            print("Bluetooth status is POWERED OFF")
        case .poweredOn:
            print("Bluetooth status is POWERED ON")
            // Now we can go forward to scan
            DispatchQueue.main.async {
                self.connectedLabel.text = "Scanning"
            }
            centralManager?.scanForPeripherals(withServices: serviceUUIDs)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        peripheralTest = peripheral
        peripheralTest?.delegate = self
        
        centralManager?.stopScan()
        centralManager?.connect(peripheralTest!)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectedLabel.text = "Connected to \(peripheral.name!)"
        }
        peripheralTest?.discoverServices(serviceUUIDs)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectedLabel.text = "Disconnected -- Scanning"
        }
        centralManager?.scanForPeripherals(withServices: serviceUUIDs)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            peripheral.discoverCharacteristics(nil, for: service) // Find every characteristic
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            peripheral.readValue(for: characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        DispatchQueue.main.async {
            self.readLabel.text = "Reading..."
        }
        

        var cnt = 0
        
        for i in 0..<8 {
            for j in 0..<3 {
                if characteristicUUID[i][j] == characteristic.uuid {
                    if j == 0 {
                        part1 = interpretReading(characteristic, isLED: j == 2)
                    } else if j == 1 {
                        part2 = interpretReading(characteristic, isLED: j == 2)
                    } else {
                        part3 = interpretReading(characteristic, isLED: j == 2)
                        readValues = part1 + part2 + part3
                        for k in 0..<9 {
                            DataView.updateDiode(led: i, diode: k, value: String(readValues[k]))
                        }
                    }
                    
                    if i == 7 && j == 2 {
                        DispatchQueue.main.async {
                            self.readLabel.text = "Done reading after notify!"
                        }
                    }
                    cnt += 1
                    if (j == 2) {
                        cnt = 0
                    }
                }
            }
        }
    }
    
    func interpretReading(_ characteristic: CBCharacteristic, isLED: Bool) -> [Int] {
        let readValue = characteristic.value
        print(readValue!.count)
        
        // If sent data is zero it's interpreted as a nullptr, which we don't want
        if (readValue!.count == 0) {
            return [0]
        }
        
        let end = isLED ? 1 : 4
        var val = [Int](repeating: Int(), count: end)
        
        for i in 0..<end {
            let idx = i * 32
            let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
            (readValue! as NSData).getBytes(pointer, range: NSMakeRange(idx, 32))
        
            let anUInt32Pointer = UnsafeMutablePointer<UInt32>(OpaquePointer(pointer))
            val[i] = Int(CFSwapInt32LittleToHost(anUInt32Pointer.pointee))
        }
        return val
    }
    
    @IBAction func onManualRefreshTap(_ sender: Any) {
        for service in peripheralTest!.services! {
            for characteristic in service.characteristics! {
                peripheralTest!.readValue(for: characteristic)
            }
        }
    }
}

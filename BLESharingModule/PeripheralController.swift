import UIKit
import Foundation
import CoreBluetooth
import os

@objc protocol PeripheralControllerDelegate {
    func bleStarted()
    func deviceDetected(_ data: String)
    func dataReceived(_ data: String)
    func dataSent(_ data: String)
    func eomSent(_ data: String)
}

@objc class PeripheralController: NSObject {
    
    @objc weak open var delegate: PeripheralControllerDelegate?
    
    var index: Int = 0
    var dataSource: Array<String>?
    
    var peripheralManager: CBPeripheralManager!
    
    var transferCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    var dataToSend = Data()
    var sendDataIndex: Int = 0
    
    override init()
    {
        dataSource = ["dummy,data,to,be,sent"]
    }
    
    @objc func initData(_sharedData:Array<String>)
    {
        index = 0
        dataSource = _sharedData
    }
    
    @objc func initManager(){
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }
    
    @objc public func start() {
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
    }
    
    @objc public func stop() {
        peripheralManager.stopAdvertising()
    }
    
    @objc func switchChanged(isOn: Bool) {
        if isOn {
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
        } else {
            peripheralManager.stopAdvertising()
        }
    }
    
    static var sendingEOM = false
    static var isEnabled = false
    
    private func sendData() {
        
        guard let transferCharacteristic = transferCharacteristic else {
            return
        }
        
        if PeripheralController.sendingEOM {
            
            let didSend = peripheralManager.updateValue("EOM".data(using: .utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            if didSend {
                PeripheralController.sendingEOM = false
            }
            
            return
        }
        
        
        if sendDataIndex >= dataToSend.count {
            return
        }
        
        var didSend = true
        while didSend {
            
            var amountToSend = dataToSend.count - sendDataIndex
            if let mtu = connectedCentral?.maximumUpdateValueLength {
                amountToSend = min(amountToSend, mtu)
            }
            
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
            
            didSend = peripheralManager.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            if !didSend {
                return
            }
            
            self.delegate?.dataSent("data sent index")
            
            sendDataIndex += amountToSend
            if sendDataIndex >= dataToSend.count {
                
                if (index + 1 < dataSource!.count) {
                    index += 1
                    
                    sendNextString()
                }
                else {
                    PeripheralController.sendingEOM = true
                    let eomSent = peripheralManager.updateValue("EOM".data(using: .utf8)!,
                                                                for: transferCharacteristic, onSubscribedCentrals: nil)
                    
                    if eomSent {
                        PeripheralController.sendingEOM = false
                        self.delegate?.eomSent("finished sending data")
                        index = 0
                    }
                    return
                }
            }
        }
    }
    
    private func setupPeripheral() {
        
        let transferCharacteristic = CBMutableCharacteristic(type: TransferService.characteristicUUID,
                                                             properties: [.notify, .writeWithoutResponse],
                                                             value: nil,
                                                             permissions: [.readable, .writeable])
        
        let transferService = CBMutableService(type: TransferService.serviceUUID, primary: true)
        
        transferService.characteristics = [transferCharacteristic]
        peripheralManager.add(transferService)
        self.transferCharacteristic = transferCharacteristic
        
    }
}

extension PeripheralController: CBPeripheralManagerDelegate {

    internal func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        PeripheralController.isEnabled = peripheral.state == .poweredOn
        
        switch peripheral.state {
        case .poweredOn:
            os_log("poweredOn")
            setupPeripheral()
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
            self.delegate?.bleStarted()
        case .poweredOff:
            os_log("poweredOff")
            return
        case .resetting:
            return
        case .unauthorized:
            if #available(iOS 13.0, *) {
                switch peripheral.authorization {
                case .denied:
                    os_log("not auth")
                case .restricted:
                    os_log("restricted")
                default:
                    os_log("wrong auth")
                }
            } else {
            }
            return
        case .unknown:
            return
        case .unsupported:
            return
        @unknown default:
            return
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
       
        index = 0;
        
        self.delegate?.deviceDetected("new device detected")
        
        connectedCentral = central
        sendNextString()
    }
    
    func sendNextString(){
        let str = dataSource?[index]
        
        dataToSend = str!.data(using: .utf8)!
        sendDataIndex = 0
        
        sendData()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        connectedCentral = nil
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendData()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for aRequest in requests {
            guard let requestValue = aRequest.value,
                let stringFromData = String(data: requestValue, encoding: .utf8) else {
                    continue
            }
            
            if stringFromData == "received" {
                index = 0
            }
            
            self.delegate?.dataReceived(stringFromData)
        }
    }
}

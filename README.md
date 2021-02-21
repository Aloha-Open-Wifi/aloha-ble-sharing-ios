# aloha-ble-sharing-ios
## Bluetooth Low Energy sharing module for iOS

This module is used to broadcast and receive data between iOS devices without pairing. 
The devices will listen in the background, broadcast/receive data when in range and notify users via a PushNotification.

# Usage:

## PeripheralController - used to broadcast data.

It uses an array of strings as a data source.
It checks for bluetooth permissions and once the bluetooth it's turned on it will start listening for nearby devices.
Once a device is in range and has a strong signal, it will start broadcasting the itemes from dataSource array. An end of message (EOM) will be sent after all the messages. 

Initialization:

> @property (strong, nonatomic)PeripheralController *peripheral;
> [..]  
> self.peripheral = [[PeripheralController alloc] init];
> self.peripheral.delegate = self;
> [self.peripheral initManager];

Delegates: 

> @objc protocol PeripheralControllerDelegate {
>    func bleStarted()
>    func deviceDetected(_ data: String)
>    func dataReceived(_ data: String)
>    func dataSent(_ data: String)
>    func eomSent(_ data: String)
>}

## CentralController - used to receive data

It listens for nearby devices.
Once a device was detected it will start listening for messages.
It will listen for messages until EOM is received.

Initialization:

> @property (strong, nonatomic)CentralController *central;
> [..]
> self.central = [[CentralController alloc] init];
> self.central.delegate = self;

Delegates:

> @objc protocol CentralControllerDelegate {
>    func dataReceived(_ data: String)
>    func eomReceived(_ data: String)
> }


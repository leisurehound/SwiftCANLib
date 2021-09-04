# SwiftCANLib

SwiftCANLib is a library used to process Controller Area Network (CAN) frames utilizing the Linux kernel open source library [SOCKETCAN.](https://www.kernel.org/doc/Documentation/networking/can.txt)
This library has been tested with Rapsbian Buster, arm32 & arm64, on a Raspberry Pi 4.  It will not compile and run on macOS/iOS/iPadOS/tvOS because SOCKETCAN is not distributed on these platforms.

This is not an officially supported Google product.

# How to add SwiftCANLib to your project
In your Package.swift file add the rollowing dependency:
```
https://github.com/leisurehound/swiftcanlib.git
```
Import SwiftCANLib in files where your project will interact with the CAN interface on your device
```
#import SwiftCANLib
```
Create a set of signals & calibrations for the frames you're interested in:
```
let speedSignal = CANCalibrations.Signal(name: "Speed",
                                            unit: "km/h",
                                            dataLength: 16, startBit: 32,
                                            endianness: .bigEndian,
                                            isSigned: false,
                                            offset: -100.0,
                                            gain: 0.01)
let rpmSignal = CANCalibrations.Signal(name: "Engine Speed",
                                            unit: "rpm",
                                            dataLength: 0, startBit: 16,
                                            endianness: .bigEndian,
                                            isSigned: false,
                                            offset: 0.0,
                                            gain: 1.0)
```
Add signals to a frame calibration:
```
let frame100Calibration = CANCalibrations.Calibration(frameID: 0x100, signals: [speedSignal])
let frame120Calibration = CANCalibrations.Calibration(frameID: 0x120, signals: [rpmSignal])
```
Add the frame calibrations to the CANCalibrations object:
```
let calibrations = CANCalibrations(calibrations: [speedCalibration, engineCalibration], delegate: self)
```
Create the CANInterface object, injecting the calibrations you're interested from that interface:
```
let primaryCAN = CANInterface(name: "can1", filters: [0x100,0x120], calibrations: calibrations)

```
Create a delegate object that conforms the `CANCalibrationsListenerDelegate` and implement the `processCalibratedData` method:
```
func processCalibratedData(_ calibrations: CANCalibrations, calibratedData: CANCalibrations.CalibratedData) {

  for 

}
}
```

# Caveats

The library supports both little and big endian frames on big and little endian platforms.  However, there are currently no big endian platforms 
that support Swift, thus running on a big endian platform is complete untested.  Big and little endian frames on a little endian platform is 
supported and tested by unit tests.

Note that Swift does not use SOCKETCAN directly.  Swift currently will not link correctly against the CSocketCAN module on Linux thus a C language bridge module is utlized to make the SOCKETCAN calls.

# License
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License.
You may obtain a copy of the License at https://www.apache.org/licenses/LICENSE-2.0

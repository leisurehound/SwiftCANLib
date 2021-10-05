//  Copyright 2021 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation
import SwiftCANLib

class SwiftCANLibExampleProcessor : CANCalibrationsListenerDelegate {
  
  private var primaryCAN: CANInterface? = nil
  
  init() {
    
    // Setup the signals that you want to calibrate
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
    
    // Added the signals to the various frame calibrations where those signals are sent
    let frame100Calibration = CANCalibrations.FrameDefinition(frameID: 0x100, signals: [speedSignal])
    let frame120Calibration = CANCalibrations.FrameDefinition(frameID: 0x120, signals: [rpmSignal])
    
    // Add all the frame calibrations to CANCalibrations
    let calibrations = CANCalibrations(frames: [frame100Calibration, frame120Calibration], delegate: self)
    
    // Create the CANInterface with the appropriate canlibrations for frames you are intrested in
    // If the inititialization is successful, the interface starts listening immediately
    primaryCAN = CANInterface(name: "can1", filters: [0x100,0x120], calibrations: calibrations)
    
  }
  
  // Delegate method where CANCalibrations are sent for further processing
  func processCalibratedData(_ calibrations: CANCalibrations, calibratedData: CANCalibrations.CalibratedData) {
    for (signalName, datum) in calibratedData.signals {
      print("Received data for \(signalName) of value \(datum.value) \(datum.unit)")
    }
  }
  
}

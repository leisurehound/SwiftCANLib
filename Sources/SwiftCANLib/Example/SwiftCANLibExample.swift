import Foundation
import SwiftCANLib

class SwiftCANLibExampleProcessor : CANCalibrationsListenerDelegate {
  
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
    let frame100Calibration = CANCalibrations.Calibration(frameID: 0x100, signals: [speedSignal])
    let frame120Calibration = CANCalibrations.Calibration(frameID: 0x120, signals: [rpmSignal])
    
    // Add all the frame calibrations to CANCalibrations
    let calibrations = CANCalibrations(calibrations: [frame100Calibration, frame120Calibration], delegate: self)
    
    // Create the CANInterface with the appropriate canlibrations for frames you are intrested in
    // If the inititialization is successful, the interface starts listening immediately
    let primaryCAN = CANInterface(name: "can1", filters: [0x100,0x120], calibrations: calibrations)
    
    
  }
  
  // Delegate method where CANCalibrations are sent for further processing
  func processCalibratedData(_ calibrations: CANCalibrations, calibratedData: CANCalibrations.CalibratedData) {
    for (signalName, datum) in calibratedData.signals {
      print("Received data for \(signalName) of value \(datum.value) \(datum.unit)")
    }
  }
  
}

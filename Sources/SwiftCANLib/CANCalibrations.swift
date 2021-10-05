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
#if os(macOS)
import mockcanhelpers
#elseif os(Linux)
import canhelpers
#endif

/// Delegate methods called when CAN messages are received and calibrated to engineering units.
public protocol CANCalibrationsListenerDelegate {
  func processCalibratedData(_ calibrations: CANCalibrations, calibratedData: CANCalibrations.CalibratedData)
}

/// The set of Calibrations translating frames from a CAN interface to engineering units.  Typically, the CANCalibrations is constructor injected to the CANInterface object.
/// CANCalibrations stores a set of CANCalibrations.Calibration, one for each CAN frameID, and each CANCalibrations.Signal represents the the data in the frameID's payload
public class CANCalibrations {
  
  /// Error values that can be returned from CANCalibrations
  public enum CANCalibrationError : Error {
    case FrameIDNotFound
    case NoDataToCalibrate
    
  }
  
  /// Enum representing a particular frame's endianess.  Typicall Intel based systems are little endian and Motorola based systems are big endian
  public enum Endianness {
    case bigEndian
    case littleEndian
    
    #if os(macOS) || os(iOS) || os(tvOS)
    internal static var systemEndianness: Endianness  = CFByteOrderGetCurrent() == CFByteOrder(CFByteOrderBigEndian.rawValue) ? .bigEndian : littleEndian
    #else
    internal static var systemEndianness: Endianness  = IsSystemLittleEndian() == 1 ? .littleEndian : .bigEndian
    #endif
    
    func signalMatchesPlatformEndianness() -> Bool {
      return self == Endianness.systemEndianness
    }
  }
  
  /// List of  the signals on a given frameID
  public struct FrameDefinition {
    //TODO: maybe this would be better as simply a dictionary of [UInt:[Signal]]
    public init(frameID: UInt, signals: [CANCalibrations.Signal]) {
      self.frameID = frameID
      self.signals = signals
    }
    
    public let frameID: UInt
    public let signals: [Signal]
    
    //TODO:  init from a string from a DBC file
  }
  
  /// Information used to translate a given frame's signal into engineering units.  Typically, a frame will have multiple `Signals`
  public struct Signal {
    let name: String
    let unit: String
    let dataLength: Int // bits
    let startBit: Int
    let endianness: Endianness
    let isSigned: Bool
    let offset: Double
    let gain: Double
    
    /// Creates a new `Signal` representing the information necessary to select the data from a CAN frame's payload and convert it into engineering units
    /// - Parameters:
    ///   - name: Name of the signal, in engineering parlance, e.g. Engine Speed, Fuel Pressure, etc.
    ///   - unit: Units of the signal once the `offset` and `gain` are applied
    ///   - dataLength: Length of the data signal in the frame's payload in bits (i.e. `dataLength` of 16 means create a 2 byte raw data value
    ///   - startBit: bit count from where the data of `dataLength` will be pulled to capture the raw data.  Must be between 0..63
    ///   - endianness: The endianness of the bytes being selected from the frame
    ///   - isSigned: `bool`of whether the data selected from the frame should result in a signed value'
    ///   - offset: offset used in computing the linear calibration from Int bytes to engineering units, i.e. EU = gain * INT + offset
    ///   - gain: gain or multiplier used in computing the linear calibration form Int bytes to engineering units, i.e. EU = gain * INT + offset
    public init(name: String, unit: String, dataLength: Int, startBit: Int, endianness: Endianness, isSigned: Bool, offset: Double, gain: Double) {
      guard dataLength <= 64 else { fatalError("SwiftCANLib: data fields larger than 64 bits are not currently supported") }
      guard startBit + dataLength <= 64 else { fatalError("SwiftCANLib: startbit + datalength spans past 64 bits, which is currently not supported") }
      self.name = name
      self.unit = unit
      self.dataLength = dataLength
      self.startBit = startBit
      self.endianness = endianness
      self.isSigned = isSigned
      self.offset = offset
      self.gain = gain
    }
    
    internal func calibrate(frame: CANInterface.Frame) -> CalibratedDatum? {
      
      // if the raw uncalibrated bytes won't fit into Int64, give up
      guard dataLength / 8 <= MemoryLayout<Int64>.size else { return nil }
      guard startBit + dataLength <= frame.data.count * 8 else { return nil }
      
      
      // create Int64 version of raw bytes, in platform Endianness
      var intValue: UInt64 = frame.data.reversed().reduce(0) { v, byte in
        return v << 8 | UInt64(byte)
      }
      
      //print("\(String(format: "%016lX", intValue)), \(intValue)")
      
      // pick out just the bits defined by user to be the signal, based on endianness
      if CANCalibrations.Endianness.systemEndianness == .bigEndian {
        // this is fully untested, not sure there is a bigEndian swift platform at this time.
        intValue = intValue << startBit
        var mask: UInt64 = 0
        for _ in 0..<dataLength {
          mask = mask << 1 | 1
        }
        if dataLength % 8 != 0 {
          let numBytes: Int = dataLength / 8 + 1
          for _ in 0..<numBytes*8-dataLength {
            mask = mask << 1 | 0
          }
        }
        mask = mask.byteSwapped
        intValue = intValue & mask
      } else {
        intValue = intValue >> startBit
        var mask: UInt64 = 0
        for _ in 0..<dataLength {
          mask = mask << 1 | 1
        }
        if endianness == .bigEndian && dataLength % 8 != 0 {
          let numBytes: Int = dataLength / 8 + 1
          for _ in 0..<numBytes*8-dataLength {
            mask = mask << 1 | 0
          }
        }
        intValue = intValue & mask
      }

      var calibratedValue: Double = 0.0
      var rawIntDatum: Int64 = 0
      
      if (!isSigned && endianness.signalMatchesPlatformEndianness()) || (dataLength <= 8 && !isSigned) { // shortcut for the not modified condition
        calibratedValue = Double(intValue) * gain + offset
        rawIntDatum = Int64(intValue)
        return CalibratedDatum(timestamp: frame.timestamp, name: name, unit: unit, value: calibratedValue, rawIntData: rawIntDatum)
      }
      switch isSigned {
      case false:
        // Once the Int64 is reduced to just the bits we want with leading zeros, reduce to smallest int for required dataLength
        // and swap the bytes if the signal's Endianness definition does not match the platform Endianness, then compute calibrated value
        // the 8 bit case is handled in the shortcut.
        if dataLength <= 16 {
          var datum: UInt16 = UInt16(truncatingIfNeeded: intValue)
          datum = endianness.signalMatchesPlatformEndianness() ? datum : datum.byteSwapped
          rawIntDatum = Int64(datum)
          calibratedValue = Double(datum) * gain + offset
        } else
        if dataLength <= 32 {
          var datum: UInt32 = UInt32(truncatingIfNeeded: intValue)
          datum = endianness.signalMatchesPlatformEndianness() ? datum : datum.byteSwapped
          rawIntDatum = Int64(datum)
          calibratedValue = Double(datum) * gain + offset
        } else
        if dataLength <= 64 {
          var datum: UInt64 = UInt64(truncatingIfNeeded: intValue)
          datum = endianness.signalMatchesPlatformEndianness() ? datum : datum.byteSwapped
          rawIntDatum = Int64(datum)
          calibratedValue = Double(datum) * gain + offset
        }
      case true:
        // Same as above, once the Int64 has the correct bits, reduce to the smallest Int for the length, swap the bytes if necessary, and
        // compute calibrated value
        if dataLength <= 8 {
          let datum: Int8 = Int8(truncatingIfNeeded: intValue)
          rawIntDatum = Int64(datum)
          calibratedValue = Double(datum) * gain + offset
        } else
        if dataLength <= 16 {
          var datum: Int16 = Int16(truncatingIfNeeded: intValue)
          datum = endianness.signalMatchesPlatformEndianness() ? datum : datum.byteSwapped
          rawIntDatum = Int64(datum)
          calibratedValue = Double(datum) * gain + offset
        } else
        if dataLength <= 32 {
          var datum: Int32 = Int32(truncatingIfNeeded: intValue)
          datum = endianness.signalMatchesPlatformEndianness() ? datum : datum.byteSwapped
          rawIntDatum = Int64(datum)
          calibratedValue = Double(datum) * gain + offset
        } else
        if dataLength <= 64 {
          var datum: Int64 = Int64(truncatingIfNeeded: intValue)
          datum = endianness.signalMatchesPlatformEndianness() ? datum : datum.byteSwapped
          rawIntDatum = Int64(datum)
          calibratedValue = Double(datum) * gain + offset
        }
      }
      
      return CalibratedDatum(timestamp: frame.timestamp, name: name, unit: unit, value: calibratedValue, rawIntData: rawIntDatum)

    }
  }
  /// And individual calibrated data point, including the timestamp, name and units of the datum, and the engineering units and raw value of the datum
  public struct CalibratedDatum {
    public let timestamp: TimeInterval
    public let name: String
    public let unit: String
    public let value: Double
    public let rawIntData: Int64
  }
  
  /// The set of all calibrated signals data for a given frame at a single timestamp
  public struct CalibratedData {
    public let timestamp: TimeInterval
    public let signals: [String:CalibratedDatum]
  }
  
  private var frameDefinitions: [UInt:FrameDefinition]
  public private(set) var delegate: CANCalibrationsListenerDelegate?
  
  /// Creeates a new set of `CANCalibrations` from an array of `Calibration`
  /// - Parameters:
  ///   - frames: Array of `Calibration` each element representiing the set of signals  for a frameID
  ///   - delegate: Delegate called when new data arrives and has been successfully calibrated to engineering units
  /// TODO:  We want to setup the calibrations various ways:
  ///  init from DBC file init(url: URL)
  ///  init from a Calibration for a single frame
  ///  init from an array of Calibration for multiple frames
  public init(frames: [FrameDefinition] = [], delegate: CANCalibrationsListenerDelegate?) {
    self.frameDefinitions = [:]
    frames.forEach { calibration in
      self.frameDefinitions[calibration.frameID] = calibration
    }
    self.delegate = delegate
  }
  
  /// Adds (or replaces) set of signals for the given frame ID
  /// - Parameters:
  ///   - frameID: frameID associated with the various signals
  ///   - signals: Array of `Signal` for the calibration strategies for bytes in the payload of the given frameID
  public func addFrame(_ frameID: UInt, signals: [Signal]) {
    frameDefinitions[frameID] = FrameDefinition(frameID: frameID, signals: signals)
  }
  
  /// Removes the calibrations/signals for given frameID, if it iests.
  /// - Parameter frameID: frameID associated with the various signals
  public func removeFrame(_ frameID: UInt) {
    frameDefinitions.removeValue(forKey: frameID)
  }
  
  /// Calibrates a given frame if found in the set of calibrations.  Calls the delegate with calibrated data
  /// - Parameter frame: Swift representation of the CANFrame for calibration.
  /// - Returns: `Result` of `CalibratedData` represending all the signals configured for the frame's payload calibrated to engineering units
  public func calibrate(frame: CANInterface.Frame) -> Result<CalibratedData?, CANCalibrationError> {
    guard let calibration = frameDefinitions[frame.frameID] else { return .failure(.FrameIDNotFound) }
    
    var calibratedSignals: [String:CalibratedDatum] = [:]
    
    for signal in calibration.signals {
      if let calibratedDatum = signal.calibrate(frame: frame) {
        calibratedSignals[calibratedDatum.name] = calibratedDatum
      }
    }
    
    guard !calibratedSignals.isEmpty else { return .failure(.NoDataToCalibrate) }
    
    let calibratedData = CalibratedData(timestamp: frame.timestamp, signals: calibratedSignals)
    delegate?.processCalibratedData(self, calibratedData: calibratedData)
    
    return .success(calibratedData)

  }
  
  
}

//
//  CANCalibrations.swift
//  
//
//  Created by Timothy Wise on 8/19/21.
//

import Foundation
import canhelpers

public protocol CANCalibrationsListener {
  func processCalibratedData(calibratedData: CANCalibrations.CalibratedData)
}

public class CANCalibrations {
  
  public enum Endianness {
    case bigEndian
    case littleEndian
    
    #if os(macOS) || os(iOS) || os(tvOS)
    internal static var systemEndianness: Endianness  = CFByteOrderGetCurrent() == CFByteOrder(CFByteOrderBigEndian.rawValue) ? .bigEndian : littleEndian
    #else
    internal static var systemEndianness: Endianness  = systemIsLittleEndian() == 1 ? .littleEndian : .bigEndian
    #endif
    
    func signalMatchesPlatformEndianness() -> Bool {
      return self == Endianness.systemEndianness
    }
  }
  
  public struct Calibration {
    public init(frameID: UInt, signals: [CANCalibrations.Signal]) {
      self.frameID = frameID
      self.signals = signals
    }
    
    public let frameID: UInt
    public let signals: [Signal]
    
    //TODO:  init from a string from a DBC file BO_
  }
  
  public struct Signal {
    let name: String
    let unit: String
    let dataLength: Int // bits
    let startBit: Int
    let endianness: Endianness
    let isSigned: Bool
    let offset: Double
    let gain: Double
    
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
        mask = mask.byteSwapped
        intValue = intValue & mask
      } else {
        intValue = intValue >> startBit
        var mask: UInt64 = 0
        for _ in 0..<dataLength {
          mask = mask << 1 | 1
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
  public struct CalibratedDatum {
    public let timestamp: TimeInterval
    public let name: String
    public let unit: String
    public let value: Double
    public let rawIntData: Int64
  }
  
  public struct CalibratedData {
    public let timestamp: TimeInterval
    public let signals: [String:CalibratedDatum]
  }
  
  private var calibrations: [UInt:Calibration]
  public private(set) var delegate: CANCalibrationsListener?
  
  //TODO:  We want to setup the calibrations various ways:
  //  init from DBC file init(url: URL)
  //  init from a Calibration for a single frame
  //  init from an array of Calibration for multiple frames
  //  Also want to add/delete/replace a Calibration for a frame
  public init(calibrations: [Calibration] = [], delegate: CANCalibrationsListener?) {
    self.calibrations = [:]
    calibrations.forEach { calibration in
      self.calibrations[calibration.frameID] = calibration
    }
    self.delegate = delegate
  }
  
  public func addFrame(_ frameID: UInt, signals: [Signal]) {
    calibrations[frameID] = Calibration(frameID: frameID, signals: signals)
  }
  
  public func removeFrame(_ frameID: UInt) {
    calibrations.removeValue(forKey: frameID)
  }
  
  public func calibrate(frame: CANInterface.Frame) -> CalibratedData? {
    guard let calibration = calibrations[frame.frameID] else { return nil }
    
    var calibratedSignals: [String:CalibratedDatum] = [:]
    
    for signal in calibration.signals {
      if let calibratedDatum = signal.calibrate(frame: frame) {
        calibratedSignals[calibratedDatum.name] = calibratedDatum
      }
    }
    
    guard !calibratedSignals.isEmpty else { return nil }
    
    let calibratedData = CalibratedData(timestamp: frame.timestamp, signals: calibratedSignals)
    delegate?.processCalibratedData(calibratedData: calibratedData)
    
    return calibratedData

  }
  
  
}

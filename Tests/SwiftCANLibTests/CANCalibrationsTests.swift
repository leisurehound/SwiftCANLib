//
//  CalibrationTests.swift
//  CalibrationTests
//
//  Created by Timothy Wise on 8/20/21.
//

import XCTest
@testable import SwiftCANLib

class CANCalibrationTests: XCTestCase {

  // single byte tests
  
  func testOneByteSignalShortPayloadNoCalibrationFactor() throws {
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 8, startBit: 8, endianness: .littleEndian, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02])
    let calibratedVaue = signal.calibrate(frame: frame)
    XCTAssertEqual(calibratedVaue!.value, Double(0x01), accuracy: 0.01)
  }
  
  func testOneByteSignalFullPayloadNoCalibrationFactor() throws {
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 8, startBit: 40, endianness: .littleEndian, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
    let calibratedVaue = signal.calibrate(frame: frame)
    XCTAssertEqual(calibratedVaue!.value, Double(0x05), accuracy: 0.01)
  }
  
  func testOneByteSignalFullPayloadWithCalibrationFactor() throws {
    
    let gain = 41.0
    let offset = 17.0
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 8, startBit: 40, endianness: .littleEndian, isSigned: false, offset: offset, gain: gain)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
    let calibratedVaue = signal.calibrate(frame: frame)
    XCTAssertEqual(calibratedVaue!.value, Double(0x05) * gain + offset, accuracy: 0.01)
  }
  
  // Same endianness tests
  //   Two Byte tests

    func testTwoByteSignalWithSameEndianessShortPayloadndNoCalibrationFactor() throws {
      let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ? .littleEndian : .bigEndian
      let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 8, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
      
      let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02])
      
      let calibratedVaue = signal.calibrate(frame: frame)
      var expectedValue = 0.0
      switch endianness {
      case .littleEndian: expectedValue = Double(UInt16(0x02) * 2 << 7 + UInt16(0x01))
      case .bigEndian: expectedValue = Double(UInt16(0x01) * 2 << 7 + UInt16(0x02))
      }
      
      XCTAssertEqual(calibratedVaue!.value, expectedValue, accuracy: 0.01)
    }
  
  func testTwoByteSignalMiddlePayloadWithSameEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ? .littleEndian : .bigEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 8, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue = 0.0
    switch endianness {
    case .littleEndian: expectedValue = Double(UInt16(0x02) * 2 << 7 + UInt16(0x01))
    case .bigEndian: expectedValue = Double(UInt16(0x01) * 2 << 7 + UInt16(0x02))
    }
    XCTAssertEqual(calibratedVaue!.value, expectedValue, accuracy: 0.01)
  }

func testTwoByteSignalEndPayloadWithSameEndianessFullPayloadAndNoCalibrationFactor() throws {
  let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ? .littleEndian : .bigEndian
  let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 48, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
  
  let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
  
  let calibratedVaue = signal.calibrate(frame: frame)
  var expectedValue = 0.0
  switch endianness {
  case .littleEndian: expectedValue = Double(UInt16(0x07) * 2 << 7 + UInt16(0x06))
  case .bigEndian: expectedValue = Double(UInt16(0x06) * 2 << 7 + UInt16(0x07))
  }
  
  XCTAssertEqual(calibratedVaue!.value, expectedValue, accuracy: 0.01)
}

func testTwoByteSignalBeginningPayloadWithSameEndianessFullPayloadAndNoCalibrationFactor() throws {
  let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
  let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
  
  let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
  
  let calibratedVaue = signal.calibrate(frame: frame)
  var expectedValue = 0.0
  switch endianness {
  case .littleEndian: expectedValue = Double(UInt16(0x01) * 2 << 7 + UInt16(0x00))
  case .bigEndian: expectedValue = Double(UInt16(0x00) * 2 << 7 + UInt16(0x01))
  }
  
  XCTAssertEqual(calibratedVaue!.value, expectedValue, accuracy: 0.01)
}
  
  func testTwoByteSignalBeginningPayloadWithSameEndianessFullPayloadAndWithCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let gain = 41.0
    let offset = 17.0
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 0, endianness: endianness, isSigned: false, offset: offset, gain: gain)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue = 0.0
    switch endianness {
    case .littleEndian: expectedValue = Double(UInt16(0x01) * 2 << 7 + UInt16(0x00))
    case .bigEndian: expectedValue = Double(UInt16(0x00) * 2 << 7 + UInt16(0x01))
    }
    
    XCTAssertEqual(calibratedVaue!.value, expectedValue * gain + offset, accuracy: 0.01)
  }
  
  func testTwoByteSignedSignalBeginningPayloadWithSameEndianessFullPayloadAndWithCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 0, endianness: endianness, isSigned: true, offset: 0.0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt16 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt16(0x01) * 2 << 7 + UInt16(0x00)
    case .bigEndian: expectedValue = UInt16(0x00) * 2 << 7 + UInt16(0x01)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(Int16(expectedValue)), accuracy: 0.01)
  }
  
  //   Four Byte tests
  func testFourByteSignalBeginningPayloadWithSameEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x03) * 2 << 23 + UInt32(0x02) * 2 << 15
                        expectedValue += UInt32(0x01) * 2 << 7 + UInt32(0x00)
    case .bigEndian: expectedValue = UInt32(0x00) * 2 << 23 + UInt32(0x01) * 2 << 15
                     expectedValue += UInt32(0x02) * 2 << 7 + UInt32(0x03)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testFourByteSignedSignalBeginningPayloadWithSameEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x03) * 2 << 23 + UInt32(0x02) * 2 << 15
                        expectedValue += UInt32(0x01) * 2 << 7 + UInt32(0x00)
    case .bigEndian: expectedValue = UInt32(0x00) * 2 << 23 + UInt32(0x01) * 2 << 15
                     expectedValue += UInt32(0x02) * 2 << 7 + UInt32(0x03)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(Int32(expectedValue)), accuracy: 0.01)
  }
  
  func testFourByteSignalEndingPayloadWithSameEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 32, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x07) * 2 << 23 + UInt32(0x06) * 2 << 15
                        expectedValue += UInt32(0x05) * 2 << 7 + UInt32(0x04)
    case .bigEndian: expectedValue = UInt32(0x04) * 2 << 23 + UInt32(0x05) * 2 << 15
                     expectedValue += UInt32(0x06) * 2 << 7 + UInt32(0x07)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testFourByteSignalMiddlePayloadWithSameEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 24, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x06) * 2 << 23 + UInt32(0x05) * 2 << 15
                        expectedValue += UInt32(0x04) * 2 << 7 + UInt32(0x03)
    case .bigEndian: expectedValue = UInt32(0x03) * 2 << 23 + UInt32(0x04) * 2 << 15
                     expectedValue += UInt32(0x05) * 2 << 7 + UInt32(0x06)
    }
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testFourByteSignalMiddlePayloadWithSameEndianessFullPayloadAndWithCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let gain = 41.0
    let offset = 17.0
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 24, endianness: endianness, isSigned: false, offset: offset, gain: gain)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x06) * 2 << 23 + UInt32(0x05) * 2 << 15
                        expectedValue += UInt32(0x04) * 2 << 7 + UInt32(0x03)
    case .bigEndian: expectedValue = UInt32(0x03) * 2 << 23 + UInt32(0x04) * 2 << 15
                     expectedValue += UInt32(0x05) * 2 << 7 + UInt32(0x06)
    }
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue) * gain + offset, accuracy: 0.01)
  }
  
  //   Eight Byte tests
  func testEightByteSignalFullPayloadWithSameEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 64, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt64 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt64(0x07) * 2 << 55 + UInt64(0x06) * 2 << 47
                        expectedValue += UInt64(0x05) * 2 << 39 + UInt64(0x04) * 2 << 31
                        expectedValue += UInt64(0x03) * 2 << 23 + UInt64(0x02) * 2 << 15
                        expectedValue += UInt64(0x01) * 2 << 7 + UInt64(0x00)
    case .bigEndian: expectedValue = UInt64(0x00) * 2 << 55 + UInt64(0x01) * 2 << 47
                     expectedValue += UInt64(0x02) * 2 << 39 + UInt64(0x03) * 2 << 31
                     expectedValue += UInt64(0x04) * 2 << 23 + UInt64(0x05) * 2 << 15
                     expectedValue += UInt64(0x06) * 2 << 7 + UInt64(0x07)
    }
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testEightByteSignalFullPayloadWithSameEndianessFullPayloadAndWithCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .littleEndian : .bigEndian
    let gain = 41.0
    let offset = 17.0
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 64, startBit: 0, endianness: endianness, isSigned: false, offset: offset, gain: gain)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt64 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt64(0x07) * 2 << 55 + UInt64(0x06) * 2 << 47
                        expectedValue += UInt64(0x05) * 2 << 39 + UInt64(0x04) * 2 << 31
                        expectedValue += UInt64(0x03) * 2 << 23 + UInt64(0x02) * 2 << 15
                        expectedValue += UInt64(0x01) * 2 << 7 + UInt64(0x00)
    case .bigEndian: expectedValue = UInt64(0x00) * 2 << 55 + UInt64(0x01) * 2 << 47
                     expectedValue += UInt64(0x02) * 2 << 39 + UInt64(0x03) * 2 << 31
                     expectedValue += UInt64(0x04) * 2 << 23 + UInt64(0x05) * 2 << 15
                     expectedValue += UInt64(0x06) * 2 << 7 + UInt64(0x07)
    }
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue) * gain + offset, accuracy: 0.01)
  }
  
  //Opposite Endianness tests
  //Two byte tests
  
    func testTwoByteSignalWithOppositeEndianessShortPayloadndNoCalibrationFactor() throws {
      let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ? .bigEndian : .littleEndian
      let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 8, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
      
      let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03])
      
      let calibratedVaue = signal.calibrate(frame: frame)
      
      var expectedValue: UInt16 = 0
      switch endianness {
      case .littleEndian: expectedValue = UInt16(0x02) * 2 << 7 + UInt16(0x01)
      case .bigEndian: expectedValue = UInt16(0x01) * 2 << 7 + UInt16(0x02)
      }
      
      XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
    }
  
    func testTwoByteSignalMiddlePayloadWithOppositeEndianessFullPayloadAndNoCalibrationFactor() throws {
      let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ? .bigEndian : .littleEndian
      let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 8, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
      
      let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
      
      let calibratedVaue = signal.calibrate(frame: frame)
      
      var expectedValue: UInt16 = 0
      switch endianness {
      case .littleEndian: expectedValue = UInt16(0x02) * 2 << 7 + UInt16(0x01)
      case .bigEndian: expectedValue = UInt16(0x01) * 2 << 7 + UInt16(0x02)
      }
      
      XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
    }
  
  func testTwoByteSignalEndPayloadWithOppositeEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ? .bigEndian : .littleEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 48, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
    
    let calibratedVaue = signal.calibrate(frame: frame)
    
    var expectedValue: UInt16 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt16(0x07) * 2 << 7 + UInt16(0x06)
    case .bigEndian: expectedValue = UInt16(0x06) * 2 << 7 + UInt16(0x07)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testTwoByteSignalBeginningPayloadWithOppositeEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ? .bigEndian : .littleEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt16 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt16(0x01) * 2 << 7 + UInt16(0x00)
    case .bigEndian: expectedValue = UInt16(0x00) * 2 << 7 + UInt16(0x01)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  //   Four Byte tests
  func testFourByteSignalBeginningPayloadWithOppositeEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .bigEndian : .littleEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x03) * 2 << 23 + UInt32(0x02) * 2 << 15
                        expectedValue += UInt32(0x01) * 2 << 7 + UInt32(0x00)
    case .bigEndian: expectedValue = UInt32(0x00) * 2 << 23 + UInt32(0x01) * 2 << 15
                     expectedValue += UInt32(0x02) * 2 << 7 + UInt32(0x03)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testFourByteSignedSignalBeginningPayloadWithOppositeEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .bigEndian : .littleEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x03) * 2 << 23 + UInt32(0x02) * 2 << 15
                        expectedValue += UInt32(0x01) * 2 << 7 + UInt32(0x00)
    case .bigEndian: expectedValue = UInt32(0x00) * 2 << 23 + UInt32(0x01) * 2 << 15
                     expectedValue += UInt32(0x02) * 2 << 7 + UInt32(0x03)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(Int32(expectedValue)), accuracy: 0.01)
  }
  
  func testFourByteSignalEndingPayloadWithOppositeEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .bigEndian : .littleEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 32, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x07) * 2 << 23 + UInt32(0x06) * 2 << 15
                        expectedValue += UInt32(0x05) * 2 << 7 + UInt32(0x04)
    case .bigEndian: expectedValue = UInt32(0x04) * 2 << 23 + UInt32(0x05) * 2 << 15
                     expectedValue += UInt32(0x06) * 2 << 7 + UInt32(0x07)
    }
    
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testFourByteSignalMiddlePayloadWithOppositeEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .bigEndian : .littleEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 24, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x06) * 2 << 23 + UInt32(0x05) * 2 << 15
                        expectedValue += UInt32(0x04) * 2 << 7 + UInt32(0x03)
    case .bigEndian: expectedValue = UInt32(0x03) * 2 << 23 + UInt32(0x04) * 2 << 15
                     expectedValue += UInt32(0x05) * 2 << 7 + UInt32(0x06)
    }
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testFourByteSignalMiddlePayloadWithOppositeEndianessFullPayloadAndWithCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .bigEndian : .littleEndian
    let gain = 41.0
    let offset = 17.0
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 32, startBit: 24, endianness: endianness, isSigned: false, offset: offset, gain: gain)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt32 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt32(0x06) * 2 << 23 + UInt32(0x05) * 2 << 15
                        expectedValue += UInt32(0x04) * 2 << 7 + UInt32(0x03)
    case .bigEndian: expectedValue = UInt32(0x03) * 2 << 23 + UInt32(0x04) * 2 << 15
                     expectedValue += UInt32(0x05) * 2 << 7 + UInt32(0x06)
    }
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue) * gain + offset, accuracy: 0.01)
  }
  
  //   Eight Byte tests
  func testEightByteSignalFullPayloadWithOppositeEndianessFullPayloadAndNoCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .bigEndian : .littleEndian
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 64, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt64 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt64(0x07) * 2 << 55 + UInt64(0x06) * 2 << 47
                        expectedValue += UInt64(0x05) * 2 << 39 + UInt64(0x04) * 2 << 31
                        expectedValue += UInt64(0x03) * 2 << 23 + UInt64(0x02) * 2 << 15
                        expectedValue += UInt64(0x01) * 2 << 7 + UInt64(0x00)
    case .bigEndian: expectedValue = UInt64(0x00) * 2 << 55 + UInt64(0x01) * 2 << 47
                     expectedValue += UInt64(0x02) * 2 << 39 + UInt64(0x03) * 2 << 31
                     expectedValue += UInt64(0x04) * 2 << 23 + UInt64(0x05) * 2 << 15
                     expectedValue += UInt64(0x06) * 2 << 7 + UInt64(0x07)
    }
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue), accuracy: 0.01)
  }
  
  func testEightByteSignalFullPayloadWithOppositeEndianessFullPayloadAndWithCalibrationFactor() throws {
    let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ?  .bigEndian : .littleEndian
    let gain = 41.0
    let offset = 17.0
    let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 64, startBit: 0, endianness: endianness, isSigned: false, offset: offset, gain: gain)
    
    let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])

    
    let calibratedVaue = signal.calibrate(frame: frame)
    var expectedValue: UInt64 = 0
    switch endianness {
    case .littleEndian: expectedValue = UInt64(0x07) * 2 << 55 + UInt64(0x06) * 2 << 47
                        expectedValue += UInt64(0x05) * 2 << 39 + UInt64(0x04) * 2 << 31
                        expectedValue += UInt64(0x03) * 2 << 23 + UInt64(0x02) * 2 << 15
                        expectedValue += UInt64(0x01) * 2 << 7 + UInt64(0x00)
    case .bigEndian: expectedValue = UInt64(0x00) * 2 << 55 + UInt64(0x01) * 2 << 47
                     expectedValue += UInt64(0x02) * 2 << 39 + UInt64(0x03) * 2 << 31
                     expectedValue += UInt64(0x04) * 2 << 23 + UInt64(0x05) * 2 << 15
                     expectedValue += UInt64(0x06) * 2 << 7 + UInt64(0x07)
    }
    XCTAssertEqual(calibratedVaue!.value, Double(expectedValue) * gain + offset, accuracy: 0.01)
  }
  

    func testCalibrationPerformance() throws {
      let endianness: CANCalibrations.Endianness = CANCalibrations.Endianness.systemEndianness == .littleEndian ? .bigEndian : .littleEndian
      let signal = CANCalibrations.Signal(name: "Engine Speed", unit: "RPM", dataLength: 16, startBit: 0, endianness: endianness, isSigned: false, offset: 0, gain: 1.0)
      
      let frame = CANInterface.Frame(interface: "Can1", timestamp: 0.0, frameID: 0x001, data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        self.measure {
           _ = signal.calibrate(frame: frame)
        }
    }
static let allTests = [
  ("testEightByteSignalFullPayloadWithOppositeEndianessFullPayloadAndWithCalibrationFactor", testEightByteSignalFullPayloadWithOppositeEndianessFullPayloadAndWithCalibrationFactor),
]

}


//
//  File.swift
//  
//
//  Created by Timothy Wise on 8/13/21.
//

import Foundation
//import CSocketCAN
import canhelpers

private let SIZEOF_CANFD_FRAME = sizeofCANFDFrame()
private let SIZEOF_CAN_FRAME = sizeofCANFrame()

@_cdecl ("SwiftCanLibBridgeModule")                                   //tv_sec is a long on most unixes, but could be a double
public func listeningDelegate(fd: CInt, ptr: UnsafeMutableRawPointer?, tv_sec: CLong, tv_usec: CLong) {
  guard let ptr = ptr, let interface = CANInterface.fdToCANInterfaceMap[fd] else { return }
  
  let deltatime: TimeInterval = TimeInterval(Double(tv_sec) + Double(tv_usec)/1_000_000)
  let data = Data(bytes: ptr, count: Int(SIZEOF_CANFD_FRAME))
  interface.frameProcessingBridge(data: data, timestamp: deltatime)
}

public protocol CANInterfaceRAWListeningDelegate {
  func processFrame(frame: CANInterface.Frame)
}

public class CANInterface {
  
  public struct Frame {
    let interface: String
    let timestamp: TimeInterval
    let frameID: UInt
    let data: [UInt8]
  }
  
  private struct swift_canfd_frame_shim {
    var can_id: UInt32
    var len : UInt8
    var flags: UInt8
    var res0: UInt8
    var res1: UInt8
    var data: [UInt8]
    
    init() {
      can_id = 0
      len = 0
      flags = 0
      res0 = 0
      res1 = 0
      data = []
    }
    
    init?(from data: Data) {
      guard data.count == SIZEOF_CANFD_FRAME else { return nil }
      can_id = data[0...3].withUnsafeBytes { $0.load(as: UInt32.self)}
      len = data[4]
      flags = data[5]
      res0 = data[6]  // should be zeros
      res1 = data[7]
      self.data = []
      for idx in 8..<8+len {
        self.data.append(data[Int(idx)])
      }
    }
  }
  
  //TODO:  this really only supports one CANInterface at the moment, need to make this a thread safe storage
  internal static var fdToCANInterfaceMap = ThreadSafeDictionary<CInt, CANInterface>()
  
  public private(set) var interfaceName: String
  
  private var addr: sockaddr = sockaddr()
  private let listeningQueue: DispatchQueue
  private let delegateQueue: DispatchQueue
  private let socketFD: CInt
  private let candumpToConsole: Bool
  private let interfaceInFDMode: Bool
  private let filters: [Int32]
  private let calibrations: CANCalibrations?
  
  private let RAWlisteningDelegate: CANInterfaceRAWListeningDelegate?
  
  /// Creates a new logical CAN interface bound to the physical CAN interface `interfaceName` via a Socket.  It then commences listening on that socket for CAN frames
  public init?(name: String,
               filters: [Int32] = [],
               calibrations: CANCalibrations? = nil,
               candumpToConsole: Bool = false,
               queue: DispatchQueue = DispatchQueue.main,
               rawDelegate: CANInterfaceRAWListeningDelegate? = nil) {
    
  
    if name.count > IFNAMSIZ {
      return nil
    }
    interfaceName = name
    delegateQueue = queue
    RAWlisteningDelegate = rawDelegate
    self.candumpToConsole = candumpToConsole
    self.filters = filters
    self.calibrations = calibrations

     
    // have to defer this call to C because the parameters PF_CAN, SOCK_RAW & CAN_RAW are not symbols available to swift
    socketFD = getCANSocket()
    if socketFD < 0 {
      return nil
    }
    listeningQueue = DispatchQueue(label: "com.leisurehoundsports.swiftcanlib.listenqueue-\(socketFD)-\(interfaceName)")
    
    // try to put the interface into CAN FD mode
    interfaceInFDMode = tryCANFDOnSocket(socketFD) == 0
    
    // set the interface frame id filters, force sets a 0x7ff mask, the most typical
    if !filters.isEmpty {
      var filterSetResult: Int32 = 0
      _ = filters.withContiguousStorageIfAvailable { ptr in
        filterSetResult = setCANFrameFilters(socketFD, UnsafeMutablePointer<Int32>(mutating: ptr.baseAddress), Int32(truncatingIfNeeded: filters.count))
      }
      if filterSetResult < 0 { return nil }
    }
    
    // Prep the name string into a format that can be sent to C
    let interfaceNameNS = NSString(string: interfaceName)
    let interfaceNamePtr = UnsafeMutablePointer<CChar>(mutating: interfaceNameNS.utf8String)

    let index = getInterfaceIndex(socketFD, interfaceNamePtr)
    
    // binding to socketcan directly in swift requires the import CSocketCan to work, but libsocketcan is not found
    // when setting the path directly to /usr/lib/arm.../libsocketcan.so.2 it then can't fund CDispatch or Dispatch
    //let bindResult = bind(socketFD, &addr, UInt32(MemoryLayout<sockaddr_can>.size))
    let bindResult = bindCANSocket(socketFD, index, &addr);

    if bindResult < 0 {
        return nil
    }

    CANInterface.fdToCANInterfaceMap[socketFD] = self
    listeningQueue.async {
      // this should never return.
      startListening(self.socketFD, &self.addr)
    }
  }
  
  
  deinit {
    if socketFD > 0 {
      close(socketFD)
    }
  }
  
  //TODO: this needs to return a Result type <Int,error> for bytes written, maybe bool, or error 
  public func writeFrame(frameID: Int32, bytes: [UInt8]) -> Int {
    let needsFDFrame: Bool = bytes.count > 8
    var writeResult: Int32 = -1
    if !interfaceInFDMode && needsFDFrame {
      return -1; //TODO send a result type with error
    }
    let len = Int8(truncatingIfNeeded: bytes.count)  
    _ = bytes.withContiguousStorageIfAvailable { ptr in
      switch needsFDFrame {
      case true: writeResult = writeCANFDFrame(socketFD, frameID, len, UnsafeMutablePointer<UInt8>(mutating: ptr.baseAddress))
      case false: writeResult = writeCANFrame(socketFD, frameID, len, UnsafeMutablePointer<UInt8>(mutating: ptr.baseAddress))
      }
    }
    return Int(writeResult)
  }
  
  /// prints the frame in a Bosch CANDUMP format
  private func candump(frame: swift_canfd_frame_shim, timestamp: TimeInterval) {

    var candump: String = "\(String(format: "%012.3f", timestamp)) \(interfaceName) \(String(format:"%02X", frame.can_id))"
    candump += " [\(frame.len)] "
    frame.data.forEach { byte in  
      candump += " \(String(format: "%02x",byte))"
    }
    print("\(candump) in swift")
  }
  
  /// Bridge from the c-decl delegate from the C side, simply builds data info a FrameShim which then passes on to the interface delegate
  internal func frameProcessingBridge(data: Data, timestamp: TimeInterval) {
    
    guard let frame_shim = swift_canfd_frame_shim(from: data) else { return }
    
    if candumpToConsole {
      candump(frame: frame_shim, timestamp: timestamp)
    }
    
    delegateQueue.async {
      // the odds of both delegates populated is minimal, so the creating of the frame twice is likely not superfluous
      if let rawDelegate = self.RAWlisteningDelegate {
        let frame = Frame(interface: self.interfaceName, timestamp: timestamp, frameID: UInt(truncatingIfNeeded: frame_shim.can_id), data: frame_shim.data)
        rawDelegate.processFrame(frame: frame)
      }
      if let calibrations = self.calibrations {
        let frame = Frame(interface: self.interfaceName, timestamp: timestamp, frameID: UInt(truncatingIfNeeded: frame_shim.can_id), data: frame_shim.data)
        _ = calibrations.calibrate(frame: frame)
      }
    }
  }
  
}

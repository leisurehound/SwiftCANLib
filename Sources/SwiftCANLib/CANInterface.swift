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

private let SIZEOF_CANFD_FRAME = SizeofCANFDFrame()
private let SIZEOF_CAN_FRAME = SizeofCANFrame()

/// Bridging global delegate method whre the C module will call with CAN messages.  Looks up the instance of the message by the
/// socket file descriptor and forwards to that instance method for processing back to Swift.  This ideally would be a private method, but
/// given its a not in an object that is impossible.
/// - Parameters:
///   - fd: socket file descriptor where the CAN frame was acquired.
///   - ptr: pointer to the CAN frame for processing
///   - tv_sec: individual element of the `struct timeval` representing the seconds since start of socket
///   - tv_usec: individual element of the `struct timeval` representing the mucro seconds since start of the socket
@_cdecl ("SwiftCanLibBridgeModule")                                   //tv_sec is a long on most unixes, but could be a double
public func listeningDelegate(fd: CInt, ptr: UnsafeMutableRawPointer?, tv_sec: CLong, tv_usec: CLong) {
  guard let ptr = ptr, let interface = CANInterface.fdToCANInterfaceMap[fd] else { return }
  
  let deltatime: TimeInterval = TimeInterval(Double(tv_sec) + Double(tv_usec)/1_000_000)
  let data = Data(bytes: ptr, count: Int(SIZEOF_CANFD_FRAME))
  interface.frameProcessingBridge(data: data, timestamp: deltatime)
}

/// Delegate protocol used to listed to raw uncalibrated CAN frames from the interface.
public protocol CANInterfaceRAWListeningDelegate {
  func processFrame(_ interface: CANInterface, frame: CANInterface.Frame)
}

/// Class representing one Controller Area Network interface
public class CANInterface {
  
  /// Swift representation of CAN_FRAME with interface name, timestamp, frame ID & payload
  public struct Frame {
    let interface: String
    let timestamp: TimeInterval
    let frameID: UInt
    let data: [UInt8]
  }
  
  private struct SwiftCANFDFrameShim {
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
  
  public enum CANInterfaceError : Error {
    case InterfaceNameTooLong
    case CreateSocketFailed
    case SetSockOptFiltersFailed
    case BindToSocketFailed
    case FDCANFramesNotAvailable
    case FileDescriptionNotValid
    case AttemptToWriteToPipeThatIsNotOpen
    case NotConnectedToPeer
    case MemoryAccessErrorOnFrameWrite
    case WriteWasInterruptedBeforeCompletion
    case NonBlockingWriteCouldNotBeWrittenImmediately
    case SizeOfBufferIsGreaterThanSSIZE_MAX
    case UnkownWriteError
  }
  
  // this is the map to take the C non-object delegate method and call the appropriate CANInterface instance
  internal static var fdToCANInterfaceMap = ThreadSafeDictionary<CInt, CANInterface>()
  
  /// Name of the underlying interface named in ifconfig on the platform
  public private(set) var interfaceName: String
  
  private var addr: sockaddr = sockaddr()
  private let listeningQueue: DispatchQueue
  private let delegateQueue: DispatchQueue
  private let socketFD: CInt
  private let candumpToConsole: Bool
  private let interfaceInFDMode: Bool
  private let filters: [Int32]
  private let calibrations: CANCalibrations?
  private var isListening: Int32 = 0 // a C Bool!
  
  private let RAWlisteningDelegate: CANInterfaceRAWListeningDelegate?
  
  /// Creates a new logical CAN interface bound to the physical CAN interface `interfaceName` via a Socket.  It then commences listening on that socket for CAN frames
  /// - Parameters:
  ///   - name: Name of the CAN hardware interface to bind this CANInterface object
  ///   - filters: Array of `[Int32]` representing the Frame IDs to listen for from the hardware interface
  ///   - calibrations: `Calibrations` object representing how to translate raw frame payloads into engineering units
  ///   - candumpToConsole: `Bool` representing whether the interface should display the received frames in CANDUMP-ish format to the console
  ///   - queue: dispatch queue to call the delegate method on
  ///   - rawDelegate: `CANInterfaceRawListeningDelegate` confirming object for receiving raw frames.
  public init(name: String,
               filters: [Int32] = [],
               calibrations: CANCalibrations? = nil,
               candumpToConsole: Bool = false,
               queue: DispatchQueue = DispatchQueue.main,
               rawDelegate: CANInterfaceRAWListeningDelegate? = nil) throws {
    
  
    if name.count > IFNAMSIZ {
      throw CANInterfaceError.InterfaceNameTooLong
    }
    interfaceName = name
    delegateQueue = queue
    RAWlisteningDelegate = rawDelegate
    self.candumpToConsole = candumpToConsole
    self.filters = filters
    self.calibrations = calibrations

     
    // have to defer this call to C because the parameters PF_CAN, SOCK_RAW & CAN_RAW are not symbols available to swift
    socketFD = GetCANSocket()
    if socketFD < 0 {
      throw CANInterfaceError.CreateSocketFailed
    }
    listeningQueue = DispatchQueue(label: "com.leisurehoundsports.swiftcanlib.listenqueue-\(socketFD)-\(interfaceName)")
    
    // try to put the interface into CAN FD mode
    interfaceInFDMode = TryCANFDOnSocket(socketFD) == 0
    
    // set the interface frame id filters, force sets a 0x7ff mask, the most typical
    if !filters.isEmpty {
      var filterSetResult: Int32 = 0
      _ = filters.withContiguousStorageIfAvailable { ptr in
        filterSetResult = SetCANFrameFilters(socketFD, UnsafeMutablePointer<Int32>(mutating: ptr.baseAddress), Int32(truncatingIfNeeded: filters.count))
      }
      if filterSetResult < 0 { throw CANInterfaceError.SetSockOptFiltersFailed }
    }
    
    // Prep the name string into a format that can be sent to C
    let interfaceNameNS = NSString(string: interfaceName)
    let interfaceNamePtr = UnsafeMutablePointer<CChar>(mutating: interfaceNameNS.utf8String)

    let index = GetInterfaceIndex(interfaceNamePtr)
    
    // binding to socketcan directly in swift requires the import CSocketCan to work, but libsocketcan is not found
    // when setting the path directly to /usr/lib/arm.../libsocketcan.so.2 it then can't fund CDispatch or Dispatch
    //let bindResult = bind(socketFD, &addr, UInt32(MemoryLayout<sockaddr_can>.size))
    let bindResult = BindCANSocket(socketFD, index, &addr);

    if bindResult < 0 {
      throw CANInterfaceError.BindToSocketFailed
    }

    CANInterface.fdToCANInterfaceMap[socketFD] = self

  }
  
  
  deinit {
    if socketFD > 0 {
      stopListening()
      close(socketFD)
    }
  }

  public func startListening() {
    isListening = 1
    listeningQueue.async {
      // this should never return.
      StartListening(self.socketFD, &self.addr, &self.isListening)
    }
  }

  public func stopListening() {
    isListening = 0
  }
  
  
  /// Writes `bytes' to the CAN interface on frame `frameID`
  /// - Parameters:
  ///   - frameID: The CAN frame Arbitration identifier to be sent
  ///   - bytes: Array of `[UInt8]` to be written to the CAN interface.  Will write >8 bytes if the hardware supports FD frames
  /// - Returns: `Result` containing the number of bytes written to the interface or a `CANInterfaceError`
  public func writeFrame(frameID: Int32, bytes: [UInt8]) -> Result<Int, CANInterfaceError> {
    let needsFDFrame: Bool = bytes.count > 8
    var writeResult: Int32 = -1
    if !interfaceInFDMode && needsFDFrame {
      return .failure(.FDCANFramesNotAvailable);
    }
    let len = Int8(truncatingIfNeeded: bytes.count)  
    _ = bytes.withContiguousStorageIfAvailable { ptr in
      switch needsFDFrame {
      case true: writeResult = WriteCANFDFrame(socketFD, frameID, len, UnsafeMutablePointer<UInt8>(mutating: ptr.baseAddress))
      case false: writeResult = WriteCANFrame(socketFD, frameID, len, UnsafeMutablePointer<UInt8>(mutating: ptr.baseAddress))
      }
    }
    if writeResult < 0 {
      switch errno {
      case EINVAL: fallthrough
      case EBADF: return .failure(.FileDescriptionNotValid)
      case EPIPE: return .failure(.AttemptToWriteToPipeThatIsNotOpen)
      case EFAULT: return .failure(.MemoryAccessErrorOnFrameWrite)
      case EINTR: return .failure(.WriteWasInterruptedBeforeCompletion)
      case EAGAIN: return .failure(.NonBlockingWriteCouldNotBeWrittenImmediately)
      default:
        return .failure(.UnkownWriteError)
      }
    }
    return .success(Int(writeResult))
  }
  
  /// prints the frame in a Bosch CANDUMP format
  private func candump(frame: SwiftCANFDFrameShim, timestamp: TimeInterval) {

    var candump: String = "\(String(format: "%012.3f", timestamp)) \(interfaceName) \(String(format:"%02X", frame.can_id))"
    candump += " [\(frame.len)] "
    frame.data.forEach { byte in  
      candump += " \(String(format: "%02x",byte))"
    }
    print("\(candump) in swift")
  }
  
  /// Bridge from the c-decl delegate from the C side, simply builds data info a FrameShim which then passes on to the interface delegate
  internal func frameProcessingBridge(data: Data, timestamp: TimeInterval) {
    
    guard let frame_shim = SwiftCANFDFrameShim(from: data) else { return }
    
    if candumpToConsole {
      candump(frame: frame_shim, timestamp: timestamp)
    }
    
    delegateQueue.async {
      // the odds of both delegates populated is minimal, so the creating of the frame twice is likely not superfluous
      if let rawDelegate = self.RAWlisteningDelegate {
        let frame = Frame(interface: self.interfaceName, timestamp: timestamp, frameID: UInt(truncatingIfNeeded: frame_shim.can_id), data: frame_shim.data)
        rawDelegate.processFrame(self, frame: frame)
      }
      if let calibrations = self.calibrations {
        let frame = Frame(interface: self.interfaceName, timestamp: timestamp, frameID: UInt(truncatingIfNeeded: frame_shim.can_id), data: frame_shim.data)
        _ = calibrations.calibrate(frame: frame)
      }
    }
  }
  
}

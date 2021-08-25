# SwiftCANLib

SwiftCANLib is a library used to process Controller Area Network frames utilizing the Linux kernel open source library [SOCKETCAN.](https://www.kernel.org/doc/Documentation/networking/can.txt)
This library has been tested on Rapsbian Buster in a Raspberry Pi 4.  It will not compile and run on macOS/iOS/iPadOS/tvOS because SOCKETCAN is not distributed on these platforms.

# Caveats

The library supports both little and big endian frames on big and little endian platforms.  However, there are currently no big endian platforms 
that support Swift, thus running on a big endian platform is complete untested.  Big and little endian frames on a little endian platform is 
supported and tested by unit tests.

Note that Swift does not use SOCKETCAN directly (even tho there is a CSocketCAN module in this repo).  Swift will not link correctly against the CSocketCAN module on Linux thus a C language bridge module is utlized to make the SOCKETCAN calls.

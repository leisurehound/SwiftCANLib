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

#ifndef __CANHELPERS_H__
#define __CANHELPERS_H__

#include <sys/socket.h>

/// Determines the Endianess of the system the library runs on.  Returns true for Little Endian
int IsSystemLittleEndian();

/// Returns the index of the interface for the given interface name, eg. can1, can0, etc.
int GetInterfaceIndex(int fd, char *name);

/// Creates the socket configured for CAN frames but does not bind the socket, returns the socket file descriptor or -1 for error
int GetCANSocket();

/// Binds the socket fd to the appropriate interface index, returns value > 0 for success
int BindCANSocket(int fd, int ifr_index, struct sockaddr *addr);

/// Attempts to put the socket into FD mode, returns 0 on success
int TryCANFDOnSocket(int fd);

/// Sets the CAN FrameID filters, returns 0 on success
int SetCANFrameFilters(int fd, int *filters, int count);

/// Returns the size of the FD CAN frame, in bytes
int SizeofCANFDFrame();

/// Returns the size of the standard CAN frame, in bytes
int SizeofCANFrame();

/// a blocking call to start listening for can frames, each frame received is returned on the configured delegate
/// NOTE:  do not start this on the main thread
void StartListening(int fd, struct sockaddr *addr);

/// Write a standard CAN frame to the socket, returns 0 on success
int WriteCANFrame(int fd, int32_t id, char len, unsigned char *data);

/// Write an FD CAN frame to the socket, returnds 0 on success
int WriteCANFDFrame(int fd, int32_t id, char len, unsigned char *data);

#endif /* __CANHELPERS.H__ */

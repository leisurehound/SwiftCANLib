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

int systemIsLittleEndian();

int getInterfaceIndex(int fd, char *name);
int getCANSocket();
int bindCANSocket(int fd, int ifr_index, struct sockaddr *addr);
int tryCANFDOnSocket(int fd);
int setCANFrameFilters(int fd, int *filters, int count);
int sizeofCANFDFrame();
int sizeofCANFrame();
void startListening(int fd, struct sockaddr *addr);
int writeCANFrame(int fd, int32_t id, char len, unsigned char *data);
int writeCANFDFrame(int fd, int32_t id, char len, unsigned char *data);

#endif /* __CANHELPERS.H__ */

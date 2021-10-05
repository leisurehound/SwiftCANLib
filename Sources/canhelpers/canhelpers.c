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

//   Snippets of this code are from https://github.com/linux-can/can-utils/blob/master/candump.c
//   Copyright (c) 2002-2009 Volkswagen Group Electronic Research
//   * All rights reserved.
//   *
//   * Redistribution and use in source and binary forms, with or without
//   * modification, are permitted provided that the following conditions
//   * are met:
//   * 1. Redistributions of source code must retain the above copyright
//   *    notice, this list of conditions and the following disclaimer.
//   * 2. Redistributions in binary form must reproduce the above copyright
//   *    notice, this list of conditions and the following disclaimer in the
//   *    documentation and/or other materials provided with the distribution.
//   * 3. Neither the name of Volkswagen nor the names of its contributors
//   *    may be used to endorse or promote products derived from this software
//   *    without specific prior written permission.
//   *

#include <errno.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <linux/can.h>
#include <linux/can/raw.h>

#include "include/canhelpers.h"

int IsSystemLittleEndian() {
  short int twoByteInt = 1;
  char *firstByte = (char *) &twoByteInt;
  return *firstByte == twoByteInt;
}

int GetInterfaceIndex(char *name) {
/// returns interface index of the can interface represented by name, e.g. can0, can1, etc.
  struct ifreq ifr;
  memset(&ifr.ifr_name, 0, sizeof(ifr.ifr_name));
  strncpy(ifr.ifr_name, name, strlen(name));

  ifr.ifr_ifindex = if_nametoindex(ifr.ifr_name);
  return ifr.ifr_ifindex;
}

int GetCANSocket() {
/// simply creates the socket file descriptor configured for CAN
  int fd = socket(PF_CAN, SOCK_RAW, CAN_RAW);
  if (fd < 0) { return fd; }
  const int timestamp_on = 1;
  setsockopt(fd, SOL_SOCKET, SO_TIMESTAMP, &timestamp_on, sizeof(timestamp_on));
  return fd;
}

int BindCANSocket(int fd, int ifr_index, struct sockaddr *sockAddr) {
/// binds the ifr_index interface to the socket file descriptor FD and returns the sockAddr stuct
  struct sockaddr_can addr;
  memset(&addr, 0, sizeof(addr));
  addr.can_family = AF_CAN;
  addr.can_ifindex = ifr_index;
  int ret = bind(fd, (struct sockaddr *)&addr, sizeof(addr));
  return ret;
}

int TryCANFDOnSocket(int fd) {
  const int canfd_on = 1;
  return setsockopt(fd, SOL_CAN_RAW, CAN_RAW_FD_FRAMES, &canfd_on, sizeof(canfd_on));
}

int SetCANFrameFilters(int fd, int *filters, int count) {
  struct can_filter can_filters[count];
  
  for (int i = 0; i < count; i++) {
    can_filters[i].can_id = filters[i];
    can_filters[i].can_mask = 0x7ff;
  }
  return setsockopt(fd, SOL_CAN_RAW, CAN_RAW_FILTER, can_filters, count * sizeof(struct can_filter));  
}
                    
int SizeofCANFDFrame() {
  return sizeof(struct canfd_frame);
}

int SizeofCANFrame() {
  return sizeof(struct can_frame);
}

// setup the bridge for call back to swift with a frame
intptr_t SwiftCanLibBridgeModule(intptr_t, void*, intptr_t, intptr_t);
intptr_t invoke_listeningDelegate(intptr_t fd, void *frame, intptr_t tv_sec, intptr_t tv_usec) {
	return SwiftCanLibBridgeModule(fd, frame, tv_sec, tv_usec);
}
 
static struct timeval base_tv = (struct timeval){0};

void StartListening(int fd, struct sockaddr *addr) {
/// starts listening on the socket and bridges frames back to swift via the listeningDelegate
  fd_set rdfs;
  struct canfd_frame frame;
  struct cmsghdr *cmsg;
  struct msghdr msg;
  struct iovec iov;
  struct timeval tv = (struct timeval){0};
  struct timeval timediff = (struct timeval){0};
  char ctrlmsg[CMSG_SPACE(sizeof(struct timeval)) + CMSG_SPACE(sizeof(__u32))];

  iov.iov_base = &frame;
  msg.msg_name = &addr;
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = &ctrlmsg;

  int running = 1;
  while(running) {

    FD_ZERO(&rdfs);
    FD_SET(fd, &rdfs);

    // the last parameter is the wait timeout, when set to NULL, the select call blocks indefinition
    // (but not a spin busy block
    if (select(fd+1, &rdfs, NULL, NULL, NULL) < 0) {
      running = 0;
      continue;
    }
    // condition true when there is data
    if (FD_ISSET(fd, &rdfs)) {

      /* these settings may be modified by recvmsg() */
	    iov.iov_len = sizeof(frame);
	    msg.msg_namelen = sizeof(addr);
	    msg.msg_controllen = sizeof(ctrlmsg);
	    msg.msg_flags = 0;
	    int nbytes = recvmsg(fd, &msg, 0);
	    if (nbytes < 0) {
	      continue;
	    }
      
      for (cmsg = CMSG_FIRSTHDR(&msg);
           cmsg && (cmsg->cmsg_level == SOL_SOCKET);
           cmsg = CMSG_NXTHDR(&msg,cmsg)) {
        if (cmsg->cmsg_type == SO_TIMESTAMP) {
          memcpy(&tv, CMSG_DATA(cmsg), sizeof(tv));
        } else if (cmsg->cmsg_type == SO_TIMESTAMPING) {

          struct timespec *stamp = (struct timespec *)CMSG_DATA(cmsg);

          /*
           * stamp[0] is the software timestamp
           * stamp[1] is deprecated
           * stamp[2] is the raw hardware timestamp
           * See chapter 2.1.2 Receive timestamps in
           * linux/Documentation/networking/timestamping.txt
           */
          tv.tv_sec = stamp[2].tv_sec;
          tv.tv_usec = stamp[2].tv_nsec/1000;
        }
      }
      
      if (tv.tv_sec != 0 && tv.tv_usec != 0) {
        if (base_tv.tv_sec == 0 && base_tv.tv_usec == 0)
          base_tv = tv;
        timediff.tv_sec = tv.tv_sec - base_tv.tv_sec;
        timediff.tv_usec = tv.tv_usec - base_tv.tv_usec;
      }
      invoke_listeningDelegate(fd, &frame, timediff.tv_sec, timediff.tv_usec);
    }
  }
  return;
}
int WriteCANFrame(int fd, int32_t id, char len,  unsigned char *data) {
  
  if (len > 8)
    return -1;

  struct can_frame frame = (struct can_frame){0};

  frame.can_id = id;
  frame.can_dlc = len;
  
  memcpy(frame.data, data, len);
  return write(fd, &frame, sizeof(frame));
}

int WriteCANFDFrame(int fd, int32_t id, char len, unsigned char *data) {

  if (len > 64)
    return -1;

  struct canfd_frame frame = (struct canfd_frame){0};
  frame.can_id = id;
  frame.len = len;

  memcpy(frame.data, data, len);
  return write(fd, &frame, sizeof(frame));
}

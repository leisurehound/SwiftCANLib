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

#include "./include/canhelpers.h"


int GetInterfaceIndex(char *name) {
  return 1;
}
int GetCANSocket() {
  return 6;
}
int BindCANSocket(int fd, int ifr_index, struct sockaddr *addr) {
  return 0;
}
int TryCANFDOnSocket(int fd) {
  return 0;
}
int SetCANFrameFilters(int fd, int *filters, int count) {
  return 0;
}
int SizeofCANFDFrame() {
  return 80;
}
int SizeofCANFrame() {
  return 30;
}
void StartListening(int fd, struct sockaddr *addr, int *running) {
  
}
int WriteCANFrame(int fd, int32_t id, char len, unsigned char *data) {
  return 0;
}
int WriteCANFDFrame(int fd, int32_t id, char len, unsigned char *data) {
  return 0;
}

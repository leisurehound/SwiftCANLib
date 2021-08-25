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

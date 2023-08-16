// ========================================================================================================
// ========================================================================================================
// *********************************************** common.h ***********************************************
// ========================================================================================================
// ========================================================================================================

#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>  
#include <sys/mman.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h> 
#include <netdb.h> 

#include <time.h>
#include <sys/time.h>
#include <math.h>

// Array constants
#define MAX_DATA_VALS 40096
//#define MAX_HISTO_VALS 2048

// String size
#define MAX_STRING_LEN 2000

#define MAX_SHORT_POS 32767
#define MAX_SHORT_NEG -32768

// NOTE: This is the range I'm using in the hardware. I find the smallest value in the distribution, subtract
// that from all values (shifting the distribution left for negative largest values and right for positive). The
// binning of values therefore starts at bin 0 and goes up through the largest positive value (minus the smallest value).
//#define DIST_RANGE 2048

// Represents +6.25% and -93.75% of 4096
//#define LV_BOUND 256
//#define HV_BOUND 3840

// =================================
// GPIO constants
#define GPIO_0_BASE_ADDR 0x41200000
#define CTRL_DIRECTION_MASK 0x00
#define DATA_DIRECTION_MASK 0xFFFFFFFF

#define OUT_CP_RESET 31
#define OUT_CP_START 30

#define OUT_CP_LM_ULM_DONE 25
#define OUT_CP_HANDSHAKE 24

#define IN_SM_READY 31
#define IN_SM_HISTO_ERR 30
#define IN_SM_HANDSHAKE 28
#include "modp_stdint.h"

#define CHARPAD '='
#define BADCHAR 0xff

/* rfc4648 std version of base32 */
static const char *std_encode_table = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=";

static const char std_decode_table[256] = {
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, 0x1a,    0x1b,    0x1c,    0x1d,    0x1e,    0x1f,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, 0x00,    0x01,    0x02,    0x03,    0x04,    0x05,    0x06,
    0x07,    0x08,    0x09,    0x0a,    0x0b,    0x0c,    0x0d,    0x0e,
    0x0f,    0x10,    0x11,    0x12,    0x13,    0x14,    0x15,    0x16,
    0x17,    0x18,    0x19,    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, 0x00,    0x01,    0x02,    0x03,    0x04,    0x05,    0x06,
    0x07,    0x08,    0x09,    0x0a,    0x0b,    0x0c,    0x0d,    0x0e,
    0x0f,    0x10,    0x11,    0x12,    0x13,    0x14,    0x15,    0x16,
    0x17,    0x18,    0x19,    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
};


/* "Extended Hex Alphabet" version of base32,
 * https://tools.ietf.org/html/rfc4648#section-7
 */
static const char *hex_encode_table = "0123456789ABCDEFGHIJKLMNOPQRSTUV=";

static const char hex_decode_table[256] = {
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    0x0,     0x1,     0x2,     0x3,     0x4,     0x5,     0x6,     0x7,
    0x8,     0x9,     BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, 0xa,     0xb,     0xc,     0xd,     0xe,     0xf,     0x10,
    0x11,    0x12,    0x13,    0x14,    0x15,    0x16,    0x17,    0x18,
    0x19,    0x1a,    0x1b,    0x1c,    0x1d,    0x1e,    0x1f,    BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, 0xa,     0xb,     0xc,     0xd,     0xe,     0xf,     0x10,
    0x11,    0x12,    0x13,    0x14,    0x15,    0x16,    0x17,    0x18,
    0x19,    0x1a,    0x1b,    0x1c,    0x1d,    0x1e,    0x1f,    BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
    BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR, BADCHAR,
};

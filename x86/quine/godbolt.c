/* Type your code here, or load an example. */
#include <stddef.h>
#include <stdint.h>
#include <string.h>
extern void write(char *, int);
extern int open(char *, int);

#define SYMBOL_SIZE (8)
#define symbols ((1U << SYMBOL_SIZE) - 1)
static const unsigned int proot =
    0x11d; /* stands for x^8+x^4+x^3+x^2+1 (see pp.37 of JIS X0510:2004) */
#define min_length (2)
#define max_length (30)
#define max_generatorSize (max_length)

unsigned char alpha[symbols + 1];
unsigned char aindex[symbols + 1];
unsigned char gen[30] = {0xb4, 0xc0, 0x28, 0xee, 0xd8, 0xfb, 0x25, 0x9c,
                         0x82, 0xe0, 0xc1, 0xe2, 0xad, 0x2a, 0x7d, 0xde,
                         0x60, 0xef, 0x56, 0x6e, 0x30, 0x32, 0xb6, 0xb3,
                         0x1f, 0xd8, 0x98, 0x91, 0xad, 0x29};

typedef struct {
    int x;
    int y;
    unsigned char status;
} point_t;
typedef struct {
    unsigned char *data;
    char bitposition;
} bitwriter_t;

// unsigned char bitset(unsigned char data, int bit, bool value) {
//     return (data & ~(1 << bit)) | (value << bit);
// }

typedef struct {
    size_t a;
    size_t b;
} adler_t;

unsigned char modules[40000];

unsigned char run_length[178];
unsigned int run_length_length;
unsigned char *bitmap;
unsigned int num_modules = 177;

unsigned char alignment_pattern[5 * 5] = {};
unsigned char finder_pattern[7 * 7] = {};

void write_pattern(unsigned char *pattern, unsigned int offset, unsigned size);

void apply_mask(unsigned char mask) {
    unsigned char *p = bitmap;
    for (unsigned int i = 0; i < 177; ++i) {
        for (unsigned int j = 0; j < 177; ++j, ++p) {
            if (*p < 0x80) {
                unsigned char v;
                switch (mask) {
                case 0:
                    v = (i + j) % 2 == 0;
                    break;
                case 1:
                    v = i % 2 == 0;
                    break;
                case 2:
                    v = j % 3 == 0;
                    break;
                case 3:
                    v = (i + j) % 3 == 0;
                    break;
                case 4:
                    v = ((i / 2) + (j / 3)) % 2 == 0;
                    break;
                case 5:
                    v = ((i * j) % 2 + (i * j) % 3) == 0;
                    break;
                case 6:
                    v = ((i * j) % 2 + (i * j) % 3) % 2 == 0;
                    break;
                case 7:
                    v = ((i + j) % 2 + (i * j) % 3) % 2 == 0;
                    break;
                default:
                    __builtin_unreachable();
                }
                *p ^= v;
            }
        }
    }
}

void write_alignment(unsigned int d) {
    const unsigned int num_modules = 177;
    const unsigned version = 39;
    unsigned int w = (version + 15) / 7;
    // unsigned int d = 24;
    unsigned int offset = 177 * 6 + 6;
    for (unsigned int y = 0; y < w; ++y) {
        for (unsigned int x = 0; x < w; ++x) {
            if (x == 0 && y == 0) {
                continue;
            }
            if (x == 0 && y == w - 1) {
                continue;
            }
            if (y == 0 && x == w - 1) {
                continue;
            }
            write_pattern(alignment_pattern, offset + d * (177 * y + x), 5);
        }
    }
}
void write_alignment2(unsigned int d) {
    const unsigned int num_modules = 177;
    const unsigned version = 39;
    unsigned int w = (version + 8) / 7;
    // unsigned int d = 24;
    unsigned int offset = 177 * 6 + 6;
    for (unsigned int i = 0; i < w; ++i) {
        write_pattern(alignment_pattern, offset + d * i, 5);
        write_pattern(alignment_pattern, offset + 177 * d * i, 5);
    }
    for (unsigned int y = 1; y <= w; ++y) {
        for (unsigned int x = 1; x <= w; ++x) {
            write_pattern(alignment_pattern, offset + d * (177 * y + x), 5);
        }
    }
}

void write_pattern(unsigned char *pattern, unsigned int offset, unsigned size) {
    unsigned char *dest = bitmap + offset;
    unsigned char *src = pattern;
    for (int y = 0; y < size; ++y) {
        for (int x = 0; x < size; ++x) {
            dest[x] = src[x];
        }
        dest += 177;
        src += size;
    }
}
void write_seperator(unsigned int offset) {
    for (int y = 0; y < 8; ++y) {
        for (int x = 0; x < 8; ++x) {
            bitmap[offset + 177 * y + x] = 0x80;
        }
    }
}

void write_timing() {
    unsigned char *p = bitmap + 6;
    unsigned int i = 177;
    for (int i = 0; i < 177; ++i) {
        unsigned char v = i % 2 == 0 ? 0x81 : 0x80;
        bitmap[177 * 6 + i] = v;
        bitmap[177 * i + 6] = v;
        //*p = v;
        // p += 177;
    }
}

void write_version_info(unsigned int version) {
    const unsigned int num_modules = 177;
    unsigned int v = version;
    for (int x = 0; x < 6; ++x) {
        for (int y = 0; y < 3; ++y) {
            bitmap[177 * (num_modules - 11) + 177 * y + x] = 0x80 | (v & 1);
            v >>= 1;
        }
    }
    v = version;
    for (int y = 0; y < 6; ++y) {
        for (int x = 0; x < 3; ++x) {
            bitmap[num_modules - 11 + 177 * y + x] = 0x80 | (v & 1);
            v >>= 1;
        }
    }
}

void write_format_info(unsigned int format) {
    const unsigned int num_modules = 177;
    for (unsigned int i = 0; i < 15; ++i) {
        unsigned char v = 0x80 + (format & 1);
        if (i < 8) {
            bitmap[177 * 8 + num_modules - 1 - i] = v;
        } else {
            bitmap[177 * (num_modules - 15 + i) + 8] = v;
        }
        if (i < 8) {
            bitmap[177 * (i < 6 ? i : i + 1) + 8] = v;
        } else {
            bitmap[177 * 8 + (i == 8 ? 7 : 14 - i)] = v;
        }
        format >>= 1;
    }
}

int compute_run_length(int stride, int offset) {
    unsigned char prev = 0;
    int count = 0;
    int run_length_idx = 0;
    bitmap += (offset)*stride;
    for (int i = 0; i < 177; ++i) {
        if ((*bitmap ^ prev) & 1) {
            run_length[run_length_idx++] = count;
            count = 1;
        } else {
            count++;
        }
        prev = *bitmap;
        bitmap += stride;
    }
    run_length[run_length_idx++] = count;
    run_length_length = run_length_idx;
}
unsigned int cond_4(unsigned int penalty) {
    unsigned int darks = 0;
    for (unsigned y = 0; y < num_modules; ++y) {
        for (unsigned x = 0; x < num_modules; ++x) {
            if (bitmap[y * 177 + x] & 1) {
                darks += 1;
            }
        }
    }
    int dark_ratio = (200 * darks + 177 * 177) / (177 * 177) / 2;
    int dark_surplus = dark_ratio - 50;
    int dark_abs_surplus = dark_surplus >= 0 ? dark_surplus : -dark_surplus;
    penalty += (dark_abs_surplus / 5) * 10;
    return penalty;
}
unsigned int cond_2(unsigned int penalty) {
    for (unsigned y = 0; y < num_modules - 1; ++y) {
        for (unsigned x = 0; x < num_modules - 1; ++x) {
            unsigned char dark =
                bitmap[y * 177 + x] & bitmap[y * 177 + (x + 1)] &
                bitmap[(y + 1) * 177 + x] & bitmap[(y + 1) * 177 + (x + 1)];
            unsigned char light =
                bitmap[y * 177 + x] | bitmap[y * 177 + (x + 1)] |
                bitmap[(y + 1) * 177 + x] | bitmap[(y + 1) * 177 + (x + 1)];
            if ((dark | (light ^ 0xff)) & 1) {
                penalty += 3;
            }
        }
    }
    return penalty;
}

unsigned int cond_13(unsigned int penalty) {
    for (unsigned int i = 0; i < run_length_length; ++i) {
        if (run_length[i] >= 5) {
            penalty += run_length[i] - 2;
        }
        if (i & 1) {
            unsigned int ratio = run_length[i];
            if (i + 4 < run_length_length) {
                if (run_length[i + 1] == ratio &&
                    run_length[i + 2] == 3 * ratio &&
                    run_length[i + 3] == ratio && run_length[i + 4] == ratio) {
                    //                    if (i == 1 || run_length[i-1] == 4 *
                    //                    ratio){
                    if (run_length[i - 1] == 4 * ratio) {
                        penalty += 40;
                        //                    } else if (i+5 >=
                        //                    run_length_length ||
                        //                    run_length[i+5] == 4 * ratio) {
                    } else if (i + 5 < run_length_length &&
                               run_length[i + 5] == 4 * ratio) {
                        penalty += 40;
                    }
                }
            }
        }
    }
    return penalty;
}

int cond_1() {
    int penalty = 0;
    for (int y = 0; y < 177; ++y) {
        int count = 0;
        int prev = 0;
        int x = 0;
        while (1) {
            unsigned char current = modules[x + 177 * y];
            if (x >= 177 || prev != current) {
                if (count >= 5) {
                    penalty += count - 2;
                    prev = current;
                    count = 0;
                }
                if (x >= 177) {
                    break;
                }
            } else {
                count++;
            }
            x++;
        }
    }
    for (int x = 0; x < 177; ++x) {
        int count = 0;
        int prev = 0;
        int y = 0;
        while (1) {
            unsigned char current = modules[x + 177 * y];
            if (y >= 177 || prev != current) {
                if (count >= 5) {
                    penalty += count - 2;
                    prev = current;
                    count = 0;
                }
                if (y >= 177) {
                    break;
                }
            } else {
                count++;
            }
            y++;
        }
    }
    return penalty;
}

int str_cmp(char *a, char *b) {
    do {
        if (*a != *b)
            return 0;
    } while (*a++ != 0 && *b++ != 0);
    return 1;
}

extern void fun_a();
extern void fun_b();

int open_test() {
    int fd;
    if ((fd = open("test", 0)) > 0) {
        return fd;
    } else {
        fun_b();
    }
}

char *t(char *x, char *b) {
    if (*b == 0) {
        return &x[0];
    } else {
        return &x[1];
    }
}

unsigned int adler32_finish(adler_t state) { return (state.b << 16) | state.a; }

adler_t adler32(adler_t state, unsigned char byte) {
    state.a = (state.a + byte) % 65521;
    state.b = (state.b + state.a) % 65521;
    return state;
}

void bitset(unsigned char *data, int bit, bool value) {
    *data = (*data & ~(1 << bit)) | (value << bit);
}
// bitwriter_t bitstring_put(int bits, int num_bits, bitwriter_t bitwriter) {
//     for (size_t i = num_bits; i --> 0;) {
//         *bitwriter.data &= ~(1 << bitwriter.)
//         *bitwriter.data |= (bits & 0x01 != 0) << bitwriter.bitposition;
//         bits >>= 1;
//         if(bitwriter.bitposition == 7) {
//             bitwriter.data++;
//             bitwriter.bitposition=0;
//         } else {
//             bitwriter.bitposition++;
//         }
//     }
//     return bitwriter;
// }
int le_to_be(int i) {
    return ((i & 0xFF000000) >> 24) | ((i & 0x00FF0000) >> 8) |
           ((i & 0x0000FF00) << 8) | ((i & 0x000000FF) << 24);
}

void fill() {
    unsigned char *bitmap = (unsigned char *)0x80000;
    unsigned char *codewords = (unsigned char *)0x810000;
    point_t point = {.x = 177 - 1, .y = 177 - 1, .status = 0x00};
    unsigned char *cur_bitmap = &bitmap[point.y * 177 + point.x];
    for (int i = 0; i < 3506; ++i) {
        char j = 7;
        do {
            *cur_bitmap = (codewords[0] >> j) & 0x01;
            do {
            retry:
                switch (point.status) {
                case 0x02:
                    if (point.y == 0) {
                        // if (point.x == 7) {
                        //     point.x = 5;
                        // } else {
                        //     point.x--;
                        // }
                        point.x--;
                        if (point.x == 6) {
                            goto retry;
                        }
                        // point.status ^= 0x03;
                        point.status = 0x01;
                    } else {
                        point.y--;
                        point.x++;
                        point.status = 0x00;
                        // point.status ^= 0x02;
                    }
                    break;
                case 0x03:
                    if (point.y == 177 - 1) {
                        point.x--;
                        point.status = 0x00;
                    } else {
                        point.x++;
                        point.y++;
                        point.status = 0x01;
                    }
                    break;
                case 0x01:
                    point.x--;
                    point.status = 0x03;
                    break;
                case 0x00:
                    point.x--;
                    point.status = 0x02;
                    break;
                }
                cur_bitmap = &bitmap[point.y * 177 + point.x];
            } while (*cur_bitmap & 0x80);
        } while (j-- != 0);
        codewords++;
    }
}

typedef struct {
    unsigned char *data;
    size_t length;
    unsigned char ecc[30];
} block_t;

static block_t blocks[25] = {};
static unsigned char codeword_buffer[3506];

void place_codewords() {
    unsigned char *codewords = codeword_buffer;
    for (int j = 0; j < 118; ++j) {
        for (int i = 0; i < 25; ++i) {
            codewords[0] = blocks[i].data[j];
            codewords++;
        }
    }
    for (int i = 19; i < 25; ++i) {
        codewords[0] = blocks[i].data[119];
        codewords++;
    }
    for (int j = 0; j < 30; ++j) {
        for (int i = 0; i < 25; ++i) {
            codewords[0] = blocks[i].ecc[j];
            codewords++;
        }
    }
}

int RSECC_encode(size_t data_length, const unsigned char *data,
                 unsigned char *ecc) {
    size_t ecc_length = 30;
    size_t i, j;
    unsigned char feedback;

    // memset(ecc, 0, ecc_length);

    for (i = 0; i < data_length; i++) {
        feedback = aindex[data[i] ^ ecc[0]];
        if (feedback != symbols) {
            for (j = 1; j < ecc_length; j++) {
                ecc[j] ^= alpha[(unsigned int)(feedback + gen[ecc_length - j]) %
                                symbols];
            }
        }
        for (int j = 0; j < ecc_length - 1; j++) {
            ecc[j] = ecc[j + 1];
        }
        // memmove(&ecc[0], &ecc[1], ecc_length - 1);
        if (feedback != symbols) {
            ecc[ecc_length - 1] =
                alpha[(unsigned int)(feedback + gen[0]) % symbols];
        } else {
            ecc[ecc_length - 1] = 0;
        }
    }

    return 0;
}

void RSECC_initLookupTable(void) {
    unsigned int i, b;

    alpha[symbols] = 0;
    aindex[0] = symbols;

    b = 1;
    for (i = 0; i < symbols; i++) {
        alpha[i] = b;
        aindex[b] = i;
        b <<= 1;
        if (b & (symbols + 1)) {
            b ^= proot;
        }
        b &= symbols;
    }
}

unsigned char *write_mode_and_character_count(unsigned char *data,
                                              unsigned char *data_end,
                                              unsigned char *bitstream) {
    uint16_t character_count = data_end - data;
    bitstream[0] = 0x40 | character_count >> 12;
    bitstream++;
    bitstream[0] = character_count >> 4;
    bitstream++;
    bitstream[0] = character_count << 4;
    return bitstream;
}

void pad_bitstream(unsigned char *bitstream, unsigned char *bitstream_end) {
    bitstream_end = (unsigned char *)0x80000;
    while (1) {
        if (bitstream == bitstream_end)
            return;
        bitstream[0] = 0xec;
        bitstream++;
        if (bitstream == bitstream_end)
            return;
        bitstream[0] = 0x11;
        bitstream++;
    }
}

void move_bitstream(unsigned char *data, unsigned char *data_end,
                    unsigned char *bitstream) {
    bitstream = (unsigned char *)0x80000;
    while (data != data_end) {
        unsigned char d = data[0];
        bitstream[0] |= d >> 4;
        bitstream++;
        bitstream[0] |= d << 4;
        // unsigned char d = (data[0] >> 4) | (data[0] << 4);
        // bitstream[0] |= d & 0x0f;
        // bitstream[1] |= d & 0xf0;
        ++data;
    }
}

void mask(unsigned char *qr) {
    for (int y = 0; y < 177; y++) {
        for (int x = 0; x < 177; x++) {
            if (qr[y * 177 + x] >= 0x80) {
                qr[y * 177 + x] ^= ~((x + y) % 2);
            }
        }
    }
}

void test(char *qr) {
    for (int y = 0; y < 177; y++) {
        for (int x = 0; x < 177; x++) {
            if (qr[y * 177 + x] & 1) {
                write("test", 4);
            } else {
                write("foo", 3);
            }
        }
        write("\n", 1);
    }
}

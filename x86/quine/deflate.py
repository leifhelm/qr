#!/usr/bin/env python3

from compressors.huffman import HuffmanCompressor
from compressors.integer import IntegerCompressor
import zlib
import struct
import segno
import qrcode


def codes(bit_lengths):
    return {
        letter: code
        for code, letter in HuffmanCompressor.generate_decode_table(bit_lengths).items()
    }


literal_length_bit_lengths = [0] * 286
literal_length_bit_lengths[0x00] = 1
literal_length_bit_lengths[0xFF] = 2
literal_length_bit_lengths[256] = 6  # End of block
literal_length_bit_lengths[265] = 4  # Length 11-12
literal_length_bit_lengths[278] = 5  # Length 83-98
literal_length_bit_lengths[282] = 6  # Length 163-194
literal_length_bit_lengths[285] = 3

literal_length_codes = codes(literal_length_bit_lengths)

distance_bit_lengths = [0] * 30
distance_bit_lengths[0] = 2  # distance 1
distance_bit_lengths[14] = 1  # distance 129-192
distance_bit_lengths[16] = 2  # distance 257-384


distance_codes = codes(distance_bit_lengths)

print("literal length codes:", literal_length_codes)
print("distance codes:", distance_codes)


huffman_trees = IntegerCompressor.encode(
    [*literal_length_bit_lengths, *distance_bit_lengths]
)

# code_length_bit_lengths = [0] * 19
# code_length_bit_lengths[0] = 3  # length 0
# code_length_bit_lengths[1] = 3  # length 1
# code_length_bit_lengths[2] = 3  # length 2
# code_length_bit_lengths[4] = 2  # length 4
# code_length_bit_lengths[17] = 0  # run of 3-10 0’s
# code_length_bit_lengths[18] = 2  # run of 11-138 0’s

# code_length_codes = codes(code_length_bit_lengths)


def run_length(data):
    if len(data) == 0:
        return 0
    length = 1
    value = data[0]
    for v in data[1:]:
        if v == value:
            length += 1
        else:
            break
    return length


def rle_huffman_tree(bit_lengths):
    symbols = []
    i = 0
    while i < len(bit_lengths):
        value = bit_lengths[i]
        count = run_length(bit_lengths[i:])
        if count < 3:
            symbols.append((value, None))
            i += 1
        else:
            if value == 0:
                if count >= 3 and count <= 10:
                    symbols.append((17, count - 3))
                    i += count
                elif count >= 11:
                    count = min(138, count)
                    symbols.append((18, count - 11))
                    i += count
            else:
                count = min(6, count)
                symbols.append((16, count - 3))
                i += count
    return symbols


def encode_huffman_tree(bit_lengths):
    symbols = rle_huffman_tree(bit_lengths)
    code_length_bit_lengths, symbol_codes = HuffmanCompressor.create_codes(
        [s[0] for s in symbols], alphabet_length=19
    )
    print(symbols)
    print(code_length_bit_lengths)
    b = bytearray()
    extra_bit_length = {16: 2, 17: 3, 18: 7}
    for s, extra in symbols:
        b += symbol_codes[s]
        if s in extra_bit_length:
            b += f"{extra:0{extra_bit_length[s]}b}".encode()[::-1]
    return (code_length_bit_lengths, b)


def last_non_zero_index(l):
    index = None
    for i, e in enumerate(l):
        if e != 0:
            index = i
    return index


code_length_order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]


def encode_block_header(is_last):
    literal_length_len = max(257, last_non_zero_index(literal_length_bit_lengths) + 1)
    distance_len = max(1, last_non_zero_index(distance_bit_lengths) + 1)
    code_length_bit_lengths, encoded_huffman_tree = encode_huffman_tree(
        literal_length_bit_lengths[:literal_length_len]
        + distance_bit_lengths[:distance_len]
    )
    encoded_code_length_bit_lengths = [
        code_length_bit_lengths[code_length_order[i]] for i in range(19)
    ]
    code_length_len = max(4, last_non_zero_index(encoded_code_length_bit_lengths) + 1)

    print("literal_length_len", literal_length_len)
    print("distance_len", distance_len)
    print("code_length_len", code_length_len)

    b = bytearray(b"1" if is_last else b"0")
    b += b"10"[::-1]  # dynamic
    b += f"{literal_length_len-257:05b}".encode()[::-1]
    b += f"{distance_len-1:05b}".encode()[::-1]
    b += f"{code_length_len-4:04b}".encode()[::-1]

    for bit_length in encoded_code_length_bit_lengths[:code_length_len]:
        b += f"{bit_length:03b}".encode()[::-1]
    b += encoded_huffman_tree
    return bytes(b)


def bitswap_byte(b):
    bits = [1 if ((b << i) & 0x80) != 0 else 0 for i in range(8)]
    swapped = 0
    for i in range(8):
        swapped |= (1 if ((b << i) & 0x80) != 0 else 0) << i
    return swapped


print(f"bitswap {bitswap_byte(0x12):02x}")


class BitStream:
    def __init__(self):
        self.b = bytearray()
        self.i = -1
        self.bit_position = 0

    def append(self, bits):
        for x in bits:
            if self.bit_position == 0:
                self.b.append(0x00)
                self.i += 1
            if x == ord("1"):
                self.b[self.i] |= 1 << self.bit_position
            self.bit_position = (self.bit_position + 1) % 8

    def bit_length(self):
        if self.bit_position == 0:
            return (self.i + 1) * 8
        else:
            return self.i * 8 + self.bit_position

    def print_asm(self):
        print(
            f"    .byte {','.join([f'0x{b:02x}' for b in self.b])} # bit position = {self.bit_position}, bit length = {self.bit_length()}"
        )


header = encode_block_header(True)
print("header bits:", header)
print("header bitlength:", len(header))

bitstream = BitStream()
bitstream.append(header)

length_table = [
    (3, 3, 0),
    (4, 4, 0),
    (5, 5, 0),
    (6, 6, 0),
    (7, 7, 0),
    (8, 8, 0),
    (9, 9, 0),
    (10, 10, 0),
    (11, 12, 1),
    (13, 14, 1),
    (15, 16, 1),
    (17, 18, 1),
    (19, 22, 2),
    (23, 26, 2),
    (27, 30, 2),
    (31, 34, 2),
    (35, 42, 3),
    (43, 50, 3),
    (51, 58, 3),
    (59, 66, 3),
    (67, 82, 4),
    (83, 98, 4),
    (99, 114, 4),
    (115, 130, 4),
    (131, 162, 5),
    (163, 194, 5),
    (195, 226, 5),
    (227, 257, 5),
    (258, 258, 0),
]

distance_table = [
    (1, 0),
    (2, 0),
    (3, 0),
    (4, 0),
    (5, 1),
    (7, 1),
    (9, 2),
    (13, 2),
    (17, 3),
    (25, 3),
    (33, 4),
    (49, 4),
    (65, 5),
    (97, 5),
    (129, 6),
    (193, 6),
    (257, 7),
    (385, 7),
    (513, 8),
    (769, 8),
    (1025, 9),
    (1537, 9),
    (2049, 10),
    (3073, 10),
    (4097, 11),
    (6145, 11),
    (8193, 12),
    (12289, 12),
    (16385, 13),
    (24577, 13),
]


def encode_length(bs, length):
    for i, (start, end, bits) in enumerate(length_table):
        if length >= start and length <= end:
            bs.append(literal_length_codes[i + 257])
            if bits != 0:
                bs.append(f"{length-start:0{bits}b}".encode()[::-1])
            return
    raise ValueError(length)


def encode_distance(bs, distance):
    for i, (start, bits) in enumerate(distance_table):
        if distance >= start and distance < start + 2**bits:
            bs.append(distance_codes[i])
            if bits != 0:
                bs.append(f"{distance-start:0{bits}b}".encode()[::-1])
            return
    raise ValueError


def encode_symbols(bs, symbols):
    for s in symbols:
        if type(s) == int:
            bs.append(literal_length_codes[s])
        else:
            length, distance = s
            encode_length(bs, length)
            encode_distance(bs, distance)


symbols = (
    [0x00, 0xFF, (184, 1)] + [(258, 186)] * 22 + [(90, 186)]
)

encode_symbols(bitstream, symbols)
bitstream.print_asm()
bitstream.append(literal_length_codes[256])  # end

line_start = BitStream()
encode_symbols(line_start, [0x00] + [0xFF] * 4)
print("scanline_start:")
line_start.print_asm()

line_end = BitStream()
encode_symbols(line_end, [0xFF] * 4 + [(258, 186)] * 5 + [(12, 186)])
print("png_scanline_end:")
line_end.print_asm()
print(f"    png_scanline_end_bit_len = {line_end.bit_length()}")

quiet_end = BitStream()
encode_symbols(
    quiet_end,
    [0x00, 0xFF, (184, 1)] + [(258, 186)] * 22 + [(90, 186), 256]
)
print("png_quiet_end:")
quiet_end.print_asm()
print(f"    png_quiet_end_bit_len = {quiet_end.bit_length()}")


# copy_lines = BitStream()
# encode_symbols(copy_lines, [(186, 372)] + [(258, 186)] * 4 + [(84, 186)])
# print("copy_scanline:")
# copy_lines.print_asm()


zbytes = bytearray(b"\x78\x01")
zbytes += bitstream.b

original_data = bytearray()
original_data += (b"\x00" + b"\xff" * 185) * 32
# original_data += b"\x00" + b"\xff" * 4 + b"\x00\xff" * 88 + b"\x00" + b"\xff" * 4
# original_data += (b"\x02" + b"\x00" * 185) * 7


adler32 = zlib.adler32(original_data)
zbytes += struct.pack(">L", adler32)

with open("../../../../c/zlib/test.zlib", "wb") as f:
    f.write(zbytes)


def hex_dump(b):
    i = 0
    while i < len(b):
        print(end=f"{i:04x}:")
        for j in range(16):
            if i >= len(b):
                break
            print(end=f" {b[i]:02x}")
            i += 1
        print()


# hex_dump(original_data)
assert zlib.decompress(zbytes) == original_data


print("Complete zlib stream")
print(f"    .byte {','.join([f'0x{b:02x}' for b in zbytes])}")
print(
    f"    .byte {','.join([f'0x{b:02x}' for b in struct.pack('>L', zlib.crc32(zbytes))])}"
)

print(f"{len(original_data):x}")

with open("../../../../zig/packer/test", "rb") as f:
    data = f.read()
# qrcode = segno.make(data, version=40, mask=0, error="l", boost_error=False)
qrcode = qrcode.QRCode(
    version=40,
    mask_pattern=0,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
)
qrcode.add_data("Hello World")
qrcode.make()
qrcode.print_ascii()

for y in range(177):
    for i in range(8):
        original_data += b"\x00" + b"\xff" * 4
        for x in range(177):
            original_data += b"\x00" if qrcode.modules[y][x] else b"\xff"
        original_data += b"\xff" * 4

print(f"0x1740 {zlib.adler32(original_data[:0x1740]):08x}")
print(original_data[0x1740 : 0x1740 + 186].hex())
for i in range(177):
    print(f"{zlib.adler32(original_data[:0x1740+186*i]):08x}")

crc_table = [0] * 256
for n in range(256):
    c = n
    for k in range(8):
        if (c & 1) != 0:
            c = 0xedb88320 ^ (c >> 1)
        else:
            c >>= 1
    crc_table[n] = c

def png_crc(buf):
    c = 0xffffffff
    for b in buf:
        c = crc_table[(c ^ b) & 0xff] ^ (c >> 8)
    return c

print("PNG CRC")
print(f"{png_crc(b'IEND')^0xffffffff:08x}")
for i in range(4):
    print(f'{png_crc(b"IDAT"[0:i+1]):08x}')


# print("0" + "1" * 186 + ("2" + "0" * 186) * 31)

# print(huffman_trees)

#!/usr/bin/env python3

import sys
import itertools

a = [ord(c) for c in sys.argv[1]]
b = [ord(c) for c in sys.argv[2]]

if len(a) < len(b):
    a += [0x79] * (len(b) - len(a))
if len(b) < len(a):
    b += [0x79] * (len(a) - len(b))

print(a, b)

obfuscated = [a ^ b for a, b in zip(a, b)]
for i, v in enumerate(itertools.batched(obfuscated, n=4)):
    print(
        f"    xor dword ptr [ecx + 0x{i*4:02x}], 0x{v[3]:02x}{v[2]:02x}{v[1]:02x}{v[0]:02x}"
    )

# for a, b in zip(sys.argv[1], sys.argv[2]):


# for code in [0x79]:

#     obfuscated = [code ^ ord(c) for c in sys.argv[1] + "\n"]

#     print(f"{code:02x}")
#     print(", ".join([f"0x{c:x}" for c in obfuscated]))
#     print("".join([chr(c) for c in obfuscated]))

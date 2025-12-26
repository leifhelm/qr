#!/usr/bin/env python3

import sys
import itertools

a = [ord(c) for c in sys.argv[1]]
b = [ord(c) for c in sys.argv[2]]

if len(a) < len(b):
    a += [0x79] * (len(b) - len(a))
if len(b) < len(a):
    b += [0x79] * (len(a) - len(b))

obfuscated = [a ^ b for a, b in zip(a, b)]
for v in itertools.batched(obfuscated, n=4):
    print(
        f"    .4byte 0x{v[3]:02x}{v[2]:02x}{v[1]:02x}{v[0]:02x}"
    )

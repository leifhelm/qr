# QR encoder in a QR code

<picture>
 <source media="(prefers-color-scheme: dark)" srcset="preview/dark.png">
 <source media="(prefers-color-scheme: light)" srcset="preview/light.png">
 <img alt="QR Code" src="preview/light.png">
</picture>

This QR code is an x86 QR code encoder which is capable of encoding itself.

## Usage

```
Usage: ./qr [OPTIONS] [FILE]
Encode FILE as an QR Code.

Without FILE the program encodes itself.
Output is always standard output.

      --png   Output QR Code as PNG image
      --help  Display help and exit
```

## Examples

Encode Hello world as a QR Code.
``` sh
echo -n "Hello, World!" | ./qr /dev/stdin --png > hello-world.png
```

Encode itself.
``` sh
./qr
```


## Acknowledgements

[libqrencode](https://github.com/fukuchi/libqrencode)

<https://www.nayuki.io/page/creating-a-qr-code-step-by-step>

<https://www.thonky.com/qr-code-tutorial>

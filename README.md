# Executable QR codes

A collection of QR codes which are executable. The whole project was inspired by this [YouTube video](https://www.youtube.com/watch?v=ExwqNreocpg).

## x86

| Name                 | Description                             |
|----------------------|-----------------------------------------|
| [msg](x86/msg)       | A small QR code which prints a message. |
| [sudoku](x86/sudoku) | A 40 level Sudoku in the terminal.      |

## aarch64

| Name               | Description                             |
|--------------------|-----------------------------------------|
| [msg](aarch64/msg) | A small QR code which prints a message. |

## Scanning and running

Generally the QR code scanner must support binary data.
Otherwise the applications will not be able to run and most likely SIGSEGV.

### Computer

[zbar](https://github.com/mchehab/zbar) can be used to scan the qr code with the webcam:

``` sh
zbarcam --raw >qr
chmod +x qr
./qr
```

or from an image:

``` sh
zbarimg --raw image.png >qr
chmod +x qr
./qr
```

### Smartphone

Use [BinaryEye](https://github.com/markusfisch/BinaryEye) to scan the qr code and save it. Transfer the file to a computer and run it there.

## Building

Each directory contains a Makefile which will build the binary and the qr code.
So simply running `make` in a directory will build it.
This repository contains a `nix` development environment with all the tools.
Just run the following if you have support for flakes enabled to enter it.

```sh
nix develop
```
This command assumes that `experimental-features = nix-command flakes` in your nix.conf.

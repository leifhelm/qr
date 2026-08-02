##
# qr-quine
#
# @file
# @version 0.1

AS ?= as
AS_FLAGS ?= --32 -Os
CC ?= gcc
CC_FLAGS ?=
LD ?= ld
LD_FLAGS ?= --static --no-dynamic-linker -n -T ../common/script.ld
OBJCOPY ?= objcopy

.PHONY: all
all: preview/light.svg preview/dark.svg

build:
	mkdir -p build

build/qr.o: qr.S | build
	$(AS) $(AS_FLAGS) -o $@ $<

build/qr: build/qr.o
	$(LD) $(LD_FLAGS) -o $@ $<

build/qr.min: build/qr
	packer --pad-text=realleif $< $@

preview:
	mkdir -p preview

preview/light.svg: build/qr.min | preview
	qrencode -8 -l L -t SVG --foreground=000000 --background=00000000 -o $@ < $<

preview/dark.svg: build/qr.min | preview
	qrencode -8 -l L -t SVG --foreground=E6E6E6 --background=00000000 -o $@ < $<


.PHONY: clean
clean:
	rm -rf build

# end

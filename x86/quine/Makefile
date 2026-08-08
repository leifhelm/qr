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
all: preview/light.png preview/dark.png

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

preview/light.png: build/qr.min | preview
	qrencode -8 -l L -t PNG -s 1 --foreground=000000 --background=00000000 -o $@ < $<

preview/dark.png: build/qr.min | preview
	qrencode -8 -l L -t PNG -s 1 --foreground=E6E6E6 --background=00000000 -o $@ < $<


.PHONY: clean
clean:
	rm -rf build
	rm -rf preview

# end

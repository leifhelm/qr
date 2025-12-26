##
# qrcode-msg
#
# @file
# @version 0.1

AS ?= as
AS_FLAGS ?=
CC ?= gcc
CC_FLAGS ?=
LD ?= ld
LD_FLAGS ?= --static --no-dynamic-linker 
OBJCOPY ?= objcopy
EXE = msg
GS_ARGS=-dBATCH -dNOPAUSE -dHaveTransparency=false -sDEVICE=pdfwrite -dNoOutputFonts

.PHONY: all
all: build/$(EXE).pdf preview/light.svg preview/dark.svg

build:
	mkdir -p build

build/$(EXE).o: $(EXE).S | build
	$(AS) $(AS_FLAGS) -o $@ $<

build/$(EXE).O: build/$(EXE).o $(EXE).ld
	$(LD) $(LD_FLAGS) -T $(EXE).ld -o $@ $<

build/$(EXE): build/$(EXE).O
	$(OBJCOPY) -O binary --only-section=.text $< $@

build/$(EXE).svg: build/$(EXE)
	qrencode -8 -l M -t SVG -o $@ < $<

build/$(EXE).pdf: $(EXE).typ build/$(EXE).svg
	typst compile $< $@

build/$(EXE)-print.pdf: build/$(EXE).pdf
	gs $(GS_ARGS) -o $@ $^

preview:
	mkdir -p preview

preview/light.svg: build/$(EXE) | preview
	qrencode -8 -l M -t SVG --foreground=000000 --background=00000000 -o $@ < $<

preview/dark.svg: build/$(EXE) | preview
	qrencode -8 -l M -t SVG --foreground=E6E6E6 --background=00000000 -o $@ < $<

.PHONY: clean
clean:
	rm -rf build

# end

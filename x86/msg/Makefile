##
# qrcode-demo
#
# @file
# @version 0.1

.PHONY: all
all: build/msg.pdf preview/light.svg preview/dark.svg

GS_ARGS=-dBATCH -dNOPAUSE -dHaveTransparency=false -sDEVICE=pdfwrite -dNoOutputFonts

build:
	mkdir -p build

build/msg: msg.S | build
	nasm -o $@ $<
	chmod +x $@

build/msg.eps: build/msg
	qrencode -8 -l M -t EPS -o $@ < $<

build/msg.pdf: build/msg.eps msg.tex
	latexmk -interaction=nonstopmode -outdir=build -pdf msg

build/msg-no-fonts.pdf: build/msg.pdf
	gs $(GS_ARGS) -o $@ $^

preview:
	mkdir -p preview

preview/light.svg: build/msg | preview
	qrencode -8 -l M -t SVG --foreground=000000 --background=00000000 -o $@ < $<

preview/dark.svg: build/msg | preview
	qrencode -8 -l M -t SVG --foreground=E6E6E6 --background=00000000 -o $@ < $<

.PHONY: clean
clean:
	rm -rf build
	rm -rf preview

# end

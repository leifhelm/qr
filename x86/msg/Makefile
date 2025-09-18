##
# qrcode-demo
#
# @file
# @version 0.1

.PHONY: all
all: build/msg.pdf

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

.PHONY: clean
clean:
	rm -rf build

# end

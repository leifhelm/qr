##
# qr-sudoku
#
# @file
# @version 0.1

.PHONY: all
all: build/postcard-no-fonts.pdf

GS_ARGS=-dBATCH -dNOPAUSE -dHaveTransparency=false -sDEVICE=pdfwrite -dNoOutputFonts

build:
	mkdir -p build

build/sudoku.S: simple.sudoku easy.sudoku intermediate.sudoku expert.sudoku | build
	./pack_sudoku.py $@ $^

build/qr: qr.S build/sudoku.S
	nasm -o $@ $<
	chmod +x $@

build/qr.min: build/qr
	elfuck -b $< $@

build/qr.eps: build/qr.min
	cat $< | qrencode -8 -l L -t EPS -o $@

build/postcard.pdf: build/qr.eps postcard.tex chaos_post_logo.pdf
	latexmk -interaction=nonstopmode -outdir=build -pdf postcard

build/postcard-no-fonts.pdf: build/postcard.pdf
	gs $(GS_ARGS) -o $@ $^

%.sudoku:
	qqwing --difficulty $* --generate 10 --one-line > $@


.PHONY: clean
clean:
	rm -rf build

# end

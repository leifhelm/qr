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

.PHONY: all
all: build/msg

build:
	mkdir -p build

build/msg.o: msg.S | build
	$(AS) $(AS_FLAGS) -o $@ $<

build/msg.O: build/msg.o
	$(LD) $(LD_FLAGS) -o $@ $<

build/msg: build/msg.O
	$(OBJCOPY) -O binary --only-section=.text $< $@


.PHONY: clean
clean:
	rm -rf build

# end

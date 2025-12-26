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

.PHONY: all
all: build/$(EXE)

build:
	mkdir -p build

build/$(EXE).o: $(EXE).S | build
	$(AS) $(AS_FLAGS) -o $@ $<

build/$(EXE).O: build/$(EXE).o $(EXE).ld
	$(LD) $(LD_FLAGS) -T $(EXE).ld -o $@ $<

build/$(EXE): build/$(EXE).O
	$(OBJCOPY) -O binary --only-section=.text $< $@


.PHONY: clean
clean:
	rm -rf build

# end

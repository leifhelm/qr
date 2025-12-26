OUTPUT_FORMAT("elf64-littleaarch64", "elf64-bigaarch64",
	      "elf64-littleaarch64")
OUTPUT_ARCH(aarch64)
ENTRY(_start)
SECTIONS {
  .text 0x400000 : {
    *(.elf)
    *(.text)
  }
}

PHDRS
{
  load PT_LOAD ; /* force one load program header */
}

SECTIONS
{
  . = SIZEOF_HEADERS + 0x80000;
  .text : { *(.text) } :load
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  .bss : { *(.bss) }
}

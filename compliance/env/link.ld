OUTPUT_ARCH("riscv")
ENTRY(_start)

/* Everything in the core's 64 KiB RAM, code first at address 0. */
SECTIONS
{
    . = 0x00000000;
    .text : { *(.text.init) *(.text) }
    . = ALIGN(4);
    .data : { *(.data) *(.rodata*) *(.srodata*) *(.sdata) }
    .bss  : { *(.bss) *(.sbss) }
}

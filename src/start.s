.set ALIGN,    1<<0
.set MEMINFO,  1<<1
.set FLAGS,    ALIGN | MEMINFO
.set MAGIC,    0x1BADB002
.set CHECKSUM, -(MAGIC + FLAGS)

.section .multiboot
    .align 4
    .long MAGIC
    .long FLAGS
    .long CHECKSUM

.section .text
.global _start
.type _start, @function
_start:
    lea stack_top, %esp
    push %ebx               # multiboot information structure pointer
    push %eax               # multiboot magic
    call kmain

1:
    cli
    hlt
    jmp 1b

.section .bss
    .align 16
stack:
    .skip 16384
stack_top:

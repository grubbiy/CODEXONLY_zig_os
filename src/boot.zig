pub const multiboot_magic: u32 = 0x1BADB002;
pub const multiboot_flag_align: u32 = 1 << 0;
pub const multiboot_flag_meminfo: u32 = 1 << 1;
pub const multiboot_flags: u32 = multiboot_flag_align | multiboot_flag_meminfo;
pub const multiboot_checksum: u32 = 0 -% (multiboot_magic + multiboot_flags);

pub export var multiboot_header: [3]u32 align(4) linksection(".multiboot") = .{
    multiboot_magic,
    multiboot_flags,
    multiboot_checksum,
};

pub export var boot_stack: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

pub export fn _start() callconv(.naked) noreturn {
    @setRuntimeSafety(false);
    asm volatile (
        \\ mov $boot_stack + 16384, %%esp
        \\ push %%ebx
        \\ push %%eax
        \\ call kmain
        \\ cli
        \\ 1:
        \\ hlt
        \\ jmp 1b
        ::: .{ .memory = true });
    unreachable;
}

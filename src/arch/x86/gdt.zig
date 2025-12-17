const io = @import("io.zig");

const GdtEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_mid: u8,
    access: u8,
    gran: u8,
    base_high: u8,
};

const GdtPtr = packed struct {
    limit: u16,
    base: u32,
};

var gdt: [3]GdtEntry = undefined;
var gdt_ptr: GdtPtr = undefined;

fn setEntry(index: usize, base: u32, limit: u32, access: u8, gran: u8) void {
    gdt[index] = .{
        .limit_low = @truncate(limit & 0xFFFF),
        .base_low = @truncate(base & 0xFFFF),
        .base_mid = @truncate((base >> 16) & 0xFF),
        .access = access,
        .gran = @truncate(((limit >> 16) & 0x0F) | (gran & 0xF0)),
        .base_high = @truncate((base >> 24) & 0xFF),
    };
}

fn load(ptr: *const GdtPtr) void {
    io.cli();
    asm volatile (
        \\ lgdt (%[ptr])
        \\ mov $0x10, %%ax
        \\ mov %%ax, %%ds
        \\ mov %%ax, %%es
        \\ mov %%ax, %%fs
        \\ mov %%ax, %%gs
        \\ mov %%ax, %%ss
        \\ ljmp $0x08, $1f
        \\ 1:
        :
        : [ptr] "r" (ptr),
        : .{ .memory = true, .eax = true });
}

pub fn init() void {
    setEntry(0, 0, 0, 0, 0);
    setEntry(1, 0, 0xFFFFF, 0x9A, 0xCF);
    setEntry(2, 0, 0xFFFFF, 0x92, 0xCF);

    gdt_ptr = .{
        .limit = @as(u16, @intCast(@sizeOf(@TypeOf(gdt)) - 1)),
        .base = @as(u32, @intCast(@intFromPtr(&gdt))),
    };
    load(&gdt_ptr);
}

pub const code_selector: u16 = 0x08;
pub const data_selector: u16 = 0x10;

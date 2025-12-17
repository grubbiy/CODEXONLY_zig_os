const std = @import("std");
const boot = @import("boot.zig");
const multiboot = @import("multiboot.zig");

const io = @import("arch/x86/io.zig");
const cpu = @import("arch/x86/cpu.zig");
const gdt = @import("arch/x86/gdt.zig");
const interrupts = @import("arch/x86/interrupts.zig");

const keyboard = @import("drivers/keyboard.zig");
const pic = @import("drivers/pic.zig");
const pit = @import("drivers/pit.zig");
const qemu = @import("drivers/qemu.zig");
const serial = @import("drivers/serial.zig");
const vga = @import("drivers/vga.zig");

const pmm = @import("memory/pmm.zig");
const heap = @import("memory/heap.zig");

comptime {
    _ = boot;
}

const MULTIBOOT_MAGIC = 0x2BADB002;

var term: vga.Terminal = .{ .fg = .LightGrey, .bg = .Black };
var boot_info: ?*const multiboot.Info = null;
var mem_lower_kb: u32 = 0;
var mem_upper_kb: u32 = 0;
var mmap_entries: [64]multiboot.MemoryMapEntry = undefined;
var mmap_count: usize = 0;
var last_page: ?usize = null;

extern const _kernel_end: u8;

fn printPrompt() void {
    term.write("\n> ");
    serial.write(serial.com1, "\r\n> ");
}

fn runCommand(line: []const u8) void {
    if (std.mem.eql(u8, line, "help")) {
        term.write("Commands: help clear ticks mem mmap alloc free kmalloc reboot exit\n");
        serial.write(serial.com1, "Commands: help clear ticks mem mmap alloc free kmalloc reboot exit\r\n");
        return;
    }
    if (std.mem.eql(u8, line, "clear")) {
        term.clear();
        return;
    }
    if (std.mem.eql(u8, line, "ticks")) {
        term.write("ticks=");
        term.writeDec(pit.ticks);
        term.putChar('\n');
        serial.write(serial.com1, "ticks=");
        serial.writeDec(serial.com1, pit.ticks);
        serial.write(serial.com1, "\r\n");
        return;
    }
    if (std.mem.eql(u8, line, "mem")) {
        if (mem_lower_kb != 0 or mem_upper_kb != 0) {
            term.write("mem_lower=");
            term.writeDec(mem_lower_kb);
            term.write("KB mem_upper=");
            term.writeDec(mem_upper_kb);
            term.write("KB\n");
            serial.write(serial.com1, "mem_lower=");
            serial.writeDec(serial.com1, mem_lower_kb);
            serial.write(serial.com1, "KB mem_upper=");
            serial.writeDec(serial.com1, mem_upper_kb);
            serial.write(serial.com1, "KB\r\n");
        } else {
            term.write("No multiboot mem info.\n");
            serial.write(serial.com1, "No multiboot mem info.\r\n");
        }
        term.write("free_pages=");
        term.writeDec(pmm.free_pages);
        term.putChar('\n');
        serial.write(serial.com1, "free_pages=");
        serial.writeDec(serial.com1, pmm.free_pages);
        serial.write(serial.com1, "\r\n");
        return;
    }
    if (std.mem.eql(u8, line, "mmap")) {
        if (mmap_count == 0) {
            term.write("No multiboot mmap.\n");
            serial.write(serial.com1, "No multiboot mmap.\r\n");
            return;
        }

        serial.write(serial.com1, "[mmap] entries=");
        serial.writeDec(serial.com1, mmap_count);
        serial.write(serial.com1, "\r\n");
        for (mmap_entries[0..mmap_count], 0..) |entry, idx| {
            serial.write(serial.com1, "[mmap] ");
            serial.writeDec(serial.com1, idx);
            serial.write(serial.com1, ": addr=0x");
            serial.writeHex(serial.com1, entry.addr());
            serial.write(serial.com1, " len=0x");
            serial.writeHex(serial.com1, entry.len());
            serial.write(serial.com1, " type=");
            serial.writeDec(serial.com1, @as(u32, @intFromEnum(entry.kind)));
            serial.write(serial.com1, "\r\n");
        }
        term.write("mmap dumped to serial.\n");
        return;
    }
    if (std.mem.eql(u8, line, "alloc")) {
        if (pmm.allocPage()) |addr| {
            last_page = addr;
            term.write("alloc page=0x");
            term.writeHex(addr);
            term.putChar('\n');
            serial.write(serial.com1, "alloc page=0x");
            serial.writeHex(serial.com1, addr);
            serial.write(serial.com1, "\r\n");
        } else {
            term.write("alloc failed\n");
            serial.write(serial.com1, "alloc failed\r\n");
        }
        return;
    }
    if (std.mem.eql(u8, line, "free")) {
        if (last_page) |addr| {
            pmm.freePage(addr);
            last_page = null;
            term.write("freed page=0x");
            term.writeHex(addr);
            term.putChar('\n');
            serial.write(serial.com1, "freed page=0x");
            serial.writeHex(serial.com1, addr);
            serial.write(serial.com1, "\r\n");
        } else {
            term.write("no page to free\n");
            serial.write(serial.com1, "no page to free\r\n");
        }
        return;
    }
    if (std.mem.eql(u8, line, "kmalloc")) {
        if (heap.allocBytes(64, 8)) |ptr| {
            const addr = @intFromPtr(ptr);
            term.write("kmalloc 64 -> 0x");
            term.writeHex(addr);
            term.putChar('\n');
            serial.write(serial.com1, "kmalloc 64 -> 0x");
            serial.writeHex(serial.com1, addr);
            serial.write(serial.com1, "\r\n");
        } else {
            term.write("kmalloc failed\n");
            serial.write(serial.com1, "kmalloc failed\r\n");
        }
        return;
    }
    if (std.mem.eql(u8, line, "reboot")) {
        term.write("Rebooting...\n");
        serial.write(serial.com1, "Rebooting...\r\n");
        io.outb(0x64, 0xFE);
        io.halt();
    }
    if (std.mem.eql(u8, line, "exit")) {
        serial.write(serial.com1, "Exiting QEMU...\r\n");
        qemu.exit(.success);
    }

    term.write("Unknown command. Try `help`.\n");
    serial.write(serial.com1, "Unknown command. Try `help`.\r\n");
}

pub export fn kmain(magic: u32, info_ptr: usize) callconv(.c) noreturn {
    cpu.enableSSE();

    term.clear();
    term.write("Zig kernel booting...\n");

    serial.init(serial.com1);
    serial.write(serial.com1, "[serial] Zig kernel starting\r\n");
    serial.write(serial.com1, "[serial] after init\r\n");

    if (magic != MULTIBOOT_MAGIC) {
        serial.write(serial.com1, "[serial] invalid multiboot magic!\r\n");
        term.write("Bad multiboot magic.\n");
        io.halt();
    }

    term.write("Multiboot magic OK\n");
    serial.write(serial.com1, "[serial] multiboot info at 0x");
    serial.writeHex(serial.com1, info_ptr);
    serial.write(serial.com1, "\r\n");

    boot_info = @ptrFromInt(info_ptr);
    const info = boot_info.?;
    serial.write(serial.com1, "[serial] multiboot flags=0x");
    serial.writeHex(serial.com1, info.flags);
    serial.write(serial.com1, "\r\n");

    if ((info.flags & multiboot.InfoFlags.memory) != 0) {
        mem_lower_kb = info.mem_lower;
        mem_upper_kb = info.mem_upper;
        serial.write(serial.com1, "[serial] mem_lower=");
        serial.writeDec(serial.com1, mem_lower_kb);
        serial.write(serial.com1, "KB mem_upper=");
        serial.writeDec(serial.com1, mem_upper_kb);
        serial.write(serial.com1, "KB\r\n");

        term.write("mem_lower=");
        term.writeDec(mem_lower_kb);
        term.write("KB mem_upper=");
        term.writeDec(mem_upper_kb);
        term.write("KB\n");
    } else {
        serial.write(serial.com1, "[serial] multiboot mem info not present\r\n");
        term.write("No multiboot mem info.\n");
    }

    if ((info.flags & multiboot.InfoFlags.mmap) != 0) {
        serial.write(serial.com1, "[serial] mmap length=");
        serial.writeDec(serial.com1, info.mmap_length);
        serial.write(serial.com1, " bytes at 0x");
        serial.writeHex(serial.com1, info.mmap_addr);
        serial.write(serial.com1, "\r\n");
        mmap_count = 0;

        const mmap_start: usize = @as(usize, info.mmap_addr);
        const mmap_end: usize = mmap_start + @as(usize, info.mmap_length);

        var cur: usize = mmap_start;
        while (cur < mmap_end and mmap_count < mmap_entries.len) {
            const entry: *const multiboot.MemoryMapEntry = @ptrFromInt(cur);
            if (entry.size == 0) break;
            mmap_entries[mmap_count] = entry.*;
            mmap_count += 1;
            const total_size: usize = @as(usize, entry.size) + @sizeOf(u32);
            cur += total_size;
        }
    } else {
        serial.write(serial.com1, "[serial] multiboot mmap not present\r\n");
    }

    const kernel_end = @intFromPtr(&_kernel_end);
    if (mmap_count != 0) {
        pmm.init(mmap_entries[0..mmap_count], kernel_end);
        serial.write(serial.com1, "[serial] pmm free_pages=");
        serial.writeDec(serial.com1, pmm.free_pages);
        serial.write(serial.com1, "\r\n");
        if (heap.init()) {
            serial.write(serial.com1, "[serial] heap online\r\n");
        } else {
            serial.write(serial.com1, "[serial] heap init failed\r\n");
        }
    } else {
        serial.write(serial.com1, "[serial] pmm not initialized (no mmap)\r\n");
    }

    gdt.init();
    interrupts.init();

    interrupts.register(interrupts.irq_base + 0, &pit.irqHandler);
    interrupts.register(interrupts.irq_base + 1, &keyboard.irqHandler);

    pit.init(100);
    pic.clearMask(0);
    pic.clearMask(1);

    term.write("Interrupts: on\n");
    serial.write(serial.com1, "[serial] interrupts enabled\r\n");
    io.sti();

    term.write("Type `help` for commands.\n");
    printPrompt();

    var line_buf: [80]u8 = undefined;
    var line_len: usize = 0;

    while (true) {
        const maybe_ch = keyboard.popByte() orelse serial.readByteNonBlocking(serial.com1);
        if (maybe_ch) |raw| {
            const ch: u8 = if (raw == '\r') '\n' else raw;
            switch (ch) {
                0x08 => {
                    if (line_len > 0) {
                        line_len -= 1;
                        term.backspace();
                        serial.write(serial.com1, "\x08 \x08");
                    }
                },
                0x7f => {
                    if (line_len > 0) {
                        line_len -= 1;
                        term.backspace();
                        serial.write(serial.com1, "\x08 \x08");
                    }
                },
                '\n' => {
                    term.putChar('\n');
                    serial.write(serial.com1, "\r\n");
                    runCommand(line_buf[0..line_len]);
                    line_len = 0;
                    printPrompt();
                },
                else => {
                    if (line_len < line_buf.len) {
                        line_buf[line_len] = ch;
                        line_len += 1;
                        term.putChar(ch);
                        serial.writeByte(serial.com1, ch);
                    }
                },
            }
        } else {
            io.hlt();
        }
    }
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    term.fg = .White;
    term.bg = .Red;
    term.clear();
    term.write("Kernel panic\n");
    term.write(msg);
    term.putChar('\n');
    serial.write(serial.com1, "[panic] ");
    serial.write(serial.com1, msg);
    serial.write(serial.com1, "\r\n");
    io.halt();
}

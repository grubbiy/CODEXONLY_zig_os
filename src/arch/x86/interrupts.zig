const std = @import("std");
const io = @import("io.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const pic = @import("../../drivers/pic.zig");
const serial = @import("../../drivers/serial.zig");

pub const irq_base: u8 = 32;

pub const InterruptFrame = extern struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    int_no: u32,
    err_code: u32,

    eip: u32,
    cs: u32,
    eflags: u32,
};

pub const Handler = *const fn (*InterruptFrame) void;

var handlers: [256]?Handler = undefined;

fn hasErrorCode(vector: usize) bool {
    return switch (vector) {
        8, 10, 11, 12, 13, 14, 17 => true,
        else => false,
    };
}

fn buildStubTable() [256]*const fn () callconv(.naked) void {
    var table: [256]*const fn () callconv(.naked) void = undefined;
    for (0..256) |i| {
        const err_code = hasErrorCode(i);
        const Stub = struct {
            fn f() callconv(.naked) void {
                @setRuntimeSafety(false);
                if (err_code) {
                    asm volatile (
                        \\ push %[vec]
                        \\ jmp interruptCommonStub
                        :
                        : [vec] "i" (i),
                    );
                } else {
                    asm volatile (
                        \\ push 0
                        \\ push %[vec]
                        \\ jmp interruptCommonStub
                        :
                        : [vec] "i" (i),
                    );
                }
                unreachable;
            }
        };
        table[i] = &Stub.f;
    }
    return table;
}

const stub_table = buildStubTable();

pub export fn interruptCommonStub() callconv(.naked) void {
    @setRuntimeSafety(false);
    asm volatile (
        \\ pusha
        \\ push %%esp
        \\ call interruptDispatch
        \\ add $4, %%esp
        \\ popa
        \\ add $8, %%esp
        \\ iret
        ::: .{ .memory = true });
    unreachable;
}

pub export fn interruptDispatch(frame: *InterruptFrame) callconv(.c) void {
    const vector: u8 = @truncate(frame.int_no);
    if (handlers[vector]) |handler| {
        handler(frame);
    } else if (vector < irq_base) {
        serial.write(serial.com1, "[isr] unhandled exception ");
        serial.writeDec(serial.com1, vector);
        serial.write(serial.com1, " err=0x");
        serial.writeHex(serial.com1, frame.err_code);
        serial.write(serial.com1, " eip=0x");
        serial.writeHex(serial.com1, frame.eip);
        serial.write(serial.com1, "\r\n");
        io.halt();
    }

    if (vector >= irq_base and vector < irq_base + 16) {
        pic.sendEoi(@as(u8, @intCast(vector - irq_base)));
    }
}

pub fn register(vector: u8, handler: Handler) void {
    handlers[vector] = handler;
}

pub fn init() void {
    handlers = std.mem.zeroes(@TypeOf(handlers));

    idt.init();
    pic.remap(irq_base, irq_base + 8);

    const gate_flags: u8 = 0x8E; // present, ring0, 32-bit interrupt gate
    for (0..256) |i| {
        idt.setGate(@as(u8, @intCast(i)), @intFromPtr(stub_table[i]), gdt.code_selector, gate_flags);
    }
    idt.load();
}

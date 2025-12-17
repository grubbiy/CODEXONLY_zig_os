const multiboot = @import("../multiboot.zig");

pub const page_size: usize = 4096;

const Page = extern struct {
    next: ?*Page,
};

var free_list: ?*Page = null;
pub var free_pages: usize = 0;

fn alignUp(value: usize, alignment: usize) usize {
    return (value + alignment - 1) & ~(alignment - 1);
}

fn alignDown(value: usize, alignment: usize) usize {
    return value & ~(alignment - 1);
}

pub fn freePage(addr: usize) void {
    @setRuntimeSafety(false);
    const page: *Page = @ptrFromInt(addr);
    page.next = free_list;
    free_list = page;
    free_pages += 1;
}

pub fn allocPage() ?usize {
    @setRuntimeSafety(false);
    const page = free_list orelse return null;
    free_list = page.next;
    free_pages -= 1;
    return @intFromPtr(page);
}

pub fn init(mmap: []const multiboot.MemoryMapEntry, kernel_end: usize) void {
    @setRuntimeSafety(false);
    free_list = null;
    free_pages = 0;

    const min_addr: usize = alignUp(@max(kernel_end, 0x100000), page_size);

    for (mmap) |entry| {
        if (entry.kind != .available) continue;

        if (entry.addr_high != 0 or entry.len_high != 0) continue;

        const start_raw: usize = @as(usize, entry.addr_low);
        const end_raw_u64: u64 = @as(u64, entry.addr_low) + @as(u64, entry.len_low);
        if (end_raw_u64 > @as(u64, ~@as(usize, 0))) continue;
        const end_raw: usize = @as(usize, @intCast(end_raw_u64));

        var start = alignUp(start_raw, page_size);
        const end = alignDown(end_raw, page_size);

        if (end <= min_addr) continue;
        if (start < min_addr) start = min_addr;

        var addr = start;
        while (addr < end) : (addr += page_size) {
            freePage(addr);
        }
    }
}

const pmm = @import("pmm.zig");

var current_page: usize = 0;
var offset: usize = 0;

fn alignUp(value: usize, alignment: usize) usize {
    return (value + alignment - 1) & ~(alignment - 1);
}

pub fn init() bool {
    if (current_page != 0) return true;
    const page = pmm.allocPage() orelse return false;
    current_page = page;
    offset = 0;
    return true;
}

pub fn allocBytes(size: usize, alignment: usize) ?[*]u8 {
    @setRuntimeSafety(false);
    if (!init()) return null;

    if (size == 0) return @ptrFromInt(current_page + offset);
    if (size > pmm.page_size) return null;

    var base = current_page;
    var start = alignUp(base + offset, alignment);
    var end_offset = (start + size) - base;
    if (end_offset > pmm.page_size) {
        base = pmm.allocPage() orelse return null;
        current_page = base;
        offset = 0;
        start = alignUp(base, alignment);
        end_offset = (start + size) - base;
        if (end_offset > pmm.page_size) return null;
    }

    offset = end_offset;
    return @ptrFromInt(start);
}

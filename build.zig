const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    });
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel.zig"),
            .target = target,
            .optimize = optimize,
            .code_model = .kernel,
            .strip = true,
        }),
    });
    kernel.setLinkerScript(b.path("linker.ld"));

    b.installArtifact(kernel);

    const run_step = b.step("run", "Run the kernel in QEMU (requires qemu-system-i386)");
    const run_cmd = b.addSystemCommand(&.{ "qemu-system-i386", "-kernel" });
    run_cmd.addArtifactArg(kernel);
    run_cmd.addArgs(&.{ "-serial", "stdio", "-no-reboot", "-no-shutdown", "-display", "none" });
    run_cmd.addArgs(&.{ "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04" });
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
}

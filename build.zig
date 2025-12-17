const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = std.zig.CrossTarget{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = .{ .path = "src/kernel.zig" },
        .target = target,
        .optimize = optimize,
        .linker_script = .{ .path = "linker.ld" },
    });
    kernel.code_model = .kernel;
    kernel.strip = true;
    kernel.addAssemblyFile("src/start.s");
    kernel.setOutputDir(b.getInstallPath(.bin, ""));

    const install_kernel = b.addInstallArtifact(kernel, .{});
    b.getInstallStep().dependOn(&install_kernel.step);

    const run = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-kernel",
    });
    run.addArtifactArg(kernel);
    run.addArgs(&[_][]const u8{
        "-serial", "stdio",
        "-no-reboot",
        "-no-shutdown",
        "-display", "none",
    });

    const run_step = b.step("run", "Run the kernel in QEMU (requires qemu-system-i386)");
    run_step.dependOn(&run.step);
    run_step.dependOn(&install_kernel.step);
}

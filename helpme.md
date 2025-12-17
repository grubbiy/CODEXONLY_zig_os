# Zig 0.15.2 Kernel Development Guide

This document explains how to build, run, and extend the small Multiboot-compatible kernel written in Zig 0.15.2 that lives in this repository.

## Quick start
- **Prerequisites:** Zig 0.15.2, `qemu-system-i386`, and standard GNU binutils (for assembling the boot stub).
- **Build:** `zig build` produces `zig-out/bin/kernel` (an ELF kernel that includes the multiboot header).
- **Run in QEMU:** `zig build run` boots the kernel headless with serial redirected to your terminal; expect the screen to clear and print status lines to VGA text memory while serial logs appear in stdout.
- **Format:** `zig fmt src build.zig` keeps Zig sources consistent.

## What the kernel does today
- Provides a **Multiboot v1 header** and 16 KiB boot stack in `src/start.s` so QEMU/GRUB can load the ELF directly with `-kernel`.
- Sets up **basic VGA text output** (80×25) to report boot progress.
- Initializes **serial logging on COM1 (0x3F8)** for debugging, with simple routines to print strings safely.
- Performs a **Multiboot magic check** and reports the pointer to the boot info structure before halting cleanly.
- Supplies a **panic handler** that writes to both VGA and serial, then halts the CPU with `hlt`.

## Repository layout
- `build.zig` – Build script targeting **x86 freestanding** with a custom linker script and QEMU runner.
- `linker.ld` – Places sections at the 1 MiB physical address and aligns segments for the kernel image.
- `src/start.s` – Multiboot header plus the `_start` entry that sets the stack and calls into Zig.
- `src/kernel.zig` – Core kernel logic (VGA/serial routines, early boot banners, panic handler).

## Extending the kernel
- Add new Zig modules under `src/` and import them from `src/kernel.zig` or future subsystem files.
- Keep the freestanding target in mind: avoid standard library features that assume an OS (files, threading, heap allocators) until you provide your own implementations.
- Use serial logging for early diagnostics—`serialWrite` is safe to call during boot before other systems are ready.

## Troubleshooting
- **Missing Zig or QEMU:** Install the required tools and re-run `zig build` / `zig build run`.
- **No serial output:** Ensure QEMU is run with `-serial stdio` (the build script does this) and check your terminal for log lines.
- **Boot hangs immediately:** Verify Multiboot magic matches (`0x2BADB002`) and that you are using a Multiboot-capable loader (`qemu-system-i386 -kernel zig-out/bin/kernel`).


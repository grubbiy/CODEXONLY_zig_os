# Zig 0.15.2 Kernel Development Guide

This document explains the plan for creating and developing a small operating system kernel using Zig 0.15.2. It also serves as a quick reference for using the repository’s build and test tooling.

## Goals and scope
- **Language and toolchain:** Zig 0.15.2, targeting bare-metal x86_64 with multiboot compatibility for early boot loaders.
- **Objectives:**
  - Bring up a minimal bootable kernel image.
  - Provide essential runtime primitives (memory management, interrupt handling, simple drivers).
  - Keep the codebase small and readable for educational purposes.

## Development roadmap
1. **Environment setup**
   - Install Zig 0.15.2 and ensure `zig` is on your PATH.
   - Install a cross-toolchain if needed for image utilities (e.g., `qemu-system-x86_64`, `grub-mkrescue`).
2. **Repository layout** (proposed)
   - `src/` — kernel sources (boot, memory, interrupts, drivers, libc-lite).
   - `build.zig` — build script producing the kernel ELF and ISO image.
   - `tools/` — helper scripts for image creation and tests.
   - `docs/` — design notes and API documentation.
3. **Boot pipeline**
   - Provide a multiboot header in the entry assembly (`boot/entry.zig` or `boot/start.s`).
   - Set up a minimal stack, clear the BSS, and jump into Zig `main` for early init.
   - Prepare the framebuffer/serial for logging during bring-up.
4. **Memory and initialization**
   - Parse bootloader-provided memory maps and initialize a physical frame allocator.
   - Establish a higher-half kernel virtual memory layout, page tables, and enable paging.
   - Add a simple heap allocator wired into Zig’s allocator interface.
5. **Interrupts and exceptions**
   - Build an IDT with handlers for faults and basic IRQs (timer, keyboard if applicable).
   - Implement a programmable interrupt controller (PIC) remap or an APIC path.
   - Provide minimal panic/reporting hooks for debugging.
6. **Device and I/O foundations**
   - Serial logging over COM1 for diagnostics.
   - Basic timer abstraction for scheduling and timekeeping.
   - (Optional) Framebuffer/console text output for on-screen status.
7. **Testing and validation**
   - Use `zig test` for unit-level pieces where possible (e.g., allocators, data structures).
   - Run `zig build run` or `zig build iso` + `qemu-system-x86_64` for integration testing.
   - Automate CI to build the kernel image and boot it under QEMU for smoke tests.

## How to use this repository
- **Build the kernel:** `zig build` (or `zig build iso` if the build script provides an ISO target).
- **Run in QEMU:** `zig build run` or `qemu-system-x86_64 -cdrom zig-out/kernel.iso -serial stdio` depending on the build outputs.
- **Format and lint:** `zig fmt src build.zig` to keep style consistent.
- **Add documentation:** place design notes and subsystem docs under `docs/` so contributors can find them easily.

## Contribution guidelines
- Favor small, incremental commits with clear messages.
- Keep public APIs stable and documented in `docs/`.
- Add tests for new subsystems and run the QEMU smoke test before submitting changes.

## Next steps
- Scaffold `build.zig` with targets for `kernel.elf`, `iso`, and `run`.
- Create the `src/boot` entry code with a multiboot header and early logging.
- Define memory layout constants and stub the allocator interfaces for later implementation.

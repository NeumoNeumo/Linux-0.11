# Linux-0.11 on x86 and x64

The modified old Linux kernel source ver 0.11 to port to x86_64 system forked
from yuan-xy/Linux-0.11.

## 1. Build on Linux

### 1.1. Linux Setup
* a linux distribution: debian, ubuntu and mint are recommended
* some tools: gcc gdb qemu
Pass test on Ubuntu 16.04 and 22.04.

1. Modify the target in `Makefile.header` to indicate the architecture
2. Run the following codes
```bash
$ make
$ make start
```

### 1.2. hack linux-0.11
```bash
$ make help     // get help
$ make          // compile
$ make start    // boot it on qemu
$ make debug    // debug it via qemu with gdb or lldb
```

```bash
$ make sofar    // make the compilable part of the x86_64 system so far
```

lldb(recommended):

```lldb
$ lldb tools/system
(lldb) gdb-remote 1234
(lldb) b main
(lldb) c
```

or
```bash
make lldb-as    // debug assembly
make lldb-src   // debug with source
```

gdb:

```gdb
$ gdb tools/system
(gdb) target remote :1234
(gdb) b main
(gdb) c
```

Hints:
1. You may use [bear](https://github.com/rizsotto/Bear) to generate compilation
database for clang tooling.
2. We use `__X64__` to indicate this code is to be compiled in x86_64 and
   `__X86__` for x86.

# 2. Port to x86_64
## 2.1 Special Marks
You can search these marks globally in this repo to check them.
1. TODO64: something to be done to port to x86_64

## 2.2 Difference between x86 and x86_64
Here are some differences between x86 and x86_64 to provides an overview to what
is ought to be modified in this repo. Please append the source and
highlight the key points.

1. Register: long mode extends general registers to 64 bits (RAX, RBX, RIP, RSP,
   RFLAGS, etc), and adds eight additional integer registers (R8, R9, ..., R15)
   plus eight more SSE registers (XMM8 to XMM15) to the CPU. **Long mode
   needs to be enabled to turn on this extension.**(Prof. Zhang says we must use
   64-bit long mode)
   [source](https://wiki.osdev.org/X86-64#How_do_I_enable_Long_Mode_.3F)

![](img/README/x64_reg.png)

from [url](https://josemariasola.github.io/reference/assembler/Stanford%20CS107%20Guide%20to%20x86-64.pdf)

2. Physical address space: extended to 52 bits (a given CPU may implement
   less than this). In essence long mode adds another mode to the CPU.
   [source](https://wiki.osdev.org/X86-64#How_do_I_enable_Long_Mode_.3F)
3. 

## 2.3 Roadmap
- [x] Activate long mode @NeumoNeumo
- [x] Setup paging @ NeumoNeumo
- [x] Higher Half Kernel @NeumoNeumo
- [ ] Flash disk boot
- [ ] tty
- [ ] Memory
  - [ ] E820h routine to get memory map
- [ ] Schedule
- [ ] x86_64 Shell
- [ ] VGA graph mode

### 2.3.1 Activate Long Mode
Normal way:
1. Intel 64 and IA-32 Architectures Software Developer's Manual, Section 9.8.5
2. "How do I enable Long Mode ?" in https://wiki.osdev.org/X86-64

Tricky way:
1. https://wiki.osdev.org/Entering_Long_Mode_Directly
2. "Entering Long Mode directly" in https://wiki.osdev.org/X86-64


# 3. Specification
1. Before you commit, `make clean` to remove all the compiled files.

# 4. General Process

## Boot(x86)

1. bootsect.s: BIOS starts from F000:FFF0 which is directly mapped to ROM. BIOS
   load the MBR to 0x7c00 and run it. Bootsect moves itself to 0x90000 and long
   jump to 0x9000:go. use BIOS interrupt 0x13 to read the next 4(SETUPLEN) to
   0x90200. Then we load the system(0x3000(SYSSIZE) * 0x10 B)(196KB, currently
   about 160KB) at 0x10000. Then long jump to 0x90200($SETUPSEG * 0x10)(used
   lgdt in setup.s)

2. setup.s: load some system info using BIOS interrupts to 0x90000(overwriting
   bootsect). Move the system from 0x10000-0x90000 to 0x0. Load tmp_idt and
   tmp_gdt. Enable A20. Program PIC. Enable protection. Long jump to 0, the
   start of the system or head.s

3. head.s: reconfigure to idt and tmp2_gdt. Check A20. Check the coprocessor.
   Enter main.c

## Boot(x64)

The x64 boot process can be summarized as follows:
1. bootsect.s (16-bit compiled)
- Starts from F000:FFF0
- Load the MBR to 0x7c00
- Move to 0x90000
- Use BIOS interrupt 0x13 to read the left of boot.
- Far jump to 0x90200

2. setup.s (16/32 compiled)
- Load some system info(changed) // TODO64
- Move the system from 0x10000-0x90000 to 0x0.
- Check the coprocessor
- Enable A20.
- Program PIC.
- Enable protection.
- check A20
- load system to 0x100000 in unreal mode
- Enter long mode(32-bit compiled)
  - Set gdt
  - Set PAE, PG, PML4
  - Set paging
  - Long jump to 0(0x5000)

3. head.s (64-bit compiled): 
- Reconfigure idtr and gdtr
- setup higher half kernel
- Setup TSS for kernel stack
- Jump to main.c

# FAQ

1. Why do we need to setup gdt/ldt in setup64.s since we will reset it in
   head64.s?

We want to use symbols in head64.s. So head64.s must be compile with `as
--64` to be consistent with other source files. However, when using `as --64`,
the compiler will assume that we are already in the long mode. So we need to
enter long mode before executing head64.s. One must setup a GDT in preparation
for long mode. Therefore, a GDT is required in setup64.s. The same applies to
LDT. But we can neglect setting up LDT in head64.s because of `cli`. So we did
not setup LDT :).

2. Why lldb disassemble incorrectly in real mode?

a. Wrong address: https://github.com/llvm/llvm-project/issues/62835

b. Wrong mode: lldb disassemble in protected mode by default which is different
when decoding some commands compared to real mode.

3. Why do we need TSS?

In long mode, when switched to a higher privilege level in an interruption(e.g.
CPL=3, DPL=0), the system will change its stack space to what DPL specifies. If
the interruption occurs when CPL=0, everything is fine. But when it turns from
0->3, TSS is needed to tell CPU where to find the kernel stack with respect to
the higher privileged level. Moreover, TSS in long mode no longer stores the
value of registers, so we have to manage task switching in OS instead of by
hardware task switching technique.

4. Why do we move `system` to 0x100000? 

First, memory address from 0 to 0xFFFFF are not all DRAM, so we had better not use
these memory. For example, some space is mapped to ROM which we cannot write to.
Second, if we load our system like what we did in the x86 version, the system
has a rather limited size. But if we load the system in the protected mode, our
system can exceeds 1MB.

```txt
+------------+------------+---------------+----------------------+------------------------------------------------+
|    start   |     end    |      size     |      description     |                      type                      |
+------------+------------+---------------+----------------------+------------------------------------------------+
|                                     Real mode address space (the first MiB)                                     |
+------------+------------+---------------+----------------------+-------------------+----------------------------+
|            |            |               | Real Mode IVT        |                   |                            |
| 0x00000000 | 0x000003FF | 1 KiB         | (Interrupt Vector    | unusable in real  |                            |
|            |            |               | Table)               | mode              |                            |
+------------+------------+---------------+----------------------+                   |                            |
| 0x00000400 | 0x000004FF | 256 bytes     | BDA (BIOS data area) |                   |                            |
+------------+------------+---------------+----------------------+-------------------+                            |
| 0x00000500 | 0x00007BFF | almost 30 KiB | Conventional memory  |                   | 640 KiB RAM ("Low memory") |
+------------+------------+---------------+----------------------+                   |                            |
| 0x00007C00 | 0x00007DFF | 512 bytes     | Your OS BootSector   | usable memory     |                            |
+------------+------------+---------------+----------------------+                   |                            |
| 0x00007E00 | 0x0007FFFF | 480.5 KiB     | Conventional memory  |                   |                            |
+------------+------------+---------------+----------------------+-------------------+                            |
| 0x00080000 | 0x0009FFFF | 128 KiB       | EBDA (Extended       | partially used by |                            |
|            |            |               | BIOS Data Area)      | the EBDA          |                            |
+------------+------------+---------------+----------------------+-------------------+----------------------------+
| 0x000A0000 | 0x000BFFFF | 128 KiB       | Video display memory | hardware mapped   |                            |
+------------+------------+---------------+----------------------+-------------------+                            |
| 0x000C0000 | 0x000C7FFF | 32 KiB        | Video BIOS           |                   |                            |
|            |            | (typically)   |                      |                   | 384 KiB System / Reserved  |
+------------+------------+---------------+----------------------+ ROM and hardware  | ("Upper Memory")           |
| 0x000C8000 | 0x000EFFFF | 160 KiB       | BIOS Expansions      | mapped/Shadow RAM |                            |
|            |            | (typically)   |                      |                   |                            |
+------------+------------+---------------+----------------------+                   |                            |
| 0x000F0000 | 0x000FFFFF | 64 KiB        | Motherboard BIOS     |                   |                            |
+------------+------------+---------------+----------------------+-------------------+----------------------------+
```
Memory map overview. Source: https://wiki.osdev.org/Memory_Map_(x86)

5. Why we need unreal mode to load `system` to 0x100000?

We need BIOS interrupt, which is designed for real mode, to load `system`.
However, we cannot reach the memory beyond 1MB in real mode. So unreal mode is
required.

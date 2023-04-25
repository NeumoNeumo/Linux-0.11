# Linux-0.11 on x86 and x64

The modified old Linux kernel source ver 0.11 to port to x86_64 system forked from yuan-xy/Linux-0.11.

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

lldb(recommended):

```lldb
$ lldb
(lldb) gdb-remote 1234
(lldb) b main
(lldb) c
```

gdb:

```gdb
$ gdb tools/system
(gdb) target remote :1234
(gdb) b main
(gdb) c
```

Hints:
You may use [bear](https://github.com/rizsotto/Bear) to generate compilation database for clang tooling.

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
   long mode)
   [source](https://wiki.osdev.org/X86-64#How_do_I_enable_Long_Mode_.3F)
2. Physical address space: extended to 52 bits (a given CPU may implement
   less than this). In essence long mode adds another mode to the CPU.
   [source](https://wiki.osdev.org/X86-64#How_do_I_enable_Long_Mode_.3F)
3. 

# 3. Specification
1. Before you commit, `make clean` to remove all the compiled files.


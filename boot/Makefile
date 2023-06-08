include ../Makefile.header

LDFLAGS	+= -Ttext 0

all: bootsect setup

bootsect: bootsect.s
	@if [ "${TARGET}" = "x86" ]; then\
		$(AS) -o bootsect.o bootsect.s;\
		$(LD) $(LDFLAGS) -o bootsect bootsect.o;\
	else\
		as --32 -o bootsect.o bootsect64.s;\
		ld -m elf_i386 -Ttext 0 -o bootsect bootsect.o;\
	fi
	@$(OBJCOPY) -R .pdr -R .comment -R.note -S -O binary bootsect


# NOTE for target x86_64: we are still in 32-bit protected mode in setup64.s.
# So assemble and link it in 32 mode.
setup: setup.s setup64.s
	@if [ "${TARGET}" = "x86" ]; then\
		$(AS) -o setup.o setup.s;\
		$(LD) $(LDFLAGS) -o setup setup.o;\
	else\
		as --32 -o setup.o setup64.s;\
		ld -m elf_i386 -Ttext 0 -o setup setup.o;\
	fi
	@$(OBJCOPY) -R .pdr -R .comment -R.note -S -O binary setup

head.o: head.s head64.s
	@if [ "${TARGET}" = "x86" ]; then\
		$(AS) -o head.o head.s;\
	else\
		$(AS) -o head.o head64.s;\
	fi
clean:
	@rm -f bootsect bootsect.o setup setup.o head.o

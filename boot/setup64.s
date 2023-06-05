.code16
# rewrite with AT&T syntax by falcon <wuzhangjin@gmail.com> at 081012
#
#	setup.s		(C) 1991 Linus Torvalds
#
# setup.s is responsible for getting the system data from the BIOS,
# and putting them into the appropriate places in system memory.
# both setup.s and system has been loaded by the bootblock.
#
# This code asks the bios for memory/disk/other parameters, and
# puts them in a "safe" place: 0x90000-0x901FF, ie where the
# boot-block used to be. It is then up to the protected mode
# system to read them from there before the area is overwritten
# for buffer-blocks.
#
.equ SYSSIZE, 0x100000

# NOTE! These had better be the same as in bootsect.s!

	.equ INITSEG, 0x9000	# we move boot here - out of the way
	.equ SYSSEG, 0x1000	# system loaded at 0x10000 (65536).
	.equ SETUPSEG, 0x9020	# this is the current segment

	.global _start, begtext, begdata, begbss, endtext, enddata, endbss
	.text
	begtext:
	.data
	begdata:
	.bss
	begbss:
	.text

	ljmp $SETUPSEG, $_start	
_start:
	mov %cs,%ax
	mov %ax,%ds
	mov %ax,%es
#
##print some message
#
	mov $0x03, %ah
	xor %bh, %bh
	int $0x10

	mov $29, %cx
	mov $0x000b,%bx
	mov $msg2,%bp
	mov $0x1301, %ax
	int $0x10
# ok, the read went well so we get current cursor position and save it for
# posterity.
	mov	$INITSEG, %ax	# this is done in bootsect already, but...
	mov	%ax, %ds
	mov	$0x03, %ah	# read cursor pos
	xor	%bh, %bh
	int	$0x10		# save it in known place, con_init fetches
	mov	%dx, %ds:0	# it from 0x90000.
# Get memory size (extended mem, kB)

	mov	$0x88, %ah 
	int	$0x15
	mov	%ax, %ds:2

# Get video-card data:

	mov	$0x0f, %ah
	int	$0x10
	mov	%bx, %ds:4	# bh = display page
	mov	%ax, %ds:6	# al = video mode, ah = window width

# check for EGA/VGA and some config parameters

	mov	$0x12, %ah
	mov	$0x10, %bl
	int	$0x10
	mov	%ax, %ds:8
	mov	%bx, %ds:10
	mov	%cx, %ds:12

# Get hd0 data

	mov	$0x0000, %ax
	mov	%ax, %ds
	lds	%ds:4*0x41, %si
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0080, %di
	mov	$0x10, %cx
	rep
	movsb

# Get hd1 data

	mov	$0x0000, %ax
	mov	%ax, %ds
	lds	%ds:4*0x46, %si
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0090, %di
	mov	$0x10, %cx
	rep
	movsb

## modify ds
	mov $INITSEG,%ax
	mov %ax,%ds
	mov $SETUPSEG,%ax
	mov %ax,%es

##show cursor pos:
	mov $0x03, %ah 
	xor %bh,%bh
	int $0x10
	mov $11,%cx
	mov $0x000c,%bx
	mov $cur,%bp
	mov $0x1301,%ax
	int $0x10
##show detail
	mov %ds:0 ,%ax
	call print_hex
	call print_nl

##show memory size
	mov $0x03, %ah
	xor %bh, %bh
	int $0x10
	mov $12, %cx
	mov $0x000a, %bx
	mov $mem, %bp
	mov $0x1301, %ax
	int $0x10

##show detail
	mov %ds:2 , %ax
	call print_hex

##show 
	mov $0x03, %ah
	xor %bh, %bh
	int $0x10
	mov $25, %cx
	mov $0x000d, %bx
	mov $cyl, %bp
	mov $0x1301, %ax
	int $0x10
##show detail
	mov %ds:0x80, %ax
	call print_hex
	call print_nl

##show 
	mov $0x03, %ah
	xor %bh, %bh
	int $0x10
	mov $8, %cx
	mov $0x000e, %bx
	mov $head, %bp
	mov $0x1301, %ax
	int $0x10
##show detail
	mov %ds:0x82, %ax
	call print_hex
	call print_nl

##show 
	mov $0x03, %ah
	xor %bh, %bh
	int $0x10
	mov $8, %cx
	mov $0x000f, %bx
	mov $sect, %bp
	mov $0x1301, %ax
	int $0x10
##show detail
	mov %ds:0x8e, %ax
	call print_hex
	call print_nl
#l:
#	jmp l
##
# Check that there IS a hd1 :-)

	mov	$0x01500, %ax
	mov	$0x81, %dl
	int	$0x13
	jc	no_disk1
	cmp	$3, %ah
	je	is_disk1
no_disk1:
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0090, %di
	mov	$0x10, %cx
	mov	$0x00, %ax
	rep
	stosb
is_disk1:

# now we want to move to protected mode ...

	cli			# no interrupts allowed ! 

/*
# first we move the system to its rightful place

	mov	$0x0000, %ax
	cld			# 'direction'=0, movs moves forward
do_move:
	mov	%ax, %es	# destination segment
	add	$0x1000, %ax
	cmp	$0x9000, %ax
	jz	end_move
	mov	%ax, %ds	# source segment
	sub	%di, %di
	sub	%si, %si
	mov 	$0x8000, %cx
	rep
	movsw
	jmp	do_move
*/

# then we load the segment descriptors

end_move:
	mov	$SETUPSEG, %ax	# right, forgot this at first. didn't work :-)
	mov	%ax, %ds

# that was painless, now we enable A20

	#call	empty_8042	# 8042 is the keyboard controller
	#mov	$0xD1, %al	# command write
	#out	%al, $0x64
	#call	empty_8042
	#mov	$0xDF, %al	# A20 on
	#out	%al, $0x60
	#call	empty_8042
	inb		 $0x92, %al	# open A20 line(Fast Gate A20).
	orb		 $0b00000010, %al
	outb		%al, $0x92

	xorl %eax,%eax
1:	incl %eax		# check that A20 really IS enabled
	movl %eax,0x100000	# loop forever if it isn't.
	cmpl %eax,0x0
	je 1b

# well, that went ok, I hope. 


# load the system at 0x100000
	mov	$0x00, %dl
	mov	$0x0800, %ax		# AH=8 is get drive parameters
	int	$0x13
	mov	$0x00, %ch
	mov	%cx, %cs:sectors+0	# %cs means sectors is in %cs

	lgdt	gdt_48
	mov	%cr0, %eax
	bts	$0, %eax
	mov	%eax, %cr0	

	mov $0x10, %ax
	mov %ax, %es

	mov %cr0, %eax
	btr $0, %eax
	mov %eax, %cr0

	xor	ah,	ah
	xor	dl,	dl
	int	13h     #reset

	call read_it
	call kill_motor

# Now we have to reprogram the interrupts :-(
# we put them right after the intel-reserved hardware interrupts, at
# int 0x20-0x2F. There they won't mess up anything. Sadly IBM really
# messed this up with the original PC, and they haven't been able to
# rectify it afterwards. Thus the bios puts interrupts at 0x08-0x0f,
# which is used for the internal hardware interrupts as well. We just
# have to reprogram the 8259's, and it isn't fun.

	mov	$0x11, %al		# initialization sequence(ICW1)
					# ICW4 needed(1),CASCADE mode,Level-triggered
	out	%al, $0x20		# send it to 8259A-1
	.word	0x00eb,0x00eb		# jmp $+2, jmp $+2
	out	%al, $0xA0		# and to 8259A-2
	.word	0x00eb,0x00eb
	mov	$0x20, %al		# start of hardware int's (0x20)(ICW2)
	out	%al, $0x21		# from 0x20-0x27
	.word	0x00eb,0x00eb
	mov	$0x28, %al		# start of hardware int's 2 (0x28)
	out	%al, $0xA1		# from 0x28-0x2F
	.word	0x00eb,0x00eb		#							 IR 7654 3210
	mov	$0x04, %al		# 8259-1 is master(0000 0100) --\
	out	%al, $0x21		#				|
	.word	0x00eb,0x00eb		#			 INT	/
	mov	$0x02, %al		# 8259-2 is slave(			 010 --> 2)
	out	%al, $0xA1
	.word	0x00eb,0x00eb
	mov	$0x01, %al		# 8086 mode for both
	out	%al, $0x21
	.word	0x00eb,0x00eb
	out	%al, $0xA1
	.word	0x00eb,0x00eb
	mov	$0xFF, %al		# mask off all interrupts for now
	out	%al, $0x21
	.word	0x00eb,0x00eb
	out	%al, $0xA1
# well, that certainly wasn't fun :-(. Hopefully it works, and we don't
# need no steenking BIOS anyway (except for the initial loading :-).
# The BIOS-routine wants lots of unnecessary data, and it's less
# "interesting" anyway. This is how REAL programmers do it.


# Well, now's the time to actually move into protected mode. To make
# things as simple as possible, we do no register set-up or anything,
# we let the gnu-compiled 32-bit programs do that. We just jump to
# absolute address 0x00000, in 32-bit protected mode.
# We immediately enter the long mode as soon as the 32-bit protection enables.
	#lidt	idt_48		# load idt with 0,0
	lgdt	gdt_48		# load gdt with whatever appropriate
	mov	%cr0, %eax	# get machine status(cr0|MSW)	
	bts	$0, %eax	# turn on the PE-bit (Protection Enable)
	mov	%eax, %cr0	# protection enabled

	# segment-descriptor				(INDEX:TI:RPL)
	#.byte 0xea, 0x00, 0x04, 0x09, 0x00, 0x08, 0x00
	ljmpl $0x0008, $0x90400

.code32
.org 0x200
after_protect:
/*
 * NOTE! 486 should set bit 16, to check for write-protect in supervisor
 * mode. Then it would be unnecessary with the "verify_area()"-calls.
 * 486 users probably want to set the NE (#5) bit also, so as to use
 * int 16 for math errors.
 */

	movl %cr0,%eax		# check math chip
	andl $0x80000011,%eax	# Save PG,PE,ET
/* "orl $0x10020,%eax" here for 486 might be good */
	orl $2,%eax		# set MP
	movl %eax,%cr0
	call check_x87

	call check_x64

	lgdt gdt_80
	movl $0x10,%eax		# reload all the segment registers
	mov %ax,%ds		
	mov %ax,%es		
	mov %ax,%fs
	mov %ax,%gs
	
	mov %cr4, %eax	
	bts $5, %eax		
	mov %eax, %cr4	# enable PAE
 
	xor %eax, %eax
	mov %eax, %cr3		# load PML4
 
	mov $0xC0000080, %ecx
	rdmsr
	or $0x100, %eax	 # set LM bit
	wrmsr					 # enable long mode

	mov	%cr0, %eax
	bts	$31, %eax		# set PG

	mov	%eax, %cr0	# enable paging

	ljmp $0x8, $0x105000

/*
 * We depend on ET to be correct. This checks for 287/387.
 */
check_x87:
	fninit
	fstsw %ax
	cmpb $0,%al
	je 1f			/* no coprocessor: have to set bits */
	movl %cr0,%eax
	xorl $6,%eax		/* reset MP, set EM */
	movl %eax,%cr0
	ret
.align 2
1:	.byte 0xDB,0xE4		/* fsetpm for 287, ignored by 387 */
	ret


check_x64:
	mov $0x80000000, %eax
	cpuid
	cmp $0x80000001, %eax
	setnb %al
	jb support_long_mode_done
	mov $0x80000001, %eax
	cpuid
	bt $29, %edx
	setc %al
support_long_mode_done:
	movzx %al, %eax
	ret
no_support:
	jmp no_support

.code16

# load the system to 0x100000 in unreal mode
sread:	.word 1 + SYSLEN	# sectors read of current track
head:	.word 0			# current head
track:	.word 0			# current track

read_it:
	movl $100000, %ebx
rp_read:
	mov 	%es, %ax
 	cmp 	$ENDSEG, %ax		# have we loaded all yet?
	jb	ok1_read
	ret
ok1_read:
	#seg cs
	mov	%cs:sectors+0, %ax
	sub	$5, %ax
	mov	%ax, %cx
	shl	$9, %cx
	add	%bx, %cx
	jnc 	ok2_read
	je 	ok2_read
	xor 	%ax, %ax
	sub 	%bx, %ax
	shr 	$9, %ax
ok2_read:
	call 	read_track
	mov 	%ax, %cx
	add 	sread, %ax
	#seg cs
	cmp 	%cs:sectors+0, %ax
	jne 	ok3_read
	mov 	$1, %ax
	sub 	head, %ax
	jne 	ok4_read
	incw    track 
ok4_read:
	mov	%ax, head
	xor	%ax, %ax
ok3_read:
	mov	%ax, sread
	shl	$9, %cx
	add	%cx, %bx
	jnc	rp_read
	add	$0x10000, %bx
	xor	%bx, %bx
	jmp	rp_read

read_track:
	push	%ax
	push	%bx
	push	%cx
	push	%dx
	mov	track, %dx
	mov	sread, %cx
	inc	%cx
	mov	%dl, %ch
	mov	head, %dx
	mov	%dl, %dh
	mov	$0, %dl
	and	$0x0100, %dx
	mov	$2, %ah
	int	$0x13
	jc	bad_rt
	pop	%dx
	pop	%cx
	pop	%bx
	pop	%ax
	ret
bad_rt:	mov	$0, %ax
	mov	$0, %dx
	int	$0x13
	pop	%dx
	pop	%cx
	pop	%bx
	pop	%ax
	jmp	read_track

#/*
# * This procedure turns off the floppy drive motor, so
# * that we enter the kernel in a known state, and
# * don't have to worry about it later.
# */
kill_motor:
	push	%dx
	mov	$0x3f2, %dx
	mov	$0, %al
	outsb
	pop	%dx
	ret
				
# This routine checks that the keyboard command queue is empty
# No timeout is used - if this hangs there is something wrong with
# the machine, and we probably couldn't proceed anyway.
/*
empty_8042:
	.word	0x00eb,0x00eb
	in	$0x64, %al	# 8042 status port
	test	$2, %al		# is input buffer full?
	jnz	empty_8042	# yes - loop
	ret
*/

gdt:
	.word	0,0,0,0		# dummy

	.word	0xFFFF		# limit = 32GB
	.word	0x0000		# base address=0
	.word	0x9A00		# code read/exec
	.word	0x00CF		# granularity=4096, 386

	.word	0xFFFF		# limit = 32GB
	.word	0x0000		# base address=0
	.word	0x9200		# data read/write
	.word	0x00CF		# granularity=4096, 386

gdt64:
	.quad	0							# dummy
	.long 0, 0x00209A00	# code readable in long mode
	.long 0, 0x00209200	# data readable in long mode

gdt_48:
	.word	0x800			# gdt limit=2048, 256 GDT entries
	.word 512+gdt, 0x9		# gdt base = 0X9xxxx, 
	# 512+gdt is the real gdt after setup is moved to 0x9020 * 0x10

gdt_80:
	.word 256*8-1		
	.word 512+gdt64, 0x9, 0, 0

print_hex:
	mov $4,%cx
	mov %ax,%dx

print_digit:
	rol $4,%dx	#循环以使低4位用上，高4位移至低4位
	mov $0xe0f,%ax #ah ＝ 请求的功能值，al = 半个字节的掩码
	and %dl,%al
	add $0x30,%al
	cmp $0x3a,%al
	jl outp
	add $0x07,%al

outp:
	int $0x10
	loop print_digit
	ret
#打印回车换行
print_nl:
	mov $0xe0d,%ax
	int $0x10
	mov $0xa,%al
	int $0x10
	ret

sectors:
	.word 0
msg2:
	.byte 13,10
	.ascii "Now we are in setup ..."
	.byte 13,10,13,10
cur:
	.ascii "Cursor POS:"
mem:
	.ascii "Memory SIZE:"
cyl:
	.ascii "KB"
	.byte 13,10,13,10
	.ascii "HD Info"
	.byte 13,10
	.ascii "Cylinders:"
head:
	.ascii "Headers:"
sect:
	.ascii "Secotrs:"
far_sel:
	.long 0x00085000
.text
endtext:
.data
enddata:
.bss
endbss:

.code64
/*
 * Port to x86_64
 */

/*
 *  head64.s contains the 64-bit startup code.
 *
 * NOTE!!! Startup happens at absolute address 0x00000000, which is also where
 * the page directory will exist. The startup code will be overwritten by
 * the page directory.
 */
.text
.globl idt,gdt,pg_dir,tmp_floppy_area

pg_dir:
/*
 * I put the kernel page tables right after the page directory,
 * using 3 of them to span 128 MB of physical memory. People with
 * more than 128MB will have to expand this.
 */
PML4:
  .quad 0x1007  # PDPT_0
  .rept 0x1ff
    .quad 0
  .endr
PDPT_0: # Not all processors that support IA-32e paging support 1 pages
  .quad 0x2007 # PD_0
  .rept 0x1ff
    .quad 0
  .endr
PD_0:
  .set i, 0
  .rept 64    # 64*2=128MB
    .quad (i << 21)+0x87
    .set i, (i+1)
  .endr
  .rept 512-64
    .quad 0
  .endr

.org 0x5000
.globl startup_64
startup_64:
	movl $0x10,%eax
	mov %ax,%ds
	mov %ax,%es
	mov %ax,%fs
	mov %ax,%gs
  lssl stack_start,%esp
	call setup_gdt

#   mov $0x1234567890123456, %rax
#   mov $0x6000, %ebx
#   mov %rax, (%ebx)
#
# l:
#   jmp l

	movl $0x10,%eax		# reload all the segment registers
	mov %ax,%ds		# after changing gdt. CS was already
	mov %ax,%es		# reloaded in 'setup_gdt'
	mov %ax,%fs
	mov %ax,%gs
# lssl stack_start,%esp # TODO
	call setup_idt
	xorl %eax,%eax
1:	incl %eax		# check that A20 really IS enabled
	movl %eax,0x000000	# loop forever if it isn't
	cmpl %eax,0x100000
	je 1b

loop:
  jmp loop

# pushq $main # TODO main
# ret

/*
 *  setup_idt
 *
 *  sets up a idt with 256 entries pointing to
 *  ignore_int, interrupt gates. It then loads
 *  idt. Everything that wants to install itself
 *  in the idt-table may do so themselves. Interrupts
 *  are enabled elsewhere, when we can be relatively
 *  sure everything is ok. This routine will be over-
 *  written by the page tables.
 */

setup_idt:
	lea ignore_int,%edx
	movl $0x00080000,%eax /* selector = 0x0008 = cs */
	movw %dx,%ax
	movw $0x8E00,%dx	/* interrupt gate - dpl=0, present */
  xorl %ebx, %ebx

	lea idt,%edi
	mov $256,%ecx
rp_sidt:
	movl %eax,(%edi)
	movl %edx,4(%edi)
  movq %rbx,8(%edi)
# movl %ebx,12(%edi)
	addl $16,%edi
	dec %ecx
	jne rp_sidt
	lidt idt_descr
	ret

/*
 *  setup_gdt
 *
 *  This routines sets up a new gdt and loads it.
 *  Only two entries are currently built, the same
 *  ones that were built in init.s. The routine
 *  is VERY complicated at two whole lines, so this
 *  rather long comment is certainly needed :-).
 *  This routine will beoverwritten by the page tables.
 */
setup_gdt:
	lgdt gdt_descr
	ret

/*
 * tmp_floppy_area is used by the floppy-driver when DMA cannot
 * reach to a buffer-block. It needs to be aligned, so that it isn't
 * on a 64kB border.
 */
tmp_floppy_area:
	.fill 1024,1,0

/* This is the default interrupt "handler" :-) */
int_msg:
	.asciz "Unknown interrupt\n\r"
.align 4
ignore_int:
	pushq %rax
	pushq %rcx
	pushq %rdx
  movw %ds, %ax
  pushw %ax
  movw %es, %ax
  pushw %ax
  movw %fs, %ax
  pushw %ax
	mov $0x10,%ax
	mov %ax,%ds
	mov %ax,%es
	mov %ax,%fs
	pushq $int_msg
# call printk      // TODO
	popq %rax
  popw %ax
  movw %ax, %fs
  popw %ax
  movw %ax, %es
  popw %ax
  movw %ax, %ds
	popq %rdx
	popq %rcx
	popq %rax
	iretq

/*
 * Setup_paging
 *
 * This routine sets up paging by setting the page bit
 * in cr0. The page tables are set up, identity-mapping
 * the first 128MB. The pager assumes that no illegal
 * addresses are produced (ie >4Mb on a 4Mb machine).
 *
 * NOTE! Although all physical memory should be identity
 * mapped by this routine, only the kernel page functions
 * use the >1Mb addresses directly. All "normal" functions
 * use just the lower 1Mb, or the local data space, which
 * will be mapped to some other place - mm keeps track of
 * that.
 */
#.align 4
#setup_paging:
#  movl PML4, %esi
#  xorl %edi, %edi
#  movl $0xc00, $ecx       # 3*4KB/4B=3K
#  cld;rep;movsl
#
#  movq %cr4, %rax
#	xorl %eax,%eax		/* pg_dir is at 0x0000 */
#	movl %eax,%cr3		/* cr3 - page directory start */
#	movl %cr0,%eax
#	orl $0x80000000,%eax
#	movl %eax,%cr0		/* set paging (PG) bit */
#	ret			/* this also flushes prefetch-queue */

.align 4
.word 0
idt_descr:
	.word 256*8-1		# idt contains 256 entries
	.long idt
.align 4
.word 0
gdt_descr:
	.word 256*16-1		# so does gdt (not that that's any
	.quad gdt	      	# magic number, but it works for me :^)

# In 64-bit processor, an entry in idt is 16B long.
.align 16
idt:	.fill 256*2,8,0		# idt is uninitialized

.align 8
gdt:
	.quad	0, 0       # dummy
  .long 0, 0x00209a00, 0, 0  # code readable in long mode
  .long 0, 0x00209200, 0, 0  # data readable in long mode
  .fill 504,8,0  # space for LDT's and TSS's etc (252*2=504)

stack_start:    # TODO This should be removed after sched.c is compiled
  .long 0x00026fa0, 0x10

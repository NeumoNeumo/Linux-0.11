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
  .fill 255,8,0
  .quad 0x1007
  .fill 255,8,0
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
	lgdt gdt_descr(%rip)
	movl $0x10,%eax		# reload all the segment registers
	mov %ax,%ds		# after changing gdt. CS was already
	mov %ax,%es		# reloaded in 'setup_gdt'
	mov %ax,%fs
	mov %ax,%gs
  mov %ax,%ss
  mov stack_start(%rip),%rsp

  mov turn_HHK(%rip), %rax
  pushq $0x08
  pushq %rax
  lretq

turn_HHK:
 .quad setup_idt # 0xFFFF8000XXXXXXXX after ld

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
	lea ignore_int(%rip),%rdx
	movl $0x00080000,%eax /* selector = 0x0008 = cs */
	movw %dx,%ax
	movw $0x8E00,%dx	/* interrupt gate - dpl=0, present */
  movq $0x00000000FFFF8000, %rbx
  lea idt(%rip), %rdi
	mov $256,%ecx
rp_sidt:
	movl %eax,(%edi)
	movl %edx,4(%edi)
  movq %rbx,8(%edi)
# movl %ebx,12(%edi)
	addl $16,%edi
	dec %ecx
	jne rp_sidt
	lidt idt_descr(%rip)

setup_tss:
  leaq tss_table(%rip), %rdx
  xorq %rax, %rax
  xorq %rcx, %rcx
  movq $0x89, %rax # present, 64bit TSS
  shlq $40, %rax
  movl %edx, %ecx 
  shrl $24, %ecx
  shlq $56, %rcx
  addq %rcx, %rax
  xorq %rcx, %rcx
  movl %edx, %ecx
  andl $0xffffff, %ecx
  shlq $16, %rcx
  addq %rcx, %rax
  addq $0x67, %rax # limit
  leaq gdt(%rip), %rdi
  movq %rax, 24(%rdi) # gdt_idx = 3
  shrq $32, %rdx
  movq %rdx, 32(%rdi)
# load tss
  mov	$0x18, %ax # 11000b, gdt_idx = 3
  ltr	%ax

# long return to main
  lea main(%rip), %rax
	pushq	$0x08
  pushq %rax
  lretq

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
	pushq	%rax
	pushq	%rbx
	pushq	%rcx
	pushq	%rdx
	pushq	%rbp
	pushq	%rdi
	pushq	%rsi
	pushq	%r8
	pushq	%r9
	pushq	%r10
	pushq	%r11
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
  movw %ds, %ax
  pushw %ax
  movw %es, %ax
  pushw %ax
  movw %fs, %ax
  pushw %ax
  movw %gs, %ax
  pushw %ax

	mov $0x10,%ax
	mov %ax,%ds
	mov %ax,%es
	mov %ax,%fs
	pushq int_msg(%rip)
# call printk      // TODO
  add $0x8, %rsp

l:
  jmp l

  popw %ax
  movw %ax, %gs
  popw %ax
  movw %ax, %fs
  popw %ax
  movw %ax, %es
  popw %ax
  movw %ax, %ds
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %r11
  popq %r10
  popq %r9
  popq %r8
  
	popq	%rsi
	popq	%rdi
	popq	%rbp
	popq	%rdx
	popq	%rcx
	popq	%rbx
	popq	%rax
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
	.word 256*16-1		# idt contains 256 entries
	.quad idt

.align 4
.word 0
gdt_descr:
	.word 256*8-1		# so does gdt (not that that's any
	.quad gdt	      	# magic number, but it works for me :^)

# In 64-bit processor, an entry in idt is 16B long.
idt:	.fill 256*2,8,0		# idt is uninitialized

gdt:
	.quad	0             # dummy
  .long 0, 0x00209a00 # code readable in long mode
  .long 0, 0x00209200 # data readable in long mode
  .fill 504,8,0       # space for LDT's and TSS's etc (252*2=504)

tss_table:
	.fill 26,4,0 # 26 * 4 = 104 (64bit TSS)

stack_start:    # TODO This should be removed after sched.c is compiled
  .quad 0x26fa0

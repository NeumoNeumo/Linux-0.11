/*
 *  linux/kernel/asm.s
 *
 *  (C) 1991  Linus Torvalds
 */

/*
 * asm.s contains the low-level code for most hardware faults.
 * page_exception is handled by the mm, so that isn't here. This
 * file also handles (hopefully) fpu-exceptions due to TS-bit, as
 * the fpu must be properly saved/resored. This hasn't been tested.
 */

.globl divide_error,debug,nmi,int3,overflow,bounds,invalid_op
.globl double_fault,coprocessor_segment_overrun
.globl invalid_TSS,segment_not_present,stack_segment
.globl general_protection,coprocessor_error,irq13,reserved

#ifdef __x86__
divide_error:
	pushl $do_divide_error
no_error_code:
	xchgl %eax,(%esp)
	pushl %ebx
	pushl %ecx
	pushl %edx
	pushl %edi
	pushl %esi
	pushl %ebp
	push %ds
	push %es
	push %fs
	pushl $0		# "error code"
	lea 44(%esp),%edx
	pushl %edx
	movl $0x10,%edx
	mov %dx,%ds
	mov %dx,%es
	mov %dx,%fs
	call *%eax
	addl $8,%esp
	pop %fs
	pop %es
	pop %ds
	popl %ebp
	popl %esi
	popl %edi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax
	iret

debug:
	pushl $do_int3		# _do_debug
	jmp no_error_code

nmi:
	pushl $do_nmi
	jmp no_error_code

int3:
	pushl $do_int3
	jmp no_error_code

overflow:
	pushl $do_overflow
	jmp no_error_code

bounds:
	pushl $do_bounds
	jmp no_error_code

invalid_op:
	pushl $do_invalid_op
	jmp no_error_code

coprocessor_segment_overrun:
	pushl $do_coprocessor_segment_overrun
	jmp no_error_code

reserved:
	pushl $do_reserved
	jmp no_error_code

irq13:
	pushl %eax
	xorb %al,%al
	outb %al,$0xF0
	movb $0x20,%al
	outb %al,$0x20
	jmp 1f
1:	jmp 1f
1:	outb %al,$0xA0
	popl %eax
	jmp coprocessor_error

double_fault:
	pushl $do_double_fault
error_code:
	xchgl %eax,4(%esp)		# error code <-> %eax
	xchgl %ebx,(%esp)		# &function <-> %ebx
	pushl %ecx
	pushl %edx
	pushl %edi
	pushl %esi
	pushl %ebp
	push %ds
	push %es
	push %fs
	pushl %eax			# error code
	lea 44(%esp),%eax		# offset
	pushl %eax
	movl $0x10,%eax
	mov %ax,%ds
	mov %ax,%es
	mov %ax,%fs
	call *%ebx
	addl $8,%esp
	pop %fs
	pop %es
	pop %ds
	popl %ebp
	popl %esi
	popl %edi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax
	iret
#elif __X64__
divide_error:
	pushq $do_divide_error
no_error_code:
	xchgq %rax,(%rsp)
	pushq %rbx
	pushq %rcx
	pushq %rdx
	pushq %rdi
	pushq %rsi
	pushq %rbp
	push %ds
	push %es
	push %fs
	pushq $0              # "error code"
	lea 44(%rsp),%rdx
	pushq %rdx
	movq $0x10,%rdx
	mov %dx,%ds
	mov %dx,%es
	mov %dx,%fs
	call *%rax
	addq $16,%rsp
	pop %fs
	pop %es
	pop %ds
	popq %rbp
	popq %rsi
	popq %rdi
	popq %rdx
	popq %rcx
	popq %rbx
	popq %rax
	iretq

double_fault:
	pushq $do_double_fault
error_code:
	xchgq %rax,8(%rsp)       # error code <-> %rax
	xchgq %rbx,(%rsp)        # &function <-> %rbx
	pushq %rcx
	pushq %rdx
	pushq %rdi
	pushq %rsi
	pushq %rbp
	push %ds
	push %es
	push %fs
	pushq %rax               # error code
	lea 44(%rsp),%rax        # offset
	pushq %rax
	movq $0x10,%rax
	mov %ax,%ds
	mov %ax,%es
	mov %ax,%fs
	call *%rbx
	addq $16,%rsp
	pop %fs
	pop %es
	pop %ds
	popq %rbp
	popq %rsi
	popq %rdi
	popq %rdx
	popq %rcx
	popq %rbx
	popq %rax
	iretq
#endif


#IFDEF __X86__
invalid_TSS:
	pushl $do_invalid_TSS
	jmp error_code

segment_not_present:
	pushl $do_segment_not_present
	jmp error_code

stack_segment:
	pushl $do_stack_segment
	jmp error_code

general_protection:
	pushl $do_general_protection
	jmp error_code
#elif __X64__
invalid_TSS:
	pushq $do_invalid_TSS
	jmp error_code

segment_not_present:
	pushq $do_segment_not_present
	jmp error_code

stack_segment:
	pushq $do_stack_segment
	jmp error_code

general_protection:
	pushq $do_general_protection
	jmp error_code
#ENDIF


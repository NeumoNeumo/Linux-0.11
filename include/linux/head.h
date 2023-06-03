#ifndef _HEAD_H
#define _HEAD_H

#include <stdint.h>

#ifdef __X86__
typedef struct desc_struct {
	unsigned long a,b;
} desc_table[256];

extern unsigned long pg_dir[1024];
extern desc_table idt,gdt;

#elif __X64__
typedef uint64_t gdt_t[256];
typedef struct idt_entry {
  uint64_t a, b;
} idt_t [256];
typedef struct ldt_entry {
  uint64_t a, b;
} ldt_t [256];

extern uint64_t pg_dir[512];
extern gdt_t gdt;
extern idt_t idt;
#endif

#define GDT_NUL 0
#define GDT_CODE 1
#define GDT_DATA 2
#define GDT_TMP 3

#define LDT_NUL 0
#define LDT_CODE 1
#define LDT_DATA 2

#endif

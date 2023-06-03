#ifndef _STDDEF_H
#define _STDDEF_H

#include <stdint.h>

#ifndef _PTRDIFF_T
#define _PTRDIFF_T
#ifdef __X86__
typedef long ptrdiff_t;
#elif __X64__
typedef int64_t ptrdiff_t;
#endif
#endif

#ifndef _SIZE_T
#define _SIZE_T
#ifdef __X86__
typedef unsigned long size_t;
#elif __X64__
typedef uint64_t size_t;
#endif
#endif

#undef NULL
#define NULL ((void *)0)

#define offsetof(TYPE, MEMBER) ((size_t) &((TYPE *)0)->MEMBER)

#endif

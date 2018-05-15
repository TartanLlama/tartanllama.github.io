---
layout:     post
title:      "Bluff Your Way in LLVM IR"
category:   llvm
tags:
 - llvm
---

I attended a great talk at ACCU in 2017 by Roger Orr entitled [Bluff your way in x64 assembler](https://www.youtube.com/watch?v=RI7VL-g6J7g). It teaches enough x64 to enable the listener to read some disassembly listings and understand vaguely what the code is doing and how it relates to the source code. I thought to myself "Wouldn't it be great if there was a similar resource for LLVM IR?" Now there is[^1].

# What is LLVM?

[The LLVM Project](https://llvm.org/) is a collection of modular and reusable compiler and toolchain technologies. It forms the underbelly of many popular compilers, such as Clang, and the Swift and Rust compilers.

TODO more

# What is LLVM IR?

# SSA Form

# Instructions, Basic Blocks, Functions, and Modules

### Instructions

In LLVM IR, like in assembly, work is carried out by instructions. An instruction looks like this:

```llvm
%9 = add nsw i32 %8, 12
```

This adds the immediate value `12` to the value of the variable `%8` and stores it in variable `%9`. All local identifiers (register names, types), begin with an `%`, whereas global identifiers (functions, global variables) begin with `@`.

### Basic Blocks

Instructions are grouped into _basic blocks_. A basic block is a straight-line sequence of instructions with no entry point other than the start of the block, and no exit point other than the end of the block. The exit point is known as the _terminator_. This is an example of a basic block:

```llvm
; <label>:7:                                      ; preds = %1
  %8 = load i32, i32* %3, align 4
  %9 = add nsw i32 %8, 12
  store i32 %9, i32* %2, align 4
  br label %10
```

This basic block has a label (`%7`), is preceeded by basic block `%1`, and its terminator branches to basic block `%10`.

### Functions

A function definition contains a list of basic blocks, where the first block is the entrance to the function. Here's an example:

```llvm
; Function Attrs: noinline nounwind optnone sspstrong uwtable
define i32 @foo(i32) #0 {
  %2 = alloca i32, align 4
  %3 = alloca i32, align 4
  store i32 %0, i32* %3, align 4
  %4 = load i32, i32* %3, align 4
  %5 = icmp ne i32 %4, 0
  br i1 %5, label %6, label %7

; <label>:6:                                      ; preds = %1
  store i32 4, i32* %2, align 4
  br label %10

; <label>:7:                                      ; preds = %1
  %8 = load i32, i32* %3, align 4
  %9 = add nsw i32 %8, 12
  store i32 %9, i32* %2, align 4
  br label %10

; <label>:10:                                     ; preds = %7, %6
  %11 = load i32, i32* %2, align 4
  ret i32 %11
}
```

TODO more

### Modules

All of the functions and global variables produced from a translation unit come together to create a module.

TODO more

```llvm
; ModuleID = 'test.c'
source_filename = "test.c"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Function Attrs: noinline nounwind optnone sspstrong uwtable
define i32 @foo(i32) #0 {
  %2 = alloca i32, align 4
  %3 = alloca i32, align 4
  store i32 %0, i32* %3, align 4
  %4 = load i32, i32* %3, align 4
  %5 = icmp ne i32 %4, 0
  br i1 %5, label %6, label %7

; <label>:6:                                      ; preds = %1
  store i32 4, i32* %2, align 4
  br label %10

; <label>:7:                                      ; preds = %1
  %8 = load i32, i32* %3, align 4
  %9 = add nsw i32 %8, 12
  store i32 %9, i32* %2, align 4
  br label %10

; <label>:10:                                     ; preds = %7, %6
  %11 = load i32, i32* %2, align 4
  ret i32 %11
}

; Function Attrs: noinline nounwind optnone sspstrong uwtable
define i32 @foo_with_2() #0 {
  %1 = call i32 @foo(i32 2)
  ret i32 %1
}

attributes #0 = { noinline nounwind optnone sspstrong uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 7, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{!"clang version 5.0.1 (tags/RELEASE_501/final)"}
```

# Types

# Common Instructions

### Alloca
`alloca` allocates memory on the stack to hold an object of the given type, and returns a pointer to this address. The following instruction allocates space for an `i32`:

```llvm
%ptr = alloca i32 ; %ptr is of type i32*
```

This is essentially equivalent to `int i;` in C.

### Load/Store

Once we've allocated space for some object, we need a way to load and store data given a pointer. The aptly named `load` and `store` instructions give us this.

```llvm
store i32 42, i32* %ptr
%val = load i32, i32* %ptr
```

### GEP

### Control flow

There are myriad instructions for handling control flow in LLVM.

Conditional and unconditional branches are handled by `br`:

```llvm
br i1 %condition, label %WhenTrue, label %WhenFalse
br label %UnconditionalBlock
```

`call` calls a function and `ret` returns from one:

```llvm
%1 = call i32 @foo(i32 2) ; call foo with the argument 2 and store the result in %1
ret i32 %1 ; return %1
ret void   ; return nothing
```

### Conversions

### Select

### Arithmetic and Logic

### PHI

### Intrinsics

# Metadata




-----------------

[^1]: Okay, okay, there are already a few like [this](https://hub.packtpub.com/introducing-llvm-intermediate-representation/) and [this](https://felixangell.com/blog/an-introduction-to-llvm-in-go), but they all leave out concepts I think are important.

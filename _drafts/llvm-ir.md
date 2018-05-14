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

# Modules, Functions, Basic Blocks, and Instructions

# Types

# Common Instructions

## Alloca
## Load/Store
## GEP
## Arithmetic

# PHI Nodes

# Metadata




-----------------

[^1]: Okay, okay, there are already a few like [this](https://hub.packtpub.com/introducing-llvm-intermediate-representation/) and [this](https://felixangell.com/blog/an-introduction-to-llvm-in-go), but they all leave out concepts I think are important.

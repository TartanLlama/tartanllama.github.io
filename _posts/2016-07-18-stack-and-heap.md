---
layout:     post
title:      "Stack and Heap: Commonly Misused Terms"
date:       2016-07-18
category:   c++
minutes: 10
tags:
 - c++
 - rants
---

The terms "stack" and "heap" are often used in C++ writings inaccurately and unnecessarily. This article will show why the usage is incorrect and what terms should be used instead.

-----------

Have a look at the following code sample and have a think about where the `int`s are stored. Write down the answers if you feel like it.

{% highlight cpp %}
static int a;
static int b = 97;

void foo (int c) {
    int d = 42;
}

int main() {
    auto e = new int{314};
    foo(*e);
}
{% endhighlight %}

A common answer might look like this:

    a -> .bss binary section
    b -> .data binary section
    c -> register
    d -> stack
    *e -> heap

This is certainly a possibility. It mostly holds for an unoptimised compilation on my x86_64 Arch Linux system.

{% highlight nasm %}
        .file   "test.cpp"
        .intel_syntax noprefix
        .local  _ZL1a
        .comm   _ZL1a,4,4           ;a in .bss
        .data                       ;b in .data
        .align 4
        .type   _ZL1b, @object
        .size   _ZL1b, 4
_ZL1b:
        .long   97
{% endhighlight %}

Don't worry if you can't read assembly. Essentially, that `.comm` directive says to allocate space for a "common" symbol, which on a platform which uses ELF (like Linux), generally means to put it in the `.bss` section. That `.data` directive tells the assembler to put the subsequently declared data into the `.data` section.

{% highlight nasm %}
main:
.LFB1:
        .cfi_startproc
        push    rbp
        .cfi_def_cfa_offset 16
        .cfi_offset 6, -16
        mov     rbp, rsp
        .cfi_def_cfa_register 6
        sub     rsp, 16
        mov     edi, 4
        call    _Znwm                     ;allocate e with new
        mov     DWORD PTR [rax], 314      ;store 314 at *e
        mov     QWORD PTR [rbp-8], rax    ;put pointer on stack
        mov     rax, QWORD PTR [rbp-8]
        mov     eax, DWORD PTR [rax]      ;put *e in register
        mov     edi, eax                  ;put *e in argument register
        call    _Z3fooi
        mov     eax, 0
        leave
        .cfi_def_cfa 7, 8
        ret
        .cfi_endproc
{% endhighlight %}

`*e` is stored on the *free store*, which is where `new` allocates from. This is the "official" name for what is often referred to as the "heap"; some think that using it is just pendantry, but I wish more would use it, as the term "heap" is unhelpfully overloaded in programming. The argument for the `c` parameter is stored in the `edi` register.

{% highlight nasm %}
_Z3fooi:                                   ;start of foo
.LFB0:
        .cfi_startproc
        push    rbp
        .cfi_def_cfa_offset 16
        .cfi_offset 6, -16
        mov     rbp, rsp
        .cfi_def_cfa_register 6
        mov     DWORD PTR [rbp-20], edi    ;move c from reg to stack
        mov     DWORD PTR [rbp-4], 42      ;d on stack
        nop
        pop     rbp
        .cfi_def_cfa 7, 8
        ret
        .cfi_endproc
{% endhighlight %}

Although `c` is passed in through a register, it is placed on the stack at the beginning of the function. `d` is allocated on the stack.

A more accurate answer for this particular compilation is:

    a -> .bss binary section
    b -> .data binary section
    c -> passed through register, stored on stack
    d -> stack
    *e -> free store

What if we turn on optimisations?

{% highlight nasm %}
        .file   "test.cpp"
        .intel_syntax noprefix
{% endhighlight %}

`a` and `b` are totally optimised out.

{% highlight nasm %}
_Z3fooi:
.LFB0:
        .cfi_startproc
        rep ret
        .cfi_endproc
{% endhighlight %}

So are `c` and `d`.

{% highlight nasm %}
main:
.LFB1:
        .cfi_startproc
        sub     rsp, 8
        .cfi_def_cfa_offset 16
        mov     edi, 4
        call    _Znwm          ;allocates e
        xor     eax, eax
        add     rsp, 8
        .cfi_def_cfa_offset 8
        ret
        .cfi_endproc
{% endhighlight %}

The calls to `foo` are removed. `*e` is allocated, but not initialized.

So for this example, the answers are:

    a -> none
    b -> none
    c -> none
    d -> none
    *e -> free store

What if we used a different operating system? Or a different compiler? The answers could be completely different again.

It should be obvious now that regardless of how a variable is declared and initialized in C++, you can't determine how it will be stored in a generic manner. `d` could be allocated on the stack, or stored in a register, or optimised out, or put in some other uncommon architecture-specific area. Sometimes you might not even *have* a stack, let alone a heap (very early BIOS code, for example).

---------------

So what does the C++ standard have to say about stacks and heaps and suchlike?

**Nothing.**

The standard says nothing about how or where things are stored. The words "stack" and "heap" are used at various points, but only in reference to things like stack unwinding, `std::stack`, and heap data structure operations (`std::make_heap` and friends).

In that case what *does* the standard say?

-------------

C++, like any programming language, is built on abstractions. The specification defines an abstract machine which implementations are to emulate, and so long as an implementation executes a well-formed program with the same observable behaviour as a possible abstract machine execution, it's free to model the machine however it wishes. Storage is another area in which the standard uses an abstraction to avoid peppering architecture-specific terms across the document.

**The standard does not define storage *location*. It defines storage *duration*.**

>Storage duration is the property of an object that defines the minimum potential lifetime of the storage containing the object. The storage duration is determined by the construct used to create the object and is one of the following:
>
> - static storage duration
> - thread storage duration
> - automatic storage duration
> - dynamic storage duration
{:.standards para="[basic.stc]/1"}

The descriptions of each of these durations are aptly precise and verbose, so I'll explain with some examples.

### Static storage duration

{% highlight cpp %}
static int a;
static int b = 42;

void foo() {
    static int c;
}

struct Bar {
    static int d;
};
{% endhighlight %}

`a`, `b`, `c` and `d` have static storage duration. The storage for them will last for the duration of the program, but it's unspecified where that storage is located.

### Thread storage duration

{% highlight cpp %}
thread_local int a;
thread_local int b = 42;

void foo() {
    thread_local int ill_formed;
    static thread_local int c;                     
}

struct Bar {
    thread_local int d;
};
{% endhighlight %}

`a`, `b`, `c` and `d` have thread storage duration. The storage for them will last for the duration of the thread in which they are created. Note that `static` must be specified for thread local class members. Thread storage duration is a C++11 feature.


### Automatic storage duration
{% highlight cpp %}
void foo(int a) {
    int b;
    register int c;
}
{% endhighlight %}

`a`, `b` and `c`  have automatic storage duration. The storage for them will last until the block in which they are created exits. `register` gives a hint to allocate the variable in a register, but it's deprecated since C++11 and will be removed in C++17.

### Dynamic storage duration
{% highlight cpp %}
int* a = new int{};

void foo() {
    int* b = new int{};
}
{% endhighlight %}

`*a` and `*b` have dynamic storage duration. The storage for them will last until it is reclaimed using `delete`.


-------------

Now that we have a common, accurate language with which to talk about these concepts, we can rephrase my original question and give the correct answer to it.

What is the storage duration of the variables in the following example?

{% highlight cpp %}
static int a;
static int b = 97;

void foo (int c) {
    int d = 42;
}

int main() {
    auto e = new int{314};
    foo(*e);
}
{% endhighlight %}

The answers:

    a -> static
    b -> static
    c -> automatic
    d -> automatic
    *e -> dynamic

-------------

Is all of this just needless pedantry? I don't believe so. As programmers we all know the value of abstraction, precicion, clarity, unambiguity. Using these terms is in aid of these goals, and is particularly helpful for those learning the language. 

My final question is this: when should we refer to the storage duration and when should we refer to the storage location? I would advise the following:

**Only refer to the storage location if you need to discuss where a variable is physically located. In all other cases, refer to the storage duration.**




---
layout:     post
title:      "Writing a Linux Debugger Part 10: Advanced topics"
category:   c++
tags:
 - c++
redirect_from:
  - /c++/2017/08/01/writing-a-linux-debugger-advanced-topics/
  - /writing-a-linux-debugger-advanced-topics.html
---

*This series has been expanded into a book! It covers many more topics in much greater detail. You can now pre-order [Building a Debugger](https://nostarch.com/building-a-debugger).*

We're finally here at the last post of the series! This time I'll be giving a high-level overview of some more advanced concepts in debugging: remote debugging, shared library support, expression evaluation, and multi-threaded support. These ideas are more complex to implement, so I won't walk through how to do so in detail, but I'm happy to answer questions about these concepts if you have any.

-------------------------------

### Series index

1. [Setup]({% post_url 2017-03-21-writing-a-linux-debugger-setup %})
2. [Breakpoints]({% post_url 2017-03-24-writing-a-linux-debugger-breakpoints %})
3. [Registers and memory]({% post_url 2017-03-31-writing-a-linux-debugger-registers %})
4. [Elves and dwarves]({% post_url 2017-04-05-writing-a-linux-debugger-elf-dwarf %})
5. [Source and signals]({% post_url 2017-04-24-writing-a-linux-debugger-source-signal %})
6. [Source-level stepping]({% post_url 2017-05-06-writing-a-linux-debugger-dwarf-step %})
7. [Source-level breakpoints]({% post_url 2017-06-19-writing-a-linux-debugger-source-break %})
8. [Stack unwinding]({% post_url 2017-06-24-writing-a-linux-debugger-unwinding %})
9. [Handling variables]({% post_url 2017-07-26-writing-a-linux-debugger-variables %})
10. [Advanced topics]({% post_url 2017-08-01-writing-a-linux-debugger-advanced-topics %})

-------------------

### Remote debugging

Remote debugging is very useful for embedded systems or debugging the effects of environment differences. It also sets a nice divide between the high-level debugger operations and the interaction with the operating system and hardware. In fact, debuggers like GDB and LLDB operate as remote debuggers even when debugging local programs. The general architecture is this:

![debugarch](/assets/debugarch.png)

The debugger is the component which we interact with through the command line. Maybe if you're using an IDE there'll be another layer on top which communicates with the debugger through the *machine interface*. On the target machine (which may be the same as the host) there will be a *debug stub*, which in theory is a very small wrapper around the OS debug library which carries out all of your low-level debugging tasks like setting breakpoints on addresses. I say "in theory" because stubs are getting larger and larger these days. The LLDB debug stub on my machine is 7.6MB, for example. The debug stub communicates with the debugee process using some OS-specific features (in our case, `ptrace`), and with the debugger though some remote protocol.

The most common remote protocol for debugging is the GDB remote protocol. This is a text-based packet format for communicating commands and information between the debugger and debug stub. I won't go into detail about it, but you can read all you could want to know about it [here](https://sourceware.org/gdb/onlinedocs/gdb/Remote-Protocol.html). If you launch LLDB and execute the command `log enable gdb-remote packets` then you'll get a trace of all packets sent through the remote protocol. On GDB you can write `set remotelogfile <file>` to do the same.

As a simple example, here's the packet to set a breakpoint:

```
$Z0,400570,1#43
```

`$` marks the start of the packet. `Z0` is the command to insert a memory breakpoint. `400570` and `1` are the argumets, where the former is the address to set a breakpoint on and the latter is a target-specific breakpoint kind specifier. Finally, the `#43` is a checksum to ensure that there was no data corruption.

The GDB remote protocol is very easy to extend for custom packets, which is very useful for implementing platform- or language-specific functionality.

-------------------

### Shared library and dynamic loading support

The debugger needs to know what shared libraries have been loaded by the debuggee so that it can set breakpoints, get source-level information and symbols, etc. As well as finding libraries which have been dynamically linked against, the debugger must track libraries which are loaded at runtime through `dlopen`. To facilitate this, the dynamic linker maintains a *rendezvous structure*. This structure maintains a linked list of shared library descriptors, along with a pointer to a function which is called whenever the linked list is updated. This structure is stored where the `.dynamic` section of the ELF file is loaded, and is initialized before program execution.

A simple tracing algorithm is this:
{:.listhead}

- The tracer looks up the entry point of the program in the ELF header (or it could use the auxillary vector stored in `/proc/<pid>/aux`)
- The tracer places a breakpoint on the entry point of the program and begins execution.
- When the breakpoint is hit, the address of the rendezvous structure is found by looking up the load address of `.dynamic` in the ELF file.
- The rendezvous structure is examined to get the list of currently loaded libraries.
- A breakpoint is set on the linker update function.
- Whenever the breakpoint is hit, the list is updated.
- The tracer infinitely loops, continuing the program and waiting for a signal until the tracee signals that it has exited.

I've written a small demonstration of these concepts, which you can find [here](https://github.com/TartanLlama/dltrace). I can do a more detailed write up of this in the future if anyone is interested.

-------------------

### Expression evaluation

Expression evaluation is a feature which lets users evaluate expressions in the original source language while debugging their application. For example, in LLDB or GDB you could execute `print foo()` to call the `foo` function and print the result.

Depending on how complex the expression is, there are a few different ways of evaluating it. If the expression is a simple identifier, then the debugger can look at the debug information, locate the variable and print out the value, just like we did in the last part of this series. If the expression is a bit more complex, then it may be possible to compile the code to an intermediate representation (IR) and interpret that to get the result. For example, for some expressions LLDB will use Clang to compile the expression to LLVM IR and interpret that. If the expression is even more complex, or requires calling some function, then the code might need to be JITted to the target and executed in the address space of the debuggee. This involves calling `mmap` to allocate some executable memory, then the compiled code is copied to this block and is executed. LLDB does this by using LLVM's JIT functionality.

If you want to know more about JIT compilation, I'd highly recommend [Eli Bendersky's posts on the subject](http://eli.thegreenplace.net/tag/code-generation).

-------------------

### Multi-threaded debugging support

The debugger shown in this series only supports single threaded applications, but to debug most real-world applications, multi-threaded support is highly desirable. The simplest way to support this is to trace thread creation and parse the procfs to get the information you want.

The Linux threading library is called `pthreads`. When `pthread_create` is called, the library creates a new thread using the `clone` syscall, and we can trace this syscall with `ptrace` (assuming your kernel is older than 2.5.46). To do this, you'll need to set some `ptrace` options after attaching to the debuggee:

{% highlight cpp %}
ptrace(PTRACE_SETOPTIONS, m_pid, nullptr, PTRACE_O_TRACECLONE);
{% endhighlight %}

Now when `clone` is called, the process will be signaled with our old friend `SIGTRAP`. For the debugger in this series, you can add a case to `handle_sigtrap` which can handle the creation of the new thread:

{% highlight cpp %}
case (SIGTRAP | (PTRACE_EVENT_CLONE << 8)):
    //get the new thread ID
    unsigned long event_message = 0;
    ptrace(PTRACE_GETEVENTMSG, pid, nullptr, message);

    //handle creation
    //...
{% endhighlight %}

Once you've got that, you can look in `/proc/<pid>/task/` and read the memory maps and suchlike to get all the information you need.

GDB uses `libthread_db`, which provides a bunch of helper functions so that you don't need to do all the parsing and processing yourself. Setting up this library is pretty weird and I won't show how it works here, but you can go and read [this tutorial](http://timetobleed.com/notes-about-an-odd-esoteric-yet-incredibly-useful-library-libthread_db/) if you'd like to use it.

The most complex part of multithreaded support is modelling the thread state in the debugger, particularly if you want to support [non-stop mode](https://sourceware.org/gdb/onlinedocs/gdb/Non_002dStop-Mode.html) or some kind of heterogeneous debugging where you have more than just a CPU involved in your computation.

-------------

### The end!

Whew! This series took a long time to write, but I learned a lot in the process and I hope it was helpful. Get in touch on Twitter [@TartanLlama](https://twitter.com/TartanLlama) or in the comments section if you want to chat about debugging or have any questions about the series. If there are any other debugging topics you'd like to see covered then let me know and I might do a bonus post.

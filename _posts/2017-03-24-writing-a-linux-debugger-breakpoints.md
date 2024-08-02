---
layout:     post
title:      "Writing a Linux Debugger Part 2: Breakpoints"
category:   c++
tags:
 - c++
redirect_from:
  - /c++/2017/03/24/writing-a-linux-debugger-breakpoints/
  - /writing-a-linux-debugger-breakpoints.html
---

*This series has been expanded into a book! It covers many more topics in much greater detail. You can now pre-order [Building a Debugger](https://nostarch.com/building-a-debugger).*

In the first part of this series we wrote a small process launcher as a base for our debugger. In this post we'll learn how breakpoints work in x86 Linux and augment our tool with the ability to set them.

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

-------------------------------

### How is breakpoint formed?

There are two main kinds of breakpoints: hardware and software. Hardware breakpoints typically involve setting architecture-specific registers to produce your breaks for you, whereas software breakpoints involve modifying the code which is being executed on the fly. We'll be focusing solely on software breakpoints for this article, as they are simpler and you can have as many as you want. On x86 you can only have four hardware breakpoints set at a given time, but they give you the power to make them fire on reading from or writing to a given address rather than only executing code there.

I said above that software breakpoints are set by modifying the executing code on the fly, so the questions are:
{:.listhead}

- How do we modify the code?
- What modifications do we make to set a breakpoint?
- How is the debugger notified?

The answer to the first question is, of course, `ptrace`. We've previously used it to set up our program for tracing and continuing its execution, but we can also use it to read and write memory.

The modification we make has to cause the processor to halt and signal the program when the breakpoint address is executed. On x86 this is accomplished by overwriting the instruction at that address with the `int 3` instruction. x86 has an *interrupt vector table* which the operating system can use to register handlers for various events, such as page faults, protection faults, and invalid opcodes. It's kind of like registering error handling callbacks, but right down at the hardware level. When the processor executes the `int 3` instruction, control is passed to the breakpoint interrupt handler, which -- in the case of Linux -- signals the process with a `SIGTRAP`. You can see this process in the diagram below, where we overwrite the first byte of the `mov` instruction with `0xcc`, which is the instruction encoding for `int 3`.

![breakpoint](/assets/breakpoint.png)

The last piece of the puzzle is how the debugger is notified of the break. If you remember back in the previous post, we can use `waitpid` to listen for signals which are sent to the debugee. We can do exactly the same thing here: set the breakpoint, continue the program, call `waitpid` and wait until the `SIGTRAP` occurs. This breakpoint can then be communicated to the user, perhaps by printing the source location which has been reached, or changing the focused line in a GUI debugger.

------------------------------

### Implementing software breakpoints

We'll implement a `breakpoint` class to represent a breakpoint on some location which we can enable or disable as we wish.

{% highlight cpp %}
class breakpoint {
public:
    breakpoint(pid_t pid, std::intptr_t addr)
        : m_pid{pid}, m_addr{addr}, m_enabled{false}, m_saved_data{}
    {}

    void enable();
    void disable();

    auto is_enabled() const -> bool { return m_enabled; }
    auto get_address() const -> std::intptr_t { return m_addr; }

private:
    pid_t m_pid;
    std::intptr_t m_addr;
    bool m_enabled;
    uint8_t m_saved_data; //data which used to be at the breakpoint address
};
{% endhighlight %}

Most of this is just tracking of state; the real magic happens in the `enable` and `disable` functions.

As we've learned above, we need to replace the instruction which is currently at the given address with an `int 3` instruction, which is encoded as `0xcc`. We'll also want to save out what used to be at that address so that we can restore the code later; we don't want to forget to execute the user's code!

{% highlight cpp %}
void breakpoint::enable() {
    auto data = ptrace(PTRACE_PEEKDATA, m_pid, m_addr, nullptr);
    m_saved_data = static_cast<uint8_t>(data & 0xff); //save bottom byte
    uint64_t int3 = 0xcc;
    uint64_t data_with_int3 = ((data & ~0xff) | int3); //set bottom byte to 0xcc
    ptrace(PTRACE_POKEDATA, m_pid, m_addr, data_with_int3);

    m_enabled = true;
}
{% endhighlight %}

The `PTRACE_PEEKDATA` request to `ptrace` is how to read the memory of the traced process. We give it a process ID and an address, and it gives us back the 64 bits which are currently at that address. `(data & ~0xff)` zeroes out the bottom byte of this data, then we bitwise `OR` that with our `int 3` instruction to set the breakpoint. Finally, we set the breakpoint by overwriting that part of memory with our new data with `PTRACE_POKEDATA`.

`disable` is easier, but still has a subtlety to it. Since the `ptrace` memory requests operate on whole words rather than bytes we need to first read the word which is at the location to restore, then overwrite the low byte with the original data and write it back to memory.

{% highlight cpp %}
void breakpoint::disable() {
    auto data = ptrace(PTRACE_PEEKDATA, m_pid, m_addr, nullptr);
    auto restored_data = ((data & ~0xff) | m_saved_data);
    ptrace(PTRACE_POKEDATA, m_pid, m_addr, restored_data);

    m_enabled = false;
}
{% endhighlight %}

------------------------------

### Adding breakpoints to the debugger

We'll make three changes to our debugger class to support setting breakpoints through the user interface:
{:.listhead}

1. Add a breakpoint storage data structure to `debugger`
2. Write a `set_breakpoint_at_address` function
3. Add a `break` command to our `handle_command` function

I'll store my breakpoints in a `std::unordered_map<std::intptr_t, breakpoint>` structure so that it's easy and fast to check if a given address has a breakpoint on it and, if so, retrieve that breakpoint object.


{% highlight cpp %}
class debugger {
    //...
    void set_breakpoint_at_address(std::intptr_t addr);
    //...
private:
    //...
    std::unordered_map<std::intptr_t,breakpoint> m_breakpoints;
}
{% endhighlight %}

In `set_breakpoint_at_address` we'll create a new breakpoint, enable it, add it to the data structure, and print out a message for the user. If you like, you could factor out all message printing so that you can use the debugger as a library as well as a command-line tool, but I'll mash it all together for simplicity.

{% highlight cpp %}
void debugger::set_breakpoint_at_address(std::intptr_t addr) {
    std::cout << "Set breakpoint at address 0x" << std::hex << addr << std::endl;
    breakpoint bp {m_pid, addr};
    bp.enable();
    m_breakpoints[addr] = bp;
}
{% endhighlight %}

Now we'll augment our command handler to call our new function.

{% highlight cpp %}
void debugger::handle_command(const std::string& line) {
    auto args = split(line,' ');
    auto command = args[0];

    if (is_prefix(command, "cont")) {
        continue_execution();
    }
    else if(is_prefix(command, "break")) {
        std::string addr {args[1], 2}; //naively assume that the user has written 0xADDRESS
        set_breakpoint_at_address(std::stol(addr, 0, 16));
    }
    else {
        std::cerr << "Unknown command\n";
    }
}
{% endhighlight %}

I've simply removed the first two characters of the string and called `std::stol` on the result, but feel free to make the parsing more robust. `std::stol` optionally takes a radix to convert from, which is handy for reading in hexadecimal.

------------------------------

### Continuing from the breakpoint

If you try this out, you might notice that if you continue from the breakpoint, nothing happens. That's because the breakpoint is still set in memory, so it's hit repeatedly. The simple solution is to disable the breakpoint, single step, re-enable it, then continue. Unfortunately we'd also need to modify the program counter to point back before the breakpoint, so we'll leave this until the next post where we'll learn about manipulating registers.

-----------------------------

### Testing it out

Of course, setting a breakpoint on some address isn't very useful if you don't know what address to set it at. In the future we'll be adding the ability to set breakpoints on function names or source code lines, but for now, we can work it out manually.

A way to test out your debugger is to write a hello world program which writes to `std::cerr` (to avoid buffering) and set a breakpoint on the call to the output operator. If you continue the debugee then hopefully the execution will stop without printing anything. You can then restart the debugger and set a breakpoint just after the call, and you should see the message being printed successfully.

One way to find the address is to use `objdump`. If you open up a shell and execute `objdump -d <your program>`, then you should see the disassembly for your code. You should then be able to find the `main` function and locate the `call` instruction which you want to set the breakpoint on. For example, I built a hello world example, disassembled it, and got this as the disassembly for `main`:

```
0000000000001189 <main>:
    1189:       f3 0f 1e fa             endbr64
    118d:       55                      push   %rbp
    118e:       48 89 e5                mov    %rsp,%rbp
    1191:       48 8d 35 6d 0e 00 00    lea    0xe6d(%rip),%rsi        # 2005 <_ZStL19piecewise_construct+0x1>
    1198:       48 8d 3d 81 2e 00 00    lea    0x2e81(%rip),%rdi        # 4020 <_ZSt4cerr@@GLIBCXX_3.4>
    119f:       e8 dc fe ff ff          callq  1080 <_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc@plt>
    11a4:       b8 00 00 00 00          mov    $0x0,%eax
    11a9:       5d                      pop    %rbp
    11aa:       c3                      retq
```

As you can see, we would want to set a breakpoint on `0x1198` to see no output, and `0x119f` to see the output.

However, these addresses may not be absolute. If the program is compiled as a [position independent executable](https://en.wikipedia.org/wiki/Position-independent_code), which is the default for some compilers, then they are offsets from the address which the binary is loaded at. And due to [address space layout randomization](https://en.wikipedia.org/wiki/Address_space_layout_randomization) this load address will change with each run of the program.

You could compile everything with `-no-pie` and be done with it, but that's not a great solution, and won't work for some projects. Instead we'll disable address space layout randomization for the programs we launch, and look up the correct load address.

To disable address space randomization, add a call to [`personality`](https://man7.org/linux/man-pages/man2/personality.2.html) before we call `execute_debugee` in the child process:

{% highlight cpp %}
if (pid == 0) {
    //child
    personality(ADDR_NO_RANDOMIZE);
    execute_debugee(prog);
}
{% endhighlight %}

To find the load address you can:

1. Start debugging the program
2. Note what the child process id is
3. Read /proc/&lt;pid&gt;/maps to find the load address

Here's the maps file for my program:

```
08000000-08001000 r--p 00000000 00:00 56882                      /path/to/hello
08001000-08002000 r-xp 00001000 00:00 56882                      /path/to/hello
08002000-08003000 r--p 00002000 00:00 56882                      /path/to/hello
08003000-08005000 rw-p 00002000 00:00 56882                      /path/to/hello
7fffff7b0000-7fffff7b1000 r--p 00000000 00:00 948077             /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fffff7b1000-7fffff7d3000 r-xp 00001000 00:00 948077             /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fffff7d3000-7fffff7d4000 r-xp 00023000 00:00 948077             /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fffff7d4000-7fffff7db000 r--p 00024000 00:00 948077             /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fffff7db000-7fffff7dc000 r--p 0002b000 00:00 948077             /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fffff7dd000-7fffff7df000 rw-p 0002c000 00:00 948077             /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fffff7df000-7fffff7e0000 rw-p 00000000 00:00 0
7fffff7ef000-7ffffffef000 rw-p 00000000 00:00 0                  [stack]
7ffffffef000-7fffffff0000 r-xp 00000000 00:00 0                  [vdso]
```

The important address is the first one noted for `/path/to/hello`, which is `0x08000000`. That's the load address of the binary. If you add the breakpoint offsets to that base address, you'll get the real addresses to set breakpoints at.

------------------------------

### Finishing up

You should now have a debugger which can launch a program and allow the user to set breakpoints on memory addresses. Next time we'll add the ability to read from and write to memory and registers. Again, let me know in the comments if you have any issues.

You can find the code for this post [here](https://github.com/TartanLlama/minidbg/tree/tut_break).

[Next post]({% post_url 2017-03-31-writing-a-linux-debugger-registers %})

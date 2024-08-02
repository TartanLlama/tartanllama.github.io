---
layout:     post
title:      "Writing a Linux Debugger Part 3: Registers and memory"
category:   c++
tags:
 - c++
redirect_from:
  - /c++/2017/03/31/writing-a-linux-debugger-registers/
  - /writing-a-linux-debugger-registers.html
---

*This series has been expanded into a book! It covers many more topics in much greater detail. You can now pre-order [Building a Debugger](https://nostarch.com/building-a-debugger).*

In the last post we added simple address breakpoints to our debugger. This time we'll be adding the ability to read and write registers and memory, which will allow us to screw around with our program counter, observe state and change the behaviour of our program.

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

---------------

### Registering our registers

Before we actually read any registers, we need to teach our debugger a bit about our target, which is x86_64. Alongside sets of general and special purpose registers, x86_64 has floating point and vector registers available. I'll be omitting the latter two for simplicity, but you can choose to support them if you like. x86_64 also allows you to access some 64 bit registers as 32, 16, or 8 bit registers, but I'll be sticking to 64. Due to these simplifications, for each register we need its name, its DWARF register number, and where it is stored in the structure returned by `ptrace`. I chose to have a scoped enum for referring to the registers, then I laid out a global register descriptor array with the elements in the same order as in the `ptrace` register structure.

{% highlight cpp %}
enum class reg {
    rax, rbx, rcx, rdx,
    rdi, rsi, rbp, rsp,
    r8,  r9,  r10, r11,
    r12, r13, r14, r15,
    rip, rflags,    cs,
    orig_rax, fs_base,
    gs_base,
    fs, gs, ss, ds, es
};

constexpr std::size_t n_registers = 27;

struct reg_descriptor {
    reg r;
    int dwarf_r;
    std::string name;
};

const std::array<reg_descriptor, n_registers> g_register_descriptors {{ "{{" }}
    { reg::r15, 15, "r15" },
    { reg::r14, 14, "r14" },
    { reg::r13, 13, "r13" },
    { reg::r12, 12, "r12" },
    { reg::rbp, 6, "rbp" },
    { reg::rbx, 3, "rbx" },
    { reg::r11, 11, "r11" },
    { reg::r10, 10, "r10" },
    { reg::r9, 9, "r9" },
    { reg::r8, 8, "r8" },
    { reg::rax, 0, "rax" },
    { reg::rcx, 2, "rcx" },
    { reg::rdx, 1, "rdx" },
    { reg::rsi, 4, "rsi" },
    { reg::rdi, 5, "rdi" },
    { reg::orig_rax, -1, "orig_rax" },
    { reg::rip, -1, "rip" },
    { reg::cs, 51, "cs" },
    { reg::rflags, 49, "eflags" },
    { reg::rsp, 7, "rsp" },
    { reg::ss, 52, "ss" },
    { reg::fs_base, 58, "fs_base" },
    { reg::gs_base, 59, "gs_base" },
    { reg::ds, 53, "ds" },
    { reg::es, 50, "es" },
    { reg::fs, 54, "fs" },
    { reg::gs, 55, "gs" },
}};
{% endhighlight %}

You can typically find the register data structure in `/usr/include/sys/user.h` if you'd like to look at it yourself, and the DWARF register numbers are taken from the [System V x86_64 ABI](https://www.uclibc.org/docs/psABI-x86_64.pdf).

Now we can write a bunch of functions to interact with registers. We'd like to be able to read registers, write to them, retrieve a value from a DWARF register number, and lookup registers by name and vice versa. Let's start with implementing `get_register_value`:

{% highlight cpp %}
uint64_t get_register_value(pid_t pid, reg r) {
    user_regs_struct regs;
    ptrace(PTRACE_GETREGS, pid, nullptr, &regs);
    //...
}
{% endhighlight %}

Again, `ptrace` gives us easy access to the data we want. We construct an instance of `user_regs_struct` and give that to `ptrace` alongside the `PTRACE_GETREGS` request.

Now we want to read `regs` depending on which register was requested. We could write a big switch statement, but since we've laid out our `g_register_descriptors` table in the same order as `user_regs_struct`, we can search for the index of the register descriptor, and access `user_regs_struct` as an array of `uint64_t`s.[^2]

[^2]: You could also reorder the `reg` enum and cast them to the underlying type to use as indexes, but I wrote it this way in the first place, it works, and I'm too lazy to change it.

{% highlight cpp %}
auto it = std::find_if(begin(g_register_descriptors), end(g_register_descriptors),
                        [r](auto&& rd) { return rd.r == r; });

return *(reinterpret_cast<uint64_t*>(&regs) + (it - begin(g_register_descriptors)));
{% endhighlight %}

The cast to `uint64_t` is safe because `user_regs_struct` is a standard layout type, but I think the pointer arithmetic is technically UB. No current compilers even warn about this and I'm lazy, but if you want to maintain utmost correctness, write a big switch statement.

`set_register_value` is much the same, we write to the location and write the registers back at the end:

{% highlight cpp %}
void set_register_value(pid_t pid, reg r, uint64_t value) {
    user_regs_struct regs;
    ptrace(PTRACE_GETREGS, pid, nullptr, &regs);
    auto it = std::find_if(begin(g_register_descriptors), end(g_register_descriptors),
                           [r](auto&& rd) { return rd.r == r; });

    *(reinterpret_cast<uint64_t*>(&regs) + (it - begin(g_register_descriptors))) = value;
    ptrace(PTRACE_SETREGS, pid, nullptr, &regs);
}
{% endhighlight %}

Next is lookup by DWARF register number. This time I'll actually check for an error condition just in case we get some weird DWARF information:

{% highlight cpp %}
uint64_t get_register_value_from_dwarf_register (pid_t pid, unsigned regnum) {
    auto it = std::find_if(begin(g_register_descriptors), end(g_register_descriptors),
                           [regnum](auto&& rd) { return rd.dwarf_r == regnum; });
    if (it == end(g_register_descriptors)) {
        throw std::out_of_range{"Unknown dwarf register"};
    }

    return get_register_value(pid, it->r);
}
{% endhighlight %}

Nearly finished, now he have register name lookups:

{% highlight cpp %}
std::string get_register_name(reg r) {
    auto it = std::find_if(begin(g_register_descriptors), end(g_register_descriptors),
                           [r](auto&& rd) { return rd.r == r; });
    return it->name;
}

reg get_register_from_name(const std::string& name) {
    auto it = std::find_if(begin(g_register_descriptors), end(g_register_descriptors),
                           [name](auto&& rd) { return rd.name == name; });
    return it->r;
}
{% endhighlight %}

And finally we'll add a helper to dump the contents of all registers:

{% highlight cpp %}
void debugger::dump_registers() {
    for (const auto& rd : g_register_descriptors) {
        std::cout << rd.name << " 0x"
                  << std::setfill('0') << std::setw(16) << std::hex << get_register_value(m_pid, rd.r) << std::endl;
    }
}
{% endhighlight %}

As you can see, iostreams has a very concise interface for outputting hex data nicely[^1]. Feel free to make an I/O manipulator to get rid of this mess if you like.

[^1]: Ahahahahahahahahahahahahahahahaha

This gives us enough support to handle registers easily in the rest of the debugger, so we can now add this to our UI.

----------------------

### Exposing our registers

All we need to do here is add a new command to the `handle_command` function. With the following code, users will be able to type `register read rax`, `register write rax 0x42` and so on.

{% highlight cpp %}
    else if (is_prefix(command, "register")) {
        if (is_prefix(args[1], "dump")) {
            dump_registers();
        }
        else if (is_prefix(args[1], "read")) {
            std::cout << get_register_value(m_pid, get_register_from_name(args[2])) << std::endl;
        }
        else if (is_prefix(args[1], "write")) {
            std::string val {args[3], 2}; //assume 0xVAL
            set_register_value(m_pid, get_register_from_name(args[2]), std::stol(val, 0, 16));
        }
    }
{% endhighlight %}

----------------------

### Where is my mind?

We've already read from and written to memory when setting our breakpoints, so we need to add a couple of functions to hide the `ptrace` call a bit.

{% highlight cpp %}
uint64_t debugger::read_memory(uint64_t address) {
    return ptrace(PTRACE_PEEKDATA, m_pid, address, nullptr);
}

void debugger::write_memory(uint64_t address, uint64_t value) {
    ptrace(PTRACE_POKEDATA, m_pid, address, value);
}
{% endhighlight %}

You might want to add support for reading and writing more than a word at a time, which you can do by incrementing the address each time you want to read another word. You could also use [`process_vm_readv` and `process_vm_writev`](http://man7.org/linux/man-pages/man2/process_vm_readv.2.html) or `/proc/<pid>/mem` instead of `ptrace` if you like.

Now we'll add commands for our UI:

{% highlight cpp %}
    else if(is_prefix(command, "memory")) {
        std::string addr {args[2], 2}; //assume 0xADDRESS

        if (is_prefix(args[1], "read")) {
            std::cout << std::hex << read_memory(std::stol(addr, 0, 16)) << std::endl;
        }
        if (is_prefix(args[1], "write")) {
            std::string val {args[3], 2}; //assume 0xVAL
            write_memory(std::stol(addr, 0, 16), std::stol(val, 0, 16));
        }
    }
{% endhighlight %}

----------------------

### Patching `continue_execution`

Before we test out our changes, we're now in a position to implement a more sane version of `continue_execution`. Since we can get the program counter, we can check our breakpoint map to see if we're at a breakpoint. If so, we can disable the breakpoint and step over it before continuing.

First we'll add for couple of helper functions for clarity and brevity:

{% highlight cpp %}
uint64_t debugger::get_pc() {
    return get_register_value(m_pid, reg::rip);
}

void debugger::set_pc(uint64_t pc) {
    set_register_value(m_pid, reg::rip, pc);
}
{% endhighlight %}

Then we can write a function to step over a breakpoint:

{% highlight cpp %}
void debugger::step_over_breakpoint() {
    // - 1 because execution will go past the breakpoint
    auto possible_breakpoint_location = get_pc() - 1;

    if (m_breakpoints.count(possible_breakpoint_location)) {
        auto& bp = m_breakpoints[possible_breakpoint_location];

        if (bp.is_enabled()) {
            auto previous_instruction_address = possible_breakpoint_location;
            set_pc(previous_instruction_address);

            bp.disable();
            ptrace(PTRACE_SINGLESTEP, m_pid, nullptr, nullptr);
            wait_for_signal();
            bp.enable();
        }
    }
}
{% endhighlight %}

First we check to see if there's a breakpoint set for the value of the current PC. If there is, we first put execution back to before the breakpoint, disable it, step over the original instruction, and re-enable the breakpoint.

`wait_for_signal` will encapsulate our usual `waitpid` pattern:

{% highlight cpp %}
void debugger::wait_for_signal() {
    int wait_status;
    auto options = 0;
    waitpid(m_pid, &wait_status, options);
}
{% endhighlight %}


Finally we rewrite `continue_execution` like this:

{% highlight cpp %}
void debugger::continue_execution() {
    step_over_breakpoint();
    ptrace(PTRACE_CONT, m_pid, nullptr, nullptr);
    wait_for_signal();
}
{% endhighlight %}


-------------------------------

### Testing it out

Now that we can read and modify registers, we can have a bit of fun with our hello world program. As a first test, try setting a breakpoint on the call instruction again and continue from it. You should see `Hello world` being printed out. For the fun part, set a breakpoint just after the output call, continue, then write the address of the call argument setup code to the program counter (`rip`) and continue. You should see `Hello world` being printed a second time due to this program counter manipulation. Just in case you aren't sure where to set the breakpoint, here's my `objdump` output from the last post again:

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

You'll want to move the program counter back to `0x1191` offset from the base address so that the `rsi` and `rdi` registers are set up properly.

In the next post, we'll take our first look at DWARF information and add various kinds of single stepping to our debugger. After that, we'll have a mostly functioning tool which can step through code, set breakpoints wherever we like, modify data and so forth. As always, drop a comment below if you have any questions!

You can find the code for this post [here](https://github.com/TartanLlama/minidbg/tree/tut_registers).

[Next post]({% post_url 2017-04-05-writing-a-linux-debugger-elf-dwarf %})

-------------------------------

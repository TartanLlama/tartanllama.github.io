---
layout:     post
title:      "Writing a Linux Debugger Part 3 -- Registers and memory"
category:   c++
tags:
 - c++
---

In the last post we got breakpoints working in our debugger. This time we'll be adding the ability to read and write registers and memory, which will allow us to screw around with our program counter and change the behaviour of our program after we've done a bit more work.

---------------

### Registering our registers

Before we actually read any registers, we need to teach our debugger a bit about our target, which is x86_64. 40 registers are available on this platform: 16 general-purpose 64-bit, 16 SSE (vector), and 8 floating point. We'll just be using the 64-bit registers for simplicity, but you could extend this to other registers if you like. Since all our registers are the same size, all we really care about is the register's name, it's DWARF register number (this will be important later), and where it is stored in structure returned by `ptrace`. I chose to have a scoped enum for referring to the registers, then I laid out a global array in the same order as the `ptrace` register structure and stored the relevant information in it.

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

Again, `ptrace` gives us easy access to the data we want. We just construct an instance of `user_regs_struct` and give that to `ptrace` alongside the `PTRACE_GETREGS` request.

Now we want to read `regs` depending on which register was requested. We could write a big switch statement, but since we've laid out our `g_register_descriptors` table in the same order as `user_regs_struct`, we can just search for the index of the register descriptor, and access `user_regs_struct` as an array of `uint64_t`s.

{% highlight cpp %}
    auto it = std::find_if(begin(g_register_descriptors), end(g_register_descriptors),
                           [r](auto&& rd) { return rd.r == r; });

    *(reinterpret_cast<uint64_t*>(&regs) + (it - begin(g_register_descriptors))) = value;
{% endhighlight %}

The cast to `uint64_t` is safe because `user_regs_struct` is a standard layout type, but I think the pointer arithmetic is technically UB. No current compilers even warn about this and I'm lazy, but if you want to maintain upmost correctness, write a big switch statement.

`set_register_value` is much the same, we just write to the location and write the registers back at the end:

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

Next is lookup by DWARF register number. This time I'll actually check for an error condition just incase we get some weird DWARF information:

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

And finally we'll add a simple helper to dump the contents of all registers:

{% highlight cpp %}
void debugger::dump_registers() {
    for (const auto& rd : g_register_descriptors) {
        std::cout << rd.name << " 0x"
                  << std::setfill('0') << std::setw(16) << std::hex << get_register_value(m_pid, rd.r) << std::endl;
    }
}
{% endhighlight %}

This gives us enough support to handle registers easily in the rest of the debugger, so we can now add this to our UI.

----------------------

### Exposing our registers

All we need to do here is add a new command to the `handle_command` function. With the following code, users will be able to type `register read rax`, `register write rax 42` and so on.

{% highlight cpp %}
    else if (is_prefix(command, "register")) {
        if (is_prefix(args[1], "dump")) {
            dump_registers();
        }
        else if (is_prefix(args[1], "read")) {
            std::cout << get_register_value(m_pid, get_register_from_name(args[2])) << std::endl;
        }
        else if (is_prefix(args[1], "write")) {
            set_register_value(m_pid, get_register_from_name(args[2]), std::stol(args[3]));
        }
    }
{% endhighlight %}

----------------------

### Where is my mind?

We've already read from and written to memory when setting our breakpoints, so we just need to add a couple of functions to make it clean.

{% highlight cpp %}
uint64_t debugger::read_memory(uint64_t address) {
    return ptrace(PTRACE_PEEKDATA, m_pid, address, nullptr);
}

void debugger::write_memory(uint64_t address, uint64_t value) {
    ptrace(PTRACE_POKEDATA, m_pid, address, value);
}
{% endhighlight %}

You might want to add support for reading and writing more than a word at a time, which you can do by just incrementing the address each time you want to read another word.

Now we'll add commands for our UI:

{% highlight cpp %}
    else if(is_prefix(command, "memory")) {
        std::string addr {args[2], 2};

        if (is_prefix(args[1], "read")) {
            std::cout << read_memory(std::stol(addr, 0, 16)) << std::endl;
        }
        if (is_prefix(args[1], "write")) {
            write_memory(std::stol(addr, 0, 16), std::stol(args[3]));
        }
    }
{% endhighlight %}

----------------------

### Testing it out

Now that we can read and modify registers, we can have a bit of fun with our hello world program. If you set a breakpoint just after the output call, try writing the address of the previous instruction to the program counter (`rip`) so that the call happens again.

In the next post, we'll take our first look at DWARF information and add various kinds of single stepping to our debugger. After that, we'll have a mostly functioning tool which can step through code, set breakpoints wherever we like, modify data and so forth. As always, drop a comment below if you have any questions!

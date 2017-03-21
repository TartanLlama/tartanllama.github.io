---
layout:     post
title:      "Writing a Linux Debugger Part 2: Breakpoints"
category:   c++
pubdraft:   true
tags:
 - c++
---

### How is breakpoint formed?

There are essentially two main kinds of breakpoints: hardware and software. Hardware breakpoints typically involve setting some architecture-specific registers to produce your breaks for you, whereas software breakpoints involve modifying the code which is being executed on the fly. We'll be focusing solely on software breakpoints for this article, as they are simpler and you can have as many as you want. On x86 you can only have four hardware breakpoints set at a given time, but they give you the power to make them fire on just reading from or writing to a given address rather than only executing them.

I said above that software breakpoints are set by modifying the executing code on the fly, so the questions are:

- How do we accomplish this?
- What modifications do we make?
- How do these modifications result in a breakpoint?

The answer to the first question is, of course, `ptrace`. We've previously used it to set up our program for tracing and continuing its execution, but we can also use it to read and write memory.

For the modification, we need to write code to the address of the desired breakpoint which will cause the processor to halt and signal the program somehow. On x86 this is accomplished with the `int 3` instruction. As you may or may not know, x86 has an *interrupt vector table* which the operating system can use to register handlers for various events, such as page faults, protection faults, and invalid opcodes. It's kind of like registering error handling callbacks, but right down at the hardware level. When the processor executes the `int 3` instruction, control is passed to the debug interrupt handler, which -- in the case of Linux -- signals the process with a `SIGTRAP`.

![breakpoint](/assets/breakpoint.png)

The above process will result in a breakpoint, because our debugger will be waiting for the child process to be signalled with `waitpid`, so when it sees that `SIGTRAP`, it can see that a breakpoint has occurred. This breakpoint can then be communicated to the user, perhaps by printing the source location which has been reached, or changing the focused line in a GUI debugger.

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

    auto is_enabled() -> bool { return m_enabled; }
    auto get_address() -> std::intptr_t { return m_addr; }

private:
    pid_t m_pid;
    std::intptr_t m_addr;
    bool m_enabled;
    uint64_t m_saved_data; //data which used to be at the breakpoint address
};
{% endhighlight %}

Hopefully that code all looks pretty straightforward. The real magic happens in the `enable` and `disable` functions.

As we've learned above, we need to replace the instruction which is currently at the given address with an `int 3` instruction. We'll also want to save out what used to be at that address so that we can restore the code later. `0xcc` is the binary encoding of `int 3`, so we just need to set the bottom two bytes of the current instruction to that.

{% highlight cpp %}
void breakpoint::enable() {
    m_saved_data = ptrace(PTRACE_PEEKDATA, m_pid, m_addr, nullptr);
    uint64_t int3 = 0xcc;
    uint64_t data_with_int3 = ((m_saved_data & ~0xff) | int3); //set bottom two bytes to 0xcc
    ptrace(PTRACE_POKEDATA, m_pid, m_addr, data_with_int3);

    m_enabled = true;
}
{% endhighlight %}

The `PTRACE_PEEKDATA` request to `ptrace` is how to read the memory of the traced process. We give it a process ID and an address, and it gives us back the 64 bits which are currently at that address. `(m_saved_data & ~0xff)` zeroes out the bottom two bytes of this data, then we bitwise OR that with our `int 3` instruction to set the breakpoint. We then overwrite that part of memory with our new data with `PTRACE_POKEDATA` and record that the breakpoint is enabled.

The implementation of `disable` is easier, as we simply need to overwrite the memory we wrote to with the original data:

{% highlight cpp %}
void breakpoint::disable() {
    ptrace(PTRACE_POKEDATA, m_pid, m_addr, m_saved_data);
    m_enabled = false;
}
{% endhighlight %}

------------------------------

### Adding breakpoints to the debugger

In order to add support for setting breakpoints through our debugger's user interface, we'll make three changes:

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

In `set_breakpoint_at_address` we'll create a new breakpoint, enable it, add it to the data structure, and print out a message for the user. If you like, you could factor out all message printing so that you can use the debugger as a library as well as just a command-line tool, but I'll just mash it all together for simplicity.

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

------------------------------

### Continuing from the breakpoint

You might notice that if you continue from the breakpoint, nothing happens. That's because the breakpoint is still set in memory, so it's just hit repeatedly. The simple solution is to just disable the breakpoint, single step, re-enable it, then continue. Unfortunately we'd also need to modify the program counter to point back before the breakpoint, so we'll leave this until the next post.

-----------------------------

### Testing it out

Of course, setting a breakpoint on some address isn't very useful if you don't know what address to set it at. In the future we'll be adding the ability to set breakpoints on function names or source code lines, but for now, we can work it out manually.

A simple way to test out your debugger is to write a hello world program which writes to `std::cerr` (to avoid buffering) and set a breakpoint on the call to the output operator. If you continue the program then hopefully the execution will stop without printing anything. You can then restart the debugger and set a breakpoint just after the call, and you should see the message being printed successfully.

One way to find the address is to use `objdump`. If you open up a shell and execute `objdump -d <your program>`, then you should see the disassembly for your code. You should then be able to find the `main` function and locate the `call` instruction. For example, I built a hello world example, disassembled it, and got this as the disassembly for `main`:

```
0000000000400936 <main>:
  400936:	55                   	push   %rbp
  400937:	48 89 e5             	mov    %rsp,%rbp
  40093a:	be 35 0a 40 00       	mov    $0x400a35,%esi
  40093f:	bf 60 10 60 00       	mov    $0x601060,%edi
  400944:	e8 d7 fe ff ff       	callq  400820 <_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc@plt>
  400949:	b8 00 00 00 00       	mov    $0x0,%eax
  40094e:	5d                   	pop    %rbp
  40094f:	c3                   	retq
```

As you can hopefully see, we would want to set a breakpoint on `0x400944` to see no output, and `0x400949` to see the output.

------------------------------

### Finishing up

That's all for now. Again, let me know in the comments if you have any issues.

You can find the code for 

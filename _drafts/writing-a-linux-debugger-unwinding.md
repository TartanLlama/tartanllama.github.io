---
layout:     post
title:      "Writing a Linux Debugger Part 8: Stack unwinding"
category:   c++
tags:
 - c++
---

Sometimes the most important information you need to know about what your current program state is how it got there. This is typically provided with a `backtrace` command, which gives you the chain of function calls which have lead to the the program is right now. Take the following program as an example:

{% highlight cpp %}
void a() {
    //stopped here
}

void e() {
     b();
}

void f() {
     c();
}

int main() {
    e();
    f();
}
{% endhighlight %}

If the debugger is stopped at the `//stopped here` line, there are two ways which it could have got there: `main->b->a` or `main->c->a`. If we set a breakpoint there with LLDB, continue, and ask for a backtrace, then we get the following:

```
* frame #0: 0x00000000004004da a.out`a() + 4 at bt.cpp:3
  frame #1: 0x00000000004004e6 a.out`b() + 9 at bt.cpp:6
  frame #2: 0x00000000004004fe a.out`main + 9 at bt.cpp:14
  frame #3: 0x00007ffff7a2e830 libc.so.6`__libc_start_main + 240 at libc-start.c:291
  frame #4: 0x0000000000400409 a.out`_start + 41

```

This says that we are currently in function `a`, which we got to from function `b`, which we got to from `main` and so on. Those final two frames are just the compiler has bootstrapped the `main` function.

The question now is how we implement this on x86_64. The most robust way to do this is to parse the `.eh_frame` section of the ELF file and work out how to unwind the stack from there, but this is a pain. You could use `libunwind` or something similar to do it for you, but that's boring. Instead, we'll assume that the compiler has laid out the stack in a certain way and we'll just walk it manually.


void debugger::print_backtrace() {
    auto frame_number = 0;
    auto current_func = get_function_from_pc(get_pc());

    auto output_frame = [&frame_number] (auto&& func) {
        std::cout << "frame #" << frame_number++ << ": 0x" << dwarf::at_low_pc(func)
        << ' ' << dwarf::at_name(func) << std::endl;
    };

    output_frame(current_func);

    auto frame_pointer = get_register_value(m_pid, reg::rbp);
    auto return_address = read_memory(frame_pointer+8);
    while (dwarf::at_name(current_func) != "main") {
        current_func = get_function_from_pc(return_address);
        output_frame(current_func);
        frame_pointer = read_memory(frame_pointer);
        return_address = read_memory(frame_pointer+8);
    }
}

    else if(is_prefix(command, "backtrace")) {
        print_backtrace();
    }

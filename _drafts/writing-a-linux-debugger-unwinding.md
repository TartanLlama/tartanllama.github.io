---
layout:     post
title:      "Writing a Linux Debugger Part 8: Stack unwinding"
category:   c++
tags:
 - c++
---

One of the most important things a debugger can tell you about the current state of your program is how you got there. This is usually accomplished with a `backtrace` command, which print out the stack of function calls which have lead to the currently executing one.

The best ways to unwind the stack are probably to use `libunwind` or parse interpret the `.eh_frame` ELF section. But we're writing our own small debugger; the first option is cheating and the second is more complex then I'd like. As such, we'll learn how the x86_64 stack is laid out and unwind it by hand.

------------------------

### How is the stack laid out

------------------------

### Unwinding

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

---
layout:     post
title:      "Writing a Linux Debugger Part 7: Stack unwinding"
category:   c++
tags:
 - c++
---

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

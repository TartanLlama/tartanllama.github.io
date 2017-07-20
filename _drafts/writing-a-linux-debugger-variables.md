---
layout:     post
title:      "Writing a Linux Debugger Part 9: Handling variables"
category:   c++
tags:
 - c++
---

Variables are sneaky. At one moment they'll be happily sitting in registers, but as soon as you turn your head they're spilled to the stack. Maybe the compiler completely throws them out of the window for the sake of optimization. Regardless of how often variables move around in memory, we need some way to track and manipulate them in our debugger. This post will show you how to implement variable manipulation in your debugger.

-------------------------------

### Series index

These links will go live as the rest of the posts are released.
{:.listhead}

1. [Setup]({% post_url 2017-03-21-writing-a-linux-debugger-setup %})
2. [Breakpoints]({% post_url 2017-03-24-writing-a-linux-debugger-breakpoints %})
3. [Registers and memory]({% post_url 2017-03-31-writing-a-linux-debugger-registers %})
4. [Elves and dwarves]({% post_url 2017-04-05-writing-a-linux-debugger-elf-dwarf %})
5. [Source and signals]({% post_url 2017-04-24-writing-a-linux-debugger-source-signal %})
6. [Source-level stepping]({% post_url 2017-05-06-writing-a-linux-debugger-dwarf-step %})
7. [Source-level breakpoints]({% post_url 2017-06-19-writing-a-linux-debugger-source-break %})
8. [Stack unwinding]({% post_url 2017-06-24-writing-a-linux-debugger-unwinding %})
9. Handling variables
10. Next steps

-------------------------------

Before you get started, make sure that the version of `libelfin` you are using is the [`fbreg` branch of my fork](https://github.com/TartanLlama/libelfin/tree/fbreg). This contains some hacks to support getting the base of the current stack frame and evaluating location lists, neither of which are supported by vanilla `libelfin`.


void debugger::read_variables() {
    using namespace dwarf;

    auto func = get_function_from_pc(get_pc());

    for (const auto& die : func) {
        if (die.tag == DW_TAG::variable) {
            auto loc_val = die[DW_AT::location];

            //only supports exprlocs for now
            if (loc_val.get_type() == value::type::exprloc) {
                ptrace_expr_context context {m_pid};
                auto result = loc_val.as_exprloc().evaluate(&context);

                switch (result.location_type) {
                case expr_result::type::address:
                {
                    auto value = read_memory(result.value);
                    std::cout << at_name(die) << " (0x" << std::hex << result.value << ") = " << value << std::endl;
                    break;
                }

                case expr_result::type::reg:
                {
                    auto value = get_register_value_from_dwarf_register(m_pid, result.value);
                    std::cout << at_name(die) << " (reg " << result.value << ") = " << value << std::endl;
                    break;
                }

                default:
                    throw std::runtime_error{"Unhandled variable location"};
                }
            }
            else {
                throw std::runtime_error{"Unhandled variable location"};
            }
        }
    }
}

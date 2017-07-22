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

Before you get started, make sure that the version of `libelfin` you are using is the [`fbreg` branch of my fork](https://github.com/TartanLlama/libelfin/tree/fbreg). This contains some hacks to support getting the base of the current stack frame and evaluating location lists, neither of which are supported by vanilla `libelfin`. You might need to pass `-gdwarf-2` to GCC to get it to generate compatible DWARF information. But before we get into the implementation, I'll give a more detailed description of how locations are encoded in DWARF 5, which is the most recent specification.

The location of a variable in memory at a given moment is encoded in the DWARF information using the `DW_AT_location` attribute. Location descriptions can be either single location descriptions, composite location descriptions, or location lists.

- Simple location descriptions describe the location of one contiguous piece (usually all) of an object. A simple location description may describe a location in addressable memory, or in a register, or the lack of a location (with or without a known value).
  - Example:
    - `DW_OP_fbreg -32`
    - A variable which is entirely stored -32 bytes from the stack frame base
- Composite location descriptions describe an object in terms of pieces, each of which may be contained in part of a register or stored in a memory location unrelated to other pieces.
  - Example:
    - `DW_OP_reg3 DW_OP_piece 4 DW_OP_reg10 DW_OP_piece 2`
    - A variable whose first four bytes reside in register 3 and whose next two bytes reside in register 10.
- Location lists describe objects which have a limited lifetime or change location during their lifetime.
  - Example:
    - `<loclist with 3 entries follows>`
      - `[ 0]<lowpc=0x2e00><highpc=0x2e19>DW_OP_reg0`
      - `[ 1]<lowpc=0x2e19><highpc=0x2e3f>DW_OP_reg3`
      - `[ 2]<lowpc=0x2ec4><highpc=0x2ec7>DW_OP_reg2`
    - A variable whose location moves between registers depending on the current value of the program counter

The `DW_AT_location` is encoded in one of three different ways, depending on the kind of location description. `exprloc`s encode simple and composite location descriptions. They consist of a byte length followed by a DWARF expression or location description. `loclist`s and `loclistptr`s encode location lists. They give indexes or offsets into the `.debug_loclists` section, which describes the actual location lists.


{% highlight cpp %}
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
{% endhighlight %}

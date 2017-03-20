---
layout:     post
title:      "Writing a Linux Debugger Part 7: Source-level breakpoints"
category:   c++
tags:
 - c++
---

Setting breakpoints on memory addresses is all well and good, but it isn't exactly the most user-friendly tool. We'd like to be able to set breakpoints on source lines and function entry addresses as well, so that we can debug at the same abstraction level as our code.

-----------------------

### Function entry

Setting breakpoints on function names can be complex if you want to take overloading, member functions and such into account, but we're just going to iterate through all of the compilation units and search for functions with names which match what we're looking for.

{% highlight cpp %}
void debugger::set_breakpoint_at_function(const std::string& name) {
    for (const auto& cu : m_dwarf.compilation_units()) {
        for (const auto& die : cu.root()) {
            if (die.has(dwarf::DW_AT::name) && at_name(die) == name) {
                auto low_pc = at_low_pc(die);
                auto entry = get_line_entry_from_pc(low_pc);
                ++entry; //skip prologue
                set_breakpoint_at_address(entry->address);
            }
        }
    }
}
{% endhighlight %}

The only bit of that code which looks a bit weird is the `++entry`. The problem is that the `DW_AT_low_pc` for a function doesn't point at the start of the user code for that function, it points to the start of the prologue. The compiler will usually output a prologue and epilogue for a function which carries out saving and restoring registers, manipulating the stack pointer and suchlike. This isn't very useful for us, so we increment the line entry by one to get the first line of the user code instead of the prologue. The DWARF line table actually has some functionality to mark an entry as the first line after the function prologue, but not all compilers output this, so I've just taken the naive approach.

-----------------------

### Source line


void debugger::set_breakpoint_at_source_line(const std::string& file, unsigned line) {
    for (const auto& cu : m_dwarf.compilation_units()) {
        if (is_suffix(file, at_name(cu.root()))) {
            const auto& lt = cu.get_line_table();

            for (const auto& entry : lt) {
                if (entry.is_stmt && entry.line == line) {
                    set_breakpoint_at_address(entry.address);
                    return;
                }
            }
        }
    }
}

-----------------------

### Adding commands


    else if(is_prefix(command, "break")) {
        if (args[1][0] == '0' && args[1][1] == 'x') {
            std::string addr {args[1], 2};
            set_breakpoint_at_address(std::stol(addr, 0, 16));
        }
        else if (args[1].find(':') != std::string::npos) {
            auto file_and_line = split(args[1], ':');
            set_breakpoint_at_source_line(file_and_line[0], std::stoi(file_and_line[1]));
        }
        else {
            set_breakpoint_at_function(args[1]);
        }
    }

---
layout:     post
title:      "Writing a Linux Debugger Part 5: Stepping on dwarves"
category:   c++
tags:
 - c++
---

In the last post we learned about DWARF information and how it lets us relate the machine code with the high-level source. This time we'll be putting this knowledge into practice by adding source-level stepping to our debugger.

------------------------

### Exposing instruction-level stepping

But we're getting ahead of ourselves. First let's expose instruction-level single stepping through the user interface. I decided to split it between an `unchecked_single_step_instruction` which can be used by other parts of the code, and a `single_step_instruction` which wraps the call to `ptrace` and `wait_on_signal`, then a `single_step_instruction_with_breakpoint_check` for maybe disabling a breakpoint first.

{% highlight cpp %}
void debugger::single_step_instruction() {
    ptrace(PTRACE_SINGLESTEP, m_pid, nullptr, nullptr);
    wait_for_signal();
}

void debugger::single_step_instruction_with_breakpoint_check() {
    //first, check to see if we need to disable and enable a breakpoint
    if (m_breakpoints.count(get_pc())) {
        step_over_breakpoint();
    }
    else {
        single_step_instruction();
    }
}
{% endhighlight %}

As usual, another command gets lumped into our `handle_command` function:

{% highlight cpp %}
else if(is_prefix(command, "stepi")) {
    single_step_instruction_with_breakpoint_check();
    auto line_entry = get_line_entry_from_pc(get_pc());
    print_source(line_entry->file->path, line_entry->line);
 }
{% endhighlight %}

--------------------------

### Setting up our DWARF parser

As I noted way back at the start of this series, we'll be using `libelfin` to handle our DWARF information. Hopefully you got this set up in the first post, but if not, do so now, and make sure that you use the `fbreg` branch of my fork.

Once you have `libelfin` building, it's time to add it to our debugger. The first step is to parse the ELF executable we're given and extract the DWARF from it. This is very easy with `libelfin`, just make these changes to `debugger`:

{% highlight cpp %}
class debugger {
public:
    debugger (std::string prog_name, pid_t pid)
         : m_prog_name{std::move(prog_name)}, m_pid{pid} {
        auto fd = open(m_prog_name.c_str(), O_RDONLY);

        m_elf = elf::elf{elf::create_mmap_loader(fd)};
        m_dwarf = dwarf::dwarf{dwarf::elf::create_loader(m_elf)};
    }
    //...
    
private:
    //...
    dwarf::dwarf m_dwarf;
    elf::elf m_elf;
};
{% endhighlight %}

---------------------------

### Debug information primatives

Next on the list is to implement a bunch of functions to handle the most common debug information queries. In particular, we want to be able to retrieve line entries and function information from program counter values and vice versa.

We'll start with `get_function_from_pc`:

{% highlight cpp %}
dwarf::die debugger::get_function_from_pc(uint64_t pc) {
    for (auto &cu : m_dwarf.compilation_units()) {
        if (die_pc_range(cu.root()).contains(get_pc())) {
            for (const auto& die : cu.root()) {
                if (die.tag == dwarf::DW_TAG::subprogram) {
                    if (die_pc_range(die).contains(pc)) {
                        return die;
                    }
                }
            }
        }
    }

    throw std::out_of_range{"Cannot find function"};
}
{% endhighlight %}

Here we take a naive approach of just iterating through compilation units until we find one which contains the program counter, then iterating through the children until we find the relevant function (`DW_TAG_subprogram`). As mentioned in the last part, you could handle things like member functions and inlining here if you wanted.

Next is `get_line_entry_from_pc`:

{% highlight cpp %}
dwarf::line_table::iterator debugger::get_line_entry_from_pc(uint64_t pc) {
    for (auto &cu : m_dwarf.compilation_units()) {
        if (die_pc_range(cu.root()).contains(pc)) {
            auto &lt = cu.get_line_table();
            auto it = lt.find_address(pc);
            if (it == lt.end()) {
                throw std::out_of_range{"Cannot find line entry"};
            }
            else {
                return it;
            }
        }
    }

    throw std::out_of_range{"Cannot find line entry"};
}
{% endhighlight %}

Again, we simply find the correct compilation unit, then ask the line table to get us the relevant entry.

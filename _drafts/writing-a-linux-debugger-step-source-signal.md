---
layout:     post
title:      "Writing a Linux Debugger Part 5: Stepping, source and signals"
category:   c++
tags:
 - c++
---

------------------------

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

### Debug information primitives

Next on the list is to implement functions to retrieve line entries and function DIEs from PC values. We'll start with `get_function_from_pc`:

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


-------------------------------

### Printing source

Of course, stepping around our code isn't very useful if we don't know what our current position is. 

{% highlight cpp %}
void debugger::print_source(const std::string& file_name, unsigned line, unsigned n_lines_context) {
    std::ifstream file {file_name};
    auto start_line = line <= n_lines_context ? 1 : line - n_lines_context;
    auto end_line = line + n_lines_context + (line < n_lines_context ? n_lines_context - line : 0) + 1;

    char c{};
    auto current_line = 1u;
    while (current_line != start_line && file.get(c)) {
        if (c == '\n') {
            ++current_line;
        }
    }
    std::cout << (current_line==line ? "> " : "  ");
    while (current_line <= end_line && file.get(c)) {
        std::cout << c;
        if (c == '\n') {
            ++current_line;
            std::cout << (current_line==line ? "> " : "  ");
        }
    }
    std::cout << std::endl;
}
{% endhighlight %}






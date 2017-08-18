---
layout:     post
title:      "Writing a Linux Debugger Part 6: Source-level stepping"
category:   c++
tags:
 - c++
redirect_from:
  - /c++/2017/05/06/writing-a-linux-debugger-dwarf-step/
  - /writing-a-linux-debugger-dwarf-step.html
---

A couple of posts ago we learned about DWARF information and how it lets us relate the machine code to the high-level source. This time we'll be putting this knowledge into practice by adding source-level stepping to our debugger.

-------------------------------

### Series index

1. [Setup]({% post_url 2017-03-21-writing-a-linux-debugger-setup %})
2. [Breakpoints]({% post_url 2017-03-24-writing-a-linux-debugger-breakpoints %})
3. [Registers and memory]({% post_url 2017-03-31-writing-a-linux-debugger-registers %})
4. [Elves and dwarves]({% post_url 2017-04-05-writing-a-linux-debugger-elf-dwarf %})
5. [Source and signals]({% post_url 2017-04-24-writing-a-linux-debugger-source-signal %})
6. [Source-level stepping]({% post_url 2017-05-06-writing-a-linux-debugger-dwarf-step %})
7. [Source-level breakpoints]({% post_url 2017-06-19-writing-a-linux-debugger-source-break %})
8. [Stack unwinding]({% post_url 2017-06-24-writing-a-linux-debugger-unwinding %})
9. [Handling variables]({% post_url 2017-07-26-writing-a-linux-debugger-variables %})
10. [Advanced topics]({% post_url 2017-08-01-writing-a-linux-debugger-advanced-topics %})

---------------------

### Exposing instruction-level stepping

But we're getting ahead of ourselves. First let's expose instruction-level single stepping through the user interface. I decided to split it between a `single_step_instruction` which can be used by other parts of the code, and a `single_step_instruction_with_breakpoint_check` which ensures that any breakpoints are disabled and re-enabled.

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


With these functions added we can begin to implement our source-level stepping functions.

--------------------------


### Implementing the steps

We're going to write very simple versions of these functions, but real debuggers tend to have the concept of a *thread plan* which encapsulates all of the stepping information. For example, a debugger might have some complex logic to determine breakpoint sites, then have some callback which determines whether or not the step operation has completed. This is a lot of infrastructure to get in place, so we'll just take a naive approach. We might end up accidentally stepping over breakpoints, but you can spend some time getting all the details right if you like.

For `step_out`, we'll just set a breakpoint at the return address of the function and continue. I don't want to get into the details of stack unwinding yet -- that'll come in a later part -- but it suffices to say for now that the return address is stored 8 bytes after the start of a stack frame. So we'll just read the frame pointer and read a word of memory at the relevant address:

{% highlight cpp %}
void debugger::step_out() {
    auto frame_pointer = get_register_value(m_pid, reg::rbp);
    auto return_address = read_memory(frame_pointer+8);

    bool should_remove_breakpoint = false;
    if (!m_breakpoints.count(return_address)) {
        set_breakpoint_at_address(return_address);
        should_remove_breakpoint = true;
    }

    continue_execution();

    if (should_remove_breakpoint) {
        remove_breakpoint(return_address);
    }
}
{% endhighlight %}

`remove_breakpoint` is a little helper function:

{% highlight cpp %}
void debugger::remove_breakpoint(std::intptr_t addr) {
    if (m_breakpoints.at(addr).is_enabled()) {
        m_breakpoints.at(addr).disable();
    }
    m_breakpoints.erase(addr);
}
{% endhighlight %}

Next is `step_in`. A simple algorithm is to just keep on stepping over instructions until we get to a new line.

{% highlight cpp %}
void debugger::step_in() {
   auto line = get_line_entry_from_pc(get_pc())->line;

    while (get_line_entry_from_pc(get_pc())->line == line) {
        single_step_instruction_with_breakpoint_check();
    }

    auto line_entry = get_line_entry_from_pc(get_pc());
    print_source(line_entry->file->path, line_entry->line);
}
{% endhighlight %}

`step_over` is the most difficult of the three for us. Conceptually, the solution is to just set a breakpoint at the next source line, but what is the next source line? It might not be the one directly succeeding the current line, as we could be in a loop, or some conditional construct. Real debuggers will often examine what instruction is being executed and work out all of the possible branch targets, then set breakpoints on all of them. I'd rather not implement or integrate an x86 instruction emulator for such a small project, so we'll need to come up with a simpler solution. A couple of horrible options are to just keep stepping until we're at a new line in the current function, or to just set a breakpoint at every line in the current function. The former would be ridiculously inefficient if we're stepping over a function call, as we'd need to single step through every single instruction in that call graph, so I'll go for the second solution.

{% highlight cpp %}
void debugger::step_over() {
    auto func = get_function_from_pc(get_pc());
    auto func_entry = at_low_pc(func);
    auto func_end = at_high_pc(func);

    auto line = get_line_entry_from_pc(func_entry);
    auto start_line = get_line_entry_from_pc(get_pc());

    std::vector<std::intptr_t> to_delete{};

    while (line->address < func_end) {
        if (line->address != start_line->address && !m_breakpoints.count(line->address)) {
            set_breakpoint_at_address(line->address);
            to_delete.push_back(line->address);
        }
        ++line;
    }

    auto frame_pointer = get_register_value(m_pid, reg::rbp);
    auto return_address = read_memory(frame_pointer+8);
    if (!m_breakpoints.count(return_address)) {
        set_breakpoint_at_address(return_address);
        to_delete.push_back(return_address);
    }

    continue_execution();

    for (auto addr : to_delete) {
        remove_breakpoint(addr);
    }
}
{% endhighlight %}

This function is a bit more complex, so I'll break it down a bit.

{% highlight cpp %}
    auto func = get_function_from_pc(get_pc());
    auto func_entry = at_low_pc(func);
    auto func_end = at_high_pc(func);
{% endhighlight %}

`at_low_pc` and `at_high_pc` are functions from `libelfin` which will get us the low and high PC values for the given function DIE.

{% highlight cpp %}
    auto line = get_line_entry_from_pc(func_entry);
    auto start_line = get_line_entry_from_pc(get_pc());

    std::vector<std::intptr_t> breakpoints_to_remove{};

    while (line->address < func_end) {
        if (line->address != start_line->address && !m_breakpoints.count(line->address)) {
            set_breakpoint_at_address(line->address);
            breakpoints_to_remove.push_back(line->address);
        }
        ++line;
    }
{% endhighlight %}

We'll need to remove any breakpoints we set so that they don't leak out of our step function, so we keep track of them in a `std::vector`. To set all the breakpoints, we loop over the line table entries until we hit one which is outside the range of our function. For each one, we make sure that it's not the line we are currently on, and that there's not already a breakpoint set at that location.

{% highlight cpp %}
    auto frame_pointer = get_register_value(m_pid, reg::rbp);
    auto return_address = read_memory(frame_pointer+8);
    if (!m_breakpoints.count(return_address)) {
        set_breakpoint_at_address(return_address);
        to_delete.push_back(return_address);
    }
{% endhighlight %}

Here we are setting a breakpoint on the return address of the function, just like in `step_out`.

{% highlight cpp %}
    continue_execution();

    for (auto addr : to_delete) {
        remove_breakpoint(addr);
    }
{% endhighlight %}

Finally, we continue until one of those breakpoints has been hit, then remove all the temporary breakpoints we set.

It ain't pretty, but it'll do for now.

Of course, we also need to add this new functionality to our UI:

{% highlight cpp %}
    else if(is_prefix(command, "step")) {
        step_in();
    }
    else if(is_prefix(command, "next")) {
        step_over();
    }
    else if(is_prefix(command, "finish")) {
        step_out();
    }
{% endhighlight %}

------------------------

### Testing it out

I tested out my implementation with a simple program which calls a bunch of different functions:

{% highlight cpp %}
void a() {
    int foo = 1;
}

void b() {
    int foo = 2;
    a();
}

void c() {
    int foo = 3;
    b();
}

void d() {
    int foo = 4;
    c();
}

void e() {
    int foo = 5;
    d();
}

void f() {
    int foo = 6;
    e();
}

int main() {
    f();
}
{% endhighlight %}

You should be able to set a breakpoint on the address of `main` and then in, over, and out all over the program. Expect things to break if you try to step out of `main` or into some dynamically linked library.

You can find the code for this post [here](https://github.com/TartanLlama/minidbg/tree/tut_dwarf_step). Next time we'll use our newfound DWARF expertise to implement source-level breakpoints.

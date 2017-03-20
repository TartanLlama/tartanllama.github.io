---
layout:     post
title:      "Writing a Linux Debugger Part 6: Stepping on dwarves"
category:   c++
tags:
 - c++
---

In the last post we learned about DWARF information and how it lets us relate the machine code with the high-level source. This time we'll be putting this knowledge into practice by adding source-level stepping to our debugger.

---------------------

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

But now there's a bit of a problem; both hitting a breakpoint and finishing a single step will send a `SIGTRAP` signal, but we need a way to tell between them. While we're at it, we'll want to tell the user if the debugee segfaults or something as well.

--------------------------

### Handling signals

Fortunately, `ptrace` comes to our rescue again. One of the possible commands to `ptrace` is `PTRACE_GETSIGINFO`, which will give you information about the last signal which the process was sent. We use it like so:

{% highlight cpp %}
siginfo_t debugger::get_signal_info() {
    siginfo_t info;
    ptrace(PTRACE_GETSIGINFO, m_pid, nullptr, &info);
    return info;
}
{% endhighlight %}

This gives us a `siginfo_t` object, which provides the following information:

{% highlight cpp %}
siginfo_t {
    int      si_signo;     /* Signal number */
    int      si_errno;     /* An errno value */
    int      si_code;      /* Signal code */
    int      si_trapno;    /* Trap number that caused
                              hardware-generated signal
                              (unused on most architectures) */
    pid_t    si_pid;       /* Sending process ID */
    uid_t    si_uid;       /* Real user ID of sending process */
    int      si_status;    /* Exit value or signal */
    clock_t  si_utime;     /* User time consumed */
    clock_t  si_stime;     /* System time consumed */
    sigval_t si_value;     /* Signal value */
    int      si_int;       /* POSIX.1b signal */
    void    *si_ptr;       /* POSIX.1b signal */
    int      si_overrun;   /* Timer overrun count;
                              POSIX.1b timers */
    int      si_timerid;   /* Timer ID; POSIX.1b timers */
    void    *si_addr;      /* Memory location which caused fault */
    long     si_band;      /* Band event (was int in
                              glibc 2.3.2 and earlier) */
    int      si_fd;        /* File descriptor */
    short    si_addr_lsb;  /* Least significant bit of address
                              (since Linux 2.6.32) */
    void    *si_lower;     /* Lower bound when address violation
                              occurred (since Linux 3.19) */
    void    *si_upper;     /* Upper bound when address violation
                              occurred (since Linux 3.19) */
    int      si_pkey;      /* Protection key on PTE that caused
                              fault (since Linux 4.6) */
    void    *si_call_addr; /* Address of system call instruction
                              (since Linux 3.5) */
    int      si_syscall;   /* Number of attempted system call
                              (since Linux 3.5) */
    unsigned int si_arch;  /* Architecture of attempted system call
                              (since Linux 3.5) */
}
{% endhighlight %}

I'll just be using `si_signo` to work out which signal was sent, and `si_code` to get more information about the signal. The best place to put this code is in our `wait_for_signal` function:

{% highlight cpp %}
void debugger::wait_for_signal() {
    int wait_status;
    auto options = 0;
    waitpid(m_pid, &wait_status, options);

    auto siginfo = get_signal_info();

    switch (siginfo.si_signo) {
    case SIGTRAP:
        handle_sigtrap(siginfo);
        break;
    case SIGSEGV:
        std::cout << "Yay, segfault. Reason: " << siginfo.si_code << std::endl;
        break;
    default:
        std::cout << "Got signal " << strsignal(siginfo.si_signo) << std::endl;
    }
}
{% endhighlight %}

Now to handle `sigtraps`. It suffices to know that `SI_KERNEL` or `TRAP_BRKPT` will be sent when a breakpoint is hit, and `TRAP_TRACE` will be sent on single step completion:

{% highlight cpp %}
void debugger::handle_sigtrap(siginfo_t info) {
    switch (info.si_code) {
    //one of these will be set if a breakpoint was hit
    case SI_KERNEL:
    case TRAP_BRKPT:
    {
        set_pc(get_pc()-1);
        std::cout << "Hit breakpoint at address 0x" << std::hex << get_pc() << std::endl;
        auto line_entry = get_line_entry_from_pc(get_pc());
        print_source(line_entry->file->path, line_entry->line);
        return;
    }
    //this will be set if the signal was sent by single stepping
    case TRAP_TRACE:
        return;
    default:
        std::cout << "Unknown SIGTRAP code " << info.si_code << std::endl;
        return;
    }
}
{% endhighlight %}


-------------------------------------

### Implementing the steps

With these functions added we can begin to implement our source-level stepping functions. We're going to implement very simple versions of these functions, but real debuggers tend to have the concept of a *thread plan* which encapsulates all of the stepping information. For example, a debugger might have some complex logic to determine breakpoint sites, then have some callback which determines whether or not the step operation has completed. This is a lot of infrastructure to get in place, so we'll just take a naive approach. We might end up accidentally stepping over breakpoints, but you can spend some time getting all the details right if you like.

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

`step_over` is the most difficult of the three for us. Conceptually, the solution is to just set a breakpoint at the next source line, but what is the next source line? It might not be the one directly succeeding the current line, as we could be in a loop, or some conditional construct. Real debuggers will often examine what instruction is being executed and work out all of the possible branch targets, then set breakpoints on all of them. I'd rather not implement an x86 instruction emulator for such a small project, so we'll need to come up with a simpler solution. A couple of horrible options are to just keep stepping until we're at a new line in the current function, or to just set a breakpoint at every line in the current function. The former would be ridiculously inefficient if we're stepping over a function call, as we'd need to single step through every single instruction in that call graph, so I'll go for the second solution.

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

------------------------

    else if(is_prefix(command, "step")) {
        step_in();
    }
    else if(is_prefix(command, "next")) {
        step_over();
    }
    else if(is_prefix(command, "finish")) {
        step_out();
    }


### Testing it out

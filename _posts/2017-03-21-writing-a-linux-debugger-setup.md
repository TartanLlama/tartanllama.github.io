---
layout:     post
title:      "Writing a Linux Debugger Part 1: Setup"
category:   c++
tags:
 - c++
redirect_from:
  - /c++/2017/03/21/writing-a-linux-debugger-setup/
  - /writing-a-linux-debugger-setup.html
---

Anyone who has written more than a hello world program should have used a debugger at some point (if you haven't, drop what you're doing and learn how to use one). However, although these tools are in such widespread use, there aren't a lot of resources which tell you how they work and how to write one[^1], especially when compared to other toolchain technologies like compilers. In this post series we'll learn what makes debuggers tick and write one for debugging Linux programs.

We'll support the following features:
{:.listhead}

- Launch, halt, and continue execution
- Set breakpoints on
  - Memory addresses
  - Source code lines
  - Function entry
- Read and write registers and memory
- Single stepping
  - Instruction
  - Step in
  - Step out
  - Step over
- Print current source location
- Print backtrace
- Print values of simple variables

In the final part I'll also outline how you could add the following to your debugger:
{:.listhead}

- Remote debugging
- Shared library and dynamic loading support
- Expression evaluation
- Multi-threaded debugging support

I'll be focusing on C and C++ for this project, but it should work just as well with any language which compiles down to machine code and outputs standard DWARF debug information (if you don't know what that is yet, don't worry, this will be covered soon). Additionally, my focus will be on just getting something up and running which works most of the time, so things like robust error handling will be eschewed in favour of simplicity.

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

-------------------------------

### Getting set up

Before we jump into things, let's get our environment set up. I'll be using two dependencies in this tutorial: [Linenoise](https://github.com/antirez/linenoise) for handling our command line input, and [libelfin](https://github.com/TartanLlama/libelfin/tree/fbreg) for parsing the debug information. You could use the more traditional libdwarf instead of libelfin, but the interface is nowhere near as nice, and libelfin also provides a mostly complete DWARF expression evaluator, which will save you a lot of time if you want to read variables. Make sure that you use the fbreg branch of my fork of libelfin, as it hacks on some extra support for reading variables on x86.

Once you've either installed these on your system, or got them building as dependencies with whatever build system you prefer, it's time to get started. I just set them to build along with the rest of my code in my CMake files.

------------------------------

### Launching the executable

Before we actually debug anything, we'll need to launch the debugee program. We'll do this with the classic fork/exec pattern.

{% highlight cpp %}
int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Program name not specified";
        return -1;
    }

    auto prog = argv[1];

    auto pid = fork();
    if (pid == 0) {
        //we're in the child process
        //execute debugee

    }
    else if (pid >= 1)  {
        //we're in the parent process
        //execute debugger
    }
{% endhighlight %}

We call `fork` and this causes our program to split into two processes. If we are in the child process, `fork` returns `0`, and if we are in the parent process, it returns the process ID of the child process.

If we're in the child process, we want to replace whatever we're currently executing with the program we want to debug.

{% highlight cpp %}
   ptrace(PTRACE_TRACEME, 0, nullptr, nullptr);
   execl(prog, prog, nullptr);
{% endhighlight %}

Here we have our first encounter with `ptrace`, which is going to become our best friend when writing our debugger. `ptrace` allows us to observe and control the execution of another process by reading registers, reading memory, single stepping and more. The API is very ugly; it's a single function which you provide with an enumerator value for what you want to do, and then some arguments which will either be used or ignored depending on which value you supply. The signature looks like this:

{% highlight cpp %}
long ptrace(enum __ptrace_request request, pid_t pid,
            void *addr, void *data);
{% endhighlight %}

`request` is what we would like to do to the traced process; `pid` is the process ID of the traced process; `addr` is a memory address, which is used in some calls to designate an address in the tracee; and `data` is some request-specific resource. The return value often gives error information, so you probably want to check that in your real code; I'm just omitting it for brevity. You can have a look at the man pages for more information.

The request we send in the above code, `PTRACE_TRACEME`, indicates that this process should allow its parent to trace it. All of the other arguments are ignored, because API design isn't important /s.

Next, we call `execl`, which is one of the many `exec` flavours. We execute the given program, passing the name of it as a command-line argument and a `nullptr` to terminate the list. You can pass any other arguments needed to execute your program here if you like.

After we've done this, we're finished with the child process; we'll just let it keep running until we're finished with it.


------------------------------

### Adding our debugger loop

Now that we've launched the child process, we want to be able to interact with it. For this, we'll create a `debugger` class, give it a loop for listening to user input, and launch that from our parent fork of our `main` function.

{% highlight cpp %}
else if (pid >= 1)  {
    //parent
    debugger dbg{prog, pid};
    dbg.run();
}
{% endhighlight %}

{% highlight cpp %}
class debugger {
public:
    debugger (std::string prog_name, pid_t pid)
        : m_prog_name{std::move(prog_name)}, m_pid{pid} {}

    void run();

private:
    std::string m_prog_name;
    pid_t m_pid;
};
{% endhighlight %}

In our `run` function, we need to wait until the child process has finished launching, then just keep on getting input from linenoise until we get an EOF (ctrl+d).

{% highlight cpp %}
void debugger::run() {
    int wait_status;
    auto options = 0;
    waitpid(m_pid, &wait_status, options);

    char* line = nullptr;
    while((line = linenoise("minidbg> ")) != nullptr) {
        handle_command(line);
        linenoiseHistoryAdd(line);
        linenoiseFree(line);
    }
}
{% endhighlight %}

When the traced process is launched, it will be sent a `SIGTRAP` signal, which is a trace or breakpoint trap. We can wait until this signal is sent using the `waitpid` function.

After we know the process is ready to be debugged, we listen for user input. The `linenoise` function takes a prompt to display and handles user input by itself. This means we get a nice command line with history and navigation commands without doing much work at all. When we get the input, we give the command to a `handle_command` function which we'll write shortly, then we add this command to the linenoise history and free the resource.

------------------------------

### Handling input

Our commands will follow a similar format to gdb and lldb. To continue the program, a user will type `continue` or `cont` or even just `c`. If they want to set a breakpoint on an address, they'll write `break 0xDEADBEEF`, where `0xDEADBEEF` is the desired address in hexadecimal format. Let's add support for these commands.

{% highlight cpp %}
void debugger::handle_command(const std::string& line) {
    auto args = split(line,' ');
    auto command = args[0];

    if (is_prefix(command, "continue")) {
        continue_execution();
    }
    else {
        std::cerr << "Unknown command\n";
    }
}
{% endhighlight %}

`split` and `is_prefix` are a couple of small helper functions:

{% highlight cpp %}
std::vector<std::string> split(const std::string &s, char delimiter) {
    std::vector<std::string> out{};
    std::stringstream ss {s};
    std::string item;

    while (std::getline(ss,item,delimiter)) {
        out.push_back(item);
    }

    return out;
}

bool is_prefix(const std::string& s, const std::string& of) {
    if (s.size() > of.size()) return false;
    return std::equal(s.begin(), s.end(), of.begin());
}
{% endhighlight %}

We'll add `continue_execution` to the `debugger` class.

{% highlight cpp %}
void debugger::continue_execution() {
    ptrace(PTRACE_CONT, m_pid, nullptr, nullptr);

    int wait_status;
    auto options = 0;
    waitpid(m_pid, &wait_status, options);
}
{% endhighlight %}

For now our `continue_execution` function will just use `ptrace` to tell the process to continue, then `waitpid` until it's signalled.

------------------------------

### Finishing up

Now you should be able to compile some C or C++ program, run it through your debugger, see it halting on entry, and be able to continue execution from your debugger. In the next part we'll learn how to get our debugger to set breakpoints. If you come across any issues, please let me know in the comments!

You can find the code for this post [here](https://github.com/TartanLlama/minidbg/tree/tut_setup).

---------------------

[^1]: Here are some pre-existing ones if you want other resources: [1](http://eli.thegreenplace.net/2011/01/23/how-debuggers-work-part-1) [2](http://t-a-w.blogspot.co.uk/2007/03/how-to-code-debuggers.html) [3](https://www.codeproject.com/Articles/43682/Writing-a-basic-Windows-debugger) [4](http://system.joekain.com/debugger/)

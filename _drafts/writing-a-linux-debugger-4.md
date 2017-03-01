---
layout:     post
title:      "Writing a Linux Debugger Part 4 -- Marching elves and dwarves"
category:   c++
tags:
 - c++
---

Up until now you've heard whispers of dwarves, of debug information, of a way to understand the source code without just parsing the thing. Today we'll be going into the details of source-level debug information and using it to implement single stepping through our code.

ELF and DWARF are two components which you may not have heard of, but probably use most days. ELF (Executable and Linkable Format) is the most widely used object file format in the Linux world; it specifies a way to store all of the different parts of a binary, like the code, static data, debug information, and strings. It also tells the loader how to take the file and get it ready for execution, which involves noting where different parts of the binary should be placed in memory, which bits need to be fixed up depending on the position of other components (*relocations*) and more. I won't cover much more of ELF in these posts, but if you're interested, you can have a look at [this wonderful infographic](https://github.com/corkami/pics/raw/master/binary/elf101/elf101-64.pdf) or [the standard](http://www.skyfree.org/linux/references/ELF_Format.pdf).

DWARF is the debug information format most commonly used with ELF. It's not necessarily tied to ELF, but the two were developed in tandem and work very well together. This format allows a compiler to tell a debugger how the original source code relates to the binary which is going to be executed. This information is split into different ELF sections, each with its own piece of information to relay. Here are the different sections which are defined, taken from this highly informative if slightly out of date [Introduction to the
DWARF Debugging Format](http://www.dwarfstd.org/doc/Debugging%20using%20DWARF-2012.pdf):

- `.debug_abbrev` Abbreviations used in the `.debug_info` section
- `.debug_aranges` A mapping between memory address and compilation
- `.debug_frame` Call Frame Information
- `.debug_info` The core DWARF data containing DWARF Information Entries (DIEs)
- `.debug_line` Line Number Program
- `.debug_loc` Location descriptions
- `.debug_macinfo` Macro descriptions
- `.debug_pubnames` A lookup table for global objects and functions
- `.debug_pubtypes` A lookup table for global types
- `.debug_ranges` Address ranges referenced by DIEs
- `.debug_str` String table used by `.debug_info`
- `.debug_types` Type descriptions

We are most interested in the `.debug_line` and `.debug_info` sections, so lets have a look at some DWARF for a simple program.

{% highlight cpp %}
int main() {
    long a = 3;
    long b = 2;
    long c = a + b;
    a = 4;
}
{% endhighlight %}

If you compile this program with the `-g` option and run the result through `dwarfdump`, you should see something like this for the line number section:

```
.debug_line: line number info for a single cu
Source lines (from CU-DIE at .debug_info offset 0x0000000b):

<pc>        [row,col] NS BB ET PE EB IS= DI= uri: "filepath"
NS new statement, BB new basic block, ET end of text sequence
PE prologue end, EB epilogue begin
IA=val ISA number, DI=val discriminator value
0x00400750  [   1, 0] NS uri: "/home/simon/MiniDbg/examples/variable.cpp"
0x00400756  [   2,10] NS PE
0x0040075e  [   3,10] NS
0x00400766  [   4,14] NS
0x0040076a  [   4,16]
0x0040076e  [   4,10]
0x00400772  [   5, 7] NS
0x0040077a  [   6, 1] NS
0x0040077c  [   6, 1] NS ET
```

The first bunch of lines is some information on how to understand the dump, and the main line number data starts at the line starting with `0x00400750`. Essentially this maps a code memory address with a line and column number in some file. `NS` means that the address marks the beginning of a new statement, which is often used for setting breakpoints or stepping. `PE` marks the end of the function prologue, which is helpful for setting function entry breakpoints. `ET` marks the end of the translation unit. The information isn't actually encoded like this; the real encoding is a very space-efficient program of sorts which can be executed to build up this line information.

So, say we want to set a breakpoint on line 4 of variable.cpp, what do we do? We look for entries corresponding to that file, then we look for a relevant line entry, look up the address which corresponds to it, and set a breakpoint there. You could do so by hand with the debugger you've already written if you want to give it a try.

The reverse works just as well. If we have a memory location -- say, a program counter value -- and want to find out where that is in the source, we just find the closest mapped address in the line table information and grab the line from there.

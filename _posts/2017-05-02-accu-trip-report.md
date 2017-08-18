---
layout:     post
title:      "ACCUConf Trip Report"
category:   c++
tags:
 - c++
redirect_from:
  - /c++/2017/05/02/accu-trip-report/
  - /accu-trip-report.html
---

I have now returned from my trip to ACCUConf, reeling from five days of talks and tutorials. This is the first conference I've been to on my own, having only met one or two people there prior to the conference. Fortunately, it was a very welcoming environment and I quickly found myself talking to new friends and a bunch of people from the [C++ Slack channel](http://cpplang.diegostamigni.com/).

Talks are beginning to go online at the [ACCUConf YouTube channel](https://www.youtube.com/channel/UCJhay24LTpO1s4bIZxuIqKw/featured), so I thought I'd go through the talks I attended so that you can get an idea of what they were like.

Be sure to check out my [post]({% post_url 2017-04-27-accu-day-1 %}) on the pre-conference workshops if you haven't already.

### To hell and back: One guitarist’s journey through modern software development - Russ Miles

The conference had a Rock theme this year, so Russ Miles kicked things off with a microservices parody of AC/DC's Highway to Hell. This was a really fun way to get things started and it ensured that everyone was already loosened up as the conference began.

After his impressive performance, Russ shifted gears (hah) into a talk about how we could use chat tools to make microservices easier to deal with and lower the cognitive load of the myriad dashboards. I'm not involved in this area at all, but I'm interested to see how these ideas develop in the future.

### The nightmare of Move Semantics for Simple Classes - Nicolai Josuttis

The question which Nico proposed at the start was "what is the best way to write a constructor which takes two strings, the second of which has a default value"? This sounds very simple, but was incrementally shown to become a nightmare if you want to do it in the most efficient way possible.

Many different issues were touched on, such as perfect forwarding overloads getting chosen as copy constructors, [`std::is_constructible`](http://en.cppreference.com/w/cpp/types/is_constructible) not working properly when declaring other constructors and default arguments being non-deduced contexts.

This talk would be very interesting for anyone who wants to know the pain that is highly optimised object construction.

### Bluff your way in x64 assembler - Roger Orr

This is a great talk for anyone who wants just enough x86_64 knowledge to understand simple assembly output. Roger walked through the most common assembly instructions which compilers output, gave an overview of the register sets available in the architecture, and showed how to use the [Compiler Explorer](http://gcc.godbolt.org/) to <s>prove your colleagues wrong</s> understand the code which your source maps down to.

### C++ Countdown Pub Quiz - Robert Chately and Jon Jagger

This was easily the most fun session in the conference. We were split up into groups of two or three people and presented with a list of tokens like so:

{% highlight cpp %}
   "else",
    "~",
    "default",
    "->",
    "using",
    "foobar",
    "0x4b"
{% endhighlight %}

We then had seven minutes to write the smallest program (not including whitespace) which compiled and used all of the given tokens. For example, I paired up with Odin Holmes and our solution for the above set of tokens was:

{% highlight cpp %}
using a = int;

auto foobar() -> a {
    if(~0x4b);
    else;
    switch(0){
        default:;
    }
}
{% endhighlight %}

The format was really great; it encouraged healthy competition and allowed for some pretty heroic submissions, but it also kept the barrier for entry very low so that everyone could take part. I especially enjoyed seeing the ridiculous hacks which others would employ so that I could unceremoniously steal them for the next round.

### The Audacity of Chapel: Scalable Parallel Programming Done Right - Brad Chamberlain

I already covered Chapel in my previous post, so I won't go over it again, but this was a very well-presented introduction to the language and I'd recommend it if your interest was piqued by what I wrote about the tutorial.

### Writing games in very modern C++ - Guy Davidson

This was a really brave and impressive talk where Guy implemented [Asteroids](https://en.wikipedia.org/wiki/Asteroids_(video_game)) incrementally as a live demo. He started off walking us through a brief history of video games before grabbing his text editor and hacking away.

The implementation is based on the [proposal](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0267r3.pdf) for adding 2D graphics rendering and display to C++. I was a bit unconvinced by the arguments for such a library being standardised rather than relying on third party libraries which can evolve more easily. The API also seemed a bit old fashioned with some global state tracking font renderers and suchlike. However, I don't work on games or 2D graphics, so Guy and the authors of the paper will know much better than me!

### An Overview of Program Optimization Techniques - Mathias Gaunard

Mathias presented a large range of program optimisations, going everywhere from software prefetching, to loop unrolling, to parallel skeletons. The content was very strong and clear, but it did feel a bit dry for a 90-minute presentation. The slides would probably make a good reference or resource for creating other shorter, more focused presentations.

### Learning (and teaching) modern C++ - Challenges and Resources - Arne Mertz

This talk enumerated the resources which we currently have for learning and teaching modern C++ and discussed which are most helpful and why. The most interesting part of this talk for me was Arne's discussion of what "Modern C++" actually is. His argument was that we can write a lot of modern-style code in old versions of the standard, just as easily as we can write ancient C++ in C++17. His dream resource would be a community-sourced book which you could filter based on what area of C++ you were interested in, e.g. embedded, distributed, or desktop. I don't know what the best tool out there for such a book would be, but it certainly sounds like a good idea!

### Bloomberg ACCUChess17

In the evening of the second day, Bloomberg sponsored a really fantastic trip to a local microbrew pub with an "Armageddon Chess" tournament. The "Armageddon" part refers to the fact that you have a mere 2.5 minutes on the clock to play, so you have to go as fast as you can. I got completely destroyed by Guy Davidson in the first round, but it was a lot of fun to watch the other games going on and cheer on those who I know.

### Automatic C++ source code generation with clang - Sergei Sadovnikov

I use Clang a lot for both general C++ programming as well as compiler projects at work, so I was interested to see how we can leverage it to get a better method for code generation. Sergei took the example of generating functions to get the name of enum values, which is an oft-implemented and tedious task. Using the Clang tooling API he parsed the file containing the enum, walked over all of the values and output a function to get the name into some new file, which was then compiled and included in other parts of the program. He also hooked this into his CMake build system so that it wasn't replacing a manual process with another manual process. I really liked this approach and will keep this in mind for my own projects.

### Mongrel Monads, Dirty, Dirty, Dirty - Niall Douglas

This was one of my favourite talks of the conference, in which all of the main C++ error reporting techniques were discussed and compared to the proposed [std::expected](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/p0323r1.pdf). Niall took us from C-style error codes, C++ exceptions, and C++11's [`<system_error>`](http://en.cppreference.com/w/cpp/header/system_error) header (which I've never even used) before explaining this very Rust/Haskell-like new feature.

In addition to the explanation, he also presented some pretty terrifying benchmarks of the cost of reporting an error up ten stack frames. In the worst case, the performance for exceptions was multiple orders of magnitude worse than the other approaches, which were all in the same ballpark. I'd be interested in seeing more benchmarks in this area, particularly ones which analyse the overhead for when no errors occur in the system.

### Functional C++ For Fun And Profit - Phil Nash

This was a great talk which discussed a lot of different areas where C++ can move into a functional paradigm. Most blog posts and talks I've seen on this subject have just gone into higher order functions, maps, folds and suchlike, but Phil discussed how to implement immutability, composability, and more. This talk also serves as a good bottom-up introduction to the concepts behind the ranges TS and similar composable APIs. Of course, since this was a talk on functional programming, he managed to sneak in the [M](https://en.wikipedia.org/wiki/Monad_(functional_programming)) word.

### Modern C++ Design Reloaded - Odin Holmes

Odin shared his thoughts about policy-based design in C++ as we write it today. He showed how we can write a generic combiner that will allow policies to tune their implementation based on the details of some other policy. For example, an allocator might want to know about the other policies which a class uses in order to partition up some blocks to best match the use-case. This was all done with nested template aliases, which have a much smaller compile-time footprint than class template-based methods, because instantiating types and having their symbols kicking around in the compiler is expensive.

I really enjoyed this talk, but it's definitely better suited to those with a reasonable amount of prior template metaprogramming experience. Odin valiantly explained both the CRTP and concept-based polymorphism in order to provide a base of understanding for the rest, but if you watch the talk, I'd recommend learning about those ideas beforehand.

### Lightning talks

Lightning talks were run on the first three days and were one of the highlights of the conference. Every speaker had exactly five minutes to give their talk before being summarily ejected from the stage. Some talks were funny, some were educational, some were both. And if you don't like one talk? Hey, the next one is just five minutes away.

My favourite of these, and one the best talks in the whole conference, was the "A Story" by Andy Balaam. He put up a single slide of a stick man on the screen and read out a story of how he got into computing and the ACCU. It was all told through the eyes of a young boy who sees the magic contained in these machines and yearns for people to share it with, but, in spite of his other privileges, he finds himself marginalised. I don't want to poorly retell his story, so I'll just say that it's a talk about acceptance, inclusion, culture, and you should at least read the text [here](http://artificialworlds.net/presentations/a-story-about-feeling-safe/a-story.html).

I gave a talk about mechanical keyboards and the C++17 keyboard firmware I've been working on. It was the first talk I've given at a conference, but I think it went down pretty well!

### Thoughts on Metaclasses - Herb Sutter

This talk blew my mind. Herb doesn't want us spewing forth all the details until he can present some of the ideas to the committee, but it's safe to say that if these new reflection and code generation tools get in to the language, C++ won't be the same.

---------------------

That's it from me! I really enjoyed this conference and hope that I'll be able to attend in future years. Feel free to leave a comment to say hi if you met me at the conference, or let me know what your favourite talk was.

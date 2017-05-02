---
layout:     post
title:      "ACCUConf Trip Report"
category:   c++
tags:
 - c++
---

### To hell and back: One guitarist’s journey through modern software development - Russ Miles

### The nightmare of Move Semantics for Simple Classes - Nicolai Josuttis

The question which Nico proposed at the start was "what is the best way to write a constructor which takes two strings, the second of which has a default value"? This sounds very simple, but was incrementally shown to become a nightmare if you want to do it in the most efficient way possible.

Many different issues were touched on, such as perfect forwarding overloads getting chosen as copy constructors, `std::is_constructible` not working properly when declaring other constructors and default arguments being non-deduced contexts.

This talk would be very interesting for anyone who wants to know the pain that is highly optimised object construction.

### Bluff your way in x64 assembler - Roger Orr



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

This was a really brave talk where Guy implemented Asteroids incrementally as a live demo. He started off walking us through a brief history of video games before grabbing his text edtor and hacking away.

The implementation is based on the [proposal](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0267r3.pdf) for adding 2D graphics rendering and display to C++. I was a bit unconvinced by the arguments for such a library being standardised rather than relying on third party libraries which can evolve more easily. The API also seemed a bit old fashioned with some global state tracking font renderers and suchlike. However, I don't work on games or 2D graphics, so Guy and the authors of the paper will know much better than me!n

### An Overview of Program Optimization Techniques - Mathias Gaunard

Mathias presented a large range of program optimisations, going everywhere from software prefetching, to loop unrolling, to parallel skeletons. The content was very strong and clear, but it did feel a bit dry for a 90-minute presentation. The slides would probably make a good reference or resource for creating other shorter, more focused presentations.

### Learning (and teaching) modern C++ - Challenges and Resources - Arne Mertz

### Bloomberg ACCUChess17

In the evening of the second day, Bloomberg sponsored a really fantastic trip to a local microbrew pub with an "Armageddon Chess" tournament. The "Armageddon" part refers to the fact that you have a mere 2.5 minutes on the clock to play, so you have to go as fast as you can. I got completely destroyed by Guy Davidson in the first round, but it was a lot of fun to watch the other games going on and cheer on those who I know.

### AI: Actual Intelligence - Fran Buontempo

### Automatic C++ source code generation with clang - Sergei Sadovnikov

### Coroutines and C++ DSLs for Human Scale Concurrency - Dominic Robinson

### Mongrel Monads, Dirty, Dirty, Dirty - Niall Douglas

This was one of my favourite talks of the conference, in which all of the main C++ error reporting techniques were discussed and compared to the proposed [std::expected](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/p0323r1.pdf). Niall took us from C-style error codes, C++ exeptions, and C++11's `<system_error>` header (which I've never even used) before explaining this very Rust/Haskell-like new feature.

In addition to the explaination, he also presented some pretty terrifying benchmarks of the cost of reporting an error up ten stack frames. In the worst case, the performance for exceptions was multiple orders of magnitude worse than the other approaches, which were all in the same ballpark. I'd be interested in seeing more benchmarks in this area, particularly ones which analyse the overhead for when no errors occur in the system.

### Functional C++ For Fun And Profit - Phil Nash

### Modern C++ Design Reloaded - Odin Holmes

### Lightning talks

Lightning talks were run on the first three days and were one of the highlights of the conference. Every speaker had exactly five minutes to give their talk before being summarily ejected from the stage.

Some talks were funny, some were educational, some were both. And if you don't like one talk? Hey, the next one is just five minutes away.

My favourite of these, and one the best talks in the whole conference, was the "A Story" by Andy Balaam. He put up a single slide of a stick man on the screen and read out a story of how he got into computing and the ACCU. It was all told through the eyes of a young boy who sees the magic contained in these machines and yearns for people to share it with. But, in spite of his other privilages, he finds himself marginalised. I don't want to poorly retell his story, so I'll just say that it's a talk about acceptance, inclusion, culture, and you should at least read the text [here](http://artificialworlds.net/presentations/a-story-about-feeling-safe/a-story.html).

I gave a talk about mechanical keyboards and the C++17 keyboard firmware I've been working on. It was the first talk I've given at a conference, but I think it went down pretty well!

### Thoughts on Metaclasses - Herb Sutter

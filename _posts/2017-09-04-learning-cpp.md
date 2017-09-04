---
layout:     post
title:      "Learning C++"
category:   c++
tags:
 - c++
---

C++ is one of the most powerful programming languages in the world. However, it can also be one of the most daunting for beginners. There is so much to learn, so many corner cases, so many little languages within the language itself, that mastering it can seem an insurmountable task. Fortunately, it's not quite as impossible as it looks. This post outlines some resources and advice for learning C++ today. Some of these also will be useful for those who have used C++ in the past and want to get familiar with modern C++, which is like an entirely different language.

If you want to learn C++ from scratch, don't rely on random online tutorials. Get a good book. One of [these](https://stackoverflow.com/questions/388242/the-definitive-c-book-guide-and-list). I read the entirety of Accelerated C++ the day before the interview for my current job, and it was enough to get stuck in to real C++ development. It's a bit outdated now, (i.e. it doesn't cover C++11/14/17) but is easily the most important book in my career development. The Effective C++ series by [Scott Meyers](https://twitter.com/Scott__Meyers) should be mandatory reading for C++ developers, particularly Effective Modern C++, which is the go-to introduction to C++11 and 14. If you prefer online resources, use reputable ones like [Kate Gregory](https://twitter.com/gregcons)'s [Pluralsight courses](https://www.pluralsight.com/authors/kate-gregory) rather than whatever Google throws out. There are a *lot* of terrible C++ tutorials out there which will only harm you. A good rule of thumb: if you see `#include <iostream.h>`, run.

However, no matter how much you read, you need to practice in order to improve. I find it helpful to have a mix of small, self-contained problems to try out new techniques, and larger applications to make sure you can use those ideas in a real-world context. Kind of like unit tests and integration tests for your programming skills; can you use these ideas in isolation, and can you fit them together into something comprehensible and maintainable.

[Stack Overflow](https://stackoverflow.com/) is a great source of skill unit tests. I learned most of my initial metaprogramming knowledge by answering Stack Overflow questions incorrectly and having people tell me why I was wrong. Unfortunately it can be an unforgiving community, and isn't friendly to very simple questions. Be sure to read through the rules thoroughly before contributing, and feel free to send me an answer you were going to post to get feedback on it if you're worried!

For skill integration tests, I'd recommend coming up with an application in a domain you're interested in and trying to develop it from start to finish. If you haven't done much of this kind of thing before, it can be a daunting task. The main piece of advice I have on this is to ensure your application has a strict scope so that you always know what you're aiming towards and when you're finished. Set a number of checkpoints or milestones so that you have explicit tasks to work on and don't get lost. Some ideas for fun projects:
{:.listhead}

* A compiler for a simple C subset
* A mini text editor
* Implement some simplified standard library classes, like `std::vector`
* A clone of a simple video game like Snake
* An [ELF](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format) file manipulation tool

One of the most valuable knowledge sources is a good C++ community to be part of. Find out if your city or a nearby one has a [User Group](https://meetingcpp.com/index.php/user-groups.html) and go along to meet other developers. They might even have a mentorship program or advice channels for people learning the language. Definitely get on to the [C++ Slack Channel](https://cpplang.now.sh/) and lurk, ask questions, join in discussions. Many of the foremost C++ experts in the world hang out there, and it's also a very friendly and welcoming environment to those learning. There are even dedicated subchannels for those learning or having problems debugging C++.

Don't be discouraged when you find things difficult, and, trust me, you will. C++ is hard, and even the experts get things wrong, or can't even agree on what's right.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">C++ was invented primarily to teach humility to humans. <a href="https://t.co/ejZKeu32O3">https://t.co/ejZKeu32O3</a></p>&mdash; Andy Balaam (@andybalaam) <a href="https://twitter.com/andybalaam/status/890856460028178432">July 28, 2017</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

If you *do* get good, pass on the knowledge. Start a blog, give advice, mentor those who need it, talk at conferences. You do *not* need to be an expert to do these things, and we need more speakers and writers from a diverse set of experience levels, as well as in background, race, gender, sexuality. The major C++ conferences all have codes of conduct and organisers who care about these issues. Many of them also have student or accessibility tickets available for those who need further assistance to attend. If in doubt, just ask the organisers, or drop me a message and I can get in touch with the relevant people.

Finally, find some good, regular blogs to learn from. Here are some I would recommend:
{:.listhead}

* [Eli Bendersky](https://twitter.com/elibendersky) &mdash; [The Green Place](http://eli.thegreenplace.net/)
* [Jonathan Boccara](https://twitter.com/JoBoccara) &mdash; [Fluent C++](http://www.fluentcpp.com/)
* [Bartlomiej Filipek](https://twitter.com/fenbf) &mdash; [Bartek's coding blog](http://www.bfilipek.com/)
* [Stephanie Hurlburt](https://twitter.com/sehurlburt) &mdash; [Blog](http://stephaniehurlburt.com/blog-archive/)
* [KrzaQ](https://twitter.com/KrzaQ2) &mdash; [/dev/krzaq](https://dev.krzaq.cc/)
* [Arne Mertz](https://twitter.com/arne_mertz) &mdash; [Simplify C++](http://arne-mertz.de/)
* [Jonathan Müller](https://twitter.com/foonathan) &mdash; [foonathan::blog()](http://foonathan.net/)
* [Vittorio Romeo](https://twitter.com/supahvee1234) &mdash; [Personal website](http://vittorioromeo.info/)
* [Filip Roséen](https://twitter.com/aboywithstories) &mdash; [b.atch.se](http://b.atch.se/)
* [Adi Shavit](https://twitter.com/AdiShavit) &mdash; [Video Cortex](https://adishavit.github.io/#blog)
* [Jason Turner](https://twitter.com/lefticus) &mdash; [C++ Weekly](https://www.youtube.com/playlist?list=PLs3KjaCtOwSZ2tbuV1hx8Xz-rFZTan2J1)

I hope that this post helps you in your journey to learn C++. It's a long, but very rewarding path, with a lot of wonderful people to meet, work with, and debate metaprogramming techniques with along the way.

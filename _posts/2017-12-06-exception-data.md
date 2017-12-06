---
layout:     post
title:      "A call for data on exceptions"
category:   c++
tags:
 - c++ 
---

Last week I released an article entitled ["Functional exceptionless error-handling with optional and expected"](https://blog.tartanllama.xyz/optional-expected/). The idea was to talk about some good ways to handle errors for those cases where you don't want to use exceptions, but without starting a huge argument about whether exceptions are good or bad. That post has since spawned arguments about exceptions on [Hacker News](https://news.ycombinator.com/item?id=15838411), [two](https://vittorioromeo.info/index/blog/adts_over_exceptions.html) [other](http://foonathan.net/blog/2017/12/04/exceptions-vs-expected.html) blog posts, and [three](https://www.reddit.com/r/cpp/comments/7hk1gs/exceptions_vs_expected_lets_find_a_compromise/?st=jatcyvuo&sh=5b3957ef) [Reddit](https://www.reddit.com/r/cpp/comments/7ha64y/why_choose_sum_types_over_exceptions/?st=jatcyx9f&sh=89cbd789) [threads](https://www.reddit.com/r/cpp/comments/7gua48/functional_exceptionless_errorhandling_with/?st=jatcyxu9&sh=38b41869). Ten points for effort, zero for execution. Since the argument has now started, I feel inclined to give my own view on the matter. 

I know people who think exceptions are dangerous. I don't personally know anyone who thinks ADT-based error handling is dangerous, but I'm sure the Internet is full of them. What I think is dangerous is blind zealotry. Many people take a stance on either side of this divide for good reasons based on the constraints of their platform, but many just hear a respected games programmer say "exceptions are evil!" and believe that this applies to all cases. How do we fight this? With data.

I believe that as a community we need to be able to answer these questions:
{:.listhead}

1. What do the different kinds of error handling cost when errors occur?
2. What do they cost when no errors occur?
3. How consistent are the costs, and what causes deviations?
4. What is the cognitive overhead of the different techniques?
5. How do they affect the design of our interfaces?

I have an intuition about all of these, backed by some understanding of the actual code which is generated and how it performs, as I'm sure many of you do. But we hit a problem when it comes to teaching. I don't believe that _teaching_ an intuition can _build_ an intuition. Such a thing can only be built by experimentation or the reduction of hard data into a broad understanding of what that data points towards. If we answer all of questions above with hard data, then we can come up with a set of strong, measurable guidelines for when to use different kinds of error handling, and we can have something concrete to point people towards to help build that intuition. The [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#e-error-handling) provides the former, but not the latter. Furthermore, when I talk about "hard data", I don't just mean microbenchmarks. Microbenchmarks can help, sure, but writing them such that they have the realistic error patterns, cache behaviour, branch prediction, etc. is _hard_. 

Of course, many people have tried to answer these questions already, so I've teamed up with [Matt Dziubinski](https://twitter.com/matt_dz) to put together a set of [existing resources on error handling](https://github.com/MattPD/cpplinks/blob/master/error_handling.md). Use it to educate yourselves and others, and please submit issues/pull requests to make it better. But I believe that there's still work to be done, so if you're a prospective PhD or Masters student and you're looking for a topic, consider helping out the industry by researching the _real_ costs of different error handling techniques in realistic code bases with modern compilers and modern hardware.

`throw end_of_blog_post;`


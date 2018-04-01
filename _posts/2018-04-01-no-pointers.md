---
layout:     post
title:      "No more pointers"
category:   c++
tags:
 - c++
 - c++20
---

One of the major changes at the most recent C++ standards meeting in Jacksonville was the decision to [deprecate raw pointers in C++20](https://arne-mertz.de/2018/04/raw-pointers-are-gone/), moving to remove them completely in C++23. This came as a surprise to many, with a lot of discussion as to how we'll get by without this fundamental utility available any more. In this post I'll look at how we can replace some of the main use-cases of raw pointers in C++20.

Three of the main reasons people use raw pointers are:
{:.listhead}

- Dynamic allocation & runtime polymorphism
- Nullable references
- Avoiding copies

I'll deal with these points in turn, but first, an answer to the main question people ask about this change.

## The elephant in the room

What about legacy code? Don't worry, the committee have come up with a way to both move forward the language boldly
forward without breaking all the millions of lines of C++ which people have written over the years: opt-in extensions.

If you want to opt-in to C++20's no-pointers feature, you use `#feature`.

{% highlight cpp %}
#feature <no_pointers> //opt-in to no pointers
#feature <cpp20>       //opt-in to all C++20 features
{% endhighlight %}

This is a really cool new direction for the language. Hopefully with this we can slowly remove features like `std::initializer_list` so that new code isn't bogged down with legacy as much as it is today.

## Dynamic allocation & runtime polymorphism

I'm sure most of you already know the answer to this one: smart pointers. If you need to dynamically allocate some resource, that resource's lifetime should be managed by a smart pointer, such as `std::unique_ptr` or `std::shared_ptr`. These types are now special compiler-built-in types rather than normal standard library types. In fact, `std::is_fundamental<std::unique_ptr<int>>::value` now evaluates to `true`!

## Nullable references

Since references cannot be rebound and cannot be null, pointers are often used to fulfil this purpose. However, with C++20, we have a new type to fulfil this purpose: `std::optional<T&>`. `std::optional` was first introduced in C++17, but was plagued with no support for references and no [monadic interface](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0798r0.html). C++20 has fixed both of these, so now we have a much more usable `std::optional` type which can fill the gap that raw pointers have left behind.

## Avoiding copies

Some people like to use raw pointers to avoid copies at interface boundaries, such as returning some resource from a function. Fortunately, we have much better options, such as (Named) Return Value Optimization. C++17 made some forms of copy elision [mandatory](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0135r0.html), which gives us even more guarantees for the performance of our code.

## Wrapping up

Of course there are more use-cases for raw pointers, but this covers three of the most common ones. Personally, I think this is a great direction to see the language going in, and I look forward to seeing other ways we can slowly make C++ into a simpler, better language.

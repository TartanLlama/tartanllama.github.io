---
layout:     post
title:      "Passing overload sets to functions"
category:   c++
tags:
 - c++ 
---

Passing functions to functions is becoming increasingly prevalant in C++. With common advice being to prefer algorithms to loops, new library features like `std::visit`, lambdas being incrementally beefed up[^1][^2] and C++ function programming talks consistently being given at conferences, it's something that almost all C++ programmers will need to do at some point. Unfortunately, passing overload sets to functions is not very well supported by the language. In this post I'll discuss a few solutions to this problem.

## An example

We have some generic operation called `foo`. We want a way of specifying this function with two key requirements to ensure that it's clean to use.

1. It should be callable directly without requiring manually specifying template arguments:

{% highlight cpp %}
auto x = foo(42);           //good
auto y = foo("hello");      //good
auto z = foo<double>(42.0); //bad
auto z = foo{}(42.0);       //bad
{% endhighlight %}

2. Passing it to a higher-order function should not require manually specifying template arguments:

{% highlight cpp %}
std::transform(first, last, target, foo);      //good
std::transform(first, last, target, foo<int>); //bad
std::transform(first, last, target, foo{});    //okay I guess
{% endhighlight %}


A simple first choice would be to make it a function template:

{% highlight cpp %}
template <class T>
T foo(T t) { /*...*/ }
{% endhighlight %}

This fulfils the first requirement, but not the second:

{% highlight cpp %}
//compiles, but not what we want
std::transform(first, last, target, foo<int>); 

//uh oh
std::transform(first, last, target, foo);

7 : <source>:7:5: error: no matching function for call to 'transform'
    std::transform(first, last, target, foo);
    ^~~~~~~~~~~~~~
/opt/compiler-explorer/gcc-7.2.0/lib/gcc/x86_64-linux-gnu/7.2.0/../../../../include/c++/7.2.0/bits/stl_algo.h:4295:5: note: candidate template ignored: couldn't infer template argument '_UnaryOperation'
    transform(_InputIterator __first, _InputIterator __last,
    ^
/opt/compiler-explorer/gcc-7.2.0/lib/gcc/x86_64-linux-gnu/7.2.0/../../../../include/c++/7.2.0/bits/stl_algo.h:4332:5: note: candidate function template not viable: requires 5 arguments, but 4 were provided
    transform(_InputIterator1 __first1, _InputIterator1 __last1,
    ^
1 error generated.
{% endhighlight %}

That's no good.

A second option is to write `foo` as a function object with a call operator template:

{% highlight cpp %}
struct foo {
    template<class T>
    T operator()(T t) { ... }
};
{% endhighlight %}

We are now required to create an instance of this type whenever we want to use the function, which is okay for passing to other functions, but not great if we just want to call it directly:

{% highlight cpp %}
//this looks okay
std::transform(first, last, target, foo{});

//this looks strange
auto x = foo{}(42.0);
auto x = foo()(42.0);      
{% endhighlight %}

We're going to need a different solution.

--------------

### Lambdas and `LIFT`

As an intermediate step, we could use the normal function template approach, but wrap it in a lambda whenever we want to pass it to another function:

{% highlight cpp %}
std::transform(first, last, target, [](const auto&... xs) { return foo(xs...); });
{% endhighlight %}

That's not great. It'll work in some contexts where we don't know what template arguments to supply, but it's not yet suitable for all cases. One improvement would be to add perfect forwarding:

{% highlight cpp %}
[](auto&&... xs) { return foo(std::forward<decltype(xs)>(xs)...); }
{% endhighlight %}

But wait, we want to be SFINAE friendly, so we'll add a trailing return type:

{% highlight cpp %}
[](auto&&... xs) -> decltype(foo(std::forward<decltype(xs)>(xs)...)) {
    return foo(std::forward<decltype(xs)>(xs)...);
}
{% endhighlight %}

Okay, it's getting pretty crazy and expert-only at this point. And we're not even done! Some contexts will care about `noexcept`:

{% highlight cpp %}
[](auto&&... xs)
    noexcept(noexcept(foo(std::forward<decltype(xs)>(xs)...)))
          -> decltype(foo(std::forward<decltype(xs)>(xs)...)) {
    return foo(std::forward<decltype(xs)>(xs)...);
}
{% endhighlight %}

Okay, so the solution is to write this every time we want to pass an overloaded function to another function. That's probably a good way to make your code reviewer cry.

What would be nice is if [Abbreviated lambdas](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0573r2.html) and [Forward without forward](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0644r0.html) were accepted into the language. That'd let us write this:

{% highlight cpp %}
[](xs...) => foo(>>xs...)
{% endhighlight %}

The above is functionally equivalent to the triplicated montrosity in the example before. Even better, if [Lifting overload sets into objects](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0834r0.html) was accepted, we could just write:

{% highlight cpp %}
[]foo
{% endhighlight %}

That lifts the overload set into a single function object which we can pass around. Unfortunately, all of those proposals have been rejected. Maybe they can be renewed at some point, but for now we need to make do with other solutions. One such solution is to approximating `[]foo` with a macro (I know, I know).

{% highlight cpp %}
#define FWD(...) std::forward<decltype(__VA_ARGS__)>(__VA_ARGS__)

#define LIFT(X) [](auto &&... args) \
    noexcept(noexcept(X(FWD(args)...)))  \
    -> decltype(X(FWD(args)...)) \
{  \
    return X(FWD(args)...); \
}
{% endhighlight %}

Now our higher-order function call becomes:

{% highlight cpp %}
std::transform(first, last, target, LIFT(foo));
{% endhighlight %}

Okay, so there's a macro in there, but it's not *too* bad (you know we're in trouble when I start trying to justify the use of macros for this kind of thing). So `LIFT` is at least some solution.

------------------------

## Making function objects work for us

You might recall from a number of examples ago that the problem with using function object types was the need to construct an instance whenever we needed to call the function. What if we just make a global instance of the function object?

{% highlight cpp %}
struct foo_impl {
    template<class T>
    T operator()(T t) { ... }
};

extern const foo_impl foo;

// in some .cpp file
foo_impl foo;
{% endhighlight %}

This works if you're able to have a single translation unit with the definition of the global object. If you're writing a header-only library then you don't have that luxury, so you need to do something different.

{% highlight cpp %}
struct foo_impl {
    template<class T>
    T operator()(T t) { ... }
};

static foo_impl foo;
{% endhighlight %}

This might look innocent, but it can lead to One-Definition Rule (ODR) violations:

{% highlight cpp %}
//test.h header
struct foo_impl {
    template<class T>
    T operator()(T t) const { return t; }
};

static const foo_impl foo;

template <class T>
int oh_no(T t) {
    auto* foop = &foo;
    return (*foop)(t);
}

//cpp1
#include "test.h"
int sad() {
    return oh_no(42);
}

//cpp2
#include "test.h"
int also_sad() {
    return oh_no(24);
}
{% endhighlight %}

Since `foo` is declared `static`, each Translation Unit (TU) will get its own definition of the variable. However, `sad` and `also_sad` will instantiate `oh_no` which will get different definitions of `foo` for `&foo`.

In C++17 the solution is simple:

{% highlight cpp %}
inline constexpr foo_impl foo{};
{% endhighlight %}

[^1]: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0315r4.pdf
[^2]: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0624r2.pdf


Thanks to Michael Maier for the motivation to write this post.

http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0834r0.html
https://github.com/ericniebler/range-v3/blob/8ccd974b5cbb91dc9de7ab969abd568fcf569019/include/range/v3/size.hpp
https://github.com/ericniebler/range-v3/blob/8ccd974b5cbb91dc9de7ab969abd568fcf569019/include/range/v3/detail/config.hpp#L412
http://ericniebler.com/2014/10/21/customization-point-design-in-c11-and-beyond/
http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/n4381.html

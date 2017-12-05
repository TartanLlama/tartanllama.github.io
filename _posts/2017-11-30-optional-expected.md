---
layout:     post
title:      "Functional exceptionless error-handling with optional and expected"
category:   c++
tags:
 - c++
---

In software things can go wrong. Sometimes we might expect them to go wrong. Sometimes it's a surprise. In most cases we want to build in some way of handling these misfortunes. Let's call them [disappointments](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0157r0.html). I'm going to exhibit how to use `std::optional` and the proposed `std::expected` to handle disappointments, and show how the types can be extended with concepts from functional programming to make the handling concise and expressive.

One way to express and handle disappointments is exceptions:

{% highlight cpp %}
void foo() {
    try {
        do_thing();
    }
    catch (...) {
        //oh no
        handle_error();
    }
}
{% endhighlight %}

There are a myriad of discussions, resources, rants, tirades, debates about the value of exceptions[^1][^2][^3][^4][^5][^6], and I will not repeat them here. Suffice to say that there are cases in which exceptions are not the best tool for the job. For the sake of being uncontroversial, I'll take the example of disappointments which are expected within reasonable use of an API.

[^1]: [Mongrel Monads, Dirty, Dirty, Dirty -- Niall Douglas -- ACCU 2017](https://www.youtube.com/watch?v=XVofgKH-uu4)
[^2]: [Why is exception handling bad? -- Stack Overflow](https://stackoverflow.com/questions/1736146/why-is-exception-handling-bad)
[^3]: [Are Exceptions in C++ really slow?  -- Stack Overflow](https://stackoverflow.com/questions/13835817/are-exceptions-in-c-really-slow)
[^4]: [C++ Exceptions: The Good, The Bad, And The Ugly -- Shane Kirk](http://www.shanekirk.com/2015/06/c-exceptions-the-good-the-bad-and-the-ugly/)
[^5]: [Top 15 C++ Exception handling mistakes and how to avoid them -- Deb Haldar -- A Coder's Journey](http://www.acodersjourney.com/2016/08/top-15-c-exception-handling-mistakes-avoid/)
[^6]: [Everything wrong with exceptions -- Musing Mortoray](https://mortoray.com/2012/04/02/everything-wrong-with-exceptions/)

The internet loves cats. The hypothetical you and I are involved in the business of producing the cutest images of cats the world has ever seen. We have produced a high-quality C++ library geared towards this sole aim, and we want it to be at the bleeding edge of modern C++.

A common operation in feline cutification programs is to locate cats in a given image. How should we express this in our API? One option is exceptions:

{% highlight cpp %}
// Throws no_cat_found if a cat is not found.
image_view find_cat (image_view img);
{% endhighlight %}

This function takes a view of an image and returns a smaller view which contains the first cat it finds. If it does not find a cat, then it throws an exception. If we're going to be giving this function a million images, half of which do not contain cats, then that's a *lot* of exceptions being thrown. In fact, we're pretty much using exceptions for control flow at that point, which is [A Bad Thing](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#e3-use-exceptions-for-error-handling-only)&trade;.

What we really want to express is a function which either returns a cat if it finds one, or it returns nothing. Enter `std::optional`.

{% highlight cpp %}
std::optional<image_view> find_cat (image_view img);
{% endhighlight %}

[`std::optional`](http://en.cppreference.com/w/cpp/utility/optional) was introduced in C++17 for representing a value which may or may not be present. It is intended to be a vocabulary type -- i.e. the canonical choice for expressing some concept in your code. The difference between this signature and the last is powerful; we've moved the description of what happens on an error from the documentation into the type system. Now it's impossible for the user to forget to read the docs, because the compiler is reading them for us, and you can be sure that it'll shout at you if you use the type incorrectly.

The most common operations on a `std::optional` are:

{% highlight cpp %}
std::optional<image_view> full_view = my_view;
std::optional<image_view> empty_view;
std::optional<image_view> another_empty_view = std::nullopt;

full_view.has_value(); //true
empty_view.has_value(); //false

if (full_view) { this_works(); }

my_view = full_view.value();
my_view = *full_view;

my_view = empty_view.value(); //throws bad_optional_access
my_view = *empty_view; //undefined behaviour
{% endhighlight %}

Now we're ready to use our `find_cat` function along with some other friends from our library to make embarrassingly adorable pictures of cats:

{% highlight cpp %}
std::optional<image_view> get_cute_cat (image_view img) {
    auto cropped = find_cat(img);
    if (!cropped) {
      return std::nullopt;
    }

    auto with_tie = add_bow_tie(*cropped);
    if (!with_tie) {
      return std::nullopt;
    }

    auto with_sparkles = make_eyes_sparkle(*with_tie);
    if (!with_sparkles) {
      return std::nullopt;
    }

    return add_rainbow(make_smaller(*with_sparkles));
}
{% endhighlight %}

Well this is... okay. The user is made to explicitly handle what happens in case of an error, so they can't forget about it, which is good. But there are two issues with this:
{:.listhead}

1. There's no information about *why* the operations failed.
2. There's too much noise; error handling dominates the logic of the code.

I'll address these two points in turn.

### Why did something fail?

`std::optional` is great for expressing that some operation produced no value, but it gives us no information to help us understand why this occurred; we're left to use whatever context we have available, or (God forbid) output parameters. What we want is a type which either contains a value, or contains some information about why the value isn't there. This is called `std::expected`.

Now don't go rushing off to cppreference to find out about `std::expected`; you won't find it there yet, because it's currently a [standards proposal](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0323r3.pdf) rather than a part of C++ proper. However, its interface follows `std::optional` pretty closely, so you already understand most of it. Again, here are the most common operations:

{% highlight cpp %}
std::expected<image_view,error_code> full_view = my_view;
std::expected<image_view,error_code> empty_view = std::unexpected(that_is_a_dog);

full_view.has_value(); //true
empty_view.has_value(); //false

if (full_view) { this_works(); }

my_view = full_view.value();
my_view = *full_view;

my_view = empty_view.value(); //throws bad_expected_access
my_view = *empty_view; //undefined behaviour

auto code = empty_view.error();
auto oh_no = full_view.error(); //undefined behaviour
{% endhighlight %}

With `std::expected` our code might look like this:

{% highlight cpp %}
std::expected<image_view, error_code> get_cute_cat (image_view img) {
    auto cropped = find_cat(img);p
    if (!cropped) {
      return no_cat_found;
    }

    auto with_tie = add_bow_tie(*cropped);
    if (!with_tie) {
      return cannot_see_neck;
    }

    auto with_sparkles = make_eyes_sparkle(*with_tie);
    if (!with_sparkles) {
      return cat_has_eyes_shut;
    }

    return add_rainbow(make_smaller(*with_sparkles));
}
{% endhighlight %}

Now when we call `get_cute_cat` and don't get a lovely image back, we have some useful information to report to the user as to why we got into this situation.

### Noisy error handling

Unfortunately, with both the `std::optional` and `std::expected` versions, there's still a lot of noise. This is a disappointing solution to handling disappointments. It's also the limit of what C++17's `std::optional` and the most recent proposed `std::expected` give us.

What we really want is a way to express the operations we want to carry out while pushing the disappointment handling off to the side. As is becoming increasingly trendy in the world of C++, we'll look to the world of functional programming for help. In this case, the help comes in the form of what I'll call `map` and `and_then`.

If we have some `std::optional` and we want to carry out some operation on it if and only if there's a value stored, then we can use `map`:

{% highlight cpp %}
widget do_thing (const widget&);

std::optional<widget> result = maybe_get_widget().map(do_thing);
auto result = maybe_get_widget().map(do_thing); //or with auto
{% endhighlight %}

This code is roughly equivalent to:

{% highlight cpp %}
widget do_thing (const widget&);

auto opt_widget = maybe_get_widget();
if (opt_widget) {
   widget result = do_thing(*opt_widget);
}
{% endhighlight %}

If we want to carry out some operation *which could itself fail* then we can use `and_then`:

{% highlight cpp %}
std::optional<widget> maybe_do_thing (const widget&);

std::optional<widget> result = maybe_get_widget().and_then(maybe_do_thing);
auto result = maybe_get_widget().and_then(maybe_do_thing); //or with auto
{% endhighlight %}

This code is roughly equivalent to:

{% highlight cpp %}
std::optional<widget> maybe_do_thing (const widget&);

auto opt_widget = maybe_get_widget();
if (opt_widget) {
   std::optional<widget> result = maybe_do_thing(*opt_widget);
}
{% endhighlight %}

The real power of this comes when we begin to chain operations together. Let's look at that original `get_cute_cat` implementation again:

{% highlight cpp %}
std::optional<image_view> get_cute_cat (image_view img) {e
    auto cropped = find_cat(img);
    if (!cropped) {
      return std::nullopt;
    }

    auto with_tie = add_bow_tie(*cropped);
    if (!with_tie) {
      return std::nullopt;
    }

    auto with_sparkles = make_eyes_sparkle(*with_tie);
    if (!with_sparkles) {
      return std::nullopt;
    }

    return add_rainbow(make_smaller(*with_sparkles));
}
{% endhighlight %}

With `map` and `and_then`, our code transforms into this:

{% highlight cpp %}
tl::optional<image_view> get_cute_cat (image_view img) {
    return crop_to_cat(img)
           .and_then(add_bow_tie)
           .and_then(make_eyes_sparkle)
           .map(make_smaller)
           .map(add_rainbow);
}
{% endhighlight %}

With these two functions we've successfully pushed the error handling off to the side, allowing us to express a series of operations which may fail without interrupting the flow of logic to test an `optional`. For more discussion about this code and the equivalent exception-based code, I'd recommend reading [Vittorio Romeo](https://twitter.com/supahvee1234)'s [Why choose sum types over exceptions?](https://vittorioromeo.info/index/blog/adts_over_exceptions.html) article.

### A theoretical aside

I didn't make up `map` and `and_then` off the top of my head; other languages have had equivalent features for a long time, and the theoretical concepts are common subjects in [Category Theory](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/).

I won't attempt to explain all the relevant concepts in this post, as others have done it far better than I could. The basic idea is that `map` comes from the concept of a *functor*, and `and_then` comes from *monads*. These two functions are called `fmap` and `>>=` (bind) in Haskell. The best description of these concepts which I have read is [Functors, Applicatives' And Monads In Pictures](http://adit.io/posts/2013-04-17-functors,_applicatives,_and_monads_in_pictures.html) by Aditya Bhargava. Give it a read if you'd like to learn more about these ideas.

### A note on overload sets

One use-case which is annoyingly verbose is passing overloaded functions to `map` or `and_then`. For example:

{% highlight cpp %}
int foo (int);

tl::optional<int> o;
o.map(foo);
{% endhighlight %}

The above code works fine. But as soon as we add another overload to `foo`:

{% highlight cpp %}
int foo (int);
int foo (double);

tl::optional<int> o;
o.map(foo);
{% endhighlight %}

then it fails to compile with a rather unhelpful error message:

```
test.cpp:7:3: error: no matching member function for call to 'map'
o.map(foo);
~~^~~
/home/simon/projects/optional/optional.hpp:759:52: note: candidate template ignored: couldn't infer template argument 'F'
  template <class F> TL_OPTIONAL_11_CONSTEXPR auto map(F &&f) & {
                                                   ^
/home/simon/projects/optional/optional.hpp:765:52: note: candidate template ignored: couldn't infer template argument 'F'
  template <class F> TL_OPTIONAL_11_CONSTEXPR auto map(F &&f) && {
                                                   ^
/home/simon/projects/optional/optional.hpp:771:37: note: candidate template ignored: couldn't infer template argument 'F'
  template <class F> constexpr auto map(F &&f) const & {
                                    ^
/home/simon/projects/optional/optional.hpp:777:37: note: candidate template ignored: couldn't infer template argument 'F'
  template <class F> constexpr auto map(F &&f) const && {
                                    ^
1 error generated.
```

One solution for this is to use a generic lambda:

{% highlight cpp %}
tl::optional<int> o;
o.map([](auto x){return foo(x);});
{% endhighlight %}

Another is a `LIFT` macro:

{% highlight cpp %}
#define FWD(...) std::forward<decltype(__VA_ARGS__)>(__VA_ARGS__)
#define LIFT(f) \
    [](auto&&... xs) noexcept(noexcept(f(FWD(xs)...))) -> decltype(f(FWD(xs)...)) \
    { return f(FWD(xs)...); }

tl::optional<int> o;
o.map(LIFT(foo));
{% endhighlight %}

Personally I hope to see [overload set lifting](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0834r0.html) get into the standard so that we don't need to bother with the above solutions.

### Current status

Maybe I've persuaded you that these extensions to `std::optional` and `std::expected` are useful and you would like to use them in your code. Fortunately I have written implementations of both with the extensions shown in this post, among others. [`tl::optional`](https://github.com/TartanLlama/optional) and [`tl::expected`](https://github.com/TartanLlama/expected) are on GitHub as single-header libraries under the [CC0](https://creativecommons.org/share-your-work/public-domain/cc0/) license, so they should be easy to integrate with projects new and old.

As far as the standard goes, there are a few avenues being entertained for adding this functionality. I have a [proposal](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0798r0.html) to extend `std::optional` with new member functions. Vicente Escribá has a [proposal](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0650r1.pdf) for a generalised monadic interface for C++. Niall Douglas' [`operator try()`](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0779r0.pdf) paper suggests an analogue to Rust's [try!](https://doc.rust-lang.org/1.9.0/std/macro.try!.html) macro for removing some of the boilerplate associated with this style of programming. It turns out that you can use [coroutines](https://github.com/toby-allsopp/coroutine_monad) for doing this stuff, although my gut feeling puts this more to the "abuse" end of the spectrum. I'd also be interested in evaluating how [Ranges](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/n4685.pdf) could be leveraged for these goals.

Ultimately I don't care how we achieve this as a community so long as we have *some* standardised solution available. As C++ programmers we're constantly finding new ways to leverage the power of the language to make expressive libraries, thus improving the quality of the code we write day to day. Let's apply this to `std::optional` and `std::expected`. They deserve it.

------------------

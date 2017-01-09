---
layout:     post
title:      "Exploding tuples with fold expressions"
category:   c++
minutes:    10
tags:
 - c++ 
 - templates
---

### Introduction

Generic programming in C++ has been made much easier with C++11's addition of [`std::tuple`](http://en.cppreference.com/w/cpp/utility/tuple). It allows us to store objects of different types in the same container and index them at compile time. Support for algorithms over heterogeneous types like `std::tuple` is pretty thin in the standard library, so some programmers tend to pull in dependencies such as the excellent [`boost::hana`](https://github.com/boostorg/hana) to hide away all the crazy template metaprogramming tricks. I'll show you how you can use fold expressions to ease the implementation such functions, and I'll demonstrate a very small abstraction function for rolling your own heterogenous algorithms.

So, say we have a tuple and we want to print out every element of it. If there was a utility to call some function on every element of a tuple, you might use it like this:

{% highlight cpp %}
for_each(std::make_tuple(1, 42.1, "hi"),
         [](auto&& e) { std::cout << e; });
{% endhighlight %}

The implementation of `for_each` would typically rely on the *indices trick*. This involves generating a compile-time sequence of indices for the tuple, then passing them as variadic non-type template arguments to another template function and expanding the resulting parameter pack. If that all sounds gibberish to you, don't worry, I'll explain.

{% highlight cpp %}
template <typename... Args, typename Func>
void for_each(const std::tuple<Args...>& t, Func&& f) {
    for_each(t, f, std::index_sequence_for<Args...>{});
}
{% endhighlight %}

The above code generates the index sequence and passes it on to to the helper function which we'll define next. `std::index_sequence_for` is part of C++14's[^1] support for compile-time sequence generation. [`std::integer_sequence`](http://en.cppreference.com/w/cpp/utility/integer_sequence) is the class you pass around, and it comes with a bunch of handy helpers, like `std::make_integer_sequence` and the one we used above. `std::index_sequence<0,1,...>` is the same as `std::integer_sequence<std::size_t, 0,1,...>`.

[^1]: If you're stuck with C++11, there are plenty implementations online, or you can just steal one from your favourite standard library implementation.

{% highlight cpp %}
template <typename... Args, typename Func, std::size_t... Idx>
void for_each(const std::tuple<Args...>& t, Func&& f, std::index_sequence<Idx...>) {
    f(std::get<Idx>(t))...;
}
{% endhighlight %}

In case you aren't familiar with some of the constructs here, I'll break this code down. `std::get<Idx>(t)` gets the `Idx`th element from the tuple `t`. `f(std::get<Idx>(t))` calls the functor `f` with that element. `f(std::get<Idx>(t))...` expands the parameter pack `Idx` over that expression. So if `for_each` is called with `std::index_sequence<0,1,2>`, it generates this code:

{% highlight cpp %}
f(std::get<0>(t));
f(std::get<1>(t));
f(std::get<2>(t));
{% endhighlight %}

Hopefully you'll see that now, when we call this:

{% highlight cpp %}
for_each(std::make_tuple(1, 42.1, "hi"),
         [](auto&& e) { std::cout << e; });
{% endhighlight %}

then `std::index_sequence<0,1,2>` will be generated in `for_each`, everything will be passed on to the helper, and it'll generate code to call our closure for each element of the tuple.

Unfortunately, that's not what happens.

----------------------------------

### Everything is awful

Keen readers might have noticed that I lied in the above section. `f(std::get<Idx>(t))...;` does *not* generate that sequence of calls to `f`. In fact, it doesn't even compile. The problem is that parameter packs can only be expanded in contexts which expect a syntactic list, such as initializers and function call arguments. You can't just expand them bare in a function body. In C++17, this problem has a nice solution, but prior to that we need to use some pretty horrible hacks. Here's one possibility which uses `std::initializer_list` to create a context in which the parameter pack can be expanded.

{% highlight cpp %}
template <typename... Args, typename Func, std::size_t... Idx>
void for_each(const std::tuple& t, Func&& f, std::index_sequence<Idx...>) {
    (void)std::initializer_list<int> { 
        (f(std::get<Idx>(t)), void(), 0)...
    };
}
{% endhighlight %}

The above successfully [compiles and runs](http://coliru.stacked-crooked.com/a/32f5cd5194fef6c6). The trick is the `, 0` inside the `initializer_list` initializer, which evaluates the function call, and uses `0` as the initializer value. The `void()` is there just incase some has been perverse enough to call this with types with overloaded `operator,`.

--------------------------

### Fold expressions are less awful

As noted above, C++17 has a nicer solution for this in the form of [fold expressions](http://en.cppreference.com/w/cpp/language/fold). Fold expressions allow the expansion of parameter packs over operators, of which `,` is one. With this feature we can write the following code to get rid of our previous hack:

{% highlight cpp %}
template <typename... Args, typename Func, std::size_t... Idx>
void for_each(const std::tuple<Args...>& t, Func&& f, std::index_sequence<Idx...>) {
    (f(std::get<Idx>(t)), ...);
}
{% endhighlight %}

I think you'll agree that this is a huge improvement.

-------------------

### Abstracting it

Even though fold expressions make writing this code easier and less guru-only, the indices trick can still be difficult for beginners. It turns out that we can actually abstract this pattern to give "normal" users access to this power.

Our abstraction function will be called `make_index_dispatcher`, and it'll produce a closure for dispatching indices based on an index sequence size.

{% highlight cpp %}
template <std::size_t... Idx>
auto make_index_dispatcher(std::index_sequence<Idx...>) {
    return [] (auto&& f) { (f(std::integral_constant<std::size_t,Idx>{}), ...); };
}

template <std::size_t N>
auto make_index_dispatcher() {
    return make_index_dispatcher(std::make_index_sequence<N>{}); 
}
{% endhighlight %}

The first template takes in an index sequence and returns a closure. This closure takes a functor argument which will be called with a compile-time `std::size_t` constant for each index in the parameter pack. The second template just generates the index sequence from the given sequence size.

`for_each` can now be implemented in a single function without any weird tricks. Here's a simple implementation:

{% highlight cpp %}
template <typename... Args, typename Func>
void for_each(const std::tuple<Args...>& t, const Func& f) {
    auto dispatcher = make_index_dispatcher<sizeof...(Args)>();
    dispatcher([&](auto idx) { f(std::get<idx>(t)); });
}
{% endhighlight %}

Here's a more generic version which uses perfect forwarding ([live demo](http://coliru.stacked-crooked.com/a/cc57b2f481a88c9d) to play with):

{% highlight cpp %}
template <typename Tuple, typename Func>
void for_each(Tuple&& t, Func&& f) {
    constexpr auto n = std::tuple_size<std::decay_t<Tuple>>::value;
    auto dispatcher = make_index_dispatcher<n>();
    dispatcher([&f,&t](auto idx) { f(std::get<idx>(std::forward<Tuple>(t))); });
}
{% endhighlight %}

--------------------

There you have it; a generic utility for compile-time dispatching on index-based containers, and the know-how to implement variations yourself. Let me know if you find any uses or improvements for this, or if you have any questions about the nitty-gritty of these techniques.

------------

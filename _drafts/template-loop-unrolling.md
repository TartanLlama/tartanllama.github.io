---
layout:     post
title:      "Unrolling loops with templates"
category:   c++
tags:
 - c++ 
 - templates
---

{% highlight cpp %}
namespace detail{
    //This is used to store the visited nodes
    template<int...> struct int_pack;

    //Primary template
    template<typename, int... I>
    struct C;

    //This is the leaf node
    template<int... Is>
    struct C<int_pack<Is...>> {
        //The loop body goes here
        static void f() {
            std::cout << __PRETTY_FUNCTION__ << '\n';
        }
    };

    //This is the recursive case
    template <int I, int... Is, int... PIs>
    struct C<int_pack<PIs...>, I,Is...> {
        template <std::size_t... Idx>
        static void f_help (std::index_sequence<Idx...>) {
            //Store the current node in the pack 
            //and call `C::f` for each loop iteration
            (void)std::initializer_list<int> {
                (C<int_pack<PIs...,Idx>,Is...>::f(), 0)... 
            };   
        }

        //Use tag dispatching to generate the loop iterations
        static void f() {
            f_help(std::make_index_sequence<I>{});
        }
    };
}

//Helper alias
template<int... Is>
using C = detail::C<detail::int_pack<>, Is...>;
{% endhighlight %}

The usage is pretty simple:

{% highlight cpp %}
C<2,3>::f();
{% endhighlight %}

This will call `f()` once for each loop iteration with the counters stored in the `int_pack`. Clang prints the following:

{% highlight cpp %}
static void detail::C<detail::int_pack<0, 0>>::f() [I = <>]
static void detail::C<detail::int_pack<0, 1>>::f() [I = <>]
static void detail::C<detail::int_pack<0, 2>>::f() [I = <>]
static void detail::C<detail::int_pack<1, 0>>::f() [I = <>]
static void detail::C<detail::int_pack<1, 1>>::f() [I = <>]
static void detail::C<detail::int_pack<1, 2>>::f() [I = <>]
{% endhighlight %}

---------------------------------

This is fine if we just want to do this loop unrolling for a single loop, but the duplication would quickly become a nightmare if we wanted to repeat it. One solution would be to inject a lambda into the class to use as the loop body. This is a pretty easy modification to make to our existing code:

{% highlight cpp %}
template<int... Is>
struct C<int_pack<Is...>> {
    //This is now a template which takes in a functor
    template <typename Func>
    static void f(const Func& func) {
        func(std::integral_constant<std::size_t, Is>{}...);
    }
};

template <int I, int... Is, int... PIs>
struct C<int_pack<PIs...>, I,Is...> {
    //We need to pass the function through here
    template <std::size_t... Idx, typename Func>
    static void f_help (std::index_sequence<Idx...>, const Func& func) {
        (void)std::initializer_list<int>{ (C<int_pack<PIs...,Idx>,Is...>::f(func), 0)... };   
    }

    //And this is our entry point
    template <typename Func>
    static void f(const Func& func) {
        f_help(std::make_index_sequence<I>{}, func);
    }
};
{% endhighlight %}

Now we can pass a lambda or anything which acts like a function to `f`:

{% highlight cpp %}
C<2,3>::f([](auto i, auto j){
    std::cout << "i " << i << " j " << j << '\n';
});
{% endhighlight %}

-----------------------

Alternatively, we could use a metaprogramming library like `boost::hana`:

{% highlight cpp %}
template <typename Func>
void unroll (const Func& func) {
    func();
}

template <std::size_t I1, std::size_t... Is, typename Func>
void unroll (const Func& func) {
    hana::for_each(hana::range_c<std::size_t, 0, I1>,
                   [&](auto x) {
                       unroll<Is...>([x, &func] (auto... xs) { func(x,xs...); });
                   });
}
{% endhighlight %}

---
layout:     post
title:      "Adding C++17 structured binding support to your classes"
data:       2016-06-2016
summary:    How to
category:   c++
draft:      true
tags:
 - c++
 - c++17
---

Structured bindings (proposals [here](https://isocpp.org/files/papers/P0144R1.pdf) and [here](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/p0217r2.html)) is a C++17 feature which allows you to declare multiple variables initialised from a tuple-like object, like this:

{% highlight cpp %}
tuple<T1,T2,T3> f(/*...*/) { /*...*/ return {a,b,c}; }
auto [x,y,z] = f(); // x has type T1, y has type T2, z has type T3
{% endhighlight %}

This is a very powerful and expressive feature, but the most interesting element for me is the ability to add structured binding support to your own classes. This post is a short tutorial on how to do this, mostly for my own future reference.

(Note: currently there aren't any implementations available to play with, so this is theory for now. I plan to update this post as things change.)

-----------------------

Adding support for structured bindings is surprisingly easy; you just need to specialize three existing template classes to express how to destructure your class. These three template classes are `std::tuple_size` (number of variables), `std::tuple_element` (types of the variables), and `std::get` (values of the variables).

For demonstration purposes we'll write a small `triple` implementation, which is like a `std::pair`, but with three elements.

{% highlight cpp %}
template <typename A, typename B, typename C>
struct triple {
	A a;
	B b;
	C c;
};
{% endhighlight %}

The simplest specialization is `std::tuple_size`. Since there are three elements, we'll just return `3`.

{% highlight cpp %}
namespace std {
    template<typename... Ts> struct tuple_size<triple<Ts...>>
        : std::integral_constant<std::size_t, 3> {};
}
{% endhighlight %}

Next is `std::tuple_element`. For this we just need to return the type corresponding to the index passed in, so `A` for `0`, `B` for `1`, and `C` for `2`. You could cheat and just wrap the types in a `std::tuple` and use `std::tuple_element` on that, but we'll do this the long way.

{% highlight cpp %}
namespace std {
    template <typename A, typename B, typename C> 
    struct tuple_element<0, triple<A,B,C>> { using type = A; };
    
    template <typename A, typename B, typename C> 
    struct tuple_element<1, triple<A,B,C>> { using type = B; };
    
    template <typename A, typename B, typename C> 
    struct tuple_element<2, triple<A,B,C>> { using type = C; };
}
{% endhighlight %}

And finally `std::get`. We'll use C++17's `if constexpr` for brevity.

{% highlight cpp %}
namespace std {
    template <typename A, typename B, typename C>
    auto get  	
}
}
{% endhighlight %}
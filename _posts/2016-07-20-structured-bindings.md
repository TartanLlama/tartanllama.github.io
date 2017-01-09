---
layout:     post
title:      "Adding C++17 decomposition declaration support to your classes"
date:       2016-07-20
category:   c++
tags:
 - c++
 - c++17
---

### Introduction

C++17 adds decomposition declarations (proposals [here](https://isocpp.org/files/papers/P0144R1.pdf) and [here](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/p0217r2.html)) to the language, which allow you to declare multiple variables initialised from a tuple-like object:

{% highlight cpp %}
tuple<T1,T2,T3> f(/*...*/) { /*...*/ return {a,b,c}; }
auto [x,y,z] = f(); // x has type T1, y has type T2, z has type T3
{% endhighlight %}

This is a very powerful and expressive feature, but the most interesting element for me is the ability to add support for this to your own classes. This post is a short tutorial on how to do this, mostly for my own future reference.

(Note: currently there aren't any implementations available to play with, so this is theory for now. I plan to update this post as things change.)

-----------------------

### Built-in support

The great news is that decomposition declarations are supported out-of-the-box for classes where all the non-static member variables are public (or all public-only non-statc members are in a single direct base class). So a class like this can be decomposed with no additional code:

{% highlight cpp %}
struct yay {
    int a;
    float b;
    std::string c;
};

yay foo();

auto [a, b, c] = foo();
{% endhighlight %}

So can this:

{% highlight cpp %}
struct yay_wrapper : yay {
    static int count;
};

yay_wrapper bar();

auto [a, b, c] = bar();
{% endhighlight %}

If you have more complex classes, or want to wrap/process members before exposing them, you'll need to add support yourself. Fortunately, this is rather elegantly built on top of existing mechanisms. All you need to do is tell the compiler how many variables you want to expose, the types of them, and how to get at the values. This is done through the `std::tuple_size`, `std::tuple_element`, and `get` utilities.

-------------------------------------

### Supporting other classes

For demonstration purposes we'll write a small class named `Config`, which stores some immutable configuration data. We'll be returning `name` as a C++17 `std::string_view`, `id` by value, and `data` by reference to const. 

{% highlight cpp %}
class Config {
    std::string name;
    std::size_t id;
    std::vector<std::string> data;
    
    //constructors and such
};
{% endhighlight %}

The simplest specialization is `std::tuple_size`. Since there are three elements, we'll just return `3`.

{% highlight cpp %}
namespace std {
    struct tuple_size<Config>
        : std::integral_constant<std::size_t, 3> {};
}
{% endhighlight %}

Next is `get`. We'll use C++17's `if constexpr` for brevity. I've just added this as a member function to avoid the headache of template friends, but you can also have it as a non-member function found through ADL.

{% highlight cpp %}
class Config {
    //...
    
   template <std::size_t N>
   decltype(auto) get() const {
       if      constexpr (N == 0) return std::string_view{name};
       else if constexpr (N == 1) return id;
       else if constexpr (N == 2) return (data); //parens needed to get reference
   }
};

{% endhighlight %}

Finally we need to specialize `std::tuple_element`. For this we just need to return the type corresponding to the index passed in, so `std::string_view` for `0`, `std::size_t` for `1`, and `const std::vector<std::string>&` for `2`. We'll cheat and get the compiler to work out the types for us using the `get` function we wrote above. This way, we don't need to touch this specialization if we want to change the types we return later, or want to add more variables to the class.

{% highlight cpp %}
namespace std {
    template<std::size_t N> 
    struct tuple_element<N, Config> { 
        using type = decltype(std::declval<Config>().get<N>()); 
    };
}
{% endhighlight %}

You could do this the long way if you aren't comfortable with the `decltype` magic:

{% highlight cpp %}
namespace std {
    template<> struct tuple_element<0,Config> { using type = std::string_view; };
    template<> struct tuple_element<1,Config> { using type = std::size_t; };
    template<> struct tuple_element<2,Config> { using type = const std::vector<std::string>&; };
}
{% endhighlight %}

--------------------------------

With all of that done, we can now decompose `Config` like so:

{% highlight cpp %}
Config get_config();

auto [name, id, data] = get_config();
{% endhighlight %}


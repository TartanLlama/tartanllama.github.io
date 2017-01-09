---
layout:     post
title:      "Check if T::value is constexpr"
category:   c++
tags:
 - c++
 - templates
---

It can sometimes be useful to check if some expression is a constant expression, i.e. computable at compile-time. This allows us to diagnose issues at compile time if possible, or to percolate information down to other functions to help the compiler optimise. 

Say, for example, we have a class template like this:

{% highlight cpp %}
template <class T>
class Foo {
      //T::value must be positive      
};
{% endhighlight %}

We want to check that `T::value` is positive as soon as possible, so if it's a constant expression, we want to issue a compiler error if it doesn't fulfil our expectation. The following couple of template functions solve this problem:

{% highlight cpp %}
template <typename T, int N = T::value>
constexpr bool is_valid(int) {
    return N > 0;
}

template <typename T>
constexpr bool is_valid(...) {
    return true;
}
{% endhighlight %}

If `T::value` is a constant expression, `is_valid` will return whether or not it is positive. Otherwise it will unconditionally return `true`. This works through [SFINAE](http://en.cppreference.com/w/cpp/language/sfinae); if `T::value` is not a constant expression, then `int N = T::value` in a template parameter is ill-formed and that first overload is removed from the candidate set. This allows us to write the following:

{% highlight cpp %}
static_assert(is_valid<T>(0), "T::value must be positive");
{% endhighlight %}

That `static_assert` will fail only if `T::value` is known to be negative at compile-time, then we can have a standard runtime `assert` or some other form to check it at runtime if necessary.



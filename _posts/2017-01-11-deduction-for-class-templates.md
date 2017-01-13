---
layout:     post
title:      "Template argument deduction for class template constructors"
category:   c++
tags:
 - c++
 - c++17
---

Have you ever found yourself writing `std::make_pair` or `std::make_move_iterator` and wondering why we need a helper function to create these objects for us? The answer is a lack of template argument deduction for class template constructors. Consider a simple `pair` class:

{% highlight cpp %}
template <typename T, typename U>
struct pair {
    T t;
    U u;

    pair (const T& t, const U& u) : t{t}, u{u} {}
};
{% endhighlight %}

Since there's no argument deduction for that constructor, we need to explicitly specify the template arguments when constructing the `pair`, like `pair<int,float> a {0, 42.42};`. It would be handy to be able to write `pair a {0, 42.42};`, but that's not currently possible. The common solution is to supply a helper function which does the deduction for you:

{% highlight cpp %}
template <typename T, typename U>
pair<T,U> make_pair (const T& t, const U& u) {
    return {t,u};
}
{% endhighlight %}

Now we can write `auto p = make_pair(0, 42.42);`. However, this isn't a particularly attractive option. It means you have different ways of constructing class template specializations and normal classes, you'll often need to look at the documentation to see if it's doing anything other than constructing the object, non-copyable and non-moveable classes become a pain, etc. It would be better if we could just deduce the template arguments in the constructor.

Fortunately, this feature is coming in C++17! This will let us avoid the `make_` functions and just construct the objects directly:

{% highlight cpp %}
pair a{0, 42.42};
std::tuple t{"hi", 15, std::vector<int>{}};
{% endhighlight %}

This feature is supported through a new concept known as *deduction guides*, which tell the compiler how to deduce template arguments for the template class from the constructor arguments. These can be implicitly synthesized, or explicitly specified.

-----------------

### Implicitly synthesized deduction guides

Deduction guides can be generated from existing constructors without any programmer guidance, so long as they're simple enough.

A good rule of thumb is this: If all of your constructors' parameter lists include all of the class template parameters in deducible contexts, you don't need to do anything.

Take our `pair` example from earlier. The constructors for `pair` -- including the compiler-generated ones -- are as follows:

{% highlight cpp %}
template <typename T, typename U>
struct pair {
    pair (const T& t, const U& u);
    pair (const pair<T,U>&);
    pair (pair<T,U>&&);
};
{% endhighlight %}

In all three of those cases, both of the template arguments for `pair` (`T` and `U`) are deducible from the constructor parameters, so we don't need to do anything. The following code will work out-of-the-box[^1]:

[^1]: Of course, you could use `auto` for `b` and `c`, this is just for purposes of demonstration.

{% highlight cpp %}
pair a {0, 42.42};
pair b = a;
pair c = std::move(b);
{% endhighlight %}

If your class doesn't fulfil the criteria for implicit deduction guides and you still want to deduce the class template arguments automatically, you can give your compiler a bit of help.

-----------------

### Explicitly specified deduction guides

Deduction guides can be explicitly specified to tell the compiler how to work out the template arguments from the constructor arguments if they can't be simply matched together.

Say we have a simple `vector` class and want to construct a `vector` from the first three elements of another. We could do this:

{% highlight cpp %}
template <typename T>
struct vector {
    vector (std::initializer_list<T> a);
    
    template <typename Iter>
    vector (Iter start, Iter end);
    
    T* begin();
    T* end();
};

vector a({1,2,3,4,5,6,7}); // Uses implicit deduction guide
auto it = a.begin();
vector b(it, it+3);        // Implicit guide will not work
{% endhighlight %}

Looking back at my rule of thumb from before, the second constructor cannot deduce `T`, so we need to provide an explicit deduction guide. This looks like the following:

{% highlight cpp %}
template<typename Iter> 
vector(Iter b, Iter e) -> vector<typename std::iterator_traits<Iter>::value_type>;
{% endhighlight %}

The above deduction guide says that the constructor for `vector` taking two `Iter`s deduces the template argument to be `typename std::iterator_traits<Iter>::value_type`. For `int*`, that's just `int`. When the compiler sees `vector b(it, it+3);`, it instantiates the deduction guide with `int*` as the template argument, and deduces `vector<int>` as the type of `b`.

----------------

Does this mean that `make_` functions are useless? No.

Although this feature removes most of the need for these helpers, there are still some cases where you should prefer the `make_` function. Two of those are `std::make_unique` and `std::make_shared`. These helpers allow you to hide the use of bare `new`, improve your exception safety, and -- in the case of `std::make_shared` -- coalesce the allocations for the control block and pointee data.

Use template deduction for template classes in most cases, but be aware of edge cases and the few places in which `make_` helpers are the better choice.

---------------

That covers the basics of template argument deduction for class template constructors. If you want to read more, you can have a look at the [proposal for this feature](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/p0091r3.html). I think this is a welcome addition to C++ which removes another of the myriad pitfalls and inconsistencies in the language. Let me know in the comments if you agree or disagree!

----------------

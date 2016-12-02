---
layout:     post
title:      "Type erasure with unified call syntax"
summary:    Doing cool stuff with templates and type erasure.
category:   c++
minutes:    10
date:       2016-12-02
tags:
 - c++
 - templates
---


Type erasure bridges the gap between compile-time and runtime polymorphism. It allows us to generate code for a range of types without inheritance relationships at compile-time, then and choose between these behaviours at runtime. As a simple example:

{% highlight cpp %}
struct a { void foo(); }
struct b { void foo(); }

fooable f = a{};
foo(f);
f = b{};
foo(f);
{% endhighlight %}

Note that the only thing which connects `A` and `B` is that they expose the same interface. They don't inherit from each other, yet we can store either of them in this `fooable` type and call the relevant version of `foo`. There are no strange edge cases with this; it acts just as you would expect. We can happily return `fooable` objects from functions, pass them around, dynamically allocate them, whatever.

One example of this in the standard library is `std::function`. So long as you give it some object which can be called with the arguments specified and which returns the right type, you can store closures, function pointers, functors, anything.

{% highlight cpp %}
std::function<int()> f = [] { return 1; };

int foo() { return 2; };
f = foo();

struct bar { int operator()() { return 3; } }
f = bar{};
{% endhighlight %}

Of course, type erasure comes at a cost. Usually, you'll incur a dynamic allocation on construction and assignment, and virtual function call on using the type-erased object. As such, you should consider the trade-off between flexibility and performance for your application when type erasure is proposed.

Thus ends our crash-course in type erasure. Later in this post we'll be implementing a `fooable` class, but with support for *unified call syntax*. Before we put these two concepts together, I'll briefly explain what I mean by this term.

-------------------------------------

If we have a class `toddler` and want to write a function called `take_a_nap` which operates on it, we have two main options for our implementation: a member function or a non-member function.

{% highlight cpp %}
struct toddler {
    void take_a_nap(); //member function
};

void take_a_nap(const toddler&); //non-member function
{% endhighlight %}

If we declare it as a member function, we need to call it like `my_toddler.take_a_nap()`, and if we declare it as a non-member, we need to call it like `take_a_nap(my_toddler)`. You *cannot* use these two forms interchangeably, i.e. you can't call a member function like `take_a_nap(my_toddler)`, or a non-member function like `my_toddler.take_a_nap()`. Unified call syntax relaxes this constraint in some direction. [D](https://dlang.org/spec/function.html#pseudo-member)  allows you to write `my_toddler.take_a_nap()` even if `take_a_nap` is declared as a non-member, but not the other way around. [Rust](https://doc.rust-lang.org/beta/book/ufcs.html) allows non-member call syntax for members. A few proposals have been written for C++[^2][^3][^4][^5][^6][^7] but they have been rejected for now.

[^2]: [Unified Call Syntax Wording](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/p0251r0.pdf)
[^3]: [Wording for Unified Call Syntax](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/p0301r1.html)
[^4]: [Extension methods for C++](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0079r0.pdf)
[^5]: [Unified Call Syntax: `x.f(y)` and `f(x,y)`](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/n4474.pdf)
[^6]: [Unified call syntax concerns](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0131r0.pdf)
[^7]: [Call syntax: `x.f(y) vs. `f(x,y)`](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2014/n4174.pdf)

---------------------------------

Putting the two concepts together, by "type erasure with uniform call syntax", I mean allowing both non-member and member call syntax for types which supply either. An example with our `fooable` class from before:

{% highlight cpp %}
struct member {
    void foo();
};

struct non_member{};

void foo(const non_member&);

fooable member_erased {member{}};
foo(member_erased);
member_erased.foo();

fooable non_member_erased {non_member{}};
foo(non_member_erased);
non_member_erased.foo();
{% endhighlight %}

Note again that `member` and `non_member` are not related by inheritance, but this time they even declare `foo` in different ways. `fooable` does some magic which allows both of them to be called in either way.

Now for the magic.

-------------------------------

The usual way to do this kind of type erasure is to have some `storage` class with a pure virtual function, and a template class which inherits from `storage` and forwards the virtual call to the type-erased object.

{% highlight cpp %}
struct storage {
    virtual void docall() = 0;  
};

template <typename T>
struct storage_impl : storage {
    T m_t;
    
    storage_impl (T t) : m_t {std::move(t)} {}
    
    void docall() override {
        m_t.foo();
    }
};
{% endhighlight %}

Note that the above storage calls `foo` using the member syntax, so it won't work with the `non_member` class. I call the function `docall` rather than `foo`, because using the same name as the function we're trying to call will get us into trouble with argument dependent lookup when we try to support non-member syntax.

In `fooable`, we store a `std::unique_ptr` to `storage`, and forward our call to `foo` on to that pointee:

{% highlight cpp %}
class fooable {
public:
    void foo() { m_storage->docall(); }

private:
    std::unique_ptr<storage> m_storage;
};
{% endhighlight %}

The clever bit is the constructor to `fooable`. We make this a template, and dynamically allocate a `storage_impl<T>` based on what got passed in:

{% highlight cpp %}
    template <typename T>
    fooable (T t) 
        : m_storage {std::make_unique<storage_impl<T>>(std::move(t))}
    {}
{% endhighlight %}

When we construct a `fooable` with some `T`, `m_storage` will hold a `storage_impl<T>`. Calls to `foo` will be forwarded through `storage`, down to `storage_impl` through the virtual function, ending up at `T` through the implementation of `storage_impl<member>::foo`.

Supporting both ways of calling `foo` on `fooable` is pretty simple: we just add a non-member function which calls `m_storage->foo()`:

{% highlight cpp %}
    friend void foo(const fooable& f) { f.m_storage->foo(); }
{% endhighlight %}

Now both `my_fooable.foo()` and `foo(my_fooable)` are supported!

The tricky bit comes in supporting erasure of types with both declaration types. We'll need some template metaprogramming trickery for this.

-------------------------

First, we'll write a trait to check if a type has a member function called `foo`. I'll use [`std::void_t`](http://en.cppreference.com/w/cpp/types/void_t) from C++17, which you can trivially implement yourself for older versions[^1]:

{% highlight cpp %}
    template <typename T, typename=void>
    struct has_member_foo : std::false_type{};
    
    template <typename T>
    struct has_member_foo<T,std::void_t<decltype(std::declval<T>().foo())>> : std::true_type{};
{% endhighlight %}

This is a rather gorgeous/horrific trick which uses [expression SFINAE](http://stackoverflow.com/questions/12654067/what-is-expression-sfinae#12654277) to ignore the partial specialization when `my_t.foo()` is not a valid expression. If you don't understand it, have a look at [this StackOverflow answer](http://stackoverflow.com/questions/27687389/how-does-void-t-work#27688405), or just believe me that it works.

[^1]: The lib fundamentals v2 TS also has the [detection idiom](http://en.cppreference.com/w/cpp/experimental/is_detected) which abstracts this pattern.

We'll then write two versions of `storage_impl`: one for when the type has a `foo` member, and one for when it does not.

{% highlight cpp %}
template <typename T, bool HasMemberFoo = has_member_foo<T>::value>
struct storage_impl : storage {
   T m_t;
    
    storage_impl (T t) : m_t {std::move(t)} {}
    
    void docall() override {
        m_t.foo();
    }
};

template <typename T>
struct fooable::storage_impl<T,false> : storage {
    T m_t;
        
    storage_impl (T t) : m_t {std::move(t)} {}
    
    void docall() override {
        foo(m_t);
    }
};
{% endhighlight %}

The only difference between these two is that one uses member call syntax and the other uses non-member syntax. Keen readers may have noticed that if a type has both a member function and non-member function called `foo`, then this will prefer the member one. I think this is pretty reasonable; if you have two different functions operating on your type with the same set of arguments and they're not functionally equivalent, you have bigger problems.

Now we're done! The code [works](http://coliru.stacked-crooked.com/a/943c66d4f278b1bd) on both GCC and Clang.

-------

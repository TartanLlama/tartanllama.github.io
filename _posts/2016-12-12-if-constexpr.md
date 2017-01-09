---
layout:     post
title:      "Simplifying templates and #ifdefs with if constexpr"
category:   c++
date:       2016-12-12
tags:
 - c++
 - c++17
 - templates
---

### Introduction

`if constexpr` is a C++17 feature which allows conditionally compiling code based on template parameters in a clear and minimal fashion. It is essentially an `if` statement where the branch is chosen at compile-time, and any not-taken branches are discarded without being instantiated. An example:

{% highlight cpp %}
template <typename T>
auto get_value(T t) {
    if constexpr (std::is_pointer_v<T>)
        return *t;
    else
        return t;
}
{% endhighlight %}

The condition `std::is_pointer_v<T>` checks whether or not `T` is a pointer type. Either the `if` or `else` clause will be discarded *at compile-time* depending on how the condition evaluates. For example, `get_value<int>` is essentially equivalent to

{% highlight cpp %}
auto get_value(int t) {
    return t;
}
{% endhighlight %}

and `get_value<int*>` is essentially equivalent to

{% highlight cpp %}
auto get_value(int* t) {
    return *t;
}
{% endhighlight %}

This post will show how to use `if constexpr` to simplify your template code and replace horrible macro code.

----------------

### Simplifying template code

The major win from `if constexpr` is in writing code which is predicated on some trait of a template argument, without having to write verbose specializations. Consider our `get_value` example above. Without `if constexpr`, we would need to implement it using SFINAE or tag dispatching:

{% highlight cpp %}
// SFINAE
template <typename T, std::enable_if_t<std::is_pointer<T>{}>* = nullptr>
auto get_value(T t) {
    return *t;
}

template <typename T, std::enable_if_t<!std::is_pointer<T>{}>* = nullptr>
auto get_value(T t) {
    return t;
}

// Tag dispatching
template <typename T>
auto get_value(T t, std::true_type) {
    return *t;
}

template <typename T>
auto get_value(T t, std::false_type) {
    return t;
}

template <typename T>
auto get_value(T t) {
    return get_value(t, std::is_pointer<T>{}); 
}
{% endhighlight %}

Our `if constexpr` version is far more simple and understandable than the above:

{% highlight cpp %}
template <typename T>
auto get_value(T t) {
    if constexpr (std::is_pointer_v<T>) return *t;
    else return t;
}
{% endhighlight %}



Recursive templates are also much easier to specify[^3]:

[^3]: Although you'd be better off using [fold expressions](http://en.cppreference.com/w/cpp/language/fold) instead.

{% highlight cpp %}
// Without if constexpr
template <int N1>
auto sum() {
    return N1;
}

template <int N1, int N2, int... Ns>
auto sum() {
    return N1 + sum<N2,Ns...>();
}

// With if constexpr
template <int N, int... Ns>
auto sum() {
    if constexpr (sizeof...(Ns) == 0)
        return N;
    else
        return N + sum<Ns...>();
}
{% endhighlight %}

The benefits are particularly clear when the number of specialisations you'd otherwise need to write becomes larger. Say we want to add support for decomposition declarations to a class so that we can write `auto [a,b,c,d] = get_my_class();`. For that, we need to write specialisations of `get` for each index:

{% highlight cpp %}
class MyClass {
public:
    template <std::size_t N>
    auto get();

private: //don't want anyone messing with my insides
    int a;
    float b;
    std::string c;
    std::vector<int> d;
};

template <>
auto MyClass::get<0>() {
    return a;
}

template <>
auto MyClass::get<1>() {
    return b;
}

template <>
auto MyClass::get<2>() {
    return c;
}

template <>
auto MyClass::get<3>() {
    return d;
}
{% endhighlight %}

With `constexpr if`, we can write this all in a single template function:

{% highlight cpp %}
template <std::size_t N>
auto get() {
     if      constexpr (N == 0) return a;
     else if constexpr (N == 1) return b;
     else if constexpr (N == 2) return c;
     else if constexpr (N == 3) return d;
}
{% endhighlight %}

Not only is this a win in terms of lines of code, it also decreases syntactic noise and increases source code locality.

---------

### Replacing #ifdef blocks

Another great use-case of `constexpr if` is to replace horrible `#ifdef` blocks. Consider an application which needs to act in different ways depending on the operating system. Without `if constexpr` you could write the code like this:

{% highlight cpp %}
void do_something() {
     //do something general

     #ifdef __linux__
     //do something Linuxy
     #elif __APPLE__
     //do something Appley
     #elif __WIN32
     //do something Windowsy
     #endif

     //do something general
}
{% endhighlight %}

This kind of code could be splattered throughout your application[^1], making it look generally awful. With `if constexpr`, you could write this instead:

[^1]: Of course, this specific problem can often be fixed by designing wrappers for the functionality which hides the macros, but for small differences or other ad-hoc things, this kind of macro code is used quite often.

{% highlight cpp %}
enum class OS { Linux, Mac, Windows };

//Translate the macros to C++ at a single point in the application
#ifdef __linux__
constexpr OS the_os = OS::Linux;
#elif __APPLE__
constexpr OS the_os = OS::Mac;
#elif __WIN32
constexpr OS the_os = OS::Windows;
#endif

void do_something() {
     //do something general

     if constexpr (the_os == OS::Linux) {
         //do something Linuxy
     }
     else if constexpr (the_os == OS::Mac) {
         //do something Appley
     }
     else if constexpr (the_os == OS::Windows) {
         //do something Windowsy
     }

     //do something general
}
{% endhighlight %}

This technique replaces the macros with real C++ constructs and lets us write all of our conditionally-compiled code without relying on the preprocessor, which is A Good Thing&trade;. For one, if we misspell the enum name or something, we'll get a descriptive compiler error rather than things just breaking. Additionally, the `if constexpr` introduces a proper C++ scope, so any extra variables we declare in it will have their lifetimes limited to the OS-specific code.

One difference between the code with macros and the code with `if constexpr` is that the code in the `if constexpr` branches is parsed and has non-dependent names looked up, even when the condition fails (see the next section), so if you are using some OS-specific libraries in one of the blocks, then compilation will fail. This could be solved by providing declarations for the functions used, so you should consider which option is more maintainable for your use-case if the header files you include will be different depending on preprocessor definitions.

This technique could also be used for things like debugging or profiling code, by translating your relevant preprocessor definition to a `constexpr bool` or similar.

{% highlight cpp %}
#ifdef _DEBUG
constexpr bool debug_mode = true;
#else
constexpr bool debug_mode = false;
#endif

if constexpr (debug_mode) {
   //debug code
}
{% endhighlight %}

------

### Caveats

Before we finish, a couple of notes about subtleties of this feature. The use of `constexpr` in `if constexpr` is *not quite* equivalent to `constexpr` functions. `constexpr` functions can be executed at both compile-time *and* run-time, and this choice depends on the context in which they are called.

{% highlight cpp %}
constexpr auto max(int i, int j) {
     if (i >= j) return i;
     return j;
}

int main() {
    std::array<int, max(4,6)>{}; //max called at compile-time
    
    int i, j;
    std::cin >> i >> j;
    std::cout << max(i,j);       //max called at run-time
}
{% endhighlight %}

In the above code, the first call to `max` is used as a template argument, so is executed at compile-time, whereas the second call cannot be known at compile-time, so is called at run-time.

The condition for an `if constexpr` is *always* executed at compile-time. As such, you can only put constant expressions in the condition.

Note also that although any not-taken branches are discarded, they still need to be valid for some instantiation, otherwise the code is ill-formed. For example, you can't write nonsense in a never-taken branch:

{% highlight cpp %}
void do_something() {
     if constexpr (true) {
         std::cout << "I am sensible";
     }
     else {
       I AM A BANANA //fails to compile
     }
}
{% endhighlight %}

Nor can you put in a `static_assert(false,...)`, just like with normal template specializations[^2]:

[^2]: You can use the usual [`dependent_false`](http://stackoverflow.com/a/25654759/496161) workaround to solve this. 

{% highlight cpp %}
template <typename T>
void do_something() {
     if constexpr (std::is_arithmetic_v<T>) {
         //do some maths
     }
     else {
       static_assert(false, "Must be arithmetic"); //invalid for all specializations
     }
}
{% endhighlight %}

One last point of interest is that you need to be sure to look after your `else` blocks. In runtime code, it's pretty common to write this:

{% highlight cpp %}
int foo() {
    if (condition())
        return 1;

    // No else block, just an unconditional return    
    return 2;
}
{% endhighlight %}

The above pattern does not work with `if constexpr` in some cases. Consider a modified version of our original example:

{% highlight cpp %}
template <typename T>
auto get_value(T t) {
    if constexpr (std::is_pointer_v<T>)
        return *t;

    return t;
}
{% endhighlight %}

The above code will not compile, if `T` is a pointer, because the second return statement will not be discarded, so there will be two return statements which return objects with different types. In such a case, you need to make sure you wrap that last statement in an `else` block.

-------

We're done! If you want to try out `constexpr if`, it is currently supported in [Clang 3.9](http://clang.llvm.org/cxx_status.html) and [GCC 7](https://gcc.gnu.org/projects/cxx-status.html). I think that this feature will clean up generic programming significantly and should make anyone decrying the lack of new C++17 features think twice.

-------

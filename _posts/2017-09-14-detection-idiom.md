---
layout:     post
title:      "Detection Idiom - A Stopgap for Concepts"
category:   c++
tags:
 - c++
---

[Concepts](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/n4641.pdf) is a proposed C++ feature which allows succinct, expressive, and powerful constraining of templates. They have been threatening to get in to C++ for a long time now, with the first proposal being rejected for C++11. They were finally [merged in to C++20](https://herbsutter.com/2017/07/15/trip-report-summer-iso-c-standards-meeting-toronto/) a few months ago, which means we need to hold on for another few years before they're in the official standard rather than a [Technical Specification](https://stackoverflow.com/questions/21342077/what-is-c-technical-specification). In the mean time, there have been various attempts to implement parts of concepts as a library so that we can have access to some of the power of Concepts without waiting for the new standard. The [detection idiom](http://en.cppreference.com/w/cpp/experimental/is_detected), which is part of the [Library Fundamentals 2 Technical Specification](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/n4617.pdf), is one such solution. This post will outline the utility of it, and show the techniques which underlie its implementation.

------------------

### A problem

We are developing a generic library. At some point on our library we need to calculate the `foo` factor for whatever types the user passes in.

{% highlight cpp %}
template <class T>
int calculate_foo_factor (const T& t);
{% endhighlight %}

Some types will have specialized implementations of this function, but for types which don't we'll need some generic calculation.

{% highlight cpp %}
struct has_special_support {
  int get_foo() const;
};

struct will_need_generic_calculation {
  // no get_foo member function
};
{% endhighlight %}

Using concepts we could write `calculate_foo_factor` like so:

{% highlight cpp %}
template <class T>
concept bool SupportsFoo = requires (T t) {
  { t.get_foo() } -> int;
};

template <SupportsFoo T>
int calculate_foo_factor (const T& t) {
    return t.get_foo();
}

template <class T>
int calculate_foo_factor (const T& t) {
    // insert generic calculation here
    return 42;
}
{% endhighlight %}

This is quite succinct and clear: `SupportsFoo` is a concept which checks that we can call `get_foo` on `t` with no arguments, and that the type of that expression is `int`. The first `calculate_foo_factor` will be selected by overload resolution for types which satisfy the `SupportsFoo` concept, and the second will be chosen for those which don't.

Unfortunately, our library has to support C++14. We'll need to try something different. I'll demonstrate a bunch of possible solutions to this problem in the next section. Some of them may seem complex if you aren't familiar with the metaprogramming techniques used, but for now, just note the differences in complexity and abstraction between them. The metaprogramming tricks will all be explained in the following section.

### Solutions

Here's a possible solution using [expression SFINAE](https://stackoverflow.com/questions/12654067/what-is-expression-sfinae):

{% highlight cpp %}
namespace detail {
  template <class T>
  auto calculate_foo_factor (const T& t, int)
    -> decltype(std::declval<T>().get_foo()) {
    return t.get_foo();
  }

  template <class T>
  int calculate_foo_factor (const T& t, ...) {
    // insert generic calculation here
    return 42;
  }
}

template <class T>
int calculate_foo_factor (const T& t) {
  return detail::calculate_foo_factor(t, 0);
}
{% endhighlight %}

Well, it works, but it's not exactly clear. What's the `int` and `...` there for? What's `std::declval`? Why do we need an extra overload? The answers are not the important part here; what is important is that unless you've got a reasonable amount of metaprogramming experience, it's unlikely you'll be able to write this code offhand, or even copy-paste it without error.

The code could be improved by abstracting out the check for the presence of the member function into its own metafunction:

{% highlight cpp %}
template <class... Ts>
using void_t = void;

template <class T, class=void>
struct supports_foo : std::false_type{};

template <class T>
struct supports_foo<T, void_t<decltype(std::declval<T>().get_foo())>>
: std::true_type{};
{% endhighlight %}

Again, some more expert-only template trickery which I'll explain later. Using this trait, we can use [`std::enable_if`](http://en.cppreference.com/w/cpp/types/enable_if) to enable and disable the overloads as required:

{% highlight cpp %}
template <class T, std::enable_if_t<supports_foo<T>::value>* = nullptr>
auto calculate_foo_factor (const T& t) {
  return t.get_foo();
}

template <class T, std::enable_if_t<!supports_foo<T>::value>* = nullptr>
int calculate_foo_factor (const T& t) {
  // insert generic calculation here
  return 42;
}
{% endhighlight %}

This works, but you'd need to understand how to implement `supports_foo`, and you'd need to repeat all the boilerplate again if you needed to write a `supports_bar` trait. It would be better if we could completely abstract away the mechanism for detecting the member function and just focus on _what_ we want to detect. This is what the detection idiom provides.

{% highlight cpp %}
template <class T>
using foo_t = decltype(std::declval<T>().get_foo());

template <class T>
using supports_foo = is_detected<foo_t,T>;
{% endhighlight %}

`is_detected` here is part of the detection idiom. Read it as "is it valid to instantiate `foo_t` with `T`?" `std::declval<T>()` essentially means "pretend that I have a value of type `T`" (more on this later). This still requires some metaprogramming magic, but it's a whole lot simpler than the previous examples. With this technique we can also easily check for the validity of arbitrary expressions:

{% highlight cpp %}
template <class T, class U>
using equality_t = decltype(std::declval<T>() == std::declval<U>());

template <class T, class U>
using supports_equality = is_detected<equality_t, T, U>;

struct foo{};
struct bar{};
struct baz{};

bool operator== (foo, bar);

static_assert( supports_equality<foo,bar>::value, "wat");
static_assert(!supports_equality<foo,baz>::value, "wat");
{% endhighlight %}

We can also compose traits using [`std::conjunction`](http://en.cppreference.com/w/cpp/types/conjunction):

{% highlight cpp %}
template <class T>
using is_regular = std::conjunction<std::is_default_constructible<T>,
                                    std::is_copy_constructible<T>,
                                    supports_equality<T,T>,
                                    supports_inequality<T,T>, //assume impl
                                    supports_less_than<T,T>>; //ditto
{% endhighlight %}

If you want to use `is_detected` today, then you can check if your standard library supports `std::experimental::is_detected`. If not, you can use the implementation from [cppreference](http://en.cppreference.com/w/cpp/experimental/is_detected) or the one which we will go on to write in the next section. If you aren't interested in how this is written, then turn back, for here be metaprogramming dragons.

-------------------------

### Metaprogramming demystified

I'll now work backwards through the metaprogramming techniques used, leading up to implementing `is_detected`.

#### Type traits and `_v` and `_t` suffixes

A type trait is some template which can be used to get information about characteristics of a type. For example, you can find out if some type is an arithmetic type using `std::is_arithmetic`:

{% highlight cpp %}
template <class T>
void foo(T t) {
     static_assert(std::is_arithmetic<T>::value, "Argument must be of an arithmetic type");
}
{% endhighlight %}

Type traits either "return" types with a `::type` member alias, or values with a `::value` alias. `_t` and `_v` suffixes are shorthand for these respectively. So `std::is_arithmetic_v<T>` is the same as `std::is_arithmetic<T>::value`, `std::add_pointer_t<T>` is the same as `typename std::add_pointer<T>::type`[^1].

[^1]: See [here](https://stackoverflow.com/questions/610245/where-and-why-do-i-have-to-put-the-template-and-typename-keywords) for information on why the `typename` keyword is needed in some places.

#### `decltype` specifiers

[`decltype`](http://en.cppreference.com/w/cpp/language/decltype) gives you access to the type of an entity or expression. For example, with `int i;`, `decltype(i)` is `int`.

#### `std::declval` trickery

[`std::declval`](http://en.cppreference.com/w/cpp/utility/declval) is a template function which helps create values inside `decltype` specifiers. `std::declval<foo>()` essentially means "pretend I have some value of type `foo`". This is needed because the types you want to inspect inside `decltype` specifiers may not be default-constructible. For example:

{% highlight cpp %}
struct foo {
    foo() = delete;
    foo(int);
    void do_something();
};

decltype(foo{}.do_something())               // invalid
decltype(std::declval<foo>().do_something()) // fine
{% endhighlight %}

#### SFINAE and `std::enable_if`

[SFINAE](http://en.cppreference.com/w/cpp/language/sfinae) stands for Substitution Failure Is Not An Error. Due to this rule, some constructs which are usually hard compiler errors just cause a function template to be ignored by overload resolution. `std::enable_if` is a way to gain easy access to this. It takes a boolean template argument and either contains or does not contain a `::type` member alias depending on the value of that boolean. This allows you to do things like this:

{% highlight cpp %}
template <class T>
std::enable_if_t<std::is_integral_v<T>> foo(T t);

template <class T>
std::enable_if_t<std::is_floating_point_v<T>> foo(T t);
{% endhighlight %}

If `T` is integral, then the second overload will be SFINAEd out, so the first is the only candidate. If `T` is floating point, then the reverse is true.

#### Expression SFINAE

[Expression SFINAE](https://stackoverflow.com/questions/12654067/what-is-expression-sfinae) is a special form of SFINAE which applies to arbitrary expressions. This is what allowed this example from above to work:

{% highlight cpp %}
namespace detail {
  template <class T>
  auto calculate_foo_factor (const T& t, int)
    -> decltype(std::declval<T>().to_foo()) {
    return t.get_foo();
  }

  template <class T>
  int calculate_foo_factor (const T& t, ...) {
    // insert generic calculation here
    return 42;
  }
}

int calculate_foo_factor (const T& t) {
  return calculate_foo_factor(t, 0);
}
{% endhighlight %}

The first overload will be SFINAEd out if calling `to_foo` on an instance of `T` is invalid. The difficulty here is that *both* overloads will be valid if the `too_foo` call is valid. For this reason, we add some dummy parameters to the overloads (`int` and `...`) to specify an order for overload resolution to follow[^2].

[^2]: Have a look [here](https://github.com/rmartinho/flamingdangerzone/blob/master/_posts/cxx11/2013-03-11-overload-ranking.md) for a better way to do this.

#### `void_t` magic

[`void_t`](http://en.cppreference.com/w/cpp/types/void_t) is a C++17 feature (although it's implementable in C++11) which makes writing traits and using expression SFINAE a bit easier. The implementation is deceptively simple[^3]:

{% highlight cpp %}
template <class... Ts>
using void_t = void;
{% endhighlight %}

[^3]: Due to standards defect [CWG1558](http://open-std.org/JTC1/SC22/WG21/docs/cwg_defects.html#1558), implementations needed an extra level of abstraction to work on some compilers.

You can see this used in this example which we used above:

{% highlight cpp %}
template <class T, class=void>
struct supports_foo : std::false_type{};

template <class T>
struct supports_foo<T, void_t<decltype(std::declval<T>().get_foo())>>
: std::true_type{};
{% endhighlight %}

The relevant parts are the `class=void` and `void_t<...>`. If the expression inside `void_t` is invalid, then that specialization of `supports_foo` will be SFINAEd out, so the primary template will be used. Otherwise, the whole expression will be evaluated to `void` due to the `void_t` and this will match the `=void` default argument to the template. This gives a pretty succinct way to check arbitrary expressions.

That covers all of the ingredients we need to implement `is_detected`.

#### The implementation

For sake of simplicity I'll just implement `is_detected` rather than all of the entities which the Lib Fundamentals 2 TS provides.

{% highlight cpp %}
namespace detail {
  template <template <class...> class Trait, class Enabler, class... Args>
  struct is_detected : std::false_type{};

  template <template <class...> class Trait, class... Args>
  struct is_detected<Trait, void_t<Trait<Args...>>, Args...> : std::true_type{};
}

template <template <class...> class Trait, class... Args>
using is_detected = typename detail::is_detected<Trait, void, Args...>::type;
{% endhighlight %}        

Let's start with that last alias template. We take a variadic template template parameter (yes really) called `Trait` and any number of other type template arguments. We forward these to our `detail::is_detected` helper with an extra `void` argument which will act as the `class=void` construct from the previous section on `void_t`[^4]. We then have a primary template which will "return" false as the result of the trait. The magic then happens in the following partial specialization. `Trait<Args...>>` is evaluated inside `void_t`. If instantiating `Traits` with `Args...` is invalid, then the partial specialization will be SFINAEd out, and if it's valid, it'll evaluate to `void` due to the `void_t`. This successfully abstracts away the implementation of the detection and allows us to focus on what we want to detect.

------------

That covers it for the detection idiom. This is a handy utility for clearing up some hairy metaprogramming, and is even more useful since it can be implemented in old versions of the standard. Let me know if there are any other parts of the code you'd like explained down in the comments or on [Twitter](https://twitter.com/TartanLlama).

------------

[^4]: The reason we can't use the same trick is that parameter packs must appear at the *end* of the template parameter list, so we need to put the `void` in the middle.

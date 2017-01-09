---
layout:     post
title:      "Selective default template arguments"
category:   c++
minutes:       10
tags:
 - c++
 - templates
---

### Introduction

When writing code which relies heavily on templates for choosing functionality at compile time (e.g. using [Policy-Based Design](https://en.wikipedia.org/wiki/Policy-based_design)), it is important to find a sweet spot between flexibility and expressibility. These techniques can often be highly generic, but incredibly verbose and syntactically noisy. Consider the following:

{% highlight cpp %}
template<typename T0 = int, typename T1 = long, typename StringT = std::string>
struct Options;
{% endhighlight %}

This class has three template parameters to select specialised code for certain types. I've limited it to three for the sake of brevity, but there could be many more parameters than this. If client code just wants to use the defaults, then the code is very simple:

{% highlight cpp %}
Options<> defaults{};
{% endhighlight %}

It's also easy to specify arguments for all parameters, or for the first couple:

{% highlight cpp %}
Options<float, bool, std::wstring> wstring_options{};
Options<short> other_options{};
{% endhighlight %}

But what if we want to set just the last argument:

{% highlight cpp %}
Options<int, long, MyString> last_changed{};
{% endhighlight %}

In the above example, we still need to specify the first two arguments, even though we just want the defaults. This is a maintenance issue even with just three parameters, as all these uses of the template must be changed if the default arguments change. With more than three arguments it's even worse, and needlessly verbose to boot. What we would like is a flexible, generic, terse way to selectively change default arguments. Read on for a few possible solutions.

This post is based on answers from myself and others in [this StackOverflow question](http://stackoverflow.com/questions/29694299/explicitly-use-defaults-for-some-parameters-in-class-template-instantiation/29694738#29694738).

-----------------------------------

### Dummy tags

One option would be to use a dummy tag to stand in for the default, then choose the real template argument value based on whether it is equal to that dummy or not.

{% highlight cpp %}
struct use_default{};

template <typename T, typename Default>
using maybe_sub_default = std::conditional_t<std::is_same<T, use_default>::value, Default, T>; 

template <typename T0 = use_default, typename T1 = use_default, typename StringT = use_default>
struct Options {
    using RT0 = maybe_sub_default<T0, int>;
    using RT1 = maybe_sub_default<T1, long>;
    using RStringT = maybe_sub_default<StringT, std::string>;
};

Options<> a; //RT0 = int, RT1 = long, RStringT = std::string
Options<use_default, use_default, std::wstring> b; //RT0 = int, RT1 = long, RStringT = std::wstring
{% endhighlight %}

Pros:
{:.listhead}
- Easy to understand and implement.

Cons:
{:.listhead}
- `Options<>` and `Options<int, long, std::string>` are different types.
- `use_default` has to be repeated quite a lot.
- Can't tell the default arguments by looking at the template declaration.
- Requires significantly altering the class

-----------------------------------

### Manual member aliases

Another option is to provide member alias templates which handle modifying the template arguments.

{% highlight cpp %}
template <typename T0 = int, typename T1 = long, typename StringT = std::string>
struct Options {
    template <typename T> 
    using WithT0 = Options<T, T1, StringT>;

    template <typename T>
    using WithT1 = Options<T0, T, StringT>;

    template <typename T>
    using WithStringT = Options<T0, T1, T>;
};

Options<>::WithT0<double> a; //Options<double,long,std::string>
Options<>::WithT1<float>::WithStringT<std::wstring> b; //Options<int,float,std::wstring>
{% endhighlight %}

Pros:
{:.listhead}
- Very terse usage.
- Default arguments are in the declaration.

Cons:
{:.listhead}
- Requires significantly altering the class.
- Need to repeat the other arguments in all the `WithX` alias templates.

---------------------------------

### Don't touch my class

It would be good to have a solution which doesn't require heavily altering the class (especially when there are many parameters). The following code is pretty complex, but does the job (you could use your favourite metaprogramming library to make it more simple).


{% highlight cpp %}
namespace detail {
    //given an index to replace at, a type to replace with and a tuple to replace in
    //return a tuple of the same type as given, with the type at ReplaceAt set to ReplaceWith
    template <size_t ReplaceAt, typename ReplaceWith, size_t... Idxs, typename... Args>
    auto replace_type (std::index_sequence<Idxs...>, std::tuple<Args...>)
        -> std::tuple<std::conditional_t<ReplaceAt==Idxs, ReplaceWith, Args>...>;

    //instantiates a template with the types held in a tuple
    template <template <typename...> class T, typename Tuple>
    struct type_from_tuple;

    template <template <typename...> class T, typename... Ts>
    struct type_from_tuple<T, std::tuple<Ts...>>
    {
        using type = T<Ts...>;
    };

    //replaces the type used in a template instantiation of In 
    //at index ReplateAt with the type ReplaceWith
    template <size_t ReplaceAt, typename ReplaceWith, class In>
    struct with_n;

    template <size_t At, typename With, template <typename...> class In, typename... InArgs>
    struct with_n<At, With, In<InArgs...>>
    {
        using tuple_type = decltype(replace_type<At,With>
                (std::index_sequence_for<InArgs...>{}, std::tuple<InArgs...>{}));

        using type = typename type_from_tuple<In,tuple_type>::type;
    };
}

//convenience alias
template <size_t ReplaceAt, typename ReplaceWith, class In>
using with_n = typename detail::with_n<ReplaceAt, ReplaceWith, In>::type;

with_n<0, float, Options<>> a; //Options<float, int, std::string>
with_n<2, std::wstring, 
   with_n<0, float, Options<>>> b; //Options<float, int, std::wstring>
{% endhighlight %}

Pros:
{:.listhead}
- Doesn't require changing the class.
- Little repetition

Cons:
{:.listhead}
- Syntax isn't as nice as the previous solution.

--------------------------------

### Frankenstien

What we really want is a solution which combines the advantages of the above two options. We can achieve this by wrapping `with_n` in a template class and inheriting from it.


{% highlight cpp %}
template <typename T>
struct EnableDefaultSetting {
    template <size_t ReplaceAt, typename ReplaceWith>
    using with_n = typename detail::with_n<ReplaceAt, ReplaceWith, T>::type;
     
    //Some convenience helpers (optional)
    template <typename ReplaceWith> using with_0 = with_n<0, ReplaceWith>;
    template <typename ReplaceWith> using with_1 = with_n<1, ReplaceWith>;
    template <typename ReplaceWith> using with_2 = with_n<2, ReplaceWith>;
    template <typename ReplaceWith> using with_3 = with_n<3, ReplaceWith>;
    template <typename ReplaceWith> using with_4 = with_n<4, ReplaceWith>;
};

template<typename T0 = int, typename T1 = long, typename StringT = std::string>
struct Options : EnableDefaultSetting<Options<T0,T1,StringT>>{/*...*/};

Options<>::with_n<0, float> a; //Options<float, int, std::string>
Options<>::with_0<float>::with_2<std::wstring> b; //Options<float, int, std::wstring>
{% endhighlight %}

Pros:
{:.listhead}
- Terse syntax.
- Adding support only requires inheriting from a type.

Cons:
{:.listhead}
- Traits don't have descriptive names.
- Requires modifying the class.

--------------------------------

If you find yourself needing this functionality, hopefully one of the above solutions works for you. Feel free to suggest others in the comments below.

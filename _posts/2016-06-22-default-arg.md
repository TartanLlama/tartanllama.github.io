---
layout:     post
title:      "Selective default template arguments"
data:       2016-06-2016
summary:    A flexible way to chose default template arguments.
category:   c++
minutes: 20
draft:      true
tags:
 - c++
 - templates
---


When writing code which relies heavily on templates for choosing functionality at compile time (e.g. using [Policy-Based Design](https://en.wikipedia.org/wiki/Policy-based_design)), it is important to find a sweet spot between flexibility and expressibility. These techniques can often be highly generic, but incredibly verbose and syntactically noisy. Consider the following:

{% highlight cpp %}
template<typename T0 = int, typename T1 = long, typename StringT = std::string>
struct Options;
{% endhighlight %}

This class has three template parameters to select gnerate specialised code for certain types. I've limited it to three for the sake of brevity, but there could be many more parameters than this. Client code wil be very simple if it just wants to use the defaults:

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

In the above example, we still need to specify the first two arguments, even though we just want the defaults. This is a maintenance issue even with just three parameters, as all these uses of the template must be changed if the default arguments change. With more than three arguments it's even worse, and needlessly verbose to boot. What we would like is a flexible, generic, terse way to selectively change default arguments. This post will outline a few different possibilities.

This post is based on answers from myself and others in [this StackOverflow question](http://stackoverflow.com/questions/29694299/explicitly-use-defaults-for-some-parameters-in-class-template-instantiation/29694738#29694738).

-----------------------------------

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
- Easy to understand and implement.

Cons:
- `Options<>` and `Options<int, long, std::string>` are different types.
- `use_default` has to be repeated quite a lot.
- Can't tell the default arguments by looking at the template declaration.

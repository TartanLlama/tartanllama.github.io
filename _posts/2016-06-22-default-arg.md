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

This post is based on answers from myself and others in [this StackOverflow question](http://stackoverflow.com/questions/29694299/explicitly-use-defaults-for-some-parameters-in-class-template-instantiation/29694738#29694738).

When writing code which relies heavily on templates for choosing functionality at compile time (e.g. using [Policy-Based Design](https://en.wikipedia.org/wiki/Policy-based_design)), it is important to find a sweet spot between flexibility and expressibility. These techniques can often be highly generic, but incredibly verbose and syntactically noisy. Consider the following:

{% highlight cpp %}
template<typename UnderlyingT0 = int, typename UnderlyingtT1 = long, typename StringT = std::string>
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

In the above example, we still need to specify the first two arguments, even though we just want the defaults.

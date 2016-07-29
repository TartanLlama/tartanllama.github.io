---
layout:     post
title:      "Check if something is constexpr"
date:       2016-07-29
summary:    Template trickery
category:   c++
draft: true
tags:
 - c++
 - templates
---

{% highlight cpp %}
template <typename T, int N = T::value>
constexpr bool is_valid(int) {
    return N > 0;
}

template <typename T>
constexpr bool is_valid(...) {
    return true;
{% endhighlight %}

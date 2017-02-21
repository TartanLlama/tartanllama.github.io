---
layout:     post
title:      "Template friends functions of template classes"
category:   c++
tags:
 - c++
 - c++17
---

{% highlight cpp %}
template <typename T, int M, int N>
struct signal;

template <typename T, int AM, int AN, int BM, int BN>
bool operator==(const signal<T,AM,AN>& lhs, const signal<T,BM,BN>& rhs);

template <typename T, int M, int N>
struct signal {
  template <typename U, int AM, int AN, int BM, int BN>
    friend bool operator==(const signal<U,AM,AN>& lhs, const signal<U,BM,BN>& rhs);
    private:
      T t;
      };

template <typename T, int AM, int AN, int BM, int BN>
bool operator==(const signal<T,AM,AN>& lhs, const signal<T,BM,BN>& rhs) {
    return lhs.t == rhs.t;
    } 
{% endhighlight %}

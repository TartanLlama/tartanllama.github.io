---
layout:     post
title:      "std::accumulate vs. std::reduce"
category:   c++
tags:
 - c++
 - c++17
---

[`std::accumulate`](http://en.cppreference.com/w/cpp/algorithm/accumulate) has been a part of the standard library since C++98. It provides a way to fold some operator (such as addition) over an iterator range, reducing the elements into one value at the end. [`std::reduce`](http://en.cppreference.com/w/cpp/algorithm/reduce) was added in C++17 and looks remarkably similar. This post will explain the difference between the two and when to use one or the other.

{% highlight cpp %}
template< class InputIt, class T >
T accumulate( InputIt first, InputIt last, T init );

template< class InputIt, class T, class BinaryOperation >
T accumulate( InputIt first, InputIt last, T init,
              BinaryOperation op );
{% endhighlight %}

{% highlight cpp %}
template<class InputIt>
typename std::iterator_traits<InputIt>::value_type reduce(
    InputIt first, InputIt last);

template<class ExecutionPolicy, class ForwardIt>
typename std::iterator_traits<ForwardIt>::value_type reduce(
    ExecutionPolicy&& policy,
    ForwardIt first, ForwardIt last);

template<class InputIt, class T>
T reduce(InputIt first, InputIt last, T init);

template<class ExecutionPolicy, class ForwardIt, class T>
T reduce(ExecutionPolicy&& policy,
         ForwardIt first, ForwardIt last, T init);

template<class InputIt, class T, class BinaryOp>
T reduce(InputIt first, InputIt last, T init, BinaryOp binary_op);

template<class ExecutionPolicy, class ForwardIt, class T, class BinaryOp>
T reduce(ExecutionPolicy&& policy,
         ForwardIt first, ForwardIt last, T init, BinaryOp binary_op);
{% endhighlight %}

![accumulate plus](/assets/reduce/fig1.png)
![reduce plus](/assets/reduce/fig2.png)
![accumulate minus](/assets/reduce/fig3.png)
![reduce minus](/assets/reduce/fig4.png)

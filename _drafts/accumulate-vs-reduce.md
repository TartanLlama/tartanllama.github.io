---
layout:     post
title:      "std::accumulate vs. std::reduce"
category:   c++
tags:
 - c++
 - c++17
---

[`std::accumulate`](http://en.cppreference.com/w/cpp/algorithm/accumulate) has been a part of the standard library since C++98. It takes a range of iterators along with an initial element and sums up all of the values in the range. You can also supply a binary operation to use instead of summation in order to do arbitrary [left folds](https://en.wikipedia.org/wiki/Fold_%28higher-order_function%29). [`std::reduce`](http://en.cppreference.com/w/cpp/algorithm/reduce) was added in C++17 and looks rermarkably similar. This post will explain the difference between the two and when to use one or the other.

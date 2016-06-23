---
layout:     post
title:      "Stack and Heap: Commonly Abused Terms"
data:       2016-06-2016
summary:    Stop abusing "stack" and "heap".
category:   c++
minutes: 20
draft:      true
tags:
 - c++
 - rants
---

The terms "stack" and "heap" are often used in C++ writings incorrectly. Stop it.

-----------

Have a look at the following code sample and have a think about where the variables are stored. Write down the answers if you feel like it.

{% highlight cpp %}
static int a;
static int b = 4;

void foo (int c) {
	int d = 42;
}

int main() {
	auto e = new int{314};
	foo(*e);
}
{% endhighlight %}
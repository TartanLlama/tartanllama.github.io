---
layout:     post
title:      "C++ Dark Corners: Declaring classes in funtion declarations"
data:       2016-06-2016
summary:    Don't do this.
category:   c++
minutes: 20
draft:      true
tags:
 - c++
---

C++ allows you to declare classes in function declarations. The following code is fully standards-compliant:

{% highlight cpp %}
void foo (class A*){}

A* g_a;

int main() {
	A* a;
	foo(a)
}
{% endhighlight %}
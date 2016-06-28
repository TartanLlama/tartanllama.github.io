---
layout:     post
title:      "You can't call a constructor in C++"
data:       2016-06-2016
summary:    Stop saying that.
category:   c++
minutes: 20
draft:      true
tags:
 - c++ 
 - rant
---

You can not directly call a constructor in C++.

{% highlight cpp %}
struct Foo{};

int main() {
	auto f1 = Foo(); //not a constructor call
	auto f2 = Foo{}; //not a constructor call
	new (&f2) Foo(); //not a constructor call
}
{% endhighlight %}

None of these are constructor calls. You can not call a constructor in C++.

-----------------

Okay, enough with empty statements, here's the proof.

> Constructors do not have names.
{:.standards}

The common follow-up question is "well, how come we can define them?"

> A special declarator syntax is used to declare or define the constructor.
{:.standards}

So if `Foo()` is not a constructor call, what is it? The standard calls this an explicit type conversion with functional notation.

> The expression `T()`, where `T` is a *simple-type-specifier* or *typename-specifier* for a non-array complete object
type or the (possibly cv-qualified) `void` type, creates a prvalue of the specified type, which is *value-initialized*
(8.5; no initialization is done for the `void()` case).
{:.standards}

`Foo{}` is similarly defined:

> Similarly, a simple-type-specifier or typename-specifier followed by a braced-init-list creates a temporary
object of the specified type direct-list-initialized (8.5.4) with the specified braced-init-list, and its value is
that temporary object as a prvalue.
{.standards}

I've seen people say that placement `new` *only* calls the constructor, unlike the other two, which also require the allocation of temporaries. But that's not true. Consider this code:

{% highlight cpp %}
#include <iostream>

struct Foo {
    void* operator new (std::size_t count, void* ptr) {
        std::cout << "Doing something naughty\n";
        return ptr;   
    }
};

int main() {
    Foo foo;
    new (&foo) Foo;
}
{% endhighlight %}

That certainly does more than just call the `Foo` constructor. And even if it didn't, the constructor call is still a small part of a more complex form of expression.

-------------------

Hopefully you're now convinced that you can't directly call a constructor in C++. But maybe you're wondering what the point of writing a blog post about it is; perhaps this seems like an academic distinction. I disagree.


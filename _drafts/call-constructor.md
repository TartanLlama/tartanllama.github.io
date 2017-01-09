---
layout:     post
title:      "You can't call a constructor in C++"
category:   c++
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
{:.standards para="[class.ctor]/1"}

The common follow-up question is "well, how come we can define them?"

> A special declarator syntax is used to declare or define the constructor.
{:.standards para="[class.ctor]/1 (cont.)"}

So if `Foo()` is not a constructor call, what is it? The standard calls this an explicit type conversion with functional notation.

> The expression `T()`, where `T` is a *simple-type-specifier* or *typename-specifier* for a non-array complete object
type or the (possibly cv-qualified) `void` type, creates a prvalue of the specified type, which is *value-initialized*
(8.5; no initialization is done for the `void()` case).
{:.standards para="[expr.type.conv]/2"}

`Foo{}` is similarly defined:

> Similarly, a *simple-type-specifier* or *typename-specifier* followed by a *braced-init-list* creates a temporary
object of the specified type *direct-list-initialized* (8.5.4) with the specified *braced-init-list*, and its value is
that temporary object as a prvalue.
{:.standards para="[expr.type.conv]/3"}

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

Thinking of these forms as "calling a constructor" just breeds confusion. If you think that you can call a constructor, then you might also think that you can take a pointer to a constructor (you can't), or be confused as to why different initialization forms are syntactically different. A quick Stack Overflow search turns up a plethora of questions about these possibilities <sup>[1](http://stackoverflow.com/questions/33079486/difference-between-constructor-calls-with-and-without)[2](http://stackoverflow.com/questions/13102046/function-pointer-to-object-constructor)[3](http://stackoverflow.com/questions/11757150/syntax-for-pointers-to-constructors-in-c)[4](http://stackoverflow.com/questions/954548/how-to-pass-a-function-pointer-that-points-to-constructor)[5](http://stackoverflow.com/questions/9253619/c-cannot-call-constructor-directly)[7](http://stackoverflow.com/questions/2494471/c-is-it-possible-to-call-a-constructor-directly-without-new)[8](http://stackoverflow.com/questions/34085147/c-cannot-call-constructor-directly-in-small-example)</sup>.

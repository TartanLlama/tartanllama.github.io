---
layout:     post
title:      "void C::C::C::A::A::A::foo() - standards conformant"
date:       2016-07-29
summary:    Some strange syntax which is valid in C++
category:   c++
draft: true
tags:
 - c++ 
---

{% highlight cpp %}
class A {
public:
    virtual void foo() = 0;
};

class B {
public:
    virtual void foo() = 0;
};

class C : public A, public B {
public:
    virtual void foo();
};

void C::foo(){
  std::cout << "C" << std::endl;
}
void C::A::foo(){
  std::cout << "A" << std::endl;
}
void C::B::foo(){
  std::cout << "B" << std::endl;
}
{% endhighlight %}

> A *class-name* is inserted into the scope in which it is declared immediately after the *class-name* is seen. The *class-name* is also inserted into the scope of the class itself; this is known as the *injected-class-name*. For purposes of access checking, the *injected-class-name* is treated as if it were a public member name. [...]
{:.standards para="[class]/2"}

Since `A` is a base class of `C` and the name `A` is injected into the scope of `A`, `A` is also visible from `C`.

Given the above, we can do horribly perverse things like:

{% highlight cpp %}
void C::C::C::A::A::A::foo(){
    std::cout << "A" << std::endl;
}
{% endhighlight %}

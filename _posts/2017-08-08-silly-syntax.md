---
layout:     post
title:      "void C::C::C::A::A::A::foo() - valid syntax monstrosity"
category:   c++
tags:
 - c++
redirect_from:
  - /c++/2017/08/08/silly-syntax/
  - /silly-syntax.html
---

Here's an odd bit of C++ syntax for you. Say we have the following class hierarchy:

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
{% endhighlight %}

The following definitions are all well-formed:

{% highlight cpp %}
void C::foo(){
  std::cout << "C";
}
void C::A::foo(){
  std::cout << "A";
}
void C::B::foo(){
  std::cout << "B";
}
{% endhighlight %}

The first one defines `C::foo`, the second defines `A::foo` and the third defines `B::foo`. This is valid because of an entity known as the *injected-type-name*:

> A *class-name* is inserted into the scope in which it is declared immediately after the *class-name* is seen. The *class-name* is also inserted into the scope of the class itself; this is known as the *injected-class-name*. For purposes of access checking, the *injected-class-name* is treated as if it were a public member name. [...]
{:.standards para="[class]/2"}

Since `A` is a base class of `C` and the name `A` is injected into the scope of `A`, `A` is also visible from `C`.

The *injected-class-name* exists to ensure that the class is found during name lookup instead of entities in an enclosing scope. It also makes referring to the class name in a template instantiation easier. But since we're awful people, we can use this perfectly reasonable feature do horribly perverse things like this:

{% highlight cpp %}
void C::C::C::A::A::A::foo(){
    std::cout << "A";
}
{% endhighlight %}

Yeah, don't do that.

---
layout:     post
title:      "Initialization in C++ is bonkers"
summary:    It really is
category:   c++
tags:
 - c++ 
---

C++ pop quiz time: what are the values of `a.a` and `b.b` at the end of this program?

{% highlight cpp %}
#include <iostream>

struct foo {
    foo() = default;
    int a;
};

struct bar {
    bar();
    int b;
};

bar::bar() = default;

int main() {
    foo a{};
    bar b{};
    std::cout << a.a << ' ' << b.b;
}
{% endhighlight %}

The answer is that `a.a` is `0` and `b.b` is indeterminate, so reading it is undefined behaviour. Why? Because initialization in C++ is bonkers.

---------------------------

Okay, the real reason is that the way in which the constructors for `foo` and `bar` are declared changes the behaviour of the types. The relevant standards passages are down at the bottom of the page if you want them, but the jist is this:

Since the constructor for `foo` is defaulted on its first declaration, it is not technically *user-provided*. The constructor for `bar`, conversely, is only defaulted at its definition, which makes it user-provided. Put another way, if you don't want your constructor to be user-provided, be sure to write `=default` when you declare it rather than define it like that elsewhere. This rule makes sense when you think about it. A translation unit with access to only the declaration of the constructor can't know if your constructor is going to be a simple compiler-generated one or if it's going to send a telegram to the Moon to retrieve some data without having access to the definition. 

The default constructor being user-provided has a few consequences for the class type. For example, you can't default-initialize a const-qualified object if it lacks a user-provided constructor:

{% highlight cpp %}
const int my_int;            //ill-formed
const std::string my_string; //well-formed

const foo my_foo; //ill-formed
const bar my_bar; //well-formed
{% endhighlight %}

Additionally, in order to be trivial (and therefore POD) or an aggregate, a class must have no user-provided constructors. Don't worry if you don't know those terms, it suffices to know that whether your constructors are user-provided or not modifies some of the restrictions of what you can do with that class and how it acts.

For our first example, however, we're interested in how user-provided constructors interact with initialization rules. The relevant standards passages mandate that in this case, the type with the user-provided constructor is default-initialized and the type without is zero-initialized. Default-initialization for `bar` leaves `b` uninitialized, whereas zero-initialization (as you might imagine) sets `a` in `foo` to `0`. This is a very subtle distiction which has inadvertantly changed our program from executing safely and happily to summoning nasal demons/eating your cat/ordering pizza/your favourite undefined behaviour metaphor.

Fortunately, there's a simple solution:

**explicitly initialize your variables.**

<b style="font-size:34px;">Seriously.</b>

<b style="font-size:54px;">Do it.</b>

<b style="font-size:64px;">EXPLICITLY INITIALIZE YOUR GORRAM VARIABLES.</b>

If you still aren't convinced that C++ initialization rules are crazy-complex, take a minute to think of all the forms of initialization you can think of. My answers after the line.

--------------------

Done? How many did you come up with? In perusal of the standard, I counted *eighteen* different forms of initialization[^1]. Here they are with a short example/description:

[^1]: Feel free to debate that some of these are different flavours of initialization forms, or attributes of initialization rather than separate concepts, I don't really care, suffice to say there are a lot.

- default: `int i;`
- value: `int i{};`
- zero: `static int i;`
- constant: `static int i = some_constexpr_function();`
- static: zero- or constant-initialization
- dynamic: not static initialization
- ordered: dynamic initialization of non-local vars which are explicitly specialized class template static data members (yes really)
- unordered: same as ordered, but for other class template static data members
- non-trivial: when a class or aggregate is initialized by a non-trivial constructor
- direct: `int i{42}; int j(42);`
- copy: `int i = 42;`
- copy-list: `int i = {42};`
- direct-list: `int i{42};`
- list: either copy-list or direct-list
- aggregate: `int is[3] = {0,1,2};`
- reference: `const int& i = 42; auto&& j = 42;`
- implicit: default or value
- explicit: direct, copy, or list

Don't try to memorise all of these rules; therein lies madness. Just be careful, and keep in mind that C++'s initialization rules are there to pounce on you when you least expect it. Explicitly initialize your variables, and if you ever fall in to the trap of thinking C++ is a sane language, remember this:

**In C++, you can give your program undefined behaviour by changing the point at which you tell the compiler to generate something it was probably going to generate for you anyway.**

-------------------------

---
layout:     post
title:      "Initialization in C++ is bonkers"
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

#### Default-, value-, and zero-initialization

Before we get into the details which cause this, I'll introduce the concepts of default-, value- and zero-initialization. Feel free to skip this section if you're already familiar with these.

{% highlight cpp %}
T global;       //default initialization

void foo() {
    T i;         //default initialization
    T j{};       //value initialization (C++11)
    T k = T();   //value initialization
    T l = T{};   //value initialization (C++11)
    T m();       //function declaration

    new T;       //default initialization
    new T();     //value initialization
    new T{};     //value initialization (C++11)
}

struct A { T t; A() : t{} /*value initialization*/ {} };
struct B { T t; B() : t{} /*value initialization*/ {} };
struct C { T t; C()       /*default initialization*/ {} };
{% endhighlight %}

The rules for these different initialization forms are fairly complex, so I'll give a simplified outline of the C++11 rules. If you want to understand all the details of these forms, check out the relevant cppreference.com articles[^1][^2][^3], or see the standards quotes at the bottom of the article.

- **default-initialization** -- If `T` is a class, the default constructor is called; if it's an array, each element is default-initialized; otherwise, no initialization is done, resulting in indeterminate values.
- **value-initialization** -- If `T` is a class, the object is default-initialized (after being zero-initialized if `T`'s default constructor is compiler-generated); if it's an array, each element is value-initialized; otherwise, the object is zero-initialized.
- **zero-initialization** -- Applied to static and thread-local variables before any other initialization. If `T` is scalar (arithmetic, pointer, enum), it is initialized from `0`; if it's a class type, all base classes and data members are zero-initialized; if it's an array, each element is zero-initialized.

Taking the simple example of `int` as `T`, `global` and all of the value-initialized variables will have the value `0`, and all other variables will have an indeterminate value. Reading these indeterminate values results in undefined behaviour. 

[^1]: [cppreference value-initialization](http://en.cppreference.com/w/cpp/language/value_initialization)
[^2]: [cppreference default-initialization](http://en.cppreference.com/w/cpp/language/default_initialization)
[^3]: [cppreference zero-initialization](http://en.cppreference.com/w/cpp/language/zero_initialization)

--------------------------

#### Back to our original example

The real reason for the result of our original example is that the behaviours of `foo` and `bar` are changed by the different location of `=default` on their constructors. Again, the relevant standards passages are down at the bottom of the page if you want them, but the jist is this:

Since the constructor for `foo` is defaulted on its first declaration, it is not technically *user-provided* (don't worry about what this term means for now). The constructor for `bar`, conversely, is only defaulted at its definition, which makes it user-provided. Put another way, if you don't want your constructor to be user-provided, be sure to write `=default` when you declare it rather than define it like that elsewhere. This rule makes sense when you think about it: without having access to the definition of a constructor, a translation unit can't know if your constructor is going to be a simple compiler-generated one, or if it's going to send a telegram to the Moon to retrieve some data.

The default constructor being user-provided has a few consequences for the class type. For example, you can't default-initialize a const-qualified object if it lacks a user-provided constructor:

{% highlight cpp %}
const int my_int;            //ill-formed, no user-provided constructor
const std::string my_string; //well-formed, has a user-providedded constructor

const foo my_foo; //ill-formed, no user-provided constructor
const bar my_bar; //well-formed, has a user-providedded constructor
{% endhighlight %}

Additionally, in order to be [trivial](http://en.cppreference.com/w/cpp/concept/TrivialType) (and therefore [POD](http://en.cppreference.com/w/cpp/concept/PODType)) or an [aggregate](http://en.cppreference.com/w/cpp/language/aggregate_initialization), a class must have no user-provided constructors. Don't worry if you don't know those terms, it suffices to know that whether your constructors are user-provided or not modifies some of the restrictions of what you can do with that class and how it acts.

For our first example, however, we're interested in how user-provided constructors interact with initialization rules. The relevant standards passages mandate that in this case that the type with the user-provided constructor is default-initialized and the type without is zero-initialized. Default-initialization for `bar` leaves `b` uninitialized, whereas zero-initialization sets `a` in `foo` to `0`. This is a very subtle distiction which has inadvertantly changed our program from executing safely to summoning nasal demons/eating your cat/ordering pizza/your favourite undefined behaviour metaphor.

Fortunately, there's a simple solution: **initialize your variables.**

<b style="font-size:34px;">Seriously.</b>

<b style="font-size:54px;">Do it.</b>

<b style="font-size:64px;">INITIALIZE YOUR GORRAM VARIABLES.</b>

If the designer of `foo` and `bar` decides that they should be default constructible, they should initialize their contents with some sensible values. If they decide that they should *not* be default constructible, they should delete the constructors to avoid issues.

{% highlight cpp %}
struct foo {
    foo() : a{0} {} //initialize to 0 explicitly
    int a;
};

struct bar {
    bar() = delete; //delete constructor
    //insert non-default constructor which does something sensible here
    int b;
};
{% endhighlight %}

If you still aren't convinced that C++ initialization rules are crazy-complex, take a minute to think of all the forms of initialization you can think of. My answers after the line.

--------------------

Done? How many did you come up with? In perusal of the standard, I counted *eighteen* different forms of initialization[^4]. Here they are with a short example/description:

[^4]: Feel free to debate that some of these are different flavours of initialization forms, or attributes of initialization rather than separate concepts, I don't really care, suffice to say there are a lot.

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

---
layout:     post
title:      "Initialization in C++ is bonkers"
category:   c++
minutes:    10
tags:
 - c++
---

C++ pop quiz time: what are the values of `a.a` and `b.b` on the last line in `main` of this program?

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
T global;       //zero-initialization, then default-initialization

void foo() {
    T i;         //default-initialization
    T j{};       //value-initialization (C++11)
    T k = T();   //value-initialization
    T l = T{};   //value-initialization (C++11)
    T m();       //function-declaration

    new T;       //default-initialization
    new T();     //value-initialization
    new T{};     //value-initialization (C++11)
}

struct A { T t; A() : t() {} }; //t is value-initialized
struct B { T t; B() : t{} {} }; //t is value-initialized (C++11)
struct C { T t; C()       {} }; //t is default-initialized
{% endhighlight %}

The rules for these different initialization forms are fairly complex, so I'll give a simplified outline of the C++11 rules (C++14 even changed some of them, so those value-initialization forms can be aggregate initialization). If you want to understand all the details of these forms, check out the relevant cppreference.com articles[^1][^2][^3], or see the standards quotes at the bottom of the article.

- **default-initialization** -- If `T` is a class, the default constructor is called; if it's an array, each element is default-initialized; otherwise, no initialization is done, resulting in indeterminate values.
- **value-initialization** -- If `T` is a class, the object is default-initialized (after being zero-initialized if `T`'s default constructor is not user-provided/deleted); if it's an array, each element is value-initialized; otherwise, the object is zero-initialized.
- **zero-initialization** -- Applied to static and thread-local variables before any other initialization. If `T` is scalar (arithmetic, pointer, enum), it is initialized from `0`; if it's a class type, all base classes and data members are zero-initialized; if it's an array, each element is zero-initialized.

Taking the simple example of `int` as `T`, `global` and all of the value-initialized variables will have the value `0`, and all other variables will have an indeterminate value. Reading these indeterminate values results in undefined behaviour.

[^1]: [cppreference value-initialization](http://en.cppreference.com/w/cpp/language/value_initialization)
[^2]: [cppreference default-initialization](http://en.cppreference.com/w/cpp/language/default_initialization)
[^3]: [cppreference zero-initialization](http://en.cppreference.com/w/cpp/language/zero_initialization)

--------------------------

#### Back to our original example

Now we have the necessary knowledge to understand what's going on in my original example. Essentially, the behaviours of `foo` and `bar` are changed by the different location of `=default` on their constructors. Again, the relevant standards passages are down at the bottom of the page if you want them, but the jist is this:

Since the constructor for `foo` is defaulted on its first declaration, it is not technically *user-provided* -- I'll explain what this term means shortly, just accept this standardese for now. The constructor for `bar`, conversely, is only defaulted at its definition, so it *is* user-provided. Put another way, if you don't want your constructor to be user-provided, be sure to write `=default` when you declare it rather than define it like that elsewhere. This rule makes sense when you think about it: without having access to the definition of a constructor, a translation unit can't know if it is going to be a simple compiler-generated one, or if it's going to send a telegram to the Moon to retrieve some data and block until it gets a response.

The default constructor being user-provided has a few consequences for the class type. For example, you can't default-initialize a const-qualified object if it lacks a user-provided constructor, the notion being that if the object should only be set once, it better be initialised with something reasonable:

{% highlight cpp %}
const int my_int;            //ill-formed, no user-provided constructor
const std::string my_string; //well-formed, has a user-provided constructor

const foo my_foo; //ill-formed, no user-provided constructor
const bar my_bar; //well-formed, has a user-provided constructor
{% endhighlight %}

Additionally, in order to be [trivial](http://en.cppreference.com/w/cpp/concept/TrivialType) (and therefore [POD](http://en.cppreference.com/w/cpp/concept/PODType)) or an [aggregate](http://en.cppreference.com/w/cpp/language/aggregate_initialization), a class must have no user-provided constructors. Don't worry if you don't know those terms, it suffices to know that whether your constructors are user-provided or not modifies some of the restrictions of what you can do with that class and how it acts.

For our first example, however, we're interested in how user-provided constructors interact with initialization rules. The language mandates that both `a` and `b` are value-initialized, but only `a` is additionally zero-initialized. Zero-initialization for `a` gives `a.a` the value `0`, whereas `b.b` is not initialized at all, giving us undefined behaviour if we attempt to read it. This is a very subtle distinction which has inadvertently changed our program from executing safely to summoning nasal demons/eating your cat/ordering pizza/your favourite undefined behaviour metaphor.

Fortunately, there's a simple solution. At the risk of repeating advice which has been given many times before, **initialize your variables.**

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

Internalising this way of thinking about initialization is key to writing unsurprising code. If you've profiled your code and found a bottleneck caused by unnecessary initialization, then sure, optimise it, but you best be certain that the extra performance is worth the possible headaches and money spent to keep the code safe.

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
- unordered: dynamic initialization of class template static data members which are not explicitly specialized
- ordered: dynamic initialization of other non-local variables with static storage duration
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

#### Appendix: Standards quotes

All quotes from N4140 (essentially C++14).

> Explicitly-defaulted functions and implicitly-declared functions are collectively called defaulted functions,
and the implementation shall provide implicit definitions for them (12.1 12.4, 12.8), which might mean
defining them as deleted. **A function is user-provided if it is user-declared and not explicitly defaulted or
deleted on its first declaration.** A user-provided explicitly-defaulted function (i.e., explicitly defaulted after its first declaration) is defined at the point where it is explicitly defaulted; if such a function is implicitly defined
as deleted, the program is ill-formed.
{:.standards para="[dcl.fct.def.default]/5"}


> To *zero-initialize* an object or reference of type `T` means:
>
> - if `T` is a scalar type (3.9), the object is initialized to the value obtained by converting the integer literal
0 (zero) to T
> - if `T` is a (possibly cv-qualified) non-union class type, each non-static data member and each base-class subobject is zero-initialized and padding is initialized to zero bits;
> - if `T` is a (possibly cv-qualified) union type, the object's first non-static named data member is zero-initialized and padding is initialized to zero bits;
> - if `T` is an array type, each element is zero-initialized;
> - if `T` is a reference type, no initialization is performed.
>
> To *default-initialize* an object of type `T` means:
>
> - if `T` is a (possibly cv-qualified) class type (Clause 9), the default constructor (12.1) for `T` is called (and the initialization is ill-formed if `T` has no default constructor or overload resolution (13.3) results in an
ambiguity or in a function that is deleted or inaccessible from the context of the initialization);
> - if `T` is an array type, each element is default-initialized;
> - otherwise, no initialization is performed.
>If a program calls for the default initialization of an object of a const-qualified type `T`, `T` shall be a class type with a user-provided default constructor.
>
> To *value-initialize* an object of type `T` means:
>
> - if `T` is a (possibly cv-qualified) class type (Clause 9) with either no default constructor (12.1) or a default constructor that is user-provided or deleted, then the object is default-initialized;
> - if `T` is a (possibly cv-qualified) class type without a user-provided or deleted default constructor, then the object is zero-initialized and the semantic constraints for default-initialization are checked, and if `T` has a non-trivial default constructor, the object is default-initialized;
> - if `T` is an array type, then each element is value-initialized;
> - otherwise, the object is zero-initialized.
{:.standards para="[dcl.init]/6-8"}


> Variables with static storage duration (3.7.1) or thread storage duration (3.7.2) shall be zero-initialized (8.5)
before any other initialization takes place. [...]
{:.standards para="[basic.start.init]/2"}

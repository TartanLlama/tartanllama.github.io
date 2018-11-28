---
layout:     post
title:      "Guaranteed Copy-Elision Never Elides Copies"
category:   c++
tags:
 - c++
---

C++17 merged in a paper called [Guaranteed copy elision through simplified value categories](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0135r0.html). The changes mandate that no copies or moves take place in some situations where they were previously allowed, e.g.:

```cpp
non_moveable make() { return {}; }
auto x = make(); //compiles in C++17, error in C++11/14
```

In spite of the name of the paper and what you might read on the Internet, the new rules *do not guarantee copy-elision*. Instead, the new value category rules are defined such that no copy exists in the first place. Understanding this nuance gives a deeper understanding of the current C++ object model, so I will explain the pre-C++17 rules, what changes were made, and how they solve real-world problems.

## Value Categories

To understand the before-and-after, we first need to understand what value categories are. Continuing the theme of C++ misnomers, value categories are *not* categories of values. They are characteristics of expressions. Every expression in C++ has one of three value categories: *lvalue*, *prvalue* (pure rvalue), or *xvalue* (eXpring value). There are then two parent categories: all lvalues and xvalues are *glvalues*, and all prvalues and xvalues are *prvalues*.

[diagram]

For an explanation of what these are, we can look at the standard ([`C++17 [basic.lval]/1`](http://eel.is/c++draft/basic.lval#1)):

- A glvalue is an expression whose evaluation determines the identity of an object, bit-field, or function.
- A prvalue is an expression whose evaluation initializes an object or a bit-field, or computes the value of an operand of an operator, as specified by the context in which it appears.
- An xvalue is a glvalue that denotes an object or bit-field whose resources can be reused (usually because it is near the end of its lifetime).
- An lvalue is a glvalue that is not an xvalue.
- An rvalue is a prvalue or an xvalue.

Some examples:

```cpp
int i;
i //lvalue

int{} //prvalue

int f();
int& g();
int&& h();

f() //prvalue
g() //lvalue
h() //xvalue

struct foo {
    int i;
};

foo{}.i //xvalue
```

## C++11

What are the properties of the expression `std::string{"hewwo"}`?

Think about it for a minute.

It's a prvalue. Its type is `std::string`. It has the value `"hewwo"`. It's a temporary.

That last one is the key point I want to talk about, and it's the real difference between the C++11 rules and C++17. In C++11, `std::string{"hewwo"}` is indeed a temporary.

From `C++11 [class.temporary]/1`:

Temporaries of class type are created in various contexts: binding a reference to a prvalue, returning a prvalue, a conversion that creates a prvalue, throwing an exception, entering a handler, and in some initializations. 

Let's look at how this interacts with this code:

```cpp
struct copyable {
    copyable() = default;
    copyable(copyable const&) { /*...*/ }
};
copyable make() { return {}; }
auto x = make();
```

`make()` results in a temporary. This temporary will be moved into `x`. Since `copyable` has no move constructor, this calls the copy constructor. However, this copy is unnecessary, since the object constructed on the way out of `make` will never be used for anything else. The standard allows this copy to be *elided* by constructing the return value at the call-site rather than in `make` (`C++11 [class.copy]`).

The unfortunate part is this: **even if all copies of the type are elided, the constructor still has to exist**.

This means that if we instead have:

```cpp
struct non_moveable {
    non_moveable() = default;
    non_moveable(non_moveable&&) = delete;
};
non_moveable make() { return {}; }
auto x = make();
```

then we get a compiler error:

```
<source>(7): error C2280: 'non_moveable::non_moveable(non_moveable &&)': attempting to reference a deleted function
<source>(3): note: see declaration of 'non_moveable::non_moveable'
<source>(3): note: 'non_moveable::non_moveable(non_moveable &&)': function was explicitly deleted
```

Aside from returning non-moveable types by value, this presents other issues:

1. Use of [Almost Always Auto](https://herbsutter.com/2013/08/12/gotw-94-solution-aaa-style-almost-always-auto/) style is prevented for immobile types:

```cpp
auto x = non_moveable{}; //compiler error
```

2. The language makes no guarantees that the constructors won't be called (in practice this isn't too much of a worry, but guarantees are more convincing than optional optimizations).
3. If we want to support some of these use-cases, we need to write copy/move constructors for types which they don't make sense for (and do what? Throw? Abort? Linker error?)
4. You can't pass non-moveable types to functions by value, in case you have some use-case which that would help with.

So what's the solution? Should the standard just say "oh, if you elide all copies, you don't need those constructors"? Maybe, but then all this language about constructing temporaries is really a lie, and building an intuition about the object model becomes even harder.

## C++17

C++17 takes a different approach. Instead of guaranteeing that copies will be elided in these cases, it changes the rules such that the copies were never there in the first place. This is achieved through redefining when temporaries are created.

As noted in the value category descriptions earlier, prvalues exist for purposes of initialization. C++11 creates temporaries eagerly, eventually using them in an initialization and cleaning up copies after the fact. In C++17, the materialization of temporaries is deferred until the initialization is performed.

That's a better name for this feature. Not guaranteed copy elision. **Deferred temporary materialization**.

Temporary materialization creates a temporary object from a prvalue, resulting in an xvalue. The most common places it occurs are when binding a reference to, or performing member access on a prvalue. 

Some examples:

```cpp
struct foo {
    int i;
};

foo make();
auto& a = make();  //temporary materialized and lifetime-extended
auto&& b = make(); //ditto

foo{}.i //temporary materialized

auto c = make(); //no temporary materialized
```

That covers the most important points of the new rules. If you'd like more details, I've linked relevant standards passages at the bottom of the article.

## Who cares?

I said at the start that understanding the new rules would grant a deeper understanding of the C++17 object model. I'd like to expand on that a bit.

The key point is that in C++11, prvalues are not "pure" in a sense. That is, the expression `std::string{"hewwo"}` represents some temporary `std::string` object with the contents `"hewwo"`. It's not the pure notion of the list of characters "hewwo". It's not the Platonic ideal of "hewwo".

In C++17, however, `std::string{"hewwo"}` *is* the Platonic ideal of "hewwo". It's not a real object in C++'s object model, it's some elusive, amorphous idea which can be passed around your program, only being given form when initializing some result object, or materializing a temporary. **C++17's prvalues are purer prvalues**.

If this all sounds a bit abstract, that's okay, but internalising this idea will make it easier to reason about aspects of your program. Consider a simple example:

```cpp
struct foo{};
auto x = foo{};
```

In the C++11 model, the prvalue `foo{}` creates a temporary which is used to move-construct `x`, but the move is likely elided by the compiler.

In the C++17 model, the prvalue `foo{}` initializes `x`.

A more complex example:

```cpp
std::string a() {
    return "hewwo";
}

std::string b() {
    return a();
}

int main() {
    auto x = b();
}
```

In the C++11 model, `return "hewwo";` initializes the temporary return object of `a()`, which move-constructs the temporary return object of `b()`, which move-constructs `x`. All of the moves are likely elided by the compiler. 

In the C++17 model, `return "hewwo";` initializes the result object of `a()`, which is the result object of `b()`, which is `x`.

In essence, rather than an initializer creating a series of temporaries which in theory move-construct a chain of return objects, the initializer is teleported to the eventual result object. In C++17, the code:

```cpp
T a() { return /* expression */ ; }
auto x = a();
```

is identical to `auto x = /* expression */;`. For any `T`.

## Closing

The "guaranteed copy elision" feature guarantees no copy elision, instead making the copy never exist by purifying prvalues even further. Next time you hear or read about "guaranteed copy elision", think instead about *deferred temporary materialization*.   





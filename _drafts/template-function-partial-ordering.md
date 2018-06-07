---
layout:     post
title:      "Function Template Partial Ordering: Worked Examples"
category:   c++
tags:
 - c++ 
---

C++ function overloading rules are complex. C++ template rules are complex. Put the two together, and you unfortunately do not get something simple; you get a hideous monster of standardese which requires great patience and knowledge to defeat. However, since C++ is mostly corner-cases, it can pay to understand how the rules apply for those times where you just can't work out why your code won't compile. This post will present a few examples of partial ordering of function templates step-by-step in order to arm you for these times of need.

Partial ordering of function templates is a step of function overload resolution. It occurs when you call a function template which is overloaded and the compiler needs to decide which one is more specialized than the other. Consider this code:

```cpp
template<class T> void f(T);        //(1)
template<class T> void f(T const*); //(2)

int const* p = nullptr;
f(p);
```

We expect `f(p)` to call `(2)`, because `p` is a `int const*`. In order to decide that `(2)` is more specialized than `(1)`, the compiler needs to execute the function template partial ordering rules. Let's see what the standard has to say.

> Partial ordering selects which of two function templates is more specialized than the other by transforming each template in turn (see next paragraph) and performing template argument deduction using the function type.
{:.standards para="[temp.func.order]/2"}

This is not so complicated. Unfortunately, the "next paragraph" and the sections which it references are almost impossible to parse without a lot of background knowledge and re-readings, so I shall step through the algorithm rather than pasting the rules for you to cry over.

There are two stages which we to have work through:
{:.listhead}
1. Transforming `(1)` and performing deduction on `(2)`.
2. Transforming `(2)` and performing deduction on `(1)`.

Let's transform `(1)` first. The rules state that for each template parameter, we create some unique type to use in its stead[^1]. Let's call this unique type `type_0`. You can pretend that this was defined somewhere like `class type_0{};`. Now we take our function template `template <class T> void f(T)` and substitute in `type_0` for `T`. This gives us `void f(type_0)`. The transformation is complete.

Now that we have transformed `template <class T> void f(T)` into `void f(type_0)`, we will perform deduction on `(2)` using the transformed function type. To do this, we imagine a call to `(2)` where the arguments have the type of the parameters for `(1)`. Concretely, it would look like this:

```cpp
template <class T> void func_2(T const*);
func_2(type_0{});
```

Would this call succeed? We can put it into our compiler to find out. [GCC 8.1 says](https://godbolt.org/g/dFKVVs):

```
<source>: In function 'int main()':
<source>:4:18: error: no matching function for call to 'func_2(type_0)'
   func_2(type_0{});
                  ^
<source>:1:25: note: candidate: 'template<class T> void func_2(const T*)'
 template <class T> void func_2(T const*);
                         ^~~~~~
<source>:1:25: note:   template argument deduction/substitution failed:
<source>:4:18: note:   mismatched types 'const T*' and 'type_0'
   func_2(type_0{});
                  ^   
```

So deduction from `(1)` to `(2)` fails, because the invented type `type_0` cannot be used to deduce `const T*`.

Let's try from `(2)` to `(1)`. Again, we'll transform `(2)` from `template <class T> void f(T const*)` to `void f(type_0 const*)`. Now we attempt deduction:

```cpp
template <class T> void func_1(T);
type_0 const* arg = nullptr;
func_1(arg);
```

[This succeeds](https://godbolt.org/g/dFKVVs) because a `type_0 const*` can be used to deduce `T`. Since deduction from `(1)` to `(2)` fails, but deduction from `(2)` to `(1)` succeeds, `(2)` is *more specialized than* `(1)` and will be chosen by overload resolution.

--------------------

Let's try a different example. How about:

```cpp
template<class T> void g(T);  //(1)
template<class T> void g(T&); //(2)
int i = 0;
g(i);
```

`(1)` transforms to `void g(type_0)`. Before we try deduction, we need to apply one of the numerous additional rules from the standard, which says we need to replace references with the type being referred to. So `template <class T> void g(T&)` becomes `template <class T> void g(T)`. Deduction time:

```cpp
template<class T> void func_2(T);
func_2(type_0{});
```

This [succeeds](https://godbolt.org/g/1uDEyC).

Now the other direction. `template<class T> void g(T&)` transforms to `void g(type_0&)`, then we remove the reference to get `void g(type_0)`. Our second deduction:

```cpp
template<class T> void func_1(T);
func_1(type_0{});
```

This is effectively identical to the previous one, so of course [it succeeds](https://godbolt.org/g/1JfZhG).

Since deduction succeeded in both directions, the call is ambiguous. Sure enough, [GCC diagnoses](https://godbolt.org/g/1e1UuS):

```
<source>: In function 'int main()':
<source>:5:8: error: call of overloaded 'g(int&)' is ambiguous
     g(i);
        ^
<source>:1:24: note: candidate: 'void g(T) [with T = int]'
 template<class T> void g(T);  //(1)
                        ^
<source>:2:24: note: candidate: 'void g(T&) [with T = int]'
 template<class T> void g(T&); //(2)
                        ^ 
```

This is why the algorithm is a _partial_ ordering: sometimes two function templates are not ordered.

--------------------------------

I'll give one more example. This one has multiple parameters and is a bit more subtle.

```cpp
template<class T>struct identity { using type = T; };
template<class T>struct A{};

template<class T, class U> void h(typename identity<T>::type, U); //(1)
template<class T, class U> void h(T, A<U>);                       //(2)
h<int>(0,A<void>{});
```

`identity` here just evaluates to its template argument, but the important thing to note is that `typename identity<T>::type` is a [non-deduced context](https://stackoverflow.com/questions/25245453/what-is-a-nondeduced-context), so `T` cannot be deduced from the argument for that parameter.

`(1)` transforms to `void h(typename identity<type_0>::type, type_0)`, which is `void h(type_0, type_0)`. Attempt deduction on `(2)`:

```cpp
template<class T, class U> void func_2(T, A<U>);
func_2(type_0{}, type_0{});
```

This [fails](https://godbolt.org/g/D8LBrF) because we can't match `type_0` against `A<U>`.

`(2)` transforms to `void h(type_0, A<type_1>)`. Try deduction against `(1)`:

```cpp
template<class T, class U> void func_1(typename identity<T>::type, U);
func_1(type_0{}, A<type_1>{});
```

This [fails](https://godbolt.org/g/1wjy85) because `typename identity<T>::type` is a non-deduced context, so we can't deduce `T`.

In the example from the last section deduction succeeded both ways so the call was ambiguous. In this example, deduction _fails_ both ways, which is also [an ambiguous call](https://godbolt.org/g/V3o7p6).

--------------------------

That's the last of the examples. Of course, there are a bunch of rules which I didn't cover here, like Concepts, parameter packs, non-type/template template parameters, and cases where both the argument and parameter types are references. Hopefully you now have enough of an intuition that you can understand what the standard says when you inevitably hit those corner cases.

--------------------------

[^1]: I'll ignore non-type template parameters and template template parameters for simplicity, but the rules are essentially the same.

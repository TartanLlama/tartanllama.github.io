---
layout:     post
title:      "integral_variable: A compile-time assignable variable"
date:       2016-07-28
category:   c++
minutes: 20
tags:
 - c++ 
 - templates
---

<h3>Introduction</h3>

C++ has a lot of cool stuff you can do at compile-time. You can automatically generate classes or functions for given a set of types, write meta-functions to operate on types, calculate anything which is calculable, explode tuples, walk type lists, and so much more. However, since C++ templates are essentially a pure functional language, you can't have things such as mutable variables. For example, the following code is invalid in C++:

{% highlight cpp %}
constexpr int a = 0; //create constexpr int
a = 42;              //try to mutate it
{% endhighlight %}

If you feed this code to GCC, it lovingly tells you:

{% highlight cpp %}
error: assignment of read-only variable 'a'
{% endhighlight %}
    
So, is there any way to get around this? It turns out that there is. I have created `integral_variable`, which has the following usage:

{% highlight cpp %}
auto a = make_integral_variable();    //variable set to 0
auto b = make_integral_variable<3>(); //variable set to 3

static_assert(a.get() == 0, "wat");   //ensure that a is 0 (at compile-time)
static_assert(b.get() == 3, "wat");   //ensure that b is 3 (ditto)

a.set<12>();                          //set a to 12
b.set<5>();                           //set b to 5

static_assert(a.get() == 12, "wat");  //ensure that a is now 12 (at compile-time)
static_assert(b.get() == 5, "wat");   //ensure that b is now 5 (ditto)
{% endhighlight %}

This may seem a bit crazy; how can a `static_assert` on the same expression yield different values? Actually, this successfully compiles on both Clang 3.7 and GCC 6.1 (it doesn't work on MSVC due to a number of compiler bugs). The rest of this post will detail how this works.

This post is split into three sections:

- Variable encoding
- Constexpr counter
- integral_variable

Since there are some fairly advanced concepts at work here, it might help to read each section a couple of times over before moving on to the next one.

Before I get into the gory details, I should note that this work is all based off of [Filip Roséen](http://stackoverflow.com/users/1090079/filip-ros%C3%A9en-refp)'s series of posts about non-constant constant expressions. These posts can be found [here](http://b.atch.se/). Filip goes into a lot of the details about why this is all technically standards-conformant, with all the necessary standardese included in the post. I'll be writing at a higher level and glossing over some of the more complex details, so if you want to know the rest, go read Filip's blog.


-------------------
<h3>Variable encoding</h3>

One of the most important considerations for this class is how we encode the state of a variable. The following encoding may seem a bit overcomplex at first, but for now, all you need to know is that it can be represented at compile-time. You can think of the encoding of `integral_variable` as a punch card. The punch card is a 2D table, where each cell is a location which can be punched out. Each cell starts in the "intact" (0) state, and we can punch it to change to the "punched" (1) state. At a given time, only one column in the table will be active, so there is a cursor to keep track of this column. Here is the starting state for a variable which has a maximum value of two and can be assigned to twice (the first column is just the row numbers for clarity):


    0 | 1 0 0
    1 | 0 0 0
    2 | 0 0 0
        ^ (cursor)

Given this encoding, we need to know two things: how do we read this variable and how do we assign a number to it.

The variable value is read by starting at the cell closest to the cursor and tracking up the column until we find a cell which is punched. The value is the row index of this cell. For this starting state, the value is `0`, because the closest punched cell to the cursor is in the `0` row.

Assigning to the variable is acheived by punching a cell, possibly advancing the cursor beforehand. There are two cases to consider: is the value we want to set greater than or less than the current value?

If the desired value is greater than the current value, we don't need to advance the cursor at all; we just punch the cell where the current cursor column and desired value row intersect. So if we set the above variable to `2`, it will look like this:

    0 | 1 0 0
    1 | 0 0 0
    2 | 1 0 0
        ^

The value of this variable is `2`, because the closest punched cell to the cursor is in the `2` row.

If the desired value is less than the current value, we advance the cursor one position and punch the relevant cell in that new column. So if we now want to assign `1` to the above variable, it will look like this:

    0 | 1 0 0
    1 | 0 1 0
    2 | 1 0 0
          ^

Advancing the counter is necessary because if we omitted it, the value would remain unchanged. For example, if we punch `0` in the second column of the above state, it will look like this:

    0 | 1 1 0
    1 | 0 1 0
    2 | 1 0 0
          ^

The value is still `1`, because that's the punched cell closest to the cursor in the active column.

Hopefully you now have an idea of how this variable operates and how it might scale to more assignments and higher values, simply by extending the array in either direction.

Now that we have a way to encode these variables, we just need to implement this at compile time.

----------------------
<h3>Constexpr counter</h3>

To implement this in C++ I used a collection of constexpr counters, slightly modified to allow writing of arbitrary values. Each column in the variable encoding is represented by a constexpr counter, the cursor is a constexpr counter, and there is one global one to allow you to generate new variables.

I'll now give a high-level overview of how these counters work (all code is from Filip's blog).

Our punch card cells are represented by functions. A function is "intact" when it is declared and "punched" when it is defined.

{% highlight cpp %}
template<size_type N>
struct ident {
  friend constexpr size_type adl_lookup (ident<N>);
  static constexpr size_type value = N;
};
{% endhighlight %}

In the above code, `adl_lookup` is the function used as the punch card cell. Since it is a friend declaration, the function is only visible through [Argument Dependent Lookup](http://en.cppreference.com/w/cpp/language/adl), hence the argument. Note that it is currently declared, but not defined, so is in the "intact" state.

Injecting the definition of `adl_lookup` through template instantiation carries out the cell punch action:

{% highlight cpp %}
template<class Ident>
struct writer {
  friend constexpr size_type adl_lookup (Ident) {
    return Ident::value;
  }
  static constexpr size_type value = Ident::value;
};
{% endhighlight %}

Now when `writer` is instantiated, `ident<N>::adl_lookup` will be defined.

Reading the current value of the metacounter is the implementation of walking up the variable state column from the bottom row. It's a bit more complicated:

{% highlight cpp %}
template<size_type N, int = adl_lookup (ident<N> {})>
static constexpr size_type value_reader (int, ident<N>) {
  return N;
}

template <size_type N>
static constexpr size_type 
value_reader (float, ident<N>,
              size_type R = value_reader (0, ident<N-1> ())) 
{
  return R;
}

static constexpr size_type value_reader (float, ident<0>) {
  return 0;
}
{% endhighlight %}

The first overload is the case where we have found the value. For some `N`, if `ident<N>::adl_lookup` has not been defined yet by instantiating `writer<ident<N>>`, then `adl_lookup(ident<N>{})` will not be a constant expression, so the overload will be [SFINAE](http://en.cppreference.com/w/cpp/language/sfinae)d out.

The second overload is the recursive case. It keeps calling `value_reader` until it finds the value or hits the last element.

The third overload is the base case; it just returns `0` if we get to the last element.

Each of the overloads has a dummy `int` or `float` parameter. This is just to force the first overload to be selected during overload resolution if it's not SFINAEd out (see [here](https://rmf.io/cxx11/overload-ranking/) for more details and a cleaner approach).

Finally, some public helper functions:

{% highlight cpp %}
template<size_type Max = 64>
static constexpr size_type 
value (size_type R = value_reader (0, ident<Max> {})) {
  return R;
}

template<size_type N = 1, class H = meta_counter>
static constexpr size_type 
next (size_type R = writer<ident<N + H::value ()>>::value) {
  return R;
}

template<size_type N, class H = meta_counter>
static constexpr size_type 
write (size_type R = writer<ident<N + H::value() - H::value()>>::value) {
  return R;
}
{% endhighlight %}

These do pretty much what you would expect: `value` gets the current value by walking from some maximum value down to zero, `next` defines `ident<value + 1>::adl_lookup` and `write` (this is the small addition I made) defines `ident<N>::adl_lookup` (the `H::value() - H::value()` is to make the expression depend on `H`, which Clang requires).

Now that we've gone over the meta counter, we need to use it to build our variables.

--------------------------
<h3>integral_variable</h3>

As noted above, an `integral_variable` is a collection of constexpr counters. It mostly operates using static functions, but provides a value wrapper interface for ease of use. 

The simplest aspect is `make_integral_variable`, which uses a global counter to create new variables:

{% highlight cpp %}
//A short helper
template <std::size_t N>
using size_constant = std::integral_constant<std::size_t, N>;

//Global counter
using VarCounter = atch::meta_counter<class VarCount>;

template <std::size_t Init = 0,
          class C = VarCounter,
          class VarTag = size_constant<C::next()>>
constexpr auto make_integral_variable() {
  //Create the new variable
  auto v = integral_variable<VarTag>{};

  //Set it to some initial value
  v.template set<Init>();
  return v;
}
{% endhighlight %}

This advances the global variable counter, creates a new variable, then sets it to the initial value.

Now we need the code to handle the assignment counter:

{% highlight cpp %}
template <class VarTag>
class integral_variable {
  using var_tag = VarTag;

  template <std::size_t Var, std::size_t Assign>
  struct assign_tag_{};

  template <class C = atch::meta_counter<var_tag>, size_type R = C::value()>
  static constexpr auto 
  assign_tag(assign_tag_<var_tag::value, R> tag = {}) {
    return tag;
  }

  template <class C = atch::meta_counter<var_tag>, size_type R = C::next()>
  static constexpr auto 
  next_assign_tag(assign_tag_<var_tag::value, R> tag = {}) {
    return tag;
  }

  //...
};
{% endhighlight %}

`assign_tag` is a template class which we will use to name our assign counter for this variable. It takes two template parameters: the global variable index and a local assignment count. `assign_tag` returns a tag encoding the current value of the assignment counter for this variable. `next_assign_tag` increments the counter before returning the same thing.

Finally, a couple of non-static member functions to get and set the variable:

{% highlight cpp %}
template <class VarCount = atch::meta_counter<var_tag>, 
          class Tag = decltype(assign_tag<VarCount>())>
constexpr size_type 
get(size_type R = atch::meta_counter<Tag>::template value()) {
  return R;
}

template <size_type N, class VarCount = atch::meta_counter<var_tag>, 
          class Tag = decltype(next_assign_tag<VarCount>())>
constexpr size_type 
set (size_type Written = atch::meta_counter<Tag>::template write<N>()) {
  return Written;
}    
{% endhighlight %}

As you might imagine, `get` returns the current value of the variable, while `set` sets it.

That covers the code for `integer_variable`.

--------------------

Before we finish up, here's a quick interesting facet of this class. Since each generated variable is a new type and the core functionality works through static functions, we get copy semantics similar to `std::reference_wrapper`. For example:

{% highlight cpp %}
template <typename Var>
void setVar (Var v) {
  v.set<4>();
}
     
int main() {
  auto var = make_integral_variable();
  static_assert(var.get() == 0, "wat");
     
  setVar(v);
  static_assert(var.get() == 4, "wat");
}
{% endhighlight %}

-------------------

So, when should we actually use this in practice?

**Never.**

Really, this is pretty awful. It probably totally breaks across translation units, and the Standards Committee wants to outlaw this kind of thing. However, it's still pretty fascinating and I hope that you've got some ideas on how to abuse this yourself.

If you want to play around with it, you can get the code [here](https://gist.github.com/TartanLlama/3aa4541c12538d1d6cf5cf244cc5d724).

----------------

<h3>Further work</h3>

This class could be adapted to work with other integral types, kind of like `std::integral_constant`. Alternatively, the whole thing could be thrown in the sea.

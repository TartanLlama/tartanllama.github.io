---
layout:     post
title:      "integral_variable: A compile-time assignable variable"
data:       2016-06-2016
summary:    Using thumbnails in your Carte Noire articles.
categories: c++ templates
minutes: 20
draft:      true
tags:
 - c++ 
 - templates
---

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

This may seem a bit crazy; how can a `static_assert` on the same expression yield different values? Actually, this successfully compiles on both Clang and GCC (I haven't tested MSVC and am scared to). The rest of this post will detail how this works.

 Before I get into the gory details, I should note that this work is all based off of [Filip Roséen](http://stackoverflow.com/users/1090079/filip-ros%C3%A9en-refp)'s series of posts about non-constant constant expressions. These posts can be found [here](http://b.atch.se/). Filip goes into a lot of the details about why this is all technically standards-conformant, with all the necessary standardese included in the post. I'll be writing at a higher level and glossing over some of the more complex details, so if you want to know the rest, go read Filip's blog.


-------------------

One of the most important considerations for this class is how we encode the state of a variable. The following encoding may seem a bit overcomplex at first, but for now, all you need to know is that it can be represented at compile-time. You can think of integral_variable as being encoded by a two-dimensional collection of buttons and a single cursor. Each button starts in the "not pressed" (0) state, and we can press it to change to the "pressed" (1) state.  Once a button has been pressed, it cannot be unpressed. At a given time, only one column in the variable state will be "active". The cursor tracks this active column. Here is the starting state for a variable which has a maximum value of two and can be assigned to twice (the first column is just the row numbers for clarity):


    0 1 0 0
    1 0 0 0
    2 0 0 0
      ^ (cursor)

Given this encoding, we need to know two things: how do we read this variable and how do we assign a number to it.

The variable value is read by starting at the cell closest to the cursor and reading up until we find a button which is pressed. For this starting state, the value is 0, because the closest pressed button to the cursor is in the 0 row.

Assigning to the variable is just pressing a button, possibly advancing the cursor beforehand. There are two cases to consider: is the value we want to set greater than or lesser than the current value?

If the desired value is greater than the current value, we don't need to advance the cursor at all; we just press the button in the current cursor row which corresponds to the value we want. So if we set the above variable to 2, it will look like this:

    0 1 0 0
    1 0 0 0
    2 1 0 0
        ^

As you can see, the value of this variable is 2, because the closest pressed button to the cursor is in the 2 row.

If the desired value is lesser than the current value, we advance the cursor one position and press the relevant button in that new column. So if we now want to assign 1 to the above variable, it will look like this:

    0 1 0 0
    1 0 1 0
    2 1 0 0
        ^

Hopefully you now have an idea of how this variable operates and how it might scale to more assignments and higher values, simply by extending the array in either direction.

Now that we have a way to encode these variables, we just need to implement this at compile time.

----------------------

To implement this in C++ I used a collection of constexpr counters from Filip's post, slightly modified to allow writing of arbitrary values.

Each column in the variable encoding is represented by a constexpr counter, the cursor is a constexpr counter, then there is one global one to allow you to generate new variables.

Here is a high-level overview of how these counters work (all code is from Filip's blog):

Our "buttons" are represented by functions. A function is "not pressed" when it is declared and "pressed" when it is defined.

{% highlight cpp %}
template<size_type N>
struct ident {
  friend constexpr size_type adl_lookup (ident<N>);
  static constexpr size_type value = N;
};
{% endhighlight %}

In the above code, `adl_lookup` is the button function. Since it is a friend declaration, the function is only visible through [Argument Dependent Lookup](http://en.cppreference.com/w/cpp/language/adl), hence the argument. Note that it is currently declared, but not defined.

Now we press the button by injecting the definition of `adl_lookup` through template instantiation:

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

template<size_type N>
static constexpr size_type value_reader (float, ident<N>,
                                         size_type R = value_reader (0, ident<N-1> ())) {
  return R;
}

static constexpr size_type value_reader (float, ident<0>) {
  return 0;
}
{% endhighlight %}

The first overload is the case where we have found the value. For some `N`, if `ident<N>::adl_lookup` has not been defined yet by instantiating `writer<ident<N>>`, then `adl_lookup(ident<N>{})` will not be a constant expression, so the overload will be [SFINAE](http://en.cppreference.com/w/cpp/language/sfinae)d out.

The second overload is the recursive case. It keeps calling value_reader until we've found the value or hit the last element.

The third overload is the base case, just returning 0 if we get to the last element.

Each of the overloads has a dummy `int` or `float` parameter; this is just to force the first overload to be selected during overload resolution if it's not SFINAEd out.

Finally, some public helper functions:

{% highlight cpp %}
template<size_type Max = 64>
static constexpr size_type value (size_type R = value_reader (0, ident<Max> {})) {
  return R;
}

template<size_type N = 1, class H = meta_counter>
static constexpr size_type next (size_type R = writer<ident<N + H::value ()>>::value) {
  return R;
}

template<size_type N, class H = meta_counter>
static constexpr size_type write (size_type R = writer<ident<N + H::value() - H::value()>>::value) {
  return R;
}
{% endhighlight %}

These do pretty much what you would expect: `value` gets the current value by walking from some maximum value down to zero, `next` defines `ident<value + 1>::adl_lookup` and `write` (this is the small addition I made) defines `ident<N>::adl_lookup` (the `H::value() - H::value()` is to make the expression depend on `H`, which Clang requires).

Now that we've gone over the meta counter, we need to use it to build our variables.

--------------------------

The most simple thing is `make_integral_variable`, which uses a global counter to create new variables:

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
  static constexpr auto assign_tag(assign_tag_<var_tag::value, R> tag = {}) {
    return tag;
  }

  template <class C = atch::meta_counter<var_tag>, size_type R = C::next()>
  static constexpr auto next_assign_tag(assign_tag_<var_tag::value, R> tag = {}) {
    return tag;
  }

  //...
};
{% endhighlight %}

`assign_tag` is a template class which we will use to name our assign counter for this variable. It takes two template parameters; the global variable index and a local assignment count. `assign_tag` returns a tag encoding the current value of the assignment counter for this variable, `next_assign_tag` increments the counter before returning the same thing.

Finally, a couple of member functions to get and set the variable:

{% highlight cpp %}
template <class VarCount = atch::meta_counter<var_tag>, 
          class Tag = decltype(assign_tag<VarCount>())>
constexpr size_type get(size_type R = atch::meta_counter<Tag>::template value()) {
  return R;
}

template <size_type N, class VarCount = atch::meta_counter<var_tag>, 
          class Tag = decltype(next_assign_tag<VarCount>())>
constexpr size_type set (size_type Written = atch::meta_counter<Tag>::template write<N>()) {
  return Written;
}    
{% endhighlight %}

As you might imagine, `get` returns the current value of the variable, while `set` sets it.

That covers the code for `integer_variable`. I'll now outline some interesting aspects of this class.

--------------------

[insert interesting stuff here]

-------------------

[insert why you should never use this here]

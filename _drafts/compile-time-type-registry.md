---
layout:     post
title:      "Compile-time type registry"
category:   c++
tags:
 - c++ 
 - templates
---

This post shows another interesting use of the constexpr counter.

{% highlight cpp %}
// This is our meta-container
using TypeMap = atch::meta_list<class A>;

// Get a unique integral number associated with the provided type
template <class T>
struct encode_type
{
    using type = T;
    // Push T into the container and store the pre-push size
    //( requires slight change to Filip's code)
    static constexpr std::size_t value = TypeMap::push<T>();
};

// Get the type uniquely associated with the provided value
template <std::size_t V>
struct decode_type
{
    static constexpr std::size_t value = V;
    // Get the type at index V
    // (requires a small helper function addition)
    using type = decltype(TypeMap::at<V>());
};
{% endhighlight %}

Since this just uses template instantiation, if you write `encode_type<AType>` twice, then it will only be encoded once.

I had to make a couple of changes to the constexpr counter to make this easier. First was to make `meta_list::push` return the size of the meta-container *before* the push:

{% highlight cpp %}
template<class T, class H = meta_list, std::size_t Size = counter::value()>
static constexpr std::size_t push (
  size_type = push_state<
    typename H::template value<>::template push<T>::result
  > ()
) { return Size; }
{% endhighlight %}

Second was to add a small `decltype` helper to hide all the dependent name mess:

{% highlight cpp %}
template<size_type Idx, class H = meta_list>
static constexpr auto at () -> typename H::template value<>::template at<Idx>::result;
{% endhighlight %}


A quick test to make sure everything works:

{% highlight cpp %}
int main () {
    std::array<int, 4> encoded { 
        encode_type<int>::value,
        encode_type<double>::value,
        encode_type<std::string>::value,
        encode_type<float>::value
    };

  std::cout << "Encoding: ";
  for (auto i : encoded) std::cout << i << ", ";
  std::cout << std::endl;

  std::array<std::type_index, 4> decoded {
      typeid(decode_type<0>::type),  
      typeid(decode_type<1>::type),
      typeid(decode_type<2>::type),
      typeid(decode_type<3>::type),
  };

  std::cout << "Decoding: ";
  for (auto i : decoded) std::cout << i.name() << ", ";
  std::cout << std::endl;
}
{% endhighlight %}

Success! Clang 3.7 prints out this:

    Encoding: 0, 1, 2, 3, 
    Decoding: i, d, NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE, f,

---
layout:     post
title:      "Lazy generators: template deduction on the left-hand side"
date:       2017-01-03
category:   c++
minutes:    10
tags:
 - c++
 - templates
---

If you are constructing or assigning to a variable from some function template call, the template magic usually occurs on the right-hand side of the expression. For example:

{% highlight cpp %}
auto i = parse<int>();
auto s = parse<std::string>();
{% endhighlight %}

But what if we could get `parse` to deduce the type we want to parse from the *left-hand side* of the construction? I.e. what if we could write this:

{% highlight cpp %}
int i = parse();
std::string s = parse();
{% endhighlight %}

This might not seem possible at first glance, since template deduction for `parse` can only occur based on the function arguments. However, we can achieve this usage with a technique I call lazy generators.

Instead of `parse` doing all of the parsing work, it's going to return a `parser`, which is the lazy generator for our example.

{% highlight cpp %}
parser parse() {
    parser p { /* maybe initialize with a stream or some settings */ };
    // maybe change some other parser settings based on state
    return p;
}
{% endhighlight %}

Now the actual parsing work will be done in the implicit conversion template function of `parser`:

{% highlight cpp %}
struct parser {
    template <typename T>
    operator T() {
        // a super naive implementation which just default constructs and reads from std::cin
        T t;
        std::cin >> t;
        return t;
    }
};
{% endhighlight %}

Now, `parser` can implicitly convert to any type with the relevant stream overloads and a default constructor, and this conversion will trigger the parsing.

{% highlight cpp %}
int i = parse();         // returns a parser, implicitly converts it to int
std::string s = parse(); // ditto with std::string
{% endhighlight %}

You can also pass the parser as an argument to functions which expect parsable types (although be careful if doing so multiple times in a function call due to unspecified evaluation order):

{% highlight cpp %}
void foo (int, std::string, float);

foo(42, parse(), 12.12);
{% endhighlight %}

If you wanted, you could add some `static_assert`s or `std::enable_if` tricks to limit the types which your generator converts to:

{% highlight cpp %}
template <typename T, typename=void>
struct parseable : std::false_type{};
    
template <typename T>
struct parseable <T, std::void_t<decltype(std::cin >> std::declval<T&>())>> 
    : std::true_type{};

template <typename T>
operator T() {
    static_assert(std::is_default_constructible<T>::value, "T must be default constructible");
    static_assert(parseable<T>::value, "T must have a std::istream overload");
        
    //...
}
{% endhighlight %}

Of course, as with any technique which relies on implicit conversion, this comes with a ton of caveats and gotchas. For one, you can do some very strange things by saving the parser object and passing it around:

{% highlight cpp %}
//problem 1
const auto& p = parse();
int i = p;
std::string s = p;
{% endhighlight %}

Or you can copy the return value of `parse()`:

{% highlight cpp %}
//problem 2
auto p = parse();
int i = p;
std::string s = p;
{% endhighlight %}


Or default-construct a `parser`:

{% highlight cpp %}
//problem 3
parser p{};
int i = p;
std::string s = p;
{% endhighlight %}

To prevent the above, you could restrict `parser` to only be constructible by `parse`, only allow implicit conversion of rvalue `parser`s, and delete all of its copy and move operations.

{% highlight cpp %}
class parser {
public:
    template &lt;typename T&gt;
    operator T() &&;
    //problem 1  ^^

    //problem 2
    parser (const parser&) = delete; 
    parser& operator= (const parser&) = delete;
    
private:
    //problem 3
    parser(){}
    friend parser parse();
};
{% endhighlight %}

Particularly deviant users can still take a reference to it with `auto&& p = parse()` and implicitly convert using `std::move(p)`, but they deserve whatever befalls them as a result.

----------------------------

Perhaps you think that this trick is more trouble than its worth for a small example like the above. Mostly I just thought it was a cool trick to have in one's arsenal, but here are some real-world examples of templated conversion operators, some of which also use lazy generators.

* [`boost::nfp::named_parameter`](http://www.boost.org/doc/libs/1_62_0/libs/test/doc/html/header/boost/test/utils/named_params_hpp.html) uses this trick to trace misuses of invalid parameters.
* [`boost::python::override`](http://www.boost.org/doc/libs/1_50_0/libs/python/doc/v2/wrapper.html) uses it to implicitly convert objects returned from Python.
* [`boost::detail::winapi::detail`](http://www.boost.org/doc/libs/master/boost/detail/winapi/detail/cast_ptr.hpp) (quite the mouthful) uses it to allow implicit casting of pointer types for communication with the Windows SDK.
* [`boost::initialized_value`](http://www.boost.org/doc/libs/1_55_0/libs/utility/value_init.htm) uses the templated implicit conversion to provide a generic value initialization method to work around various compiler issues.
* [`boost::spirit::hold_any`](http://www.boost.org/doc/libs/1_51_0/boost/spirit/home/support/detail/hold_any.hpp) allows implicit conversion to any type rather than explicit casting in some configurations.
* [`boost::multiprecision::number`](http://www.boost.org/doc/libs/1_61_0/libs/multiprecision/doc/html/boost_multiprecision/ref/number.html) marks the operator `explicit` to only allow explicit casting.

I'm sure you could find many more uses for this technique for generic utilities, API adaption, embedded DSLs, etc.





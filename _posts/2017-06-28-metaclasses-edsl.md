---
layout:     post
title:      "Metaclasses for embedded domain specific languages"
category:   c++
tags:
 - c++
---

Metaclasses are a [proposed feature](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0707r0.pdf) to C++ which will allow the creation of abstractions over classes and the extension of the language's type definition system. As an example, consider this definition of `IShape`:

{% highlight cpp %}
class IShape {
public:
 virtual int area() const =0;
 virtual void scale_by(double factor) =0;
 // ... etc.
 virtual ~IShape() noexcept { };
};
{% endhighlight %}

This class is obviously defining an interface of some kind: all of the member functions are public, pure virtual, and it has a virtual destructor. Other classes will need to be added which inherit from this interface for it to be useful. But those properties I listed are really just boilerplate; it's just noise that we need to type to get the compiler to do The Right Thing&#8482. It would be a lot clearer and less error-prone if we could push the boilerplate aside and just focus on the details which are important to us. This is the essence of metaclasses. If there were a metaclass called `interface`, you could write something like this:

{% highlight cpp %}
interface IShape {
 int area() const;
 void scale_by(double factor);
};
{% endhighlight %}

I'm sure you'd agree this is a huge improvement over the last sample. The magic happens in the definition for the `interface` metaclass, which could look like this:

{% highlight cpp %}
$class interface {
  ~interface() noexcept { }
  constexpr {
    compiler.require($interface.variables().empty(),
                     "interfaces may not contain data");
    for (auto f : $interface.functions()) {
      compiler.require(!f.is_copy() && !f.is_move(),
                       "interfaces may not copy or move; consider a"
                       " virtual clone() instead");
      if (!f.has_access()) f.make_public();
      compiler.require(f.is_public(),
                       "interface functions must be public");
      f.make_pure_virtual();
    }
  }
};
{% endhighlight %}

The `~interface() noexcept { }` defines a destructor for instances of the metaclass; this is essentially a default implementation so that you don't need to type one yourself. Inside the `constexpr` block we have code to ensure that there are no data members and no copy or move constructors, and to change each function to be virtual and public. Be sure to read over this code a few times to really understand what it's doing. The first time I saw this code my mind was well and truly blown.

But enough of stealing examples from the paper. I've been interested in metaclasses since seeing Herb talk about them at ACCU 2017, and since then I've always been looking for places where they could make C++ programming safer, more elegant, more maintainable. In this post I'll talk about how they can aid creation of embedded domain specific languages.

------------------

### Embedded what?

Before I get into the meat of what I want to discuss, I have some terms to define.

A *domain specific language* (DSL) is a language which is specifically designed for some problem area. C++ is a general-purpose language because it can be used for solving any kind of programming problem. SQL is a domain-specific language because it is designed only for reading and manipulating databases.

An *embedded* DSL (EDSL) is a domain specific language hosted inside a more general language. For example, [Boost.Spirit](http://boost-spirit.com/home/) is a parser library which embeds a language for parsing code into C++ by using expression templates and operator overloading.

### My case study

The example I'm going to be using is from my [ETKF](https://github.com/TartanLlama/etkf) keyboard firmware library. A keyboard definition for ETKF looks like this:

{% highlight cpp %}
struct my_keyboard {
    using rows = pin_set<b4, b6, f1, f0>;
    using columns = pin_set<f6, f7, c7, c6, d3, d2, d1, d0, b7, b3, b2, b1, b0>;

    using key_positions = typelist<
        row<1,1,1,1,1,1,1,1,1,1,1,1,1>,
        row<1,1,1,1,1,1,1,1,1,1,1,0,1>,
        row<1,0,1,1,1,1,1,1,1,1,1,1,1>,
        row<1,1,1,0,1,1,0,1,1,1,1,1,1>
    >;

    using layouts = typelist<
        row<tab, quot,comm,dot, p,   y,   f,   g,   c,   r,   l,   bspc, null>,
        row<lctl,a,   o,   e,   u,   i,   d,   h,   t,   n,   s,   ent>,
        row<lsft,scln,q,   j,   k,   x,   b,   m,   w,   v,   z,   del>,
        row<caps,lgui,esc,lalt, spc,      null,null,left,down,up,  righ>
    >;
};
{% endhighlight %}

This is an EDSL which is hosted inside the C++ template system. It is very declarative in nature; the class declares how the switches are wired up, which parts of the switch matrix have holes in them, and how the keymap should look, but it doesn't say how the firmware should carry out any computations. We are declaring our problem at a high level of abstraction and the implementation of the library is in charge of mapping this abstraction onto real operations. There are no metaclasses in this example; the implementation is all in C++17. But what could metaclasses add to this?

The first improvement is as embarrassingly simple as it is expressive: changing `struct my_keyboard` to `keyboard my_keyboard`. Metaclasses allow us to express not only the name of our class, but also what kind of entity it is. If we had a bunch of declarations like this kicking around -- maybe some define processors, some define hardware pins -- having a strong indication of the classes' nature right in the declaration is powerful. `my_keyboard` is no longer a `struct`, it is no longer a `class`, it **is** a `keyboard`.

The second is in compiler diagnostics. When I was writing ETKF I wanted to toe the line between carrying out crazy compile-time optimisations and having a clean interface which even non-programmers could use. "This'll be great", I thought naively, "I'll just have a ton of `static_asserts` which run over the templates before generating the firmware code". This is indeed possible, but have a look at the resulting compiler errors:

```
In file included from /home/simon/etkf/src/main.cpp:17:0:
/home/simon/etkf/include/validations.hpp: In instantiation of 'void validate_layout(etkf::typelist<Rows ...>) [with Kbd = test_keyboard; Rows = {etkf::row<(etkf::keys::key)43, (etkf::keys::key)52, (etkf::keys::key)54, (etkf::keys::key)55, (etkf::keys::key)19, (etkf::keys::key)28, (etkf::keys::key)9, (etkf::keys::key)10, (etkf::keys::key)6, (etkf::keys::key)21, (etkf::keys::key)15, (etkf::keys::key)42, (etkf::keys::key)111>, etkf::row<(etkf::keys::key)100, (etkf::keys::key)4, (etkf::keys::key)18, (etkf::keys::key)8, (etkf::keys::key)24, (etkf::keys::key)12, (etkf::keys::key)7, (etkf::keys::key)11, (etkf::keys::key)23, (etkf::keys::key)17, (etkf::keys::key)22, (etkf::keys::key)40>, etkf::row<(etkf::keys::key)57, (etkf::keys::key)103, (etkf::keys::key)41, (etkf::keys::key)102, (etkf::keys::key)44, (etkf::keys::key)109, (etkf::keys::key)111, (etkf::keys::key)80, (etkf::keys::key)81, (etkf::keys::key)82, (etkf::keys::key)79>}]':
/home/simon/etkf/include/validations.hpp:14:26:   required from 'void validate_layouts(etkf::typelist<Rows ...>) [with Kbd = test_keyboard; Layouts = {etkf::typelist<etkf::row<(etkf::keys::key)43, (etkf::keys::key)52, (etkf::keys::key)54, (etkf::keys::key)55, (etkf::keys::key)19, (etkf::keys::key)28, (etkf::keys::key)9, (etkf::keys::key)10, (etkf::keys::key)6, (etkf::keys::key)21, (etkf::keys::key)15, (etkf::keys::key)42, (etkf::keys::key)111>, etkf::row<(etkf::keys::key)100, (etkf::keys::key)4, (etkf::keys::key)18, (etkf::keys::key)8, (etkf::keys::key)24, (etkf::keys::key)12, (etkf::keys::key)7, (etkf::keys::key)11, (etkf::keys::key)23, (etkf::keys::key)17, (etkf::keys::key)22, (etkf::keys::key)40>, etkf::row<(etkf::keys::key)57, (etkf::keys::key)103, (etkf::keys::key)41, (etkf::keys::key)102, (etkf::keys::key)44, (etkf::keys::key)109, (etkf::keys::key)111, (etkf::keys::key)80, (etkf::keys::key)81, (etkf::keys::key)82, (etkf::keys::key)79> >, etkf::typelist<etkf::row<(etkf::keys::key)43, (etkf::keys::key)30, (etkf::keys::key)31, (etkf::keys::key)32, (etkf::keys::key)33, (etkf::keys::key)34, (etkf::keys::key)35, (etkf::keys::key)36, (etkf::keys::key)37, (etkf::keys::key)38, (etkf::keys::key)39, (etkf::keys::key)42, (etkf::keys::key)111>, etkf::row<(etkf::keys::key)100, (etkf::keys::key)47, (etkf::keys::key)48, (etkf::keys::key)56, (etkf::keys::key)46, (etkf::keys::key)45, (etkf::keys::key)50, (etkf::keys::key)49, (etkf::keys::key)53, (etkf::keys::key)17, (etkf::keys::key)22, (etkf::keys::key)40>, etkf::row<(etkf::keys::key)101, (etkf::keys::key)58, (etkf::keys::key)59, (etkf::keys::key)60, (etkf::keys::key)61, (etkf::keys::key)62, (etkf::keys::key)63, (etkf::keys::key)64, (etkf::keys::key)65, (etkf::keys::key)66, (etkf::keys::key)67, (etkf::keys::key)76>, etkf::row<(etkf::keys::key)57, (etkf::keys::key)103, (etkf::keys::key)41, (etkf::keys::key)102, (etkf::keys::key)44, (etkf::keys::key)109, (etkf::keys::key)111, (etkf::keys::key)80, (etkf::keys::key)81, (etkf::keys::key)82, (etkf::keys::key)79> >, etkf::typelist<etkf::row<(etkf::keys::key)43, (etkf::keys::key)20, (etkf::keys::key)26, (etkf::keys::key)8, (etkf::keys::key)21, (etkf::keys::key)23, (etkf::keys::key)28, (etkf::keys::key)24, (etkf::keys::key)12, (etkf::keys::key)18, (etkf::keys::key)19, (etkf::keys::key)42, (etkf::keys::key)111>, etkf::row<(etkf::keys::key)100, (etkf::keys::key)4, (etkf::keys::key)22, (etkf::keys::key)7, (etkf::keys::key)9, (etkf::keys::key)10, (etkf::keys::key)11, (etkf::keys::key)13, (etkf::keys::key)14, (etkf::keys::key)15, (etkf::keys::key)51, (etkf::keys::key)40>, etkf::row<(etkf::keys::key)101, (etkf::keys::key)29, (etkf::keys::key)27, (etkf::keys::key)6, (etkf::keys::key)25, (etkf::keys::key)5, (etkf::keys::key)17, (etkf::keys::key)16, (etkf::keys::key)54, (etkf::keys::key)55, (etkf::keys::key)56, (etkf::keys::key)76>, etkf::row<(etkf::keys::key)57, (etkf::keys::key)103, (etkf::keys::key)41, (etkf::keys::key)102, (etkf::keys::key)44, (etkf::keys::key)109, (etkf::keys::key)111, (etkf::keys::key)80, (etkf::keys::key)81, (etkf::keys::key)82, (etkf::keys::key)79> >}]'
/home/simon/etkf/include/validations.hpp:19:26:   required from 'void validate_keyboard() [with Kbd = test_keyboard]'
/home/simon/etkf/src/main.cpp:267:44:   required from here
/home/simon/etkf/include/validations.hpp:8:5: error: static assertion failed: A layout has the wrong number of rows
     static_assert(sizeof...(Rows) == variadic_size<typename Kbd::rows>::value,
```

Yeah.

I got my wish of a nice little assert message at the bottom which tells you exactly what you did wrong, but if you're not a seasoned C++ developer you don't get that far. You run. Fast.

However, with the help of metaclasses and `requires` clauses from concepts, we could write something like this[^1]:

{% highlight cpp %}
$class keyboard {
    constexpr {
        compiler.require(requires(keyboard kbd) { keyboard::layouts{}; },
                         "must have type 'layouts'");
        compiler.require(requires(keyboard kbd) { keyboard::rows{}; },
                         "must have type 'rows'");
        compiler.require(requires(keyboard kbd) { keyboard::columns{}; },
                         "must have type 'columns'");
        compiler.require(requires(keyboard kbd) { keyboard::key_positions{}; },
                         "must have type 'key_positions'");

        if (!all_types<keyboard::key_positions> ([](auto type){
                return variadic_size<decltype(type)::type> == variadic_size<keyboard::columns>;
            })) {
            compiler.error("Each row of 'key_positions' must be the same size as 'columns'");
            compiler.error("Check the definition of 'key_positions' here",
                           $(keyboard::key_positions).source_location());
            compiler.error("Check the definition of 'columns' here",
                           $(keyboard::columns).source_location());
        }
    }
}
{% endhighlight %}

[^1]: There's not an implementation fully-featured enough to compile this yet, but it seems to be in line with the paper's definition.

Now the validations are run as part of generating a class from the metaclass, and the diagnostics should be placed depending on the source location which is given to the `compiler.error` calls. With sufficiently fine-grained control over the placement of diagnostics, all error messages can be emitted **at the abstraction level of the EDSL** rather than having C++ template guff injecting itself into the party.

The above also somewhat addresses problem of cohesion and code locality. In my C++17 ETKF implementation, the validations which are run over the keyboard descriptions are quite separate from the code which generates the firmware from the template declarations. But really, these are both part of the abstraction which I'm trying to express in the interface. Metaclasses provide a means to tie together the constraints on the declaration as well as the code which lowers the EDSL into normal C++ land.

---------------------

That's it for my contribution to the metaclass hype train. Maybe I'll write some more posts as I come up with more ideas, but I'm particularly interested in exploring the design space for declarative EDSLs in C++. Templates are a powerful host for other languages, and metafunctions only make them more so.

---------------------

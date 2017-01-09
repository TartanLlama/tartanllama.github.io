---
layout:     post
title:      "The effect of a try-catch-rethrow"
category:   c++
tags:
 - c++ 
---

A try-catch-rethrow with an empty handler does more than a standard block. Here's what I mean:

{% highlight cpp %}
{
    //Some code which may throw
}
{% endhighlight %}


{% highlight cpp %}
try {
    //Some code which may throw
} catch(...) {
    throw;
}
{% endhighlight %}

Under some circumstances, these two forms are different. Specifically, the latter necessitates stack unwinding, whereas for the former it is implementation-defined whether or not the stack is unwound. The relevant standards quotes:

> As control passes from a *throw-expression* to a handler, destructors are invoked for all automatic objects constructed since the try block was entered. The automatic objects are destroyed in the reverse order of the completion of their construction.
{:.standards para="[except.ctor]/1"}

> The process of calling destructors for automatic objects constructed on the path from a try block to a *throw-expression* is called “stack unwinding.” [...]
{:.standards para="[except.ctor]/3"}

The above paragraphs mandate stack unwinding when control passes to the handler (the `catch` block).

> In some situations exception handling must be abandoned for less subtle error handling techniques. [Notes]
>
> In such cases, `std::terminate()` is called (18.8.3). **In the situation where no matching handler is found, it is implementation-defined whether or not the stack is unwound before `std::terminate()` is called**. [...]
{:.standards para="[except.terminate]/1-2"}

As such, if you want to guarantee that your automatic objects have their destructors run in the case of an unhandled exception (e.g. some persistent storage must be mutated on destruction) then `try {/*code*/} catch (...) {throw;}` will do that, but `{/*code*/}` will not.

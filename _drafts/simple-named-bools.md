---
layout:     post
title:      "Super Simple Named Boolean Parameters"
category:   c++
tags:
 - c++
---

Quite often we come across interfaces with multiple boolean parameters, like this:

```cpp
cake make_cake (bool with_dairy, bool chocolate_sauce, bool poison);
```

A call to this function might look like:

```cpp
auto c = make_cake(true, true, false);
```

Unfortunately, this is not very descriptive. We need to look at the declaration of the function to know what each of those `bool`s mean, and it would be _way_ too easy to accidentally flip the wrong argument during maintainance and end up poisoning ourselves rather than having a chocolatey treat.

There are many solutions which people use, from just adding comments to each argument, to creating tagged types. I recently came across a very simple trick which I had not seen before:

```cpp
#define K(name) true
```

Yep, it's a macro which takes an argument and gets replaced by `true`. This may look strange, but it enables us to write this:

```cpp
auto c = make_cake(K(with_dairy), !K(chocolate_sauce), !K(poison));

// or using `not` if you prefer
auto c = make_cake(K(with_dairy), not K(chocolate_sauce), not K(poison));
```

Of course, it's up to you whether you think using a macro for this kind of thing is worth it, or if you think that macro should have a name which is less likely to collide. Personally I think it's quite a neat trick to solve this issue in a low-overhead manner.

A guess I need to come up with a marketing name for this. Since we already have [X Macros](https://en.wikipedia.org/wiki/X_Macro), I hereby dub this trick "K Macros".



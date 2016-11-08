---
layout:     post
title:      "You can't call a constructor in C++"
summary:    Stop saying that.
category:   c++
tags:
 - c++ 
 - rant
---

{% highlight cpp %}
#include <type_traits>
#include <memory>
#include <iostream>

template<typename... Types>
class variant
{
    using storage_t = std::aligned_union_t<0u, Types...>;
    storage_t m_storage;
    int m_type_index;

    /* creation of content */
    template<typename T> void set_value (T const & value);

    /* destruction of content */
    void destroy_current_data();

public:
    variant() = delete;
    template<typename T> variant(T value)  {
        set_value(value);
    }

    template<typename T> variant & operator=(T & value) {
        destroy_current_data();
        set_value(value);
        return *this;
    }

    ~variant() {
        destroy_data();
    }
};

/* tests */
int main()
{
    variant<int, std::string> var_test_2(42);
    var_test_2 = std::string("Hello again !");

    return 0; // it crashes when the destructor of var_test_2 is called
}
{% endhighlight %}

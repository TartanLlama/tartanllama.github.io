

{% highlight cpp %}
#include <iostream>
#include <memory>

struct member {
    void foo(){std::cout << __PRETTY_FUNCTION__;}
};

struct non_member{};

void foo(const non_member&){std::cout << __PRETTY_FUNCTION__;}

struct no_foo{};

struct fooable {
    struct storage {
        virtual void docall() = 0;  
    };
    
    template <typename T, typename=void>
    struct has_member_foo : std::false_type{};
    
    template <typename T>
    struct has_member_foo<T,std::void_t<decltype(std::declval<T>().foo())>> : std::true_type{};
    
    template <typename T, bool HasMemberFoo = has_member_foo<T>::value>
    struct storage_impl : storage {
        T m_t;
    
        storage_impl (T t) : m_t {std::move(t)} {}
    
        void docall() override {
            m_t.foo();
        }
    };
    
    template <typename T>
    fooable (T t) : m_storage{std::make_unique<storage_impl<T>>(std::move(t))} {}
    
    friend void foo(const fooable& f) { f.m_storage->docall(); }
    
    std::unique_ptr<storage> m_storage;
};

template <typename T>
struct fooable::storage_impl<T,false> : storage {
    T m_t;
        
    storage_impl (T t) : m_t {std::move(t)} {}
    
    void docall() override {
        foo(m_t);
    }
};

int main () {
    fooable mem_foo {member{}};
    fooable non_mem_foo {non_member{}};
    member{}.foo();
    foo(non_member{});
    foo(mem_foo);
    foo(non_mem_foo);
}
{% endhighlight %}

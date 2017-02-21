---
layout:     post
title:      "Template template template template parameters"
category:   c++
tags:
 - c++
---

#include <vector>

template <template <class...> class T, class... Us>
struct inject {
    using type = T<Us...>;
    };

template <template <template <class...> class, class...> class T,
          template <class...> class U>
          struct inject_template {
              template <class... V>
                  using type = typename T<U,V...>::type;
                  };

template <template <template <template <class...> class, class...> class,
          template <class...> class> class T,
                    template <template <class...> class, class...> class U>
                    struct inject_template_template {
                        template <template <class...> class V>
                            struct type {
                                    template <class... W>
                                            using type = typename T<U,V>::template type<W...>;
                                                };
                                                };

template <typename T> using eval = typename T::type;

template<typename>struct TC;

int main() {
    TC<eval<inject<std::vector, int>>>{};
        TC<inject_template<inject, std::vector>::type<int>>{};
            TC<inject_template_template<inject_template, inject>::type<std::vector>::type<int>>{};
            }


$class keyboard {
    constexpr {
        compiler.require(requires(keyboard kbd) { keyboard::layouts(); }, "must have function 'layouts'");
        compiler.require(requires(keyboard kbd) { keyboard::rows{}; }, "must have type 'rows'");
        compiler.require(requires(keyboard kbd) { keyboard::columns{}; }, "must have type 'columns'");
        compiler.require(requires(keyboard kbd) { keyboard::key_positions{}; }, "must have type 'key_positions'");
        compiler.require(all_types<keyboard::key_positions>
                           ([](auto type){return variadic_size<decltype(type)::type> == variadic_size<keyboard::columns>;}),
                         "Each row of 'key_positions' must be the same size as 'columns'",
                         $(keyboard::key_positions).source_location());
        compiler.require(all_types<keyboard::key_positions, decltype(keyboard::layout())>,
                           ([](auto pos_t, auto layout_type) {
                               return variadic_size(pos_t) == count_ones(layout_type);
                            }),
                         "Each row of 'layout' must have the same number of keys as there are '1's in the corresponding 'key_positions' row",
                         $(keyboard::layout).source_location());
    }
}

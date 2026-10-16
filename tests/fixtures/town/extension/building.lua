kind = "registry"
registry = "buildings"
buildings = { loop_shop = {
 area = "hyggebyen", kind = "shop", name_key = "BLD_LOOP_SHOP", interior = "int_loop_shop", size = "M",
 keeper = "loop_neighbour", shop = "loop_shop", post = "int_loop_shop.counter",
 hours = { open = 9, close = 21, closed = { 5 } }, wave = "ext",
} }

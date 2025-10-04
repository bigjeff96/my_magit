package my_magit

import "core:fmt"
import "core:terminal/ansi"
import "core:strings"

main :: proc() {
    ctx := tui_ctx_init(context.temp_allocator)

    for {
        move_cursor(&ctx, 50, 50)
        erase_right_down(&ctx)
        tui_flush(&ctx)
    }
}


//TODO: Deal with the timing stuff or refreshing the screen when something happens, which seems
// more complicated than necessary

package my_magit

import "core:fmt"
import "core:terminal/ansi"
import "core:strings"

main :: proc() {
    ctx := tui_ctx_init(context.temp_allocator)
    rows, cols := ctx.rows, ctx.cols
    for {
        tui_start(&ctx)
        clear_screen(&ctx)
        move_cursor(&ctx, rows / 2, cols /2)
        fmt.sbprint(&ctx.builder, "HELLO JEFF")
        tui_flush(&ctx)
    }
}

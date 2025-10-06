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
        write_at(&ctx, rows / 2, cols / 2, "HELLO JEFF")
        write_at(&ctx, 0, 0, "BOO")
        tui_flush(&ctx)
    }
}

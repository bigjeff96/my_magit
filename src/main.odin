package my_magit

import "core:fmt"
import "core:terminal/ansi"
import "core:strings"

main :: proc() {
    ctx := tui_ctx_init(context.temp_allocator)
    for {
        tui_start(ctx)
        clear_screen(ctx)
        write_at(ctx, ctx.rows / 2, ctx.cols / 2, "HELLO JEFF")
        write_at(ctx, 0, 0, "BOO")
        tui_flush(ctx)
    }

    tui_end(ctx)
}

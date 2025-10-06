package my_magit

import "core:strings"
import "core:terminal/ansi"
import "core:mem"
import "core:time"
import "core:sys/linux"
import "core:fmt"
import "core:c"

//NOTE: this only works if we start the program in an already running terminal
linux_get_window_size :: proc() -> (rows, cols: int) {
    winsize :: struct {
        ws_row: c.ushort, // rows, in characters
        ws_col: c.ushort, // col, in characters
        ws_xpixel: c.ushort, // horizontal size, pixels
        ws_ypixel: c.ushort, // vertical size, pixels
    }
    TIOCGWINSZ :: 0x5413 // request to get the window size

    terminal_window: winsize

    ret := linux.ioctl(linux.STDOUT_FILENO, TIOCGWINSZ, cast(uintptr)(&terminal_window))

    rows = auto_cast terminal_window.ws_row
    cols = auto_cast terminal_window.ws_col
    return
}
//TODO: find out how to use signals to find when the terminal is resized


Tui_ctx :: struct {
    builder: strings.Builder,
    rows: int,
    cols: int,
    tick: time.Tick,
}

tui_ctx_init :: proc(allocator := context.allocator) -> Tui_ctx {
    assert(ODIN_OS == .Linux)
    rows, cols := linux_get_window_size()
    return Tui_ctx{
        builder = strings.builder_make(allocator),
        rows = rows,
        cols = cols,
    }
}

SEP :: ";"

move_cursor :: proc(ctx: ^Tui_ctx, row, col: int) {
    row := row + 1
    col := col + 1
    fmt.sbprintf(&ctx.builder, ansi.CSI + "%d" + SEP + "%d" + ansi.CUP, row, col)
}

erase_right_down :: proc(ctx: ^Tui_ctx) {
    fmt.sbprint(&ctx.builder, ansi.CSI + "0" + ansi.ED)
}

clear_screen :: proc(ctx: ^Tui_ctx) {
    move_cursor(ctx, 0, 0)
    erase_right_down(ctx)
}

tui_start :: proc(ctx: ^Tui_ctx) {
    //NOTE: nothing, for now
}

tui_flush :: proc(ctx: ^Tui_ctx) {
    duration := time.tick_lap_time(&ctx.tick)
    if duration < FRAME_DURATION_NANO {
        time.accurate_sleep(FRAME_DURATION_NANO - duration)
    }

    fmt.print(strings.to_string(ctx.builder), flush = true)
    strings.builder_reset(&ctx.builder)
}

FRAME_DURATION_NANO :: time.Duration(33333333) // 30 fps
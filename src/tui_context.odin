package my_magit

import "base:runtime"
import "base:intrinsics"
import "core:sys/posix"
import "core:strings"
import "core:terminal/ansi"
import "core:mem"
import "core:time"
import "core:sys/linux"
import "core:fmt"
import "core:c"
import core_log "core:log"
import os "core:os/os2"

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


//TODO: how to determine keyboard/mouse events for the terminal
//TODO: when sigint is received, close the log file

@(private="file")
current_tui_ctx: ^Tui_ctx

original_termios: posix.termios


Tui_ctx :: struct {
    builder: strings.Builder,
    rows: int,
    cols: int,
    tick: time.Tick,
    window_resize: bool,
    logger: core_log.Logger,
}

handle_terminal_resize :: proc "c" (signal: posix.Signal) {
    // posix.sigaction(auto_cast posix.SIGWINCH, nil, nil)
    intrinsics.atomic_store(&current_tui_ctx.window_resize, true)
    return
}

handle_terminal_sigint :: proc "c" (signal: posix.Signal) {
    context = runtime.default_context()
    assert(signal == auto_cast posix.SIGINT)
    fmt.print(ansi.CSI + ansi.DECTCEM_SHOW, flush = true)
    fmt.print(ansi.CSI + "1" + SEP + "1" + ansi.CUP, flush = true)
    fmt.print(ansi.CSI + "0" + ansi.ED, flush = true)
    ok1 := posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &original_termios)
    assert(ok1 == .OK)
    os.exit(0)
}

tui_ctx_init :: proc(allocator := context.allocator) -> ^Tui_ctx {
    assert(ODIN_OS == .Linux)

    file, err := os.create("my_magit_logs.txt")
    assert(err == nil)

    logger := core_log.create_file_logger(auto_cast os.fd(file))
    window_resize_sigaction : posix.sigaction_t
    window_resize_sigaction.sa_handler = handle_terminal_resize
    posix.sigemptyset(&window_resize_sigaction.sa_mask)
    window_resize_sigaction.sa_flags = {}
    ret := posix.sigaction(auto_cast posix.SIGWINCH, &window_resize_sigaction, nil)
    assert(ret == .OK)
    ret1 := posix.sigaction(auto_cast posix.SIGINT, &{sa_handler = handle_terminal_sigint}, nil)
    assert(ret1 == . OK)

    rows, cols := linux_get_window_size()
    current_tui_ctx = new(Tui_ctx)
    current_tui_ctx.builder = strings.builder_make(allocator)
    current_tui_ctx.rows = rows
    current_tui_ctx.cols = cols
    current_tui_ctx.logger = logger

    log("tui with", rows,"rows and", cols, "cols")
    return current_tui_ctx
}

SEP :: ";"

hide_cursor :: proc(ctx: ^Tui_ctx) {
    fmt.sbprintf(&ctx.builder, ansi.CSI + ansi.DECTCEM_HIDE)
}

show_cursor :: proc(ctx: ^Tui_ctx) {
    fmt.sbprintf(&ctx.builder, ansi.CSI + ansi.DECTCEM_SHOW)
}

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

write_at :: proc(ctx: ^Tui_ctx, row, col: int, txt: string) {
    move_cursor(ctx, row, col)
    fmt.sbprint(&ctx.builder, txt)
}

tui_start :: proc(ctx: ^Tui_ctx) {
    if ctx.window_resize {
        ctx.rows, ctx.cols = linux_get_window_size()
        log("resized to ", ctx.rows, ctx.cols)
        ctx.window_resize = false
    }
}

tui_flush :: proc(ctx: ^Tui_ctx) {
    duration := time.tick_lap_time(&ctx.tick)
    if duration < FRAME_DURATION_NANO {
        time.accurate_sleep(FRAME_DURATION_NANO - duration)
    }
    fmt.print(strings.to_string(ctx.builder), flush = true)
    strings.builder_reset(&ctx.builder)
}

tui_end :: proc(ctx: ^Tui_ctx) {
    core_log.destroy_file_logger(context.logger)
}

@(private="file")
log :: proc(args: ..any, sep := " ", location := #caller_location) {
    context.logger = current_tui_ctx.logger
    core_log.debug(args, sep, location)
}

@(private="file")
logf :: proc(fmt_str: string, args: ..any, location := #caller_location) {
    context.logger = current_tui_ctx.logger
    core_log.debugf(fmt_str, args, location)
}

FRAME_DURATION_NANO :: time.Duration(33333333) // 30 fps

//TODO: how to dynamically change the frame rate of the terminal depends on the events from the
// user or the terminal or changes in the file-system?

//---------------------------------------------

//TODO: how does raw mode affect the signals the terminal will receive?


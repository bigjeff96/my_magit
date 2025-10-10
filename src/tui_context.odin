package my_magit

import "base:runtime"
import "core:sys/posix"
import "core:strings"
import "core:terminal/ansi"
import "core:mem"
import "core:time"
import "core:sys/linux"
import "core:fmt"
import "core:c"
import "core:log"
import os "core:os/os2"


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


//TODO: how to save and restore cursor position
//TODO: find what is raw mode for the terminal
//TODO: how to determine keyboard/mouse events for the terminal
//TODO: write logs into a temp file then use tail -F on that file to get logging outside of the terminal

@(private="file")
current_tui_ctx: ^Tui_ctx


Tui_ctx :: struct {
    builder: strings.Builder,
    rows: int,
    cols: int,
    tick: time.Tick,
    window_resize: bool,
    logger: log.Logger,
}

handle_terminal_resize :: proc "c" (signal: posix.Signal) {
    context = runtime.default_context()
    assert(signal == auto_cast posix.SIGWINCH)
    current_tui_ctx.window_resize = true
}

tui_ctx_init :: proc(allocator := context.allocator) -> ^Tui_ctx {
    assert(ODIN_OS == .Linux)

    file, err := os.open("my_magit_logs.txt", {.Read, .Write, .Create}, 0o666)
    assert(err == nil)

    logger := log.create_file_logger(auto_cast os.fd(file))
    ret := posix.sigaction(auto_cast posix.SIGWINCH, &{sa_handler = handle_terminal_resize}, nil)
    assert (ret == .OK)

    rows, cols := linux_get_window_size()
    current_tui_ctx = new(Tui_ctx)
    current_tui_ctx.builder = strings.builder_make(allocator)
    current_tui_ctx.rows = rows
    current_tui_ctx.cols = cols
    current_tui_ctx.logger = logger

    log.debug("tui with", rows,"rows and", cols, "cols")
    return current_tui_ctx
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

write_at :: proc(ctx: ^Tui_ctx, row, col: int, txt: string) {
    move_cursor(ctx, row, col)
    fmt.sbprint(&ctx.builder, txt)
}

tui_start :: proc(ctx: ^Tui_ctx) {
    context.logger = ctx.logger
    if ctx.window_resize {
        ctx.rows, ctx.cols = linux_get_window_size()
        log.debug("resized to ", ctx.rows, ctx.cols)
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
    log.destroy_file_logger(context.logger)
}

FRAME_DURATION_NANO :: time.Duration(33333333) // 30 fps

//TODO: how to dynamically change the frame rate of the terminal depends on the events from the
// user or the terminal or changes in the file-system?

//---------------------------------------------

//TODO: how to catch a SIGINT signal
//TODO: how does raw mode affect the signals the terminal will receive?

/*
Probing for flag support
       The following example program exits with status EXIT_SUCCESS if
       SA_EXPOSE_TAGBITS is determined to be supported, and EXIT_FAILURE
       otherwise.

       #include <signal.h>
       #include <stdio.h>
       #include <stdlib.h>
       #include <unistd.h>

       static void
       handler(int signo, siginfo_t *info, void *context)
       {
           struct sigaction oldact;

           if (sigaction(SIGSEGV, NULL, &oldact) == -1
               || (oldact.sa_flags & SA_UNSUPPORTED)
               || !(oldact.sa_flags & SA_EXPOSE_TAGBITS))
           {
               _exit(EXIT_FAILURE);
           }
           _exit(EXIT_SUCCESS);
       }

       int
       main(void)
       {
           struct sigaction act = { 0 };

           act.sa_flags = SA_SIGINFO | SA_UNSUPPORTED | SA_EXPOSE_TAGBITS;
           act.sa_sigaction = &handler;
           if (sigaction(SIGSEGV, &act, NULL) == -1) {
               perror("sigaction");
               exit(EXIT_FAILURE);
           }

           raise(SIGSEGV);
       }
*/


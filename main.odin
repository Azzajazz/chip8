package chip8

import "core:mem"
import rl "vendor:raylib"

Emulator :: struct {
    memory: [4096]u8, // 4KB of RAM
    display: [64 * 32]u8,

    // Addressable memory is only 12 bits
    pc: u16,
    i: u16,

    stack: [dynamic]u16, //@TODO: Is this supposed to be fixed size?
    delay_timer: u64, //@TODO: What is the maximum value here?
    sound_timer: u64, //@TODO: What is the maximum value here?

    // @TODO: Should these be in an array?
    v0: u8,
    v1: u8,
    v2: u8,
    v3: u8,
    v4: u8,
    v5: u8,
    v6: u8,
    v7: u8,
    v8: u8,
    v9: u8,
    v10: u8,
    v11: u8,
    v12: u8,
    v13: u8,
    v14: u8,
    v15: u8,
}

hz_to_ms :: proc(hz: f32) -> f32 {
    return 1000/hz
}

init_emulator :: proc(emulator: ^Emulator) {
    font_data := [?]u8 {
        0xf0, 0x90, 0x90, 0x90, 0xf0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xf0, 0x10, 0xf0, 0x80, 0xf0, // 2
        0xf0, 0x10, 0xf0, 0x10, 0xf0, // 3
        0x90, 0x90, 0xf0, 0x10, 0x10, // 4
        0xf0, 0x80, 0xf0, 0x10, 0xf0, // 5
        0xf0, 0x80, 0xf0, 0x90, 0xf0, // 6
        0xf0, 0x10, 0x20, 0x40, 0x40, // 7
        0xf0, 0x90, 0xf0, 0x90, 0xf0, // 8
        0xf0, 0x90, 0xf0, 0x10, 0xf0, // 9
        0xf0, 0x90, 0xf0, 0x90, 0x90, // A
        0xe0, 0x90, 0xe0, 0x90, 0xe0, // B
        0xf0, 0x80, 0x80, 0x80, 0xf0, // C
        0xe0, 0x90, 0x90, 0x90, 0xe0, // D
        0xf0, 0x80, 0xf0, 0x80, 0xf0, // E
        0xf0, 0x80, 0xf0, 0x80, 0x80  // F
    }

    mem.copy_non_overlapping(&emulator.memory[0x50], &font_data[0], size_of(font_data))
}

main :: proc() {
    emulator: Emulator
    init_emulator(&emulator)

    rl.SetTargetFPS(60)
    rl.InitWindow(800, 600, "Chip8")

    decode_loop_ms := hz_to_ms(700)
    decode_loop_counter: f32 = 0
    for !rl.WindowShouldClose() {
        decode_loop_counter += rl.GetFrameTime() * 1000
        if decode_loop_counter > decode_loop_ms {
            decode_loop_counter -= decode_loop_ms
        }
        rl.BeginDrawing()
        rl.EndDrawing()
    }
    rl.CloseWindow()
}

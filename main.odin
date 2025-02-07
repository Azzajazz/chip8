package chip8

import "core:mem"
import "core:thread"
import "core:fmt"
import "core:time"

import rl "vendor:raylib"

Emulator :: struct {
    memory: [4096]u8, // 4KB of RAM
    display: [64 * 32]u8,

    // Addressable memory is only 12 bits
    pc: u16,
    i: u16,

    stack: [dynamic]u16, //@TODO: Is this supposed to be fixed size?
    delay_timer: u8,
    sound_timer: u8,

    registers: [16]u8,
}

hz_to_ns :: proc(hz: i64) -> i64 {
    return 1e9/hz
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

    //@TODO: Load program into memory
}

get_imm_12 :: #force_inline proc(instr: u16) -> u16 {
    return instr & 0xfff
}

get_imm_8 :: #force_inline proc(instr: u16) -> u8 {
    return instr & 0xff
}

get_imm_4 :: #force_inline proc(instr: u16) -> u8 {
    return instr & 0xf
}

get_x :: #force_inline proc(instr: u16) -> u8 {
    return instr >> 8 & 0xf
}

get_y :: #force_inline proc(instr: u16) -> u8 {
    return inst >> 4 & 0xf
}

decode_and_execute :: proc(data: rawptr) {
    emulator := cast(^Emulator)data
    ns_between_decodes := cast(time.Duration)hz_to_ns(700)

    for {
        start_time := time.now()

        /* FETCH */
        // The native encoding is little endian, but CHIP-8 architecture is big endian.
        first_byte := emulator.memory[emulator.pc]
        second_byte := emulator.memory[emulator.pc + 1]
        instruction := cast(u16)second_byte << 8 | cast(u16)first_byte
        emulator.pc += 2

        /* DECODE + EXECUTE */
        if instruction == 0x00E0 {
            // Clear the screen here
        }
        else {
            op_code := instruction >> 20
            switch (op_code) {
                case 0x1:
                    emulator.pc := get_imm_12(instruction)

                case 0x6:
                    reg := get_x(instruction)
                    emulator.registers[reg] = get_imm_8(instruction)

                case 0x7:
                    reg := get_x(instruction)
                    emulator.registers[reg] += get_imm_8(instruction)

                case 0xa:
                    emulator.i = get_imm_12(instruction)

                case 0xd:
                    // Display execution here
            }
        }

        switch

        /* EXECUTE */

        end_time := time.now()
        diff_time := time.diff(start_time, end_time)
        start_time = end_time
        time.accurate_sleep(ns_between_decodes - diff_time) // Sleep for one second
    }
}

main :: proc() {
    emulator: Emulator
    init_emulator(&emulator)

    rl.SetTargetFPS(60)
    rl.InitWindow(800, 600, "Chip8")

    decode_thread := thread.create_and_start_with_data(&emulator, decode_and_execute)
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.EndDrawing()
    }

    thread.terminate(decode_thread, 0)
    rl.CloseWindow()
}

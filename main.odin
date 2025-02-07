package chip8

import "core:mem"
import "core:thread"
import "core:fmt"
import "core:time"
import "core:sync"
import "core:os"

import rl "vendor:raylib"

DISPLAY_WIDTH :: 64
DISPLAY_HEIGHT :: 32

FONT_START :: 0x50

Emulator :: struct {
    memory: [4096]u8, // 4KB of RAM
    display: [DISPLAY_HEIGHT][DISPLAY_WIDTH]bool,
    display_mutex: sync.Mutex,

    // Addressable memory is only 12 bits
    pc: u16,
    i_reg: u16,

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

    mem.copy_non_overlapping(&emulator.memory[FONT_START], &font_data[0], size_of(font_data))
}

dump_emulator :: proc(emulator: ^Emulator) {
    fmt.println("Registers:")
    fmt.printfln("  PC = %x", emulator.pc)
    fmt.printfln("  I  = %x", emulator.i_reg)
    for reg, i in emulator.registers {
        fmt.printfln("  V%v = %x", i, reg)
    }

    fmt.println("Display:")
    for y := 0; y < DISPLAY_HEIGHT; y += 1 {
        for x := 0; x < DISPLAY_WIDTH; x += 1 {
            if emulator.display[y][x] {
                fmt.print("1 ")
            }
            else {
                fmt.print("0 ")
            }
        }
        fmt.println()
    }
}

dump_program :: proc(program: []u8) {
    for i := 0; i < len(program); i += 2 {
        instruction := cast(u16)program[i] << 8 | cast(u16)program[i + 1]
        fmt.printfln("%04x", instruction)
    }
}

load_program :: proc(emulator: ^Emulator, file: string) -> bool {
    file_data, did_read := os.read_entire_file(file)
    if !did_read do return false
    dump_program(file_data)

    mem.copy_non_overlapping(&emulator.memory[0x200], &file_data[0], len(file_data))
    emulator.pc = 0x200
    return true
}

get_imm_12 :: #force_inline proc(instr: u16) -> u16 {
    return instr & 0xfff
}

get_imm_8 :: #force_inline proc(instr: u16) -> u16 {
    return instr & 0xff
}

get_imm_4 :: #force_inline proc(instr: u16) -> u16 {
    return instr & 0xf
}

get_x :: #force_inline proc(instr: u16) -> u16 {
    return instr >> 8 & 0xf
}

get_y :: #force_inline proc(instr: u16) -> u16 {
    return instr >> 4 & 0xf
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
        instruction := cast(u16)first_byte << 8 | cast(u16)second_byte
        emulator.pc += 2

        /* DECODE + EXECUTE */
        if instruction == 0x00E0 {
            // Clear the screen
        }
        else if instruction == 0 {
            thread.yield()
            emulator.pc -= 2
        }
        else {
            op_code := instruction >> 12
            switch op_code {
                case 0x1:
                    emulator.pc = get_imm_12(instruction)

                case 0x3:
                    x_value := emulator.registers[get_x(instruction)]
                    if x_value == cast(u8)get_imm_8(instruction) do emulator.pc += 2

                case 0x4:
                    x_value := emulator.registers[get_x(instruction)]
                    if x_value != cast(u8)get_imm_8(instruction) do emulator.pc += 2

                case 0x5:
                    x_value := emulator.registers[get_x(instruction)]
                    y_value := emulator.registers[get_y(instruction)]
                    if x_value == y_value do emulator.pc += 2

                case 0x6:
                    emulator.registers[get_x(instruction)] = cast(u8)get_imm_8(instruction)

                case 0x7:
                    emulator.registers[get_x(instruction)] += cast(u8)get_imm_8(instruction)

                case 0x8:
                    switch get_imm_4(instruction) {
                        case 0x5:
                            y_value := emulator.registers[get_y(instruction)]
                            emulator.registers[get_x(instruction)] -= y_value
                        case:
                            fmt.panicf("Unknown sub-instruction for opcode 8 %v", get_imm_4(instruction))                            
                    }

                case 0xa:
                    emulator.i_reg = get_imm_12(instruction)

                case 0xd: {
                    sync.lock(&emulator.display_mutex)

                    x := emulator.registers[get_x(instruction)] % DISPLAY_WIDTH
                    y := emulator.registers[get_y(instruction)] % DISPLAY_HEIGHT
                    n := cast(u8)get_imm_4(instruction)
                    emulator.registers[0xf] = 0

                    for dy: u8 = 0; dy < n; dy += 1 {
                        if y + dy >= DISPLAY_HEIGHT do break // Do not wrap

                        sprite_byte := emulator.memory[emulator.i_reg + cast(u16)dy]
                        for dx: u8 = 0; dx < 8; dx += 1 {
                            byte_i := 7 - dx
                            if x + dx >= DISPLAY_WIDTH do break // Do not wrap

                            should_toggle := sprite_byte & (1 << byte_i) != 0

                            if should_toggle {
                                if emulator.display[y + dy][x + dx] {
                                    emulator.display[y + dy][x + dx] = false
                                    emulator.registers[0xf] = 1
                                }
                                else {
                                    emulator.display[y + dy][x + dx] = true
                                }
                            }
                        }
                    }

                    sync.unlock(&emulator.display_mutex)
                }

                case 0xf: {
                    switch get_imm_8(instruction) {
                        case 0x29:
                            character := emulator.registers[get_x(instruction)] & 0xf
                            emulator.i_reg = FONT_START + 5 * cast(u16)character

                        case:
                            fmt.panicf("Unknown subcommand for opcode f %x", get_imm_8(instruction))
                    }
                }

                case:
                    dump_emulator(emulator)
                    fmt.panicf("Unknown instruction %x", instruction)
            }
        }

        end_time := time.now()
        diff_time := time.diff(start_time, end_time)
        start_time = end_time
        time.accurate_sleep(ns_between_decodes - diff_time) // Sleep for one second
    }
}

main :: proc() {
    emulator: Emulator
    init_emulator(&emulator)
    file_name := "programs/BC_test.ch8"
    did_load := load_program(&emulator, file_name)
    if !did_load {
        fmt.println("Could not load program", file_name)
        os.exit(1)
    }

    pixel_width: i32 = 10

    rl.SetTargetFPS(60)
    rl.InitWindow(800, 600, "Chip8")

    decode_thread := thread.create_and_start_with_data(&emulator, decode_and_execute)
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
            // @TODO: Hopefully this won't mess with timing too much?
            sync.lock(&emulator.display_mutex)

            for y := 0; y < DISPLAY_HEIGHT; y += 1 {
                for x := 0; x < DISPLAY_WIDTH; x += 1 {
                    if emulator.display[y][x] {
                        rl.DrawRectangle(cast(i32)x * pixel_width, cast(i32)y * pixel_width, pixel_width, pixel_width, rl.WHITE)
                    }
                }
            }

            sync.unlock(&emulator.display_mutex)
        rl.EndDrawing()
    }

    thread.terminate(decode_thread, 0)
    rl.CloseWindow()
}

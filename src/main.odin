package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"


Vec2i :: [2]int

// --------------
//     WINDOW
// --------------

GAME_NAME :: "The Room"
WINDOW_SIZE :: 1000


// --------------
//      GRID
// --------------

GRID_WIDTH :: 20
GRID_SIZE :: GRID_WIDTH * GRID_WIDTH
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE


// --------------
//      TIME
// --------------

TICK_RATE :: 0.13
tick_timer: f32 = TICK_RATE
fps: int = 0

print_fps :: proc() {
	buf: [32]u8
	frame_time_str := strconv.itoa(buf[:], fps)
	buf[len(frame_time_str)] = 0
	cstr := cstring(&buf[0])
	rl.DrawText(cstr, 0, 0, 30, rl.WHITE)
}

// --------------
//      LEVEL
// --------------

Room :: struct {
	width:      int,
	height:     int,
	player_pos: Vec2i,
	grid:       [dynamic]Cell,
}

Cell :: struct {
	pos:        Vec2i,
	screen_pos: rl.Vector2,
	type:       CellType,
}

CellType :: union {
	Wall,
	Floor,
	Door,
}

Wall :: struct {}

Floor :: struct {
	item: Item,
}

Door :: struct {
	is_open:   bool,
	needs_key: bool,
}

Item :: enum {
	None,
	Key,
}

load_level :: proc(file_path: string) -> (room: Room, err: string) {
	data, ok := os.read_entire_file(file_path)
	if !ok {
		err = "can't read file"
		return
	}
	lines := strings.split(string(data), "\n")

	defer delete(lines)
	defer delete(data)


	height := len(lines)

	if height == 0 {
		err = "no lines in level file"
		return
	}

	width := len(lines[0])

	if width == 0 {
		err = "no char in first line"
		return
	}

	grid := make([dynamic]Cell, width * height)
	player_pos: Vec2i
	for y := 0; y < height; y += 1 {
		line := lines[y]
		if len(line) != width {
			err = "inconsistent level width"
			return
		}
		for x := 0; x < width; x += 1 {
			char := line[x]
			pos: Vec2i = {x, y}
			screen_pos := rl.Vector2{f32(x) * CELL_SIZE, f32(y) * CELL_SIZE}
			color := rl.BLACK
			cell_type: CellType = Floor {
				item = .None,
			}
			switch char {
			case '*':
				cell_type = Wall{}
			case 'd':
				cell_type = Door{}
			case 'D':
				cell_type = Door {
					needs_key = true,
				}
			case 'k':
				cell_type = Floor {
					item = .Key,
				}
			case 'p':
				player_pos = {x, y}
			}
			cell := Cell{pos, screen_pos, cell_type}
			grid[(y * width) + x] = cell
			fmt.println("cell ", x, ";", y, ": ", grid[(y * width) + x])
		}
	}

	room = Room{width, height, player_pos, grid}
	return
}


// --------------
//     PLAYER
// --------------

Player :: struct {
	screen_pos:  rl.Vector2,
	current_pos: Vec2i,
	target_pos:  Vec2i,
	can_move:    bool,
	has_key:     bool,
}

create_player :: proc(init_pos: Vec2i) -> Player {
	screen_pos: rl.Vector2 = {f32(init_pos.x) * CELL_SIZE, f32(init_pos.y) * CELL_SIZE}
	return Player{screen_pos, init_pos, init_pos, true, false}
}

handle_input :: proc(current_pos: Vec2i) -> Vec2i {
	target: Vec2i = current_pos
	if (rl.IsKeyDown(.A)) {
		target.x -= 1
	}
	if (rl.IsKeyDown(.D)) {
		target.x += 1
	}
	if (rl.IsKeyDown(.W)) {
		target.y -= 1
	}
	if (rl.IsKeyDown(.S)) {
		target.y += 1
	}

	return target
}

move_player :: proc(player: ^Player, room: ^Room, frame_time: f32) {
	speed: f32 = 25
	using player

	if rl.IsKeyDown(.LEFT_SHIFT) {
		speed = 50
	}

	if can_move {
		new_target := handle_input(target_pos)

		idx := clamp((new_target.y * room.width) + new_target.x, 0, GRID_SIZE - 1)
		cell := room.grid[idx]
		#partial switch &c in cell.type {
		case Floor:
			#assert(type_of(c) == Floor)
			target_pos = new_target
			#partial switch c.item {
			case .Key:
				player.has_key = true
				new_cell := Cell {
					pos        = cell.pos,
					screen_pos = cell.screen_pos,
					type       = Floor{.None},
				}
				room.grid[idx] = new_cell
			}
		case Door:
			#assert(type_of(c) == Door)
			if (!c.needs_key || player.has_key) {
				new_cell := Cell {
					pos        = cell.pos,
					screen_pos = cell.screen_pos,
					type       = Floor{.None},
				}
				room.grid[idx] = new_cell
			}
		}

	}

	tar_pos: rl.Vector2 = {f32(target_pos.x * CELL_SIZE), f32(target_pos.y * CELL_SIZE)}

	if (rl.Vector2Distance(screen_pos, tar_pos) < 0.1) {
		screen_pos = tar_pos
		can_move = true
	} else {
		screen_pos.x += (tar_pos.x - screen_pos.x) * frame_time * speed
		screen_pos.y += (tar_pos.y - screen_pos.y) * frame_time * speed
		can_move = false
	}
}


// --------------
//    RENDERING
// --------------

draw_player :: proc(player: Player) {
	using player
	player_rect := rl.Rectangle{screen_pos.x, screen_pos.y, CELL_SIZE, CELL_SIZE}

	rl.DrawRectangleRec(player_rect, rl.WHITE)
}

draw_room :: proc(room: Room) {
	for c in room.grid[:] {
		x := i32(c.screen_pos.x)
		y := i32(c.screen_pos.y)
		color: rl.Color

		switch t in c.type {
		case Floor:
			#assert(type_of(t) == Floor)
			switch t.item {
			case .Key:
				color = rl.YELLOW
			case .None:
				color = rl.BLACK
			}
		case Door:
			#assert(type_of(t) == Door)
			switch t.needs_key {
			case true:
				color = rl.DARKBROWN
			case false:
				color = rl.DARKGRAY
			}
		case Wall:
			#assert(type_of(t) == Wall)
			color = rl.GRAY
		}

		rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, color)
	}
}


// --------------
//      GAME
// --------------

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}
		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track)
	}

	room, err := load_level("assets/room1")

	defer {
		delete(room.grid)
	}

	if err != "" {
		panic(fmt.aprintfln("Error while loading level: {}", err))
	}


	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, GAME_NAME)

	player := create_player(room.player_pos)

	for !rl.WindowShouldClose() {
		frame_time := rl.GetFrameTime()
		tick_timer -= frame_time

		if tick_timer <= 0 {
			fps = int(1 / frame_time)
			tick_timer = TICK_RATE - tick_timer
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		camera := rl.Camera2D {
			zoom = f32(WINDOW_SIZE) / CANVAS_SIZE,
		}

		rl.BeginMode2D(camera)

		move_player(&player, &room, frame_time)
		draw_room(room)
		draw_player(player)

		rl.EndMode2D()

		print_fps()

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

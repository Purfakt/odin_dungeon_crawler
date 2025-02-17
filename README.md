# Dungeon Crawler

A simple dungeon crawler made in Odin with RayLib

## How to play

- WASD to move.
- Walk on Doors (Dark grey) to open them.
- Walk on Key (Yellow) to obtain.
- Walk on Locked Doors (Dark Brown) to open (if you have a key of course).

## How to run

```sh
odin run src/main.odin -file
```

## Edit level

You can edit the file `asset/room1` to create your own level.

- `.` is a floor tile.
- `*` is a wall tile.
- `p` is the player starting position.
- `d` is a door.
- `D` is a locked door.
- `k` is a key.

Level must have a consistent width (each line must have the same length).

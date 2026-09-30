# 8051 Tic-Tac-Toe

A hardware-based **Tic-Tac-Toe game implemented in 8051 assembly language**, supporting both **Player vs Player (PvP)** and **Player vs AI (PvAI)** modes.

The project demonstrates low-level embedded-system design using GPIO, internal RAM, a matrix keypad, bi-colour LED control, lookup tables, debouncing, and a rule-based game-playing algorithm — all implemented directly on an 8051 microcontroller.

## Features

- **Two game modes**
  - **PvP:** Two human players take turns.
  - **PvAI:** A human player competes against a rule-based AI.
- **Hardware mode selection** using a physical switch.
- **3×3 Tic-Tac-Toe board** represented using **9 bi-colour LEDs**.
- **GPIO-scanned matrix keypad** for player input.
- **Software key debouncing** to prevent unintended multiple inputs.
- **Internal RAM-based board state** for tracking occupied cells.
- **MOVC lookup table** for efficient table-based data retrieval.
- **Bit-masked GPIO control** for independently driving the board indicators.
- **Rule-based AI** with the following decision hierarchy:
  1. Win if possible
  2. Block the opponent's winning move
  3. Take the center
  4. Take a corner
  5. Take a side
- Designed for operation on an **8051-compatible microcontroller**.

## System Overview

```text
                    ┌──────────────────────┐
                    │   8051 Microcontroller│
                    │                      │
                    │  Game Logic          │
                    │  PvP / PvAI          │
                    │  AI Decision Rules   │
                    │  Board State (RAM)   │
                    │  Keypad Scanning     │
                    │  Debouncing          │
                    └───────┬───────┬──────┘
                            │       │
                 ┌──────────┘       └──────────┐
                 ▼                             ▼
        ┌─────────────────┐          ┌─────────────────┐
        │ Matrix Keypad   │          │ 9 Bi-Colour LEDs│
        │   GPIO Scanned  │          │    3×3 Board    │
        └─────────────────┘          └─────────────────┘

                 ┌─────────────────┐
                 │  Hardware Mode  │
                 │     Switch      │
                 └─────────────────┘
```

## Hardware

The implementation uses:

| Component | Purpose |
|---|---|
| 8051-compatible microcontroller | Executes the game and handles all I/O |
| Matrix keypad | Selects board positions |
| 9 × bi-colour LEDs | Represents the 3×3 game board and player marks |
| Hardware mode switch | Selects PvP or PvAI mode |
| GPIO ports | Interface with keypad, LEDs, and switch |

> **Note:** Exact port/pin assignments depend on the hardware schematic and assembly source used for the project.

## Software Architecture

The program is organized around a simple embedded game loop:

```text
Start
  │
  ▼
Initialize I/O and game state
  │
  ▼
Read hardware mode switch
  │
  ├────────────── PvP ──────────────┐
  │                                 │
  └────────────── PvAI ─────────────┤
                                    ▼
                            Read player input
                                    │
                                    ▼
                              Debounce key
                                    │
                                    ▼
                            Validate board cell
                                    │
                                    ▼
                            Update board state
                                    │
                                    ▼
                              Update LEDs
                                    │
                                    ▼
                             Check game state
                              /           \
                           Win/Draw       Continue
                              │              │
                              │              ▼
                              │        AI makes move
                              │              │
                              │              ▼
                              │        Update board
                              │              │
                              │              ▼
                              └──────► Check game state
                                             │
                                             ▼
                                           Repeat
```

## Input Handling

### Matrix Keypad Scanning

The keypad is read through **GPIO scanning** rather than relying on a dedicated keypad controller.

The firmware:

1. Drives the keypad rows/columns in sequence.
2. Reads the corresponding GPIO inputs.
3. Detects the pressed key.
4. Applies software debouncing.
5. Converts the key position into the corresponding game-board cell.

This keeps the design fully self-contained within the 8051.

### Software Debouncing

Mechanical key presses can produce short bursts of transitions known as **contact bounce**. A software delay/checking mechanism is used to ensure that a single physical press is interpreted as one valid input.

## Board Representation

The current game state is stored in the **8051's internal RAM**.

Each board position corresponds to a logical cell in the 3×3 grid:

```text
        1       2       3
      ┌───────┬───────┬───────┐
      │       │       │       │
      │   1   │   2   │   3   │
      │       │       │       │
      ├───────┼───────┼───────┤
      │       │       │       │
      │   4   │   5   │   6   │
      │       │       │       │
      ├───────┼───────┼───────┤
      │       │       │       │
      │   7   │   8   │   9   │
      │       │       │       │
      └───────┴───────┴───────┘
```

The exact RAM locations and cell encoding are defined by the assembly implementation.

## LED Display

The game board is displayed using **9 bi-colour LEDs**.

Because multiple LEDs share microcontroller ports, the firmware uses **bit-masking** to update individual LED states without unintentionally changing the states of other outputs.

Conceptually:

```text
Board state        LED output
-----------        ----------
Empty              Off
Player 1           Colour A
Player 2 / AI      Colour B
```

This allows the physical LED array to act as the game's visual interface.

## AI Logic

The PvAI mode uses a deterministic **rule-based strategy** rather than a search-based algorithm such as Minimax.

The AI evaluates possible moves in the following order:

```text
            ┌─────────────────────────┐
            │ Can AI win this turn?   │
            └────────────┬────────────┘
                         │ No
                         ▼
            ┌─────────────────────────┐
            │ Can opponent win next?  │
            │       → Block           │
            └────────────┬────────────┘
                         │ No
                         ▼
            ┌─────────────────────────┐
            │       Take center       │
            └────────────┬────────────┘
                         │ Occupied
                         ▼
            ┌─────────────────────────┐
            │       Take a corner     │
            └────────────┬────────────┘
                         │ Unavailable
                         ▼
            ┌─────────────────────────┐
            │        Take a side      │
            └─────────────────────────┘
```

This makes the AI lightweight enough for an 8051 while still providing meaningful gameplay.

## Use of 8051 Assembly Features

The project makes practical use of several low-level 8051 features:

### Internal RAM

The board state and temporary game variables are maintained in the microcontroller's internal RAM, allowing fast access without external memory.

### `MOVC` Lookup Tables

`MOVC` is used to retrieve data from code memory through a lookup-table mechanism. This is useful for mapping input states, board information, or other predefined values without implementing larger conditional structures.

### Bit Manipulation

The design relies heavily on bit-level operations for:

- GPIO control
- LED selection
- Board display updates
- Input/output masking

This is particularly appropriate for an 8-bit microcontroller with limited resources.

## Game Flow

### PvP Mode

```text
Player 1 selects a cell
        ↓
Validate move
        ↓
Update board
        ↓
Update LEDs
        ↓
Check win/draw
        ↓
Player 2 selects a cell
        ↓
Repeat
```

### PvAI Mode

```text
Human selects a cell
        ↓
Validate move
        ↓
Update board + LEDs
        ↓
Check win/draw
        ↓
AI evaluates board
        ↓
AI selects move
        ↓
Update board + LEDs
        ↓
Check win/draw
        ↓
Repeat
```

## Win / Draw Detection

After each valid move, the firmware checks the current board state for the possible winning combinations:

```text
Rows
1 2 3
4 5 6
7 8 9

Columns
1 4 7
2 5 8
3 6 9

Diagonals
1 5 9
3 5 7
```

If one player occupies all three positions of any winning combination, the game ends.

If all nine positions are occupied without a winning combination, the game is a draw.

## Project Structure

A typical repository layout can be organized as:

```text
8051-tic-tac-toe/
│
├── README.md
├── src/
│   └── tictactoe.asm
├── simulation/
│   └── ...
├── schematic/
│   └── ...
└── media/
    └── ...
```

The exact filenames and folders may vary depending on how the project is uploaded.

## Building / Running

This project is written in **8051 assembly language**.

To run it:

1. Open the assembly source in an 8051 development environment/toolchain compatible with the source.
2. Assemble/build the program to generate the MCU machine code.
3. Program the resulting binary/HEX file into the target 8051-compatible microcontroller, or load it into an 8051 simulation environment.
4. Connect the matrix keypad, mode switch, and 9 bi-colour LEDs according to the project's hardware schematic.
5. Select the desired mode and start playing.

> The exact build steps depend on the assembler and simulator used for the project.

## Technical Highlights

This project combines several embedded-systems concepts in a single application:

- Low-level **8051 assembly programming**
- GPIO-based **matrix keypad interfacing**
- **Software debouncing**
- Internal RAM **state management**
- `MOVC`-based **lookup tables**
- **Bit-masked** peripheral control
- Multi-port LED interfacing
- Hardware mode selection
- Deterministic **embedded AI**
- Finite-state game logic
- Win/draw detection

## Possible Extensions

Some natural improvements for a future version would be:

- Minimax-based AI for optimal play
- Difficulty selection
- Score tracking across multiple rounds
- Buzzer/audio feedback
- Seven-segment or LCD/OLED score display
- Interrupt-driven keypad handling
- More efficient LED multiplexing
- Configurable board/input mapping

## Why This Project?

The project was designed as a practical exercise in **resource-constrained embedded programming**. Instead of relying on a high-level language or external game libraries, the complete game logic, user input, state handling, AI, and display control are implemented at the 8051 assembly level.

It demonstrates how a relatively simple microcontroller can combine **hardware interfacing, low-level programming, data structures, and decision-making logic** into a complete interactive system.

## Author

**Zaeed Ahmad**

BSc in Electrical and Electronic Engineering, Islamic University of Technology (IUT)

- GitHub: [@Sparkp1](https://github.com/Sparkp1)
- LinkedIn: [Zaeed Ahmad](https://www.linkedin.com/in/zaeedahmad)

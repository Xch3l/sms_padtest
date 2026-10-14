# Padtest (SMS version)

Quick ROM to test the buttons of a controller. Supports normal Sega MasterSystem controllers as well as Genesis' normal (3 button) and 6 buttons controllers.

## The screen

![Main screen](https://github.com/user-attachments/assets/c94562e1-05ba-4518-9cc5-4cd0a42c5f6b)

- `Pad data`: Shows the current reading from the console's first port. These bytes correspond to the third to sixth readings, inverted.
- `Type`: Shows the type of controller.
- The bottom half shows which button is being currently pressed as well as reflecting the type of controller attached.

## Readings

The following tables are for reference to the data presented on screen. Bytes are the state when no buttons are held down.

### Type `00` - SMS: `00 00 00 00`

| Reading | TH  | TR | TL | D3    | D2   | D1   | D0
| ------- | --- | -- | -- | ----- | ---- | ---- | --
| any     | n/c | 2  | 1  | Right | Left | Down | Up

Bytes map to: `--21RLDU --21RLDU --21RLDU --21RLDU`

### Type `01` - Genesis 3-Button: `0C 00 0C 00`

| Reading | TH | TR    | TL | D3    | D2   | D1   | D0
| ------- | -- | ----- | -- | ----- | ---- | ---- | --
| 1       | 1  | C     | B  | Right | Left | Down | Up
| 2       | 0  | Start | A  | 0     | 0    | Down | Up

Bytes map to: `--CBRLDU --SA00DU --CBRLDU --SA00DU`

### Type `02` - Genesis 6-Button: `0C 00 0F 00`

| Reading | TH | TR    | TL | D3    | D2   | D1   | D0
| ------- | -- | ----- | -- | --    | --   | --   | --
| 1       | 1  | C     | B  | Right | Left | Down | Up
| 2       | 0  | Start | A  | 0     | 0    | Down | Up
| 3       | 1  | C     | B  | Right | Left | Down | Up
| 4       | 0  | Start | A  | 0     | 0    | Down | Up
| 5       | 1  | C     | B  | Right | Left | Down | Up
| 6       | 0  | Start | A  | 0     | 0    | 0    | 0
| 7       | 1  | C     | B  | Mode  | X    | Y    | Z
| 8       | 0  | Start | A  | ---   | ---  | ---  | --- 

Bytes map to: `--CBRLDU --SA00DU --CBMXYZ --SA0000`

## Compiling

Assemble `main.asm` with WLA-DX Z80 or use the included "assemble" bat/sh files. Calling the batch files with `-r` will skip the backing up step and recreate the output files instead.

## Acknowledgements

- SMS Power for [the documentation](https://www.smspower.org/Development/Index) on the SMS' VDP, I/O and control pad.
- SegaRetro for the Genesis' [3 button](https://segaretro.org/Control_Pad_(Mega_Drive)) and [6 button](https://segaretro.org/Six_Button_Control_Pad_(Mega_Drive)) controller protocols.

**No Artificial Intelligence (AI) of any kind was used in the creation of this software and its assets**

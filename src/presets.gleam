import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

import game_engine

/// Represents a preset
/// 
/// A preset is a setup arrangement of pieces on the board that were created
/// by the community as a well-performing and strategic setup
pub type Preset {
  Preset(name: String, description: String, pieces: List(PresetPiece))
}

/// Represents a piece in a preset
pub type PresetPiece {
  PresetPiece(kind: game_engine.PieceKind, coords: game_engine.Coords)
}

/// Names of the presets we support
pub const preset_names: List(String) = ["fritzlein", "MH", "99of9"]

/// Parse a preset content into a Preset
/// 
/// Presets are described as text with the following format:
/// 
/// "Preset description"
/// 
/// PIECE - (x, y)
/// ... 
///
/// Description always needs to be at the top of the file and
/// piece placements uses the [Arimaa notation](https://en.wikibooks.org/wiki/Arimaa/Playing_The_Game#Notation).
/// Whitelines are ignored.
/// Presets are agnostic to the player color, so the coordinates 
/// are expressed in "1" and "2" terms. We convert them later
/// to "7" and "8" if we apply the preset to the silver player.
pub fn parse_preset(name: String, content: String) -> Result(Preset, String) {
  // Check if content is empty or only whitespace
  case string.trim(content) {
    "" -> Error("Empty preset file")
    _ -> {
      let lines =
        string.split(content, "\n")
        |> list.filter(fn(line) { !string.is_empty(string.trim(line)) })

      case lines {
        [] -> Error("Empty preset file")
        [description_line, ..piece_lines] -> {
          let description = extract_description(description_line)

          case parse_pieces(piece_lines) {
            Ok(pieces) ->
              Ok(Preset(name: name, description: description, pieces: pieces))
            Error(err) -> Error(err)
          }
        }
      }
    }
  }
}

/// Extract description from the first line (remove quotes and trim)
fn extract_description(line: String) -> String {
  line
  |> string.trim()
  |> string.replace("\"", "")
}

/// Parse piece lines into PresetPiece list
fn parse_pieces(lines: List(String)) -> Result(List(PresetPiece), String) {
  list.try_map(lines, parse_piece_line)
}

/// Parse a single piece line like "R - (1, 2)"
fn parse_piece_line(line: String) -> Result(PresetPiece, String) {
  let trimmed = string.trim(line)

  case string.split(trimmed, " - ") {
    [piece_str, coords_str] -> {
      case
        parse_piece_kind(string.trim(piece_str)),
        parse_coords(string.trim(coords_str))
      {
        Ok(kind), Ok(coords) -> Ok(PresetPiece(kind: kind, coords: coords))
        Error(err), _ -> Error("Invalid piece: " <> err)
        _, Error(err) -> Error("Invalid coordinates: " <> err)
      }
    }
    _ -> Error("Invalid line format: " <> line)
  }
}

/// Parse piece kind from letter
fn parse_piece_kind(piece_str: String) -> Result(game_engine.PieceKind, String) {
  case piece_str {
    "R" -> Ok(game_engine.Rabbit)
    "D" -> Ok(game_engine.Dog)
    "C" -> Ok(game_engine.Cat)
    "H" -> Ok(game_engine.Horse)
    "M" -> Ok(game_engine.Camel)
    "E" -> Ok(game_engine.Elephant)
    _ -> Error("Unknown piece: " <> piece_str)
  }
}

/// Parse coordinates from string like "(1, 2)"
fn parse_coords(coords_str: String) -> Result(game_engine.Coords, String) {
  let cleaned =
    coords_str
    |> string.replace("(", "")
    |> string.replace(")", "")
    |> string.trim()

  case string.split(cleaned, ",") {
    [x_str, y_str] -> {
      case int.parse(string.trim(x_str)), int.parse(string.trim(y_str)) {
        Ok(x), Ok(y) -> Ok(#(x, y))
        _, _ -> Error("Invalid coordinate numbers")
      }
    }
    _ -> Error("Invalid coordinate format")
  }
}

/// Convert preset coordinates for the given player color
/// Gold uses coordinates as-is, Silver converts x: 1->7, 2->8
pub fn convert_coords_for_color(
  coords: game_engine.Coords,
  color: game_engine.PieceColor,
) -> game_engine.Coords {
  let #(x, y) = coords

  case color {
    game_engine.Gold -> #(x, y)
    game_engine.Silver -> {
      let new_x = case x {
        1 -> 7
        2 -> 8
        _ -> x
      }
      #(new_x, y)
    }
  }
}

/// Apply a preset to the game board for the given player color
pub fn apply_preset_to_game(
  game: game_engine.Game,
  preset: Preset,
  color: game_engine.PieceColor,
) -> game_engine.Game {
  let pieces_with_converted_coords =
    list.map(preset.pieces, fn(preset_piece) {
      let converted_coords =
        convert_coords_for_color(preset_piece.coords, color)
      #(preset_piece.kind, converted_coords)
    })

  // Clear existing pieces of this color from positioning rows
  let cleared_game = clear_player_pieces(game, color)

  // Place all pieces from the preset
  list.fold(
    pieces_with_converted_coords,
    cleared_game,
    fn(acc_game, piece_info) {
      let #(kind, coords) = piece_info
      let piece = create_piece_for_preset(kind, color, acc_game.board)
      let target_square = game_engine.retrieve_square(acc_game.board, coords)

      game_engine.execute_placement(acc_game, None, piece, target_square)
    },
  )
}

/// Clear all pieces of the given color from positioning rows
fn clear_player_pieces(
  game: game_engine.Game,
  color: game_engine.PieceColor,
) -> game_engine.Game {
  let positioning_rows = case color {
    game_engine.Gold -> [1, 2]
    game_engine.Silver -> [7, 8]
  }

  let pieces_to_clear =
    list.filter(game.board, fn(square) {
      case square.piece {
        Some(piece) -> {
          piece.color == color && list.contains(positioning_rows, square.x)
        }
        None -> False
      }
    })

  list.fold(pieces_to_clear, game, fn(acc_game, square) {
    let cleared_square = game_engine.Square(..square, piece: None)
    game_engine.Game(
      ..acc_game,
      board: list.map(acc_game.board, fn(board_square) {
        case board_square.x == square.x && board_square.y == square.y {
          True -> cleared_square
          False -> board_square
        }
      }),
    )
  })
}

/// Create a piece for preset application, finding an appropriate ID
fn create_piece_for_preset(
  kind: game_engine.PieceKind,
  color: game_engine.PieceColor,
  board: game_engine.Board,
) -> game_engine.Piece {
  let existing_pieces =
    list.filter(board, fn(square) {
      case square.piece {
        Some(piece) -> piece.kind == kind && piece.color == color
        None -> False
      }
    })
    |> list.map(fn(square) {
      let assert Some(piece) = square.piece
      piece.id
    })

  let next_id = case list.is_empty(existing_pieces) {
    True -> 1
    False -> {
      let max_id = list.fold(existing_pieces, 0, int.max)
      max_id + 1
    }
  }

  game_engine.Piece(kind: kind, color: color, id: next_id)
}

/// Returns the content of the preset with the given name
pub fn preset_content(name: String) -> Result(String, String) {
  case name {
    "fritzlein" -> Ok(fritzlein_preset())
    "MH" -> Ok(mh_preset())
    "99of9" -> Ok(ninety_nine_preset())
    _ -> Error("Preset not found")
  }
}

// (Hardcoded for now, in the future we'll read them from txt files)
fn fritzlein_preset() -> String {
  "
    \"A setup where the rabbit are put behind traps\"

    R - (1, 1)
    C - (1, 2)
    R - (1, 3)
    D - (1, 4)
    D - (1, 5)
    R - (1, 6)
    C - (1, 7)
    R - (1, 8)
    R - (2, 1)
    H - (2, 2)
    R - (2, 3)
    M - (2, 4)
    E - (2, 5)
    R - (2, 6)
    H - (2, 7)
    R - (2, 8)
  "
}

// (Hardcoded for now, in the future we'll read them from txt files)
fn mh_preset() -> String {
  "
    \"Camel-Horse setup\"

    R - (1, 1)
    R - (1, 2)
    R - (1, 3)
    R - (1, 4)
    D - (1, 5)
    R - (1, 6)
    R - (1, 7)
    R - (1, 8)
    R - (2, 1)
    H - (2, 2)
    C - (2, 3)
    D - (2, 4)
    E - (2, 5)
    C - (2, 6)
    M - (2, 7)
    H - (2, 8)
  "
}

// (Hardcoded for now, in the future we'll read them from txt files)
fn ninety_nine_preset() -> String {
  "
    \"Classic setup that prioritizes flexibility\"

    R - (1, 1)
    R - (1, 2)
    R - (1, 3)
    D - (1, 4)
    D - (1, 5)
    R - (1, 6)
    R - (1, 7)
    R - (1, 8)
    R - (2, 1)
    H - (2, 2)
    C - (2, 3)
    E - (2, 4)
    M - (2, 5)
    C - (2, 6)
    H - (2, 7)
    R - (2, 8)
"
}

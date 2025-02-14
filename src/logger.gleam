import gleam/int
import gleam/io

import game_engine.{
  type Coords, type Piece, piece_color_to_string, piece_kind_to_string,
}

pub fn print_move_error(error: String, piece: Piece, target_coords: Coords) {
  let piece_log = "Piece: " <> piece_to_string(piece)
  let target_coords_log = "Target coords: " <> coords_to_string(target_coords)
  io.println_error("Move error")
  io.println_error(error)
  io.println(piece_log)
  io.println(target_coords_log)
}

pub fn print_reposition_error(
  error: String,
  strong_piece: Piece,
  weak_piece: Piece,
  target_coords: Coords,
) {
  let strong_piece_log = "Strong piece: " <> piece_to_string(strong_piece)
  let weak_piece_log = "Weak piece: " <> piece_to_string(weak_piece)
  let target_coords_log = "Target coords: " <> coords_to_string(target_coords)
  io.println_error("Reposition error")
  io.println_error(error)
  io.println(strong_piece_log)
  io.println(weak_piece_log)
  io.println(target_coords_log)
}

pub fn print_placement_error(error: String, piece: Piece, target_coords: Coords) {
  let piece_log = "Piece: " <> piece_to_string(piece)
  let target_coords_log = "Target coords: " <> coords_to_string(target_coords)
  io.println_error("Placement error")
  io.println_error(error)
  io.println(piece_log)
  io.println(target_coords_log)
}

fn piece_to_string(piece: Piece) {
  piece_color_to_string(piece.color) <> " " <> piece_kind_to_string(piece.kind)
}

fn coords_to_string(coords: Coords) {
  "x: " <> int.to_string(coords.0) <> ", " <> "y: " <> int.to_string(coords.1)
}

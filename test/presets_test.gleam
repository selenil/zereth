import gleam/list
import gleam/option.{Some}
import gleeunit
import gleeunit/should

import game_engine
import presets

pub fn main() {
  gleeunit.main()
}

// Test preset parsing
pub fn parse_preset_basic_test() {
  let content =
    "\"Test preset description\"

R - (1, 1)
E - (1, 5)
C - (2, 3)"

  let result = presets.parse_preset("test", content)

  should.be_ok(result)
  let assert Ok(preset) = result

  should.equal(preset.name, "test")
  should.equal(preset.description, "Test preset description")
  should.equal(list.length(preset.pieces), 3)
}

pub fn parse_preset_empty_content_test() {
  let content = ""
  let result = presets.parse_preset("empty", content)
  should.be_error(result)
}

pub fn parse_preset_invalid_piece_test() {
  let content =
    "\"Test preset\"

X - (1, 1)"

  let result = presets.parse_preset("invalid", content)
  should.be_error(result)
}

pub fn parse_preset_invalid_coords_test() {
  let content =
    "\"Test preset\"

R - (invalid, coords)"

  let result = presets.parse_preset("invalid", content)
  should.be_error(result)
}

pub fn parse_preset_with_empty_lines_test() {
  let content =
    "\"Test preset\"

R - (1, 1)

E - (1, 5)

"

  let result = presets.parse_preset("test", content)

  should.be_ok(result)
  let assert Ok(preset) = result
  should.equal(list.length(preset.pieces), 2)
}

// Test piece kind parsing
pub fn parse_piece_kinds_test() {
  let test_cases = [
    #("R", game_engine.Rabbit),
    #("D", game_engine.Dog),
    #("C", game_engine.Cat),
    #("H", game_engine.Horse),
    #("M", game_engine.Camel),
    #("E", game_engine.Elephant),
  ]

  list.each(test_cases, fn(test_case) {
    let #(piece_str, expected_kind) = test_case
    let content = "\"Test preset\"

" <> piece_str <> " - (1, 1)"

    let result = presets.parse_preset("test", content)
    should.be_ok(result)
    let assert Ok(preset) = result
    let assert [piece] = preset.pieces
    should.equal(piece.kind, expected_kind)
  })
}

// Test coordinate conversion
pub fn convert_coords_gold_test() {
  let coords = #(1, 4)
  let result = presets.convert_coords_for_color(coords, game_engine.Gold)
  should.equal(result, #(1, 4))

  let coords2 = #(2, 7)
  let result2 = presets.convert_coords_for_color(coords2, game_engine.Gold)
  should.equal(result2, #(2, 7))
}

pub fn convert_coords_silver_test() {
  let coords = #(1, 4)
  let result = presets.convert_coords_for_color(coords, game_engine.Silver)
  should.equal(result, #(7, 4))

  let coords2 = #(2, 7)
  let result2 = presets.convert_coords_for_color(coords2, game_engine.Silver)
  should.equal(result2, #(8, 7))

  // Test that other coordinates remain unchanged
  let coords3 = #(3, 5)
  let result3 = presets.convert_coords_for_color(coords3, game_engine.Silver)
  should.equal(result3, #(3, 5))
}

// Test preset application
pub fn apply_preset_to_game_test() {
  let game = game_engine.new_game()

  let preset =
    presets.Preset(name: "test", description: "Test preset", pieces: [
      presets.PresetPiece(kind: game_engine.Rabbit, coords: #(1, 1)),
      presets.PresetPiece(kind: game_engine.Elephant, coords: #(1, 5)),
    ])

  let result = presets.apply_preset_to_game(game, preset, game_engine.Gold)

  // Check that pieces were placed correctly
  let square_1_1 = game_engine.retrieve_square(result.board, #(1, 1))
  let square_1_5 = game_engine.retrieve_square(result.board, #(1, 5))

  case square_1_1.piece, square_1_5.piece {
    Some(piece1), Some(piece2) -> {
      should.equal(piece1.kind, game_engine.Rabbit)
      should.equal(piece1.color, game_engine.Gold)
      should.equal(piece2.kind, game_engine.Elephant)
      should.equal(piece2.color, game_engine.Gold)
    }
    _, _ -> should.fail()
  }
}

pub fn apply_preset_silver_conversion_test() {
  let game = game_engine.new_game()

  let preset =
    presets.Preset(name: "test", description: "Test preset", pieces: [
      presets.PresetPiece(kind: game_engine.Rabbit, coords: #(1, 1)),
      presets.PresetPiece(kind: game_engine.Elephant, coords: #(2, 5)),
    ])

  let result = presets.apply_preset_to_game(game, preset, game_engine.Silver)

  // Check that pieces were placed with converted coordinates
  let square_7_1 = game_engine.retrieve_square(result.board, #(7, 1))
  let square_8_5 = game_engine.retrieve_square(result.board, #(8, 5))

  case square_7_1.piece, square_8_5.piece {
    Some(piece1), Some(piece2) -> {
      should.equal(piece1.kind, game_engine.Rabbit)
      should.equal(piece1.color, game_engine.Silver)
      should.equal(piece2.kind, game_engine.Elephant)
      should.equal(piece2.color, game_engine.Silver)
    }
    _, _ -> should.fail()
  }
}

// Test real preset parsing
pub fn parse_fritzlein_preset_test() {
  let content =
    "\"A setup where the rabbit are put behind traps\"

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
R - (2, 8)"

  let result = presets.parse_preset("fritzlein", content)

  should.be_ok(result)
  let assert Ok(preset) = result

  should.equal(preset.name, "fritzlein")
  should.equal(
    preset.description,
    "A setup where the rabbit are put behind traps",
  )
  should.equal(list.length(preset.pieces), 16)

  // Check that we have the right number of each piece type
  let rabbits =
    list.filter(preset.pieces, fn(p) { p.kind == game_engine.Rabbit })
  let elephants =
    list.filter(preset.pieces, fn(p) { p.kind == game_engine.Elephant })
  let camels = list.filter(preset.pieces, fn(p) { p.kind == game_engine.Camel })
  let horses = list.filter(preset.pieces, fn(p) { p.kind == game_engine.Horse })
  let dogs = list.filter(preset.pieces, fn(p) { p.kind == game_engine.Dog })
  let cats = list.filter(preset.pieces, fn(p) { p.kind == game_engine.Cat })

  should.equal(list.length(rabbits), 8)
  should.equal(list.length(elephants), 1)
  should.equal(list.length(camels), 1)
  should.equal(list.length(horses), 2)
  should.equal(list.length(dogs), 2)
  should.equal(list.length(cats), 2)
}

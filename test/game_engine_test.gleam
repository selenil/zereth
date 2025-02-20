import game_engine.{
  type Game, type Piece, type PieceColor, Camel, Cat, Dog, Elephant, Game, Gold,
  Horse, Piece, Rabbit, Silver,
}
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Helper function to create a test game with specific pieces
fn setup_test_game(pieces: List(#(Piece, #(Int, Int)))) -> Game {
  let game = Game(..game_engine.new_game(), remaining_moves: 999)

  list.fold(pieces, game, fn(game, piece_data) {
    let #(piece, coords) = piece_data
    let target_square = game_engine.retrieve_square(game.board, coords)

    let updated_game =
      game_engine.execute_placement(game, None, piece, target_square)
    updated_game
  })
}

// Basic game setup and initialization tests
pub fn is_positioning_initial_board_test() {
  let game = game_engine.new_game()
  should.be_true(game_engine.is_positioning(game.board))
}

pub fn is_positioning_completed_setup_test() {
  let build_piece = fn(i: Int, piece_color: PieceColor) {
    let x = case i < 9, piece_color {
      True, Gold -> 1
      False, Gold -> 2
      True, Silver -> 8
      False, Silver -> 7
    }
    let y = case i < 9 {
      True -> i
      False -> i - 8
    }

    #(Piece(Rabbit, piece_color, i), #(x, y))
  }

  let pieces =
    list.range(1, 16)
    |> list.flat_map(fn(i) { [build_piece(i, Gold), build_piece(i, Silver)] })

  let game = setup_test_game(pieces)
  should.be_false(game_engine.is_positioning(game.board))
}

pub fn get_available_pieces_empty_board_test() {
  let game = game_engine.new_game()
  let available = game_engine.get_aviable_pieces_to_place(game.board)

  should.equal(list.length(available), 32)
}

pub fn get_available_pieces_some_placed_test() {
  let elephant = Piece(Elephant, Gold, 1)
  let game = setup_test_game([#(elephant, #(1, 1))])

  let available = game_engine.get_aviable_pieces_to_place(game.board)

  should.equal(list.length(available), 31)
  should.be_false(list.contains(available, elephant))
}

// Ortogonal path tests
pub fn ortogonal_path_horizontal_test() {
  // Moving right 3 squares from (1,1) to (4,1)
  game_engine.ortogonal_path(1, 4, 1, 1)
  |> should.equal([#(2, 1), #(3, 1), #(4, 1)])

  // Moving left 2 squares from (4,1) to (2,1)
  game_engine.ortogonal_path(4, 2, 1, 1)
  |> should.equal([#(3, 1), #(2, 1)])
}

pub fn ortogonal_path_vertical_test() {
  // Moving up 3 squares from (1,1) to (1,4)
  game_engine.ortogonal_path(1, 1, 1, 4)
  |> should.equal([#(1, 2), #(1, 3), #(1, 4)])

  // Moving down 2 squares from (1,4) to (1,2)
  game_engine.ortogonal_path(1, 1, 4, 2)
  |> should.equal([#(1, 3), #(1, 2)])
}

// Diagonal paths tests
pub fn diagonal_paths_distance_1_test() {
  // Moving diagonally up-right from (1,1) to (2,2)
  game_engine.diagonal_paths(1, 1, 2, 2)
  |> should.equal([
    [#(2, 1), #(2, 2)],
    // Right then up
    [#(1, 2), #(2, 2)],
    // Up then right
  ])

  // Moving diagonally down-left from (2,2) to (1,1)
  game_engine.diagonal_paths(2, 2, 1, 1)
  |> should.equal([
    [#(1, 2), #(1, 1)],
    // Left then down
    [#(2, 1), #(1, 1)],
    // Down then left
  ])
}

pub fn diagonal_paths_distance_2_test() {
  // Moving diagonally up-right from (1,1) to (3,3)
  game_engine.diagonal_paths(1, 1, 3, 3)
  |> should.equal([
    [#(2, 1), #(2, 2), #(3, 2), #(3, 3)],
    // Right path
    [#(1, 2), #(2, 2), #(2, 3), #(3, 3)],
    // Up path
  ])

  // Moving diagonally down-left from (3,3) to (1,1)
  game_engine.diagonal_paths(3, 3, 1, 1)
  |> should.equal([
    [#(2, 3), #(2, 2), #(1, 2), #(1, 1)],
    // Left path
    [#(3, 2), #(2, 2), #(2, 1), #(1, 1)],
    // Down path
  ])
}

pub fn multi_axis_paths_3_moves_test() {
  // L-shaped move: right 2, up 1 from (1,1) to (3,2)
  game_engine.multi_axis_paths(1, 1, 3, 2)
  |> should.equal([
    [#(2, 1), #(3, 1), #(3, 2)],
    // Right twice then up
    [#(1, 2), #(2, 2), #(3, 2)],
    // Up then right twice
  ])

  // L-shaped move: right 1, up 2 from (1,1) to (2,3)
  game_engine.multi_axis_paths(1, 1, 2, 3)
  |> should.equal([
    [#(1, 2), #(1, 3), #(2, 3)],
    // Up twice then right
    [#(2, 1), #(2, 2), #(2, 3)],
    // Right then up twice
  ])
}

pub fn multi_axis_paths_4_moves_test() {
  // L-shaped move: right 3, up 1 from (1,1) to (4,2)
  game_engine.multi_axis_paths(1, 1, 4, 2)
  |> should.equal([
    [#(2, 1), #(3, 1), #(4, 1), #(4, 2)],
    // Right thrice then up
    [#(1, 2), #(2, 2), #(3, 2), #(4, 2)],
    // Up then right thrice
  ])

  // L-shaped move: right 1, up 3 from (1,1) to (2,4)
  game_engine.multi_axis_paths(1, 1, 2, 4)
  |> should.equal([
    [#(1, 2), #(1, 3), #(1, 4), #(2, 4)],
    // Up thrice then right
    [#(2, 1), #(2, 2), #(2, 3), #(2, 4)],
    // Right then up thrice
  ])
}

// Piece placement tests
pub fn place_piece_valid_gold_territory_test() {
  let game = setup_test_game([])
  let piece = Piece(Elephant, Gold, 1)
  let target_coords = #(1, 1)

  let result = game_engine.place_piece(game, target_coords, piece, None)

  should.be_ok(result)
  let assert Ok(updated_game) = result
  let target_square =
    game_engine.retrieve_square(updated_game.board, target_coords)
  should.equal(target_square.piece, Some(piece))
}

pub fn place_piece_valid_silver_territory_test() {
  let game = setup_test_game([])
  let piece = Piece(Elephant, Silver, 1)
  let target_coords = #(8, 1)

  let result = game_engine.place_piece(game, target_coords, piece, None)

  should.be_ok(result)
  let assert Ok(updated_game) = result
  let target_square =
    game_engine.retrieve_square(updated_game.board, target_coords)
  should.equal(target_square.piece, Some(piece))
}

pub fn place_piece_invalid_territory_test() {
  let game = setup_test_game([])
  let piece = Piece(Elephant, Gold, 1)
  let target_coords = #(3, 1)
  // Invalid territory for Gold

  let result = game_engine.place_piece(game, target_coords, piece, None)

  should.be_error(result)
}

pub fn place_piece_occupied_square_test() {
  let game = setup_test_game([#(Piece(Elephant, Gold, 1), #(1, 1))])
  let piece = Piece(Camel, Gold, 1)
  let target_coords = #(1, 1)

  let result = game_engine.place_piece(game, target_coords, piece, None)

  should.be_error(result)
}

pub fn place_piece_wrong_territory_test() {
  let game = setup_test_game([])
  let piece = Piece(Elephant, Gold, 1)
  let target_coords = #(8, 1)
  // Silver's territory

  let result = game_engine.place_piece(game, target_coords, piece, None)

  should.be_error(result)
}

pub fn place_piece_with_source_coords_test() {
  let initial_game = setup_test_game([#(Piece(Elephant, Gold, 1), #(1, 1))])

  let piece = Piece(Elephant, Gold, 1)
  let source_coords = #(1, 1)
  let target_coords = #(2, 1)

  let result =
    game_engine.place_piece(
      initial_game,
      target_coords,
      piece,
      Some(source_coords),
    )

  should.be_ok(result)
  let assert Ok(updated_game) = result

  // Check source square is empty
  let source_square =
    game_engine.retrieve_square(updated_game.board, source_coords)
  should.equal(source_square.piece, None)

  // Check target square has the piece
  let target_square =
    game_engine.retrieve_square(updated_game.board, target_coords)
  should.equal(target_square.piece, Some(piece))
}

// Win condition tests
pub fn win_by_rabbit_reaching_opposite_end_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(8, 4)),
      // Gold rabbit on Silver's end
    ])

  let win_game = game_engine.check_win(game)
  should.be_true(win_game.win)
}

pub fn win_by_capturing_all_pieces_test() {
  // Setup game with only one Silver piece which will be captured
  let game =
    setup_test_game([
      #(Piece(Rabbit, Silver, 1), #(3, 3)),
      // Silver rabbit on trap
    ])

  let captured_game = game_engine.perform_captures(game)
  let win_game = game_engine.check_win(captured_game)
  should.be_true(win_game.win)
}

pub fn no_win_normal_game_state_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(2, 4)),
      // Gold rabbit on own territory
      #(Piece(Rabbit, Silver, 1), #(7, 4)),
      // Silver rabbit on own territory
    ])

  let win_game = game_engine.check_win(game)
  should.be_false(win_game.win)
}

// String conversion tests
pub fn piece_color_to_string_test() {
  game_engine.piece_color_to_string(Gold)
  |> should.equal("gold")

  game_engine.piece_color_to_string(Silver)
  |> should.equal("silver")
}

pub fn piece_kind_to_string_test() {
  game_engine.piece_kind_to_string(Elephant)
  |> should.equal("elephant")

  game_engine.piece_kind_to_string(Rabbit)
  |> should.equal("rabbit")

  game_engine.piece_kind_to_string(Horse)
  |> should.equal("horse")

  game_engine.piece_kind_to_string(Dog)
  |> should.equal("dog")

  game_engine.piece_kind_to_string(Cat)
  |> should.equal("cat")

  game_engine.piece_kind_to_string(Camel)
  |> should.equal("camel")
}

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
pub fn new_game_test() {
  let game = game_engine.new_game()
  should.equal(game.current_player_color, Gold)
  should.equal(game.remaining_moves, 0)
  should.be_true(game.positioning)
  should.be_false(game.win)
  should.equal(game.history, [])
  should.equal(game.previous_board, None)
}

pub fn new_debug_game_test() {
  let game = game_engine.new_debug_game()
  should.equal(game.current_player_color, Gold)
  should.equal(game.remaining_moves, 4)
  should.be_false(game.positioning)
  should.be_false(game.win)
  should.equal(game.history, [])
  should.equal(game.previous_board, None)

  // Check that debug board has pieces placed
  let elephant_square = game_engine.retrieve_square(game.board, #(1, 4))
  should.equal(elephant_square.piece, Some(Piece(Elephant, Gold, 1)))
}

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

// Pass turn tests
pub fn pass_turn_with_remaining_moves_test() {
  let game = Game(..game_engine.new_game(), remaining_moves: 2)
  let result = game_engine.pass_turn(game)

  should.equal(result.remaining_moves, 2)
  should.equal(result.current_player_color, Gold)
}

pub fn pass_turn_no_remaining_moves_test() {
  let game =
    Game(
      ..game_engine.new_game(),
      remaining_moves: 0,
      current_player_color: Gold,
    )
  let result = game_engine.pass_turn(game)

  should.equal(result.remaining_moves, 4)
  should.equal(result.current_player_color, Silver)
  should.equal(result.previous_board, Some(game.board))
}

pub fn pass_turn_silver_to_gold_test() {
  let game =
    Game(
      ..game_engine.new_game(),
      remaining_moves: 0,
      current_player_color: Silver,
    )
  let result = game_engine.pass_turn(game)

  should.equal(result.remaining_moves, 4)
  should.equal(result.current_player_color, Gold)
}

// Piece strength tests
pub fn is_piece_stronger_elephant_vs_rabbit_test() {
  let elephant = Piece(Elephant, Gold, 1)
  let rabbit = Piece(Rabbit, Silver, 1)

  should.be_true(game_engine.is_piece_stronger(elephant, rabbit))
  should.be_false(game_engine.is_piece_stronger(rabbit, elephant))
}

pub fn is_piece_stronger_same_pieces_test() {
  let elephant1 = Piece(Elephant, Gold, 1)
  let elephant2 = Piece(Elephant, Silver, 1)

  should.be_false(game_engine.is_piece_stronger(elephant1, elephant2))
  should.be_false(game_engine.is_piece_stronger(elephant2, elephant1))
}

pub fn is_piece_stronger_hierarchy_test() {
  let pieces = [
    Piece(Elephant, Gold, 1),
    Piece(Camel, Gold, 1),
    Piece(Horse, Gold, 1),
    Piece(Dog, Gold, 1),
    Piece(Cat, Gold, 1),
    Piece(Rabbit, Gold, 1),
  ]

  // Test that each piece is stronger than all pieces after it
  list.index_map(pieces, fn(piece1, i) {
    list.drop(pieces, i + 1)
    |> list.each(fn(piece2) {
      should.be_true(game_engine.is_piece_stronger(piece1, piece2))
    })
  })
}

// Piece frozen tests
pub fn is_piece_frozen_no_adjacent_pieces_test() {
  let game = setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))])
  let rabbit = Piece(Rabbit, Gold, 1)
  let square = game_engine.retrieve_square_from_piece(game.board, rabbit)

  game_engine.is_piece_frozen(game.board, rabbit, square)
  |> should.be_false()
}

pub fn is_piece_frozen_with_ally_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(4, 4)),
      #(Piece(Cat, Gold, 1), #(4, 5)),
      #(Piece(Dog, Silver, 1), #(5, 4)),
    ])
  let rabbit = Piece(Rabbit, Gold, 1)
  let square = game_engine.retrieve_square_from_piece(game.board, rabbit)

  game_engine.is_piece_frozen(game.board, rabbit, square)
  |> should.be_false()
}

pub fn is_piece_frozen_by_stronger_enemy_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(4, 4)),
      #(Piece(Dog, Silver, 1), #(5, 4)),
    ])
  let rabbit = Piece(Rabbit, Gold, 1)
  let square = game_engine.retrieve_square_from_piece(game.board, rabbit)

  game_engine.is_piece_frozen(game.board, rabbit, square)
  |> should.be_true()
}

pub fn is_piece_frozen_by_weaker_enemy_test() {
  let game =
    setup_test_game([
      #(Piece(Dog, Gold, 1), #(4, 4)),
      #(Piece(Rabbit, Silver, 1), #(5, 4)),
    ])
  let dog = Piece(Dog, Gold, 1)
  let square = game_engine.retrieve_square_from_piece(game.board, dog)

  game_engine.is_piece_frozen(game.board, dog, square)
  |> should.be_false()
}

// Rabbit backwards movement tests
pub fn is_rabbit_moving_backwards_gold_test() {
  let rabbit = Piece(Rabbit, Gold, 1)
  let source =
    game_engine.retrieve_square(game_engine.new_game().board, #(4, 4))
  let target_forward =
    game_engine.retrieve_square(game_engine.new_game().board, #(5, 4))
  let target_backward =
    game_engine.retrieve_square(game_engine.new_game().board, #(3, 4))

  should.be_false(game_engine.is_rabbit_moving_backwards(
    rabbit,
    source,
    target_forward,
  ))
  should.be_true(game_engine.is_rabbit_moving_backwards(
    rabbit,
    source,
    target_backward,
  ))
}

pub fn is_rabbit_moving_backwards_silver_test() {
  let rabbit = Piece(Rabbit, Silver, 1)
  let source =
    game_engine.retrieve_square(game_engine.new_game().board, #(4, 4))
  let target_forward =
    game_engine.retrieve_square(game_engine.new_game().board, #(3, 4))
  let target_backward =
    game_engine.retrieve_square(game_engine.new_game().board, #(5, 4))

  should.be_false(game_engine.is_rabbit_moving_backwards(
    rabbit,
    source,
    target_forward,
  ))
  should.be_true(game_engine.is_rabbit_moving_backwards(
    rabbit,
    source,
    target_backward,
  ))
}

pub fn is_rabbit_moving_backwards_non_rabbit_test() {
  let dog = Piece(Dog, Gold, 1)
  let source =
    game_engine.retrieve_square(game_engine.new_game().board, #(4, 4))
  let target =
    game_engine.retrieve_square(game_engine.new_game().board, #(3, 4))

  should.be_false(game_engine.is_rabbit_moving_backwards(dog, source, target))
}

// Movement legal tests
pub fn is_movement_legal_no_source_piece_test() {
  let game = game_engine.new_game()
  let source = game_engine.retrieve_square(game.board, #(4, 4))
  let target = game_engine.retrieve_square(game.board, #(4, 5))

  let result = game_engine.is_movement_legal(game.board, 4, source, target)
  should.be_error(result)
}

pub fn is_movement_legal_occupied_target_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(4, 4)),
      #(Piece(Cat, Gold, 1), #(4, 5)),
    ])
  let source = game_engine.retrieve_square(game.board, #(4, 4))
  let target = game_engine.retrieve_square(game.board, #(4, 5))

  let result = game_engine.is_movement_legal(game.board, 4, source, target)
  should.be_error(result)
}

// Move piece tests
pub fn move_piece_simple_valid_move_test() {
  let game =
    Game(
      ..setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))]),
      remaining_moves: 4,
    )
  let rabbit = Piece(Rabbit, Gold, 1)

  let result = game_engine.move_piece(game, rabbit, #(4, 5))
  should.be_ok(result)

  let assert Ok(updated_game) = result
  should.equal(updated_game.remaining_moves, 3)

  let target_square = game_engine.retrieve_square(updated_game.board, #(4, 5))
  should.equal(target_square.piece, Some(rabbit))

  let source_square = game_engine.retrieve_square(updated_game.board, #(4, 4))
  should.equal(source_square.piece, None)
}

pub fn move_piece_not_enough_moves_test() {
  let game =
    Game(
      ..setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))]),
      remaining_moves: 1,
    )
  let rabbit = Piece(Rabbit, Gold, 1)

  let result = game_engine.move_piece(game, rabbit, #(4, 6))
  should.be_error(result)
}

pub fn move_piece_frozen_piece_test() {
  let game =
    Game(
      ..setup_test_game([
        #(Piece(Rabbit, Gold, 1), #(4, 4)),
        #(Piece(Dog, Silver, 1), #(5, 4)),
      ]),
      remaining_moves: 4,
    )
  let rabbit = Piece(Rabbit, Gold, 1)

  let result = game_engine.move_piece(game, rabbit, #(4, 5))
  should.be_error(result)
}

pub fn move_piece_rabbit_backwards_test() {
  let game =
    Game(
      ..setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))]),
      remaining_moves: 4,
    )
  let rabbit = Piece(Rabbit, Gold, 1)

  let result = game_engine.move_piece(game, rabbit, #(3, 4))
  should.be_error(result)
}

// Reposition piece tests
pub fn reposition_piece_valid_pull_test() {
  let game =
    Game(
      ..setup_test_game([
        #(Piece(Dog, Gold, 1), #(4, 4)),
        #(Piece(Rabbit, Silver, 1), #(5, 4)),
      ]),
      remaining_moves: 4,
    )
  let dog = Piece(Dog, Gold, 1)
  let rabbit = Piece(Rabbit, Silver, 1)

  let result = game_engine.reposition_piece(game, dog, rabbit, #(4, 5))
  should.be_ok(result)

  let assert Ok(updated_game) = result
  should.equal(updated_game.remaining_moves, 2)
}

pub fn reposition_piece_valid_push_test() {
  let game =
    Game(
      ..setup_test_game([
        #(Piece(Dog, Gold, 1), #(4, 4)),
        #(Piece(Rabbit, Silver, 1), #(5, 4)),
      ]),
      remaining_moves: 4,
    )
  let dog = Piece(Dog, Gold, 1)
  let rabbit = Piece(Rabbit, Silver, 1)

  let result = game_engine.reposition_piece(game, dog, rabbit, #(6, 4))
  should.be_ok(result)

  let assert Ok(updated_game) = result
  should.equal(updated_game.remaining_moves, 2)
}

pub fn reposition_piece_not_enough_moves_test() {
  let game =
    Game(
      ..setup_test_game([
        #(Piece(Dog, Gold, 1), #(4, 4)),
        #(Piece(Rabbit, Silver, 1), #(5, 4)),
      ]),
      remaining_moves: 1,
    )
  let dog = Piece(Dog, Gold, 1)
  let rabbit = Piece(Rabbit, Silver, 1)

  let result = game_engine.reposition_piece(game, dog, rabbit, #(4, 5))
  should.be_error(result)
}

pub fn reposition_piece_same_color_test() {
  let game =
    Game(
      ..setup_test_game([
        #(Piece(Dog, Gold, 1), #(4, 4)),
        #(Piece(Rabbit, Gold, 1), #(5, 4)),
      ]),
      remaining_moves: 4,
    )
  let dog = Piece(Dog, Gold, 1)
  let rabbit = Piece(Rabbit, Gold, 1)

  let result = game_engine.reposition_piece(game, dog, rabbit, #(4, 5))
  should.be_error(result)
}

pub fn reposition_piece_weak_stronger_than_strong_test() {
  let game =
    Game(
      ..setup_test_game([
        #(Piece(Rabbit, Gold, 1), #(4, 4)),
        #(Piece(Dog, Silver, 1), #(5, 4)),
      ]),
      remaining_moves: 4,
    )
  let rabbit = Piece(Rabbit, Gold, 1)
  let dog = Piece(Dog, Silver, 1)

  let result = game_engine.reposition_piece(game, rabbit, dog, #(4, 5))
  should.be_error(result)
}

// Capture tests
pub fn perform_captures_piece_on_trap_no_allies_test() {
  let game = setup_test_game([#(Piece(Rabbit, Gold, 1), #(3, 3))])
  let captured_game = game_engine.perform_captures(game)

  let trap_square = game_engine.retrieve_square(captured_game.board, #(3, 3))
  should.equal(trap_square.piece, None)

  // Check history contains capture record
  should.equal(list.length(captured_game.history), 1)
}

pub fn perform_captures_piece_on_trap_with_ally_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(3, 3)),
      #(Piece(Cat, Gold, 1), #(3, 4)),
    ])
  let captured_game = game_engine.perform_captures(game)

  let trap_square = game_engine.retrieve_square(captured_game.board, #(3, 3))
  should.equal(trap_square.piece, Some(Piece(Rabbit, Gold, 1)))

  // Check no capture in history
  should.equal(list.length(captured_game.history), 0)
}

pub fn perform_captures_no_piece_on_trap_test() {
  let game = setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))])
  let captured_game = game_engine.perform_captures(game)

  // Board should remain unchanged
  should.equal(captured_game.board, game.board)
  should.equal(list.length(captured_game.history), 0)
}

pub fn perform_captures_multiple_traps_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(3, 3)),
      #(Piece(Cat, Silver, 1), #(6, 6)),
    ])
  let captured_game = game_engine.perform_captures(game)

  // Both pieces should be captured
  let trap1_square = game_engine.retrieve_square(captured_game.board, #(3, 3))
  should.equal(trap1_square.piece, None)

  let trap2_square = game_engine.retrieve_square(captured_game.board, #(6, 6))
  should.equal(trap2_square.piece, None)

  // Check history contains both capture records
  should.equal(list.length(captured_game.history), 2)
}

// Undo move tests
pub fn undo_last_move_simple_move_test() {
  let initial_game =
    Game(
      ..setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))]),
      remaining_moves: 4,
    )
  let rabbit = Piece(Rabbit, Gold, 1)

  let assert Ok(moved_game) =
    game_engine.move_piece(initial_game, rabbit, #(4, 5))
  let undone_game = game_engine.undo_last_move(moved_game)

  should.equal(undone_game.remaining_moves, 4)

  let source_square = game_engine.retrieve_square(undone_game.board, #(4, 4))
  should.equal(source_square.piece, Some(rabbit))

  let target_square = game_engine.retrieve_square(undone_game.board, #(4, 5))
  should.equal(target_square.piece, None)
}

pub fn undo_last_move_reposition_test() {
  // Test undoing a reposition move instead of a capture
  let game =
    Game(
      ..setup_test_game([
        #(Piece(Dog, Gold, 1), #(4, 4)),
        #(Piece(Rabbit, Silver, 1), #(5, 4)),
      ]),
      remaining_moves: 4,
    )
  let dog = Piece(Dog, Gold, 1)
  let rabbit = Piece(Rabbit, Silver, 1)

  // Perform a reposition (pull)
  let assert Ok(repositioned_game) =
    game_engine.reposition_piece(game, dog, rabbit, #(4, 5))

  should.equal(repositioned_game.remaining_moves, 2)
  should.be_true(list.length(repositioned_game.history) > 0)

  let undone_game = game_engine.undo_last_move(repositioned_game)

  let dog_square = game_engine.retrieve_square(undone_game.board, #(4, 4))
  should.equal(dog_square.piece, Some(dog))

  let rabbit_square = game_engine.retrieve_square(undone_game.board, #(5, 4))
  should.equal(rabbit_square.piece, Some(rabbit))

  should.equal(undone_game.remaining_moves, 4)
}

// Adjacent coords tests
pub fn adjacent_coords_center_test() {
  let coords = #(4, 4)
  let adjacent = game_engine.adjacent_coords(coords)

  should.equal(list.length(adjacent), 4)
  should.be_true(list.contains(adjacent, #(5, 4)))
  should.be_true(list.contains(adjacent, #(3, 4)))
  should.be_true(list.contains(adjacent, #(4, 5)))
  should.be_true(list.contains(adjacent, #(4, 3)))
}

pub fn adjacent_coords_corner_test() {
  let coords = #(1, 1)
  let adjacent = game_engine.adjacent_coords(coords)

  should.equal(list.length(adjacent), 2)
  should.be_true(list.contains(adjacent, #(2, 1)))
  should.be_true(list.contains(adjacent, #(1, 2)))
}

pub fn adjacent_coords_edge_test() {
  let coords = #(1, 4)
  let adjacent = game_engine.adjacent_coords(coords)

  should.equal(list.length(adjacent), 3)
  should.be_true(list.contains(adjacent, #(2, 4)))
  should.be_true(list.contains(adjacent, #(1, 5)))
  should.be_true(list.contains(adjacent, #(1, 3)))
}

// Adjacent pieces tests
pub fn adjacent_pieces_with_pieces_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(4, 4)),
      #(Piece(Cat, Gold, 1), #(5, 4)),
      #(Piece(Dog, Silver, 1), #(4, 5)),
    ])

  let adjacent = game_engine.adjacent_pieces(game.board, #(4, 4))

  should.equal(list.length(adjacent), 2)
  should.be_true(list.contains(adjacent, Piece(Cat, Gold, 1)))
  should.be_true(list.contains(adjacent, Piece(Dog, Silver, 1)))
}

pub fn adjacent_pieces_no_pieces_test() {
  let game = setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))])

  let adjacent = game_engine.adjacent_pieces(game.board, #(4, 4))

  should.equal(list.length(adjacent), 0)
}

// Valid coords for piece tests
pub fn valid_coords_for_piece_basic_test() {
  let game = setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))])
  let rabbit = Piece(Rabbit, Gold, 1)

  let valid_coords =
    game_engine.valid_coords_for_piece(game.board, 1, #(4, 4), rabbit)

  should.be_true(list.length(valid_coords) > 0)
  // Should include adjacent empty squares
  should.be_true(
    list.any(valid_coords, fn(coord_tuple) {
      let #(coord, _kind) = coord_tuple
      coord == #(5, 4)
      || coord == #(4, 5)
      || coord == #(3, 4)
      || coord == #(4, 3)
    }),
  )
}

pub fn valid_coords_for_piece_pathfinding_capture_test() {
  // Test that coordinates are not marked as valid if all paths 
  // to reach them involve the piece being captured in an intermediate step
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(4, 4)),
      #(Piece(Dog, Silver, 1), #(3, 3)),
      // Enemy piece near trap
      #(Piece(Dog, Silver, 2), #(6, 3)),
      // Enemy piece near trap
    ])
  let rabbit = Piece(Rabbit, Gold, 1)

  let valid_coords =
    game_engine.valid_coords_for_piece(game.board, 2, #(4, 4), rabbit)

  // The rabbit should not be able to reach the trap squares (3,3) and (6,3)
  // because it would be captured there due to no adjacent friendly pieces
  let coords_only =
    list.map(valid_coords, fn(tuple) {
      let #(coord, _kind) = tuple
      coord
    })

  should.be_false(list.contains(coords_only, #(3, 3)))
  should.be_false(list.contains(coords_only, #(6, 3)))
}

pub fn valid_coords_for_piece_pathfinding_frozen_test() {
  // Test that coordinates are not marked as valid if all paths 
  // to reach them involve the piece being frozen in an intermediate step
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(4, 4)),
      #(Piece(Dog, Silver, 1), #(5, 5)),
      // Enemy piece that would freeze the rabbit
    ])
  let rabbit = Piece(Rabbit, Gold, 1)

  let valid_coords =
    game_engine.valid_coords_for_piece(game.board, 2, #(4, 4), rabbit)

  // The rabbit should not be able to reach (5,5) because it would be frozen there
  // by the stronger enemy piece with no friendly pieces adjacent
  let coords_only =
    list.map(valid_coords, fn(tuple) {
      let #(coord, _kind) = tuple
      coord
    })

  should.be_false(list.contains(coords_only, #(5, 5)))
}

// Retrieve square tests
pub fn retrieve_square_valid_coords_test() {
  let game = game_engine.new_game()
  let square = game_engine.retrieve_square(game.board, #(4, 4))

  should.equal(square.x, 4)
  should.equal(square.y, 4)
  should.equal(square.piece, None)
}

pub fn retrieve_square_from_piece_test() {
  let game = setup_test_game([#(Piece(Rabbit, Gold, 1), #(4, 4))])
  let rabbit = Piece(Rabbit, Gold, 1)

  let square = game_engine.retrieve_square_from_piece(game.board, rabbit)

  should.equal(square.x, 4)
  should.equal(square.y, 4)
  should.equal(square.piece, Some(rabbit))
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

pub fn multi_axis_paths_invalid_length_test() {
  // Test paths that are too long or invalid
  game_engine.multi_axis_paths(1, 1, 6, 2)
  |> should.equal([])

  game_engine.multi_axis_paths(1, 1, 2, 6)
  |> should.equal([])
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
  let elephant = Piece(Elephant, Gold, 1)
  let camel = Piece(Camel, Gold, 1)
  let game = setup_test_game([#(elephant, #(1, 1)), #(camel, #(2, 1))])
  let target_coords = #(1, 1)

  let assert Ok(updated_game) =
    game_engine.place_piece(game, target_coords, camel, Some(#(2, 1)))
  let source_square = game_engine.retrieve_square(updated_game.board, #(2, 1))
  should.equal(source_square.piece, Some(elephant))

  let target_square = game_engine.retrieve_square(updated_game.board, #(1, 1))
  should.equal(target_square.piece, Some(camel))
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

pub fn win_by_rabbit_reaching_opposite_end_silver_test() {
  let game =
    setup_test_game([
      #(Piece(Rabbit, Silver, 1), #(1, 4)),
      // Silver rabbit on Gold's end
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

pub fn win_by_capturing_all_gold_pieces_test() {
  // Setup game with only one Gold piece which will be captured
  let game =
    setup_test_game([
      #(Piece(Rabbit, Gold, 1), #(3, 3)),
      // Gold rabbit on trap
      #(Piece(Cat, Silver, 1), #(4, 4)),
      // Silver piece to avoid empty board
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

pub fn piece_strength_test() {
  game_engine.piece_strength(Rabbit)
  |> should.equal(1)

  game_engine.piece_strength(Cat)
  |> should.equal(2)

  game_engine.piece_strength(Dog)
  |> should.equal(3)

  game_engine.piece_strength(Horse)
  |> should.equal(4)

  game_engine.piece_strength(Camel)
  |> should.equal(5)

  game_engine.piece_strength(Elephant)
  |> should.equal(6)
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

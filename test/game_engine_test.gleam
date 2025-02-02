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

pub fn move_piece_valid_move_test() {
  let piece = Piece(Horse, Gold, 1)
  let game = setup_test_game([#(piece, #(2, 2))])

  let assert Ok(updated_game) = game_engine.move_piece(game, piece, #(2, 3))

  let assert Ok(new_square) =
    list.find(updated_game.board, fn(s) { s.x == 2 && s.y == 3 })

  should.equal(new_square.piece, Some(piece))

  let assert Ok(old_square) =
    list.find(updated_game.board, fn(s) { s.x == 2 && s.y == 2 })
  should.equal(old_square.piece, None)

  should.equal(updated_game.remaining_moves, game.remaining_moves - 1)
}

pub fn move_piece_invalid_no_moves_remaining_test() {
  let piece = Piece(Horse, Gold, 1)
  let game = Game(..game_engine.new_game(), remaining_moves: 0)

  let result = game_engine.move_piece(game, piece, #(2, 3))
  should.be_error(result)
}

pub fn move_piece_invalid_non_adjacent_test() {
  let piece = Piece(Horse, Gold, 1)
  let game = setup_test_game([#(piece, #(2, 2))])

  let result = game_engine.move_piece(game, piece, #(4, 4))
  should.be_error(result)
}

pub fn move_piece_rabbit_backwards_test() {
  let gold_rabbit = Piece(Rabbit, Gold, 1)
  let silver_rabbit = Piece(Rabbit, Silver, 1)

  let game =
    setup_test_game([#(gold_rabbit, #(3, 3)), #(silver_rabbit, #(6, 6))])

  // Gold rabbit trying to move backwards (decreasing x)
  let gold_result = game_engine.move_piece(game, gold_rabbit, #(2, 3))
  should.be_error(gold_result)

  // Silver rabbit trying to move backwards (increasing x)
  let silver_result = game_engine.move_piece(game, silver_rabbit, #(7, 6))
  should.be_error(silver_result)
}

pub fn move_piece_invalid_no_net_board_change_test() {
  let rabbit = Piece(Rabbit, Gold, 1)

  let game = Game(..setup_test_game([#(rabbit, #(2, 2))]), remaining_moves: 0)
  let updated_game = game_engine.pass_turn(game)

  let assert Ok(updated_game) =
    game_engine.move_piece(updated_game, rabbit, #(2, 3))
  let assert Ok(updated_game) =
    game_engine.move_piece(updated_game, rabbit, #(2, 2))
  let assert Ok(updated_game) =
    game_engine.move_piece(updated_game, rabbit, #(2, 3))
  let updated_game = game_engine.move_piece(updated_game, rabbit, #(2, 2))

  should.be_error(updated_game)
}

pub fn reposition_piece_valid_push_test() {
  let elephant = Piece(Elephant, Gold, 1)
  let rabbit = Piece(Rabbit, Silver, 1)

  let game = setup_test_game([#(elephant, #(4, 4)), #(rabbit, #(4, 5))])

  let assert Ok(updated_game) =
    game_engine.reposition_piece(game, elephant, rabbit, #(4, 6))

  let assert Ok(rabbit_square) =
    list.find(updated_game.board, fn(s) { s.x == 4 && s.y == 6 })
  should.equal(rabbit_square.piece, Some(rabbit))

  let assert Ok(elephant_square) =
    list.find(updated_game.board, fn(s) { s.x == 4 && s.y == 5 })
  should.equal(elephant_square.piece, Some(elephant))

  should.equal(updated_game.remaining_moves, game.remaining_moves - 2)
}

pub fn reposition_piece_valid_pull_test() {
  let elephant = Piece(Elephant, Gold, 1)
  let rabbit = Piece(Rabbit, Silver, 1)

  let game = setup_test_game([#(elephant, #(4, 4)), #(rabbit, #(4, 5))])

  let assert Ok(updated_game) =
    game_engine.reposition_piece(game, elephant, rabbit, #(4, 3))

  let assert Ok(elephant_square) =
    list.find(updated_game.board, fn(s) { s.x == 4 && s.y == 3 })
  should.equal(elephant_square.piece, Some(elephant))

  let assert Ok(rabbit_square) =
    list.find(updated_game.board, fn(s) { s.x == 4 && s.y == 4 })

  should.equal(rabbit_square.piece, Some(rabbit))
}

pub fn reposition_piece_invalid_same_color_test() {
  let elephant = Piece(Elephant, Gold, 1)
  let rabbit = Piece(Rabbit, Gold, 1)

  let game = setup_test_game([#(elephant, #(4, 4)), #(rabbit, #(4, 5))])

  let result = game_engine.reposition_piece(game, elephant, rabbit, #(4, 6))
  should.be_error(result)
}

pub fn reposition_piece_invalid_weaker_piece_test() {
  let rabbit = Piece(Rabbit, Gold, 1)
  let elephant = Piece(Elephant, Silver, 1)

  let game = setup_test_game([#(rabbit, #(4, 4)), #(elephant, #(4, 5))])

  let result = game_engine.reposition_piece(game, rabbit, elephant, #(4, 6))
  should.be_error(result)
}

pub fn reposition_piece_invalid_net_test() {
  let elephant = Piece(Elephant, Gold, 1)
  let rabbit = Piece(Rabbit, Silver, 1)

  let game =
    Game(
      ..setup_test_game([#(elephant, #(4, 4)), #(rabbit, #(4, 5))]),
      remaining_moves: 0,
    )

  let updated_game = game_engine.pass_turn(game)

  let assert Ok(updated_game) =
    game_engine.reposition_piece(updated_game, elephant, rabbit, #(4, 6))

  let updated_game =
    game_engine.reposition_piece(updated_game, elephant, rabbit, #(4, 4))

  should.be_error(updated_game)
}

pub fn place_piece_valid_placement_test() {
  let game = game_engine.new_game()
  let piece = Piece(Elephant, Gold, 1)

  let assert Ok(updated_game) =
    game_engine.place_piece(game, #(1, 1), piece, None)

  let assert Ok(square) =
    list.find(updated_game.board, fn(s) { s.x == 1 && s.y == 1 })
  should.equal(square.piece, Some(piece))
}

pub fn place_piece_invalid_position_test() {
  let game = game_engine.new_game()
  let gold_piece = Piece(Elephant, Gold, 1)
  let silver_piece = Piece(Elephant, Silver, 1)

  let gold_result = game_engine.place_piece(game, #(7, 1), gold_piece, None)
  should.be_error(gold_result)

  let silver_result = game_engine.place_piece(game, #(2, 1), silver_piece, None)
  should.be_error(silver_result)
}

pub fn place_piece_occupied_square_test() {
  let game = game_engine.new_game()
  let piece1 = Piece(Elephant, Gold, 1)
  let piece2 = Piece(Cat, Gold, 1)

  let assert Ok(updated_game) =
    game_engine.place_piece(game, #(1, 1), piece1, None)
  let result = game_engine.place_piece(updated_game, #(1, 1), piece2, None)

  should.be_error(result)
}

pub fn place_piece_with_source_coords_test() {
  let piece = Piece(Dog, Gold, 1)
  let game = setup_test_game([#(piece, #(1, 1))])

  let assert Ok(updated_game) =
    game_engine.place_piece(game, #(2, 2), piece, Some(#(1, 1)))

  let assert Ok(new_square) =
    list.find(updated_game.board, fn(s) { s.x == 2 && s.y == 2 })
  should.equal(new_square.piece, Some(piece))

  let assert Ok(old_square) =
    list.find(updated_game.board, fn(s) { s.x == 1 && s.y == 1 })

  should.equal(old_square.piece, None)
}

pub fn is_piece_frozen_by_stronger_enemy_test() {
  let rabbit = Piece(Rabbit, Gold, 1)
  let elephant = Piece(Elephant, Silver, 1)

  let game = setup_test_game([#(rabbit, #(4, 4)), #(elephant, #(4, 5))])

  let rabbit_square = game_engine.retrieve_square(game.board, #(4, 4))
  should.be_true(game_engine.is_piece_frozen(game.board, rabbit, rabbit_square))
}

pub fn is_piece_not_frozen_with_ally_adjacent_test() {
  let rabbit = Piece(Rabbit, Gold, 1)
  let elephant = Piece(Elephant, Silver, 1)
  let dog = Piece(Dog, Gold, 1)

  let game =
    setup_test_game([#(rabbit, #(4, 4)), #(elephant, #(4, 5)), #(dog, #(4, 3))])

  let rabbit_square = game_engine.retrieve_square(game.board, #(4, 4))
  should.be_false(game_engine.is_piece_frozen(game.board, rabbit, rabbit_square))
}

pub fn perform_captures_piece_on_trap_no_allies_test() {
  let rabbit = Piece(Rabbit, Gold, 1)
  let game = setup_test_game([#(rabbit, #(3, 3))])

  let updated_game = game_engine.perform_captures(game)

  let trap_square = game_engine.retrieve_square(updated_game.board, #(3, 3))
  should.equal(trap_square.piece, None)
}

pub fn perform_captures_piece_on_trap_with_ally_test() {
  let rabbit = Piece(Rabbit, Gold, 1)
  let dog = Piece(Dog, Gold, 1)

  let game = setup_test_game([#(rabbit, #(3, 3)), #(dog, #(3, 4))])

  let updated_game = game_engine.perform_captures(game)

  let trap_square = game_engine.retrieve_square(updated_game.board, #(3, 3))
  should.equal(trap_square.piece, Some(rabbit))
}

pub fn check_win_rabbit_reaches_goal_test() {
  let gold_rabbit = Piece(Rabbit, Gold, 1)
  let silver_rabbit = Piece(Rabbit, Silver, 1)

  let gold_win_game = setup_test_game([#(gold_rabbit, #(8, 4))])
  let gold_win_result = game_engine.check_win(gold_win_game)
  should.be_true(gold_win_result.win)

  let silver_win_game = setup_test_game([#(silver_rabbit, #(1, 4))])
  let silver_win_result = game_engine.check_win(silver_win_game)
  should.be_true(silver_win_result.win)
}

pub fn check_win_all_pieces_captured_test() {
  let elephant = Piece(Elephant, Gold, 1)

  let game = setup_test_game([#(elephant, #(4, 4))])

  let result = game_engine.check_win(game)
  should.be_true(result.win)
}

pub fn is_piece_stronger_test() {
  let elephant = Piece(Elephant, Gold, 1)
  let camel = Piece(Camel, Silver, 1)
  let rabbit = Piece(Rabbit, Gold, 1)

  should.be_true(game_engine.is_piece_stronger(elephant, camel))
  should.be_true(game_engine.is_piece_stronger(camel, rabbit))
  should.be_false(game_engine.is_piece_stronger(rabbit, elephant))
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

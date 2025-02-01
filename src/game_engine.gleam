import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}

pub type Game {
  Game(
    board: Board,
    current_player_color: PieceColor,
    remaining_moves: Int,
    positioning: Bool,
    win: Bool,
  )
}

pub type Square {
  Square(x: Int, y: Int, piece: Option(Piece))
}

pub type Piece {
  Piece(kind: PieceKind, color: PieceColor, id: Int)
}

pub type PieceKind {
  Elephant
  Camel
  Horse
  Dog
  Cat
  Rabbit
}

pub type PieceColor {
  Gold
  Silver
}

pub type RepositionType {
  Pull
  Push
}

pub type Coords =
  #(Int, Int)

pub type Board =
  List(Square)

pub const trap_squares = [#(3, 3), #(3, 6), #(6, 3), #(6, 6)]

const pieces_strength = [
  #(Elephant, 6),
  #(Camel, 5),
  #(Horse, 4),
  #(Dog, 3),
  #(Cat, 2),
  #(Rabbit, 1),
]

const pieces_amount_per_player = [
  #(Elephant, 1),
  #(Camel, 1),
  #(Horse, 2),
  #(Dog, 2),
  #(Cat, 2),
  #(Rabbit, 8),
]

pub fn new_game() -> Game {
  Game(
    board: new_board(),
    current_player_color: Gold,
    remaining_moves: 0,
    positioning: True,
    win: False,
  )
}

pub fn new_debug_game() {
  Game(
    board: new_debug_board(),
    current_player_color: Gold,
    remaining_moves: 4,
    positioning: False,
    win: False,
  )
}

fn new_board() -> Board {
  list.range(1, 8)
  |> list.flat_map(fn(x) {
    list.map(list.range(1, 8), fn(y) { Square(x, y, None) })
  })
  |> list.reverse()
}

fn new_debug_board() {
  list.range(1, 8)
  |> list.flat_map(fn(x) {
    list.map(list.range(1, 8), fn(y) {
      Square(x, y, case x, y {
        2, y -> Some(Piece(Rabbit, Gold, y))
        7, y -> Some(Piece(Rabbit, Silver, y))
        1, 1 -> Some(Piece(Horse, Gold, 1))
        1, 8 -> Some(Piece(Horse, Gold, 2))
        8, 1 -> Some(Piece(Horse, Silver, 1))
        8, 8 -> Some(Piece(Horse, Silver, 1))
        1, 2 -> Some(Piece(Dog, Gold, 1))
        1, 7 -> Some(Piece(Dog, Gold, 2))
        8, 2 -> Some(Piece(Dog, Silver, 1))
        8, 7 -> Some(Piece(Dog, Silver, 2))
        1, 3 -> Some(Piece(Cat, Gold, 1))
        1, 6 -> Some(Piece(Cat, Gold, 2))
        8, 3 -> Some(Piece(Cat, Silver, 1))
        8, 6 -> Some(Piece(Cat, Silver, 2))
        1, 4 -> Some(Piece(Elephant, Gold, 1))
        8, 4 -> Some(Piece(Elephant, Silver, 1))
        1, 5 -> Some(Piece(Camel, Gold, 1))
        8, 5 -> Some(Piece(Camel, Silver, 1))
        _, _ -> None
      })
    })
  })
  |> list.reverse()
}

pub fn pass_turn(game: Game) {
  case game.remaining_moves == 0 {
    False -> game
    True ->
      Game(..game, remaining_moves: 4, current_player_color: case
        game.current_player_color
      {
        Gold -> Silver
        Silver -> Gold
      })
  }
}

/// Attempts to move the specified `piece` by the given
/// `target_coords`. In Arimaa, pieces moves one square per time and only
/// in ortogonal directions. Also, another set of rules determines if a
/// piece can move or not.
///
/// This function performs several checks to ensure the move is legal:
/// - Verifies that the game has remaining moves.
/// - Checks if the movement is within legal bounds.
/// - Ensures the piece is not frozen.
/// - Prevents rabbits from moving backwards.
///
///
/// # Parameters
///
/// - `game`: The current state of the game.
/// - `piece`: The piece to be moved.
/// - `delta_coords`: The change in coordinates for the move.
///
/// # Returns
///
/// - `Ok(Game)`: The updated game state after the move.
/// - `Error(String)`: An error message if the move is invalid.
pub fn move_piece(
  game: Game,
  piece: Piece,
  target_coords: Coords,
) -> Result(Game, String) {
  use <- bool.guard(
    game.remaining_moves < 1,
    Error("No moves remaining in the current turn"),
  )

  let source_square = retrieve_square_from_piece(game.board, piece)
  let target_square = retrieve_square(game.board, target_coords)

  case validate_move(game.board, piece, source_square, target_square) {
    Ok(_) -> {
      let updated_board = execute_move(game.board, source_square, target_square)

      Ok(
        Game(
          ..game,
          board: updated_board,
          remaining_moves: game.remaining_moves - 1,
        ),
      )
    }
    Error(reason) -> Error("Not a valid move because: " <> reason)
  }
}

fn validate_move(
  board: Board,
  piece: Piece,
  source_square: Square,
  target_square: Square,
) -> Result(Nil, String) {
  case
    is_movement_legal(source_square, target_square),
    is_piece_frozen(board, piece, source_square),
    is_rabbit_moving_backwards(piece, source_square, target_square)
  {
    Ok(_), False, False -> Ok(Nil)
    Error(reason), _, _ -> Error("Movement not legal because: " <> reason)
    _, True, _ -> Error("Piece is frozen")
    _, _, True -> Error("Rabbits cannot move backwards")
  }
}

fn execute_move(
  board: Board,
  source_square: Square,
  target_square: Square,
) -> Board {
  let updated_source_square = Square(..source_square, piece: None)
  let updated_target_square =
    Square(..target_square, piece: source_square.piece)
  update_board(board, [updated_source_square, updated_target_square])
}

/// Attempts to reposition a weaker piece using a stronger piece via push or pull maneuvers.
///
/// In Arimaa, a stronger piece can reposition an adjacent weaker opponent's piece by either:
/// - **Pulling**: The stronger piece moves into an adjacent empty square, pulling the weaker piece into the vacated square.
/// - **Pushing**: The stronger piece pushes the weaker piece into an adjacent empty square and then moves into the weaker piece's original square.
///
/// This function checks if the `strong_piece` can reposition the `weak_piece` to the `target_coords` using either maneuver. It ensures that:
/// - The turn has at least two remaining moves.
/// - Both specified pieces exist on the board.
/// - The `strong_piece` is indeed stronger than the `weak_piece`.
/// - The `target_coords` is adjacent to the `strong_piece`.
///
/// If all conditions are met, it performs the appropriate maneuver and updates the game state.
///
/// # Parameters
///
/// - `game`: The current state of the game.
/// - `strong_piece`: The piece attempting to reposition the weaker piece.
/// - `weak_piece`: The piece to be repositioned.
/// - `target_coords`: The target coordinates for the weaker piece after the maneuver.
pub fn reposition_piece(
  game: Game,
  strong_piece: Piece,
  weak_piece: Piece,
  target_coords: Coords,
) -> Result(Game, String) {
  use <- bool.guard(
    game.remaining_moves < 2,
    Error("Not enough moves remaining in the current turn"),
  )

  use <- bool.guard(
    strong_piece.color == weak_piece.color,
    Error("Both pieces must be of different colors"),
  )

  use <- bool.guard(
    !is_piece_stronger(strong_piece, weak_piece),
    Error("Strong piece is actually not stronger than weak piece"),
  )

  let strong_piece_square = retrieve_square_from_piece(game.board, strong_piece)
  let weak_piece_square = retrieve_square_from_piece(game.board, weak_piece)

  let strong_piece_adjacent_coords =
    adjacent_coords(#(strong_piece_square.x, strong_piece_square.y))
  let target_square = retrieve_square(game.board, target_coords)

  // if the stronger piece wants to move to an adjacent square
  // then the reposition is a pull, otherwise is a push
  let reposition_type = case
    list.contains(strong_piece_adjacent_coords, target_coords)
  {
    True -> Pull
    False -> Push
  }

  execute_reposition(
    game,
    strong_piece,
    strong_piece_square,
    weak_piece,
    weak_piece_square,
    target_square,
    reposition_type,
  )
}

fn execute_reposition(
  game: Game,
  strong_piece: Piece,
  strong_piece_square: Square,
  weak_piece: Piece,
  weak_piece_square: Square,
  target_square: Square,
  reposition_type: RepositionType,
) {
  let #(first_movement_source, first_movement_target) = case reposition_type {
    Pull -> #(strong_piece_square, target_square)
    Push -> #(weak_piece_square, target_square)
  }

  case is_movement_legal(first_movement_source, first_movement_target) {
    Ok(_) -> {
      let #(strong_piece_square, weak_piece_square, target_square) = case
        reposition_type
      {
        Pull -> #(
          Square(..strong_piece_square, piece: None),
          weak_piece_square,
          Square(..target_square, piece: Some(strong_piece)),
        )
        Push -> #(
          strong_piece_square,
          Square(..weak_piece_square, piece: None),
          Square(..target_square, piece: Some(weak_piece)),
        )
      }

      let #(second_movement_source, second_movement_target) = case
        reposition_type
      {
        Pull -> #(weak_piece_square, strong_piece_square)
        Push -> #(strong_piece_square, weak_piece_square)
      }

      case is_movement_legal(second_movement_source, second_movement_target) {
        Ok(_) -> {
          let #(strong_piece_square, weak_piece_square, target_square) = case
            reposition_type
          {
            Pull -> #(
              Square(..strong_piece_square, piece: Some(weak_piece)),
              Square(..weak_piece_square, piece: None),
              target_square,
            )

            Push -> #(
              Square(..strong_piece_square, piece: None),
              Square(..weak_piece_square, piece: Some(strong_piece)),
              target_square,
            )
          }

          Ok(
            Game(
              ..game,
              board: update_board(game.board, [
                weak_piece_square,
                target_square,
                strong_piece_square,
              ]),
              remaining_moves: game.remaining_moves - 2,
            ),
          )
        }

        Error(reason) -> Error(reason)
      }
    }
    Error(reason) -> Error(reason)
  }
}

pub fn place_piece(
  game: Game,
  target_coords: Coords,
  target_piece: Piece,
  source_coords: Option(Coords),
) {
  let target_square = retrieve_square(game.board, target_coords)

  case is_placement_legal(target_piece, target_square) {
    Error(reason) -> Error("Placement not legal because: " <> reason)
    Ok(_) -> {
      let updated_squares = case source_coords {
        Some(dest_coords) -> {
          let source_square = retrieve_square(game.board, dest_coords)

          [
            Square(..target_square, piece: Some(target_piece)),
            Square(..source_square, piece: None),
          ]
        }

        None -> [Square(..target_square, piece: Some(target_piece))]
      }

      let board = update_board(game.board, updated_squares)
      let positioning = is_positioning(board)
      let remains_movements = case positioning {
        True -> 0
        False -> 4
      }

      Ok(
        Game(
          ..game,
          board: board,
          positioning: positioning,
          remaining_moves: remains_movements,
        ),
      )
    }
  }
}

pub fn is_movement_legal(
  source_square: Square,
  target_square: Square,
) -> Result(Nil, String) {
  use <- bool.guard(
    source_square.piece == None,
    Error("Not a piece in the source square"),
  )

  use <- bool.guard(
    target_square.piece != None,
    Error("Already a piece in the target square"),
  )

  let adjacent_coords = adjacent_coords(#(source_square.x, source_square.y))
  use <- bool.guard(
    !list.contains(adjacent_coords, #(target_square.x, target_square.y)),
    Error("Not an adjacent square"),
  )

  Ok(Nil)
}

pub fn is_placement_legal(
  piece: Piece,
  target_square: Square,
) -> Result(Nil, String) {
  use <- bool.guard(
    target_square.piece != None,
    Error("There is already a piece in the target square"),
  )

  case piece.color {
    Gold -> {
      use <- bool.guard(
        !list.contains([1, 2], target_square.x),
        Error("Attempeted to place a piece in a non-valid square"),
      )
      Ok(Nil)
    }

    Silver -> {
      use <- bool.guard(
        !list.contains([7, 8], target_square.x),
        Error("Attempeted to place a piece in a non-valid square"),
      )
      Ok(Nil)
    }
  }
}

pub fn perform_captures(game: Game) {
  let board =
    list.map(game.board, fn(square) {
      let coords = #(square.x, square.y)

      case square.piece, list.contains(trap_squares, coords) {
        None, _ -> square
        Some(_), False -> square
        Some(piece), True -> {
          let adjacent_ally_pieces =
            adjacent_pieces(game.board, coords)
            |> list.filter(fn(p) {
              case p {
                Some(p) if p.color == piece.color -> True
                _ -> False
              }
            })

          case list.is_empty(adjacent_ally_pieces) {
            True -> Square(..square, piece: None)
            False -> square
          }
        }
      }
    })

  Game(..game, board: board)
}

pub fn check_win(game: Game) {
  let win =
    list.any(game.board, fn(square) {
      check_rabbit_win(square) || check_all_piece_captured_win(game.board)
    })

  Game(..game, win: win)
}

fn check_rabbit_win(square: Square) {
  case square.piece, square.x {
    Some(Piece(Rabbit, Gold, _)), 8 -> True
    Some(Piece(Rabbit, Silver, _)), 1 -> True
    _, _ -> False
  }
}

fn check_all_piece_captured_win(_board: Board) {
  // todo: implement this
  False
}

pub fn get_aviable_pieces_to_place(board: Board) {
  let pieces =
    list.flat_map([Gold, Silver], fn(color) {
      list.flat_map([Elephant, Camel, Horse, Dog, Cat, Rabbit], fn(kind) {
        let piece_ids = case
          list.find(pieces_amount_per_player, fn(p) { p.0 == kind })
        {
          Ok(#(_, amount)) -> amount
          Error(_) -> 0
        }

        list.map(list.range(1, piece_ids), fn(id) { Piece(kind, color, id) })
      })
    })

  let position_squares =
    list.filter(board, fn(square) {
      square.x == 1 || square.x == 2 || square.x == 7 || square.x == 8
    })

  pieces
  |> list.filter(fn(piece) {
    list.all(position_squares, fn(square) { square.piece != Some(piece) })
  })
  |> list.reverse()
}

pub fn is_positioning(board: Board) {
  let position_squares =
    list.filter(board, fn(square) {
      square.x == 1 || square.x == 2 || square.x == 7 || square.x == 8
    })

  list.any(position_squares, fn(square) { square.piece == None })
}

fn retrieve_square(board: Board, coords: Coords) {
  let assert Ok(square) =
    list.find(board, fn(square) {
      let #(x, y) = coords
      square.x == x && square.y == y
    })

  square
}

fn retrieve_square_from_piece(board: Board, piece: Piece) {
  let assert Ok(square) =
    list.find(board, fn(square) { square.piece == Some(piece) })

  square
}

pub fn is_piece_frozen(board: Board, piece: Piece, source_square: Square) {
  let adjacents_pieces =
    adjacent_pieces(board, #(source_square.x, source_square.y))

  case
    list.all(adjacents_pieces, fn(p) {
      case p {
        Some(_) -> False
        None -> True
      }
    })
  {
    True -> False
    False -> {
      let #(enemy_pieces, ally_pieces) =
        adjacents_pieces
        |> list.fold(#([], []), fn(acc, p) {
          case p {
            Some(ally_piece) if ally_piece.color == piece.color -> #(acc.0, [
              ally_piece,
            ])
            Some(enemy_piece) if enemy_piece.color != piece.color ->
              case is_piece_stronger(enemy_piece, piece) {
                True -> #(acc.0, [enemy_piece])
                False -> acc
              }
            _ -> acc
          }
        })

      !list.is_empty(enemy_pieces) && list.is_empty(ally_pieces)
    }
  }
}

pub fn is_rabbit_moving_backwards(
  piece: Piece,
  source_square: Square,
  target_square: Square,
) {
  case piece.kind {
    Rabbit -> {
      case piece.color {
        Gold -> target_square.x < source_square.x

        Silver -> target_square.x > source_square.x
      }
    }
    _ -> False
  }
}

fn update_board(board: Board, squares: Board) {
  list.fold(squares, board, fn(acc, square) {
    list.map(acc, fn(s) {
      case s.x == square.x && s.y == square.y {
        True -> square
        False -> s
      }
    })
  })
}

fn is_piece_stronger(piece1: Piece, piece2: Piece) {
  let strength1 = case
    list.find(pieces_strength, fn(p) { p.0 == piece1.kind })
  {
    Ok(#(_, strength)) -> strength
    Error(_) -> 0
  }

  let strength2 = case
    list.find(pieces_strength, fn(p) { p.0 == piece2.kind })
  {
    Ok(#(_, strength)) -> strength
    Error(_) -> 0
  }

  strength1 > strength2
}

pub fn adjacent_coords(coords: Coords) {
  let #(x, y) = coords
  let possible = [#(x + 1, y), #(x - 1, y), #(x, y + 1), #(x, y - 1)]

  list.filter(possible, fn(coord) {
    let #(x, y) = coord
    x >= 1 && x <= 8 && y >= 1 && y <= 8
  })
}

pub fn get_piece_asset_name(piece: Piece) {
  let color = piece_color_to_string(piece.color)

  let kind = piece_kind_to_string(piece.kind)

  "assets/pieces/" <> color <> "_" <> kind <> ".png"
}

pub fn piece_color_to_string(piece_color: PieceColor) {
  case piece_color {
    Gold -> "gold"
    Silver -> "silver"
  }
}

pub fn piece_kind_to_string(piece_kind: PieceKind) {
  case piece_kind {
    Elephant -> "elephant"
    Camel -> "camel"
    Horse -> "horse"
    Dog -> "dog"
    Cat -> "cat"
    Rabbit -> "rabbit"
  }
}

pub fn adjacent_pieces(board: Board, coords: Coords) {
  coords
  |> adjacent_coords()
  |> list.map(fn(a_coords) {
    case list.find(board, fn(s) { s.x == a_coords.0 && s.y == a_coords.1 }) {
      Ok(s) -> s.piece
      Error(_) -> None
    }
  })
}

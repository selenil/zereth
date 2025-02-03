import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}

/// Represents the current state of an Arimaa game
pub type Game {
  Game(
    /// The current board state
    board: Board,
    /// The previous board state (for checking if the board has changed between turns)
    previous_board: Option(Board),
    /// The history of moves made in the game
    history: List(Delta),
    /// The color of the current player's turn
    current_player_color: PieceColor,
    /// Number of moves remaining in the current turn
    remaining_moves: Int,
    /// Whether the game is in the positioning phase
    positioning: Bool,
    /// Whether the game has been won
    win: Bool,
  )
}

/// Represents a change in the game state
pub type Delta {
  Move(source_coords: Coords, target_coords: Coords)
  Reposition(
    strong_piece_source_coords: Coords,
    weak_piece_source_coords: Coords,
    target_coords: Coords,
    reposition_type: RepositionType,
  )
  Capture(piece: Piece, trap_coords: Coords)
}

/// Represents a square on the game board
pub type Square {
  Square(x: Int, y: Int, piece: Option(Piece))
}

/// Represents a game piece
pub type Piece {
  Piece(kind: PieceKind, color: PieceColor, id: Int)
}

/// The different types of pieces in order of strength
pub type PieceKind {
  Elephant
  Camel
  Horse
  Dog
  Cat
  Rabbit
}

/// The two colors in the game
pub type PieceColor {
  Gold
  Silver
}

/// The type of repositioning move
pub type RepositionType {
  Pull
  Push
}

/// Board coordinates as a tuple of x,y positions
pub type Coords =
  #(Int, Int)

/// The game board as a list of squares
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

/// Creates a new game with an empty board
pub fn new_game() -> Game {
  Game(
    board: new_board(),
    previous_board: None,
    history: [],
    current_player_color: Gold,
    remaining_moves: 0,
    positioning: True,
    win: False,
  )
}

/// Creates a new game with a pre-configured board for debugging
pub fn new_debug_game() -> Game {
  Game(
    board: new_debug_board(),
    previous_board: None,
    history: [],
    current_player_color: Gold,
    remaining_moves: 4,
    positioning: False,
    win: False,
  )
}

fn new_board() {
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

fn update_board(board: Board, squares: Board) {
  use acc, square <- list.fold(squares, board)
  use s <- list.map(acc)

  case s.x == square.x && s.y == square.y {
    True -> square
    False -> s
  }
}

/// Passes the turn to the next player if no moves remain
/// Returns the same game state if moves still remain
pub fn pass_turn(game: Game) -> Game {
  case game.remaining_moves == 0 {
    False -> game
    True ->
      Game(
        ..game,
        previous_board: Some(game.board),
        remaining_moves: 4,
        current_player_color: case game.current_player_color {
          Gold -> Silver
          Silver -> Gold
        },
      )
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
/// ## Parameters
///
/// - `game`: The current state of the game.
/// - `piece`: The piece to be moved.
/// - `target_coords`: The change in coordinates for the move.
///
/// ## Returns
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
      use <- bool.guard(
        game.remaining_moves == 1
          && !check_if_board_changed(game, updated_board),
        Error("Invalid move. A turn has to produce a net change in the board"),
      )

      let new_history_record =
        Move(#(source_square.x, source_square.y), #(
          target_square.x,
          target_square.y,
        ))

      Ok(
        Game(
          ..game,
          board: updated_board,
          remaining_moves: game.remaining_moves - 1,
          history: [new_history_record, ..game.history],
        )
        |> perform_captures()
        |> pass_turn()
        |> check_win(),
      )
    }
    Error(reason) -> Error("Not a valid move because: " <> reason)
  }
}

fn execute_move(board: Board, source_square: Square, target_square: Square) {
  let updated_source_square = Square(..source_square, piece: None)
  let updated_target_square =
    Square(..target_square, piece: source_square.piece)
  update_board(board, [updated_source_square, updated_target_square])
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

fn check_if_board_changed(game: Game, updated_board: Board) {
  case game.previous_board {
    Some(previous_board) -> previous_board != updated_board
    None -> True
  }
}

/// Checks if a movement between squares is legal according to the rules
/// of the game.
///
/// Checks if:
/// - Source square has no piece
/// - Target square is occupied
/// - Target is not adjacent
///
/// This function only performs core checks and it is not exhaustive. In order
/// validate a given movement, we need to perform additional checks depending on
/// the movement.
///
/// ## Returns
///
/// - `Ok(Nil)`: The movement is legal.
/// - `Error(String)`: An error message if the movement is invalid.
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

/// Checks if a piece is frozen (surrounded by stronger enemy pieces with no friendly pieces adjacent)
pub fn is_piece_frozen(
  board: Board,
  piece: Piece,
  source_square: Square,
) -> Bool {
  let adjacent_pieces =
    adjacent_pieces(board, #(source_square.x, source_square.y))

  let #(ally_pieces, enemy_pieces) = {
    use acc, p <- list.fold(adjacent_pieces, #([], []))
    case p.color == piece.color {
      True -> #([p, ..acc.0], acc.1)
      False -> #(acc.0, [p, ..acc.1])
    }
  }

  list.any(enemy_pieces, fn(enemy_piece) {
    is_piece_stronger(enemy_piece, piece)
  })
  && list.is_empty(ally_pieces)
}

/// Checks if a rabbit is attempting to move backwards
pub fn is_rabbit_moving_backwards(
  piece: Piece,
  source_square: Square,
  target_square: Square,
) -> Bool {
  case piece.kind {
    Rabbit if piece.color == Gold -> target_square.x < source_square.x
    Rabbit if piece.color == Silver -> target_square.x > source_square.x
    _ -> False
  }
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
/// ## Parameters
///
/// - `game`: The current state of the game.
/// - `strong_piece`: The piece attempting to reposition the weaker piece.
/// - `weak_piece`: The piece to be repositioned.
/// - `target_coords`: The target coordinates for the weaker piece after the maneuver.
///
/// ## Returns
///
/// - `Ok(Game)`: The updated game state after the reposition.
/// - `Error(String)`: An error message if the reposition is invalid.
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
  // the reposition is a pull, otherwise is a push
  let reposition_type = case
    list.contains(strong_piece_adjacent_coords, target_coords)
  {
    True -> Pull
    False -> Push
  }

  let updated_board =
    execute_reposition(
      game,
      strong_piece,
      strong_piece_square,
      weak_piece,
      weak_piece_square,
      target_square,
      reposition_type,
    )

  case updated_board {
    Ok(updated_board) -> {
      use <- bool.guard(
        game.remaining_moves == 2
          && !check_if_board_changed(game, updated_board),
        Error("Invalid move. A turn has to produce a net change in the board"),
      )

      let new_history_record =
        Reposition(
          #(strong_piece_square.x, strong_piece_square.y),
          #(weak_piece_square.x, weak_piece_square.y),
          #(target_square.x, target_square.y),
          reposition_type,
        )

      Ok(
        Game(
          ..game,
          board: updated_board,
          remaining_moves: game.remaining_moves - 2,
          history: [new_history_record, ..game.history],
        )
        |> perform_captures()
        |> pass_turn()
        |> check_win(),
      )
    }
    Error(reason) -> Error(reason)
  }
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
            update_board(game.board, [
              weak_piece_square,
              target_square,
              strong_piece_square,
            ]),
          )
        }

        Error(reason) -> Error(reason)
      }
    }
    Error(reason) -> Error(reason)
  }
}

/// Checks if `piece1` is stronger than `piece2`
pub fn is_piece_stronger(piece1: Piece, piece2: Piece) -> Bool {
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

/// Places a piece on the board during the positioning phase
/// Before the placement, checks if:
/// - The target square is occupied
/// - The placement is in an invalid territory
///
/// ## Parameters
///
/// - `game`: The current state of the game.
/// - `target_coords`: The coordinates of the target square.
/// - `target_piece`: The piece to be placed on the board.
/// - `source_coords`: The coordinates of the source square.
///
/// ## Returns
///
/// - `Ok(Game)`: The updated game state after placing the piece on the board.
/// - `Error(String)`: An error message if the placement is invalid.
pub fn place_piece(
  game: Game,
  target_coords: Coords,
  target_piece: Piece,
  source_coords: Option(Coords),
) -> Result(Game, String) {
  let target_square = retrieve_square(game.board, target_coords)
  case is_placement_legal(target_piece, target_square) {
    Error(reason) -> Error("Placement not legal because: " <> reason)
    Ok(_) -> {
      let updated_game =
        execute_placement(game, source_coords, target_piece, target_square)

      let positioning = is_positioning(game.board)
      let remaining_moves = case positioning {
        True -> 0
        False -> 4
      }

      Ok(Game(..updated_game, positioning:, remaining_moves:))
    }
  }
}

/// Places a piece on the board
///
/// This function does not perform any check before placing the piece, just
/// places the pieces at the given coordinates. This function is more intented
/// to testing and debuggin propouses. For actual games, use the `place_piece`
/// function instead as that function validates the placements before execute
/// it.
///
/// ## Returns
///
/// - `Game`:  The updated game state after placing the piece on the board
pub fn execute_placement(
  game: Game,
  source_coords: Option(Coords),
  target_piece: Piece,
  target_square: Square,
) -> Game {
  let updated_squares = case source_coords {
    Some(source_coords) -> {
      let source_square = retrieve_square(game.board, source_coords)

      [
        Square(..target_square, piece: Some(target_piece)),
        Square(..source_square, piece: None),
      ]
    }

    None -> [Square(..target_square, piece: Some(target_piece))]
  }

  let board = update_board(game.board, updated_squares)

  Game(..game, board:)
}

/// Checks if a piece placement is legal
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

/// Returns a list of pieces that can still be placed during setup
pub fn get_aviable_pieces_to_place(board: Board) -> List(Piece) {
  let colors = [Gold, Silver]
  let piece_types = [Elephant, Camel, Horse, Dog, Cat, Rabbit]

  let get_piece_amount = fn(kind) {
    case list.find(pieces_amount_per_player, fn(p) { p.0 == kind }) {
      Ok(#(_, amount)) -> amount
      Error(_) -> 0
    }
  }

  let get_pieces = fn(color, kind) {
    let piece_ids = get_piece_amount(kind)
    list.map(list.range(1, piece_ids), fn(id) { Piece(kind, color, id) })
  }

  let pieces =
    list.flat_map(colors, fn(color) {
      list.flat_map(piece_types, fn(kind) { get_pieces(color, kind) })
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

/// Checks if the game is still in the positioning phase
pub fn is_positioning(board: Board) -> Bool {
  let position_squares =
    list.filter(board, fn(square) {
      square.x == 1 || square.x == 2 || square.x == 7 || square.x == 8
    })

  list.any(position_squares, fn(square) { square.piece == None })
}

/// Undoes the last move made in the game by reverting the board state and updating the remaining moves.
///
/// This function handles undoing different types of moves:
///
/// - Regular moves: Returns the moved piece to its original square
/// - Repositions (pushes/pulls): Returns both pieces to their original squares
/// - Captures: First restores the captured piece, then undoes the move that led to the capture
///
/// ## Parameters
///
/// - `game`: The current state of the game
///
/// ## Returns
///
/// - `Game`: The updated game state after undoing the last move, with:
///   - Board state reverted to before the move
///   - Remaining moves increased appropriately
///   - History updated to reflect the undone move
pub fn undo_last_move(game: Game) -> Game {
  let assert [last_move, ..history] = game.history

  case last_move {
    Move(source_coords, target_coords) -> {
      let source_square = retrieve_square(game.board, source_coords)
      let target_square = retrieve_square(game.board, target_coords)
      let assert Some(target_piece) = target_square.piece

      let updated_board =
        update_board(game.board, [
          Square(..source_square, piece: Some(target_piece)),
          Square(..target_square, piece: None),
        ])

      Game(
        ..game,
        board: updated_board,
        remaining_moves: game.remaining_moves + 1,
        history:,
      )
    }

    Reposition(
      strong_piece_source_coords,
      weak_piece_source_coords,
      target_coords,
      reposition_type,
    ) -> {
      let strong_piece_source_square =
        retrieve_square(game.board, strong_piece_source_coords)
      let weak_piece_source_square =
        retrieve_square(game.board, weak_piece_source_coords)

      let target_square = retrieve_square(game.board, target_coords)

      let #(strong_piece, weak_piece) = case reposition_type {
        Pull -> {
          let assert Some(strong_piece) = target_square.piece
          let assert Some(weak_piece) = strong_piece_source_square.piece

          #(strong_piece, weak_piece)
        }
        Push -> {
          let assert Some(strong_piece) = weak_piece_source_square.piece
          let assert Some(weak_piece) = target_square.piece

          #(strong_piece, weak_piece)
        }
      }

      let updated_board =
        update_board(game.board, [
          Square(..strong_piece_source_square, piece: Some(strong_piece)),
          Square(..weak_piece_source_square, piece: Some(weak_piece)),
          Square(..target_square, piece: None),
        ])

      Game(
        ..game,
        board: updated_board,
        remaining_moves: game.remaining_moves + 2,
        history:,
      )
    }

    Capture(piece, trap_coords) -> {
      let assert True = list.contains(trap_squares, trap_coords)
      let trap_square = retrieve_square(game.board, trap_coords)
      let updated_board =
        update_board(game.board, [Square(..trap_square, piece: Some(piece))])

      undo_last_move(Game(..game, board: updated_board, history:))
    }
  }
}

/// Removes pieces on trap squares with no adjacent friendly pieces
///
/// ## Returns
///
/// - `Game`: The updated game state after performing captures
pub fn perform_captures(game: Game) -> Game {
  let #(updated_squares, new_history_records) = {
    use acc, trap_coords <- list.fold(trap_squares, #([], []))

    let trap_square = retrieve_square(game.board, trap_coords)

    case trap_square.piece {
      None -> acc
      Some(piece) -> {
        let has_adjacent_allies =
          adjacent_pieces(game.board, trap_coords)
          |> list.any(fn(p) { p.color == piece.color })

        case has_adjacent_allies {
          True -> acc
          False -> {
            let updated_squares = [Square(..trap_square, piece: None), ..acc.0]
            let updated_history = [Capture(piece, trap_coords), ..acc.1]
            #(updated_squares, updated_history)
          }
        }
      }
    }
  }

  let updated_board = update_board(game.board, updated_squares)
  let updated_history =
    list.fold(new_history_records, game.history, fn(acc, record) {
      [record, ..acc]
    })

  Game(..game, board: updated_board, history: updated_history)
}

/// Checks if either player has won the game and updates the game state accordingly.
///
/// Supported win conditions:
///
/// - A rabbit has reached its opposite end of the board
/// - All pieces from one player has beencaptured
///
/// ## Returns
///
/// - `Game`: The updated game state after checking for a win
pub fn check_win(game: Game) -> Game {
  let win_conditions = [
    is_rabbit_reached_opposite_end,
    player_has_all_pieces_captured,
  ]

  let win = list.any(win_conditions, fn(condition) { condition(game.board) })

  Game(..game, win:)
}

fn is_rabbit_reached_opposite_end(board: Board) {
  board
  |> list.filter(fn(square) { list.contains([1, 8], square.x) })
  |> list.any(fn(square) {
    case square.piece, square.x {
      Some(Piece(Rabbit, Gold, _)), 8 -> True
      Some(Piece(Rabbit, Silver, _)), 1 -> True
      _, _ -> False
    }
  })
}

fn player_has_all_pieces_captured(board: Board) {
  let #(gold_pieces, silver_pieces) = {
    use acc, square <- list.fold(board, #([], []))
    case square.piece {
      Some(piece) if piece.color == Gold -> #([piece, ..acc.0], acc.1)
      Some(piece) if piece.color == Silver -> #(acc.0, [piece, ..acc.1])
      _ -> acc
    }
  }

  list.is_empty(gold_pieces) || list.is_empty(silver_pieces)
}

/// Finds a square at the given coordinates
pub fn retrieve_square(board: Board, coords: Coords) -> Square {
  let assert Ok(square) =
    list.find(board, fn(square) {
      let #(x, y) = coords
      square.x == x && square.y == y
    })

  square
}

/// Finds the square containing the given piece
pub fn retrieve_square_from_piece(board: Board, piece: Piece) -> Square {
  let assert Ok(square) =
    list.find(board, fn(square) { square.piece == Some(piece) })

  square
}

/// For a given coordinate, returns the list of all
/// adyacent coordinates in the board
pub fn adjacent_coords(coords: Coords) -> List(Coords) {
  let #(x, y) = coords
  let possible = [#(x + 1, y), #(x - 1, y), #(x, y + 1), #(x, y - 1)]

  list.filter(possible, fn(coord) {
    let #(x, y) = coord
    x >= 1 && x <= 8 && y >= 1 && y <= 8
  })
}

/// Returns a list of pieces in adjacent squares
pub fn adjacent_pieces(board: Board, coords: Coords) -> List(Piece) {
  coords
  |> adjacent_coords()
  |> list.filter_map(fn(a_coords) {
    let assert Ok(square) =
      list.find(board, fn(s) { s.x == a_coords.0 && s.y == a_coords.1 })

    case square.piece {
      Some(piece) -> Ok(piece)
      None -> Error("No piece found in the adjacent square")
    }
  })
}

/// Converts a piece color to its string representation
pub fn piece_color_to_string(piece_color: PieceColor) {
  case piece_color {
    Gold -> "gold"
    Silver -> "silver"
  }
}

/// Converts a piece kind to its string representation
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

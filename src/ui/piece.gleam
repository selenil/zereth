import lustre/attribute
import lustre/element/html

import game_engine

pub fn render(piece: game_engine.Piece, class_name: String, is_ghost: Bool) {
  let piece_alt =
    game_engine.piece_color_to_string(piece.color)
    <> "_"
    <> game_engine.piece_kind_to_string(piece.kind)

  html.div(
    [
      attribute.class("piece"),
      attribute.class(class_name),
      case is_ghost {
        True -> attribute.class("ghost")
        False -> attribute.none()
      },
      attribute.attribute("draggable", "true"),
    ],
    [
      html.img([
        attribute.src(get_piece_asset_name(piece)),
        attribute.alt(piece_alt),
      ]),
    ],
  )
}

fn get_piece_asset_name(piece: game_engine.Piece) {
  let color = game_engine.piece_color_to_string(piece.color)

  let kind = game_engine.piece_kind_to_string(piece.kind)

  "assets/pieces/" <> color <> "_" <> kind <> ".png"
}

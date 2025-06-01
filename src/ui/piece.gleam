import lustre/attribute
import lustre/element/html

import game_engine

pub fn render(piece: game_engine.Piece, class_name: String) {
  let piece_alt =
    game_engine.piece_color_to_string(piece.color)
    <> "_"
    <> game_engine.piece_kind_to_string(piece.kind)

  html.div(
    [
      attribute.class("piece"),
      attribute.class(class_name),
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

pub fn render_ghost(piece: game_engine.Piece) {
  render(piece, "ghost")
}

fn get_piece_asset_name(piece: game_engine.Piece) {
  let color = game_engine.piece_color_to_string(piece.color)

  let kind = game_engine.piece_kind_to_string(piece.kind)

  "assets/pieces/" <> color <> "_" <> kind <> ".png"
}

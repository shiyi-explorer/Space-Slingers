package services.levels.objects

import io.circe.{Decoder, Encoder}

final case class LevelId(value: String)

object LevelId:
  given Encoder[LevelId] = Encoder.encodeString.contramap(_.value)
  given Decoder[LevelId] = Decoder.decodeString.map(LevelId.apply)

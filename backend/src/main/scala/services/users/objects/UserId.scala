package services.users.objects

import io.circe.{Decoder, Encoder}

final case class UserId(value: String)

object UserId:
  given Encoder[UserId] = Encoder.encodeString.contramap(_.value)
  given Decoder[UserId] = Decoder.decodeString.map(UserId.apply)

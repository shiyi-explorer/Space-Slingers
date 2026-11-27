package services.users.objects

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

import java.time.Instant

final case class User(
  id: UserId,
  username: String,
  createdAt: Instant
)

object User:
  given Encoder[User] = deriveEncoder[User]
  given Decoder[User] = deriveDecoder[User]

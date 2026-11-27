package services.users.objects.apiTypes

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.users.objects.UserId

final case class CurrentUserResponse(
  userId: UserId,
  username: String
)

object CurrentUserResponse:
  given Encoder[CurrentUserResponse] = deriveEncoder[CurrentUserResponse]
  given Decoder[CurrentUserResponse] = deriveDecoder[CurrentUserResponse]

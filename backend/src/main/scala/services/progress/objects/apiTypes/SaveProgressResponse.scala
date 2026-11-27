package services.progress.objects.apiTypes

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

final case class SaveProgressResponse(saved: Boolean)

object SaveProgressResponse:
  given Encoder[SaveProgressResponse] = deriveEncoder[SaveProgressResponse]
  given Decoder[SaveProgressResponse] = deriveDecoder[SaveProgressResponse]

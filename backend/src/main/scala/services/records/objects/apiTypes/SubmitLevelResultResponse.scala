package services.records.objects.apiTypes

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

final case class SubmitLevelResultResponse(
  accepted: Boolean,
  bestScore: Long
)

object SubmitLevelResultResponse:
  given Encoder[SubmitLevelResultResponse] = deriveEncoder[SubmitLevelResultResponse]
  given Decoder[SubmitLevelResultResponse] = deriveDecoder[SubmitLevelResultResponse]

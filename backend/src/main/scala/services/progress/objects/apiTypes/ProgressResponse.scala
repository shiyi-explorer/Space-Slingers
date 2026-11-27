package services.progress.objects.apiTypes

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

final case class ProgressResponse(
  unlocked: Boolean,
  completed: Boolean,
  bestScore: Long,
  minCompletedBirdsUsed: Option[Int]
)

object ProgressResponse:
  given Encoder[ProgressResponse] = deriveEncoder[ProgressResponse]
  given Decoder[ProgressResponse] = deriveDecoder[ProgressResponse]

package services.stats.objects.apiTypes

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

final case class PlayerStatsResponse(
  totalRuns: Int,
  completedRuns: Int,
  totalBirdsUsed: Int,
  totalScore: Long,
  bestScore: Long
)

object PlayerStatsResponse:
  given Encoder[PlayerStatsResponse] = deriveEncoder[PlayerStatsResponse]
  given Decoder[PlayerStatsResponse] = deriveDecoder[PlayerStatsResponse]

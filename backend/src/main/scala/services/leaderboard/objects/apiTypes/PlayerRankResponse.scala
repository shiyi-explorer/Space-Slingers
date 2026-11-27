package services.leaderboard.objects.apiTypes

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

final case class PlayerRankResponse(
  levelId: String,
  rank: Int,
  bestScore: Long
)

object PlayerRankResponse:
  given Encoder[PlayerRankResponse] = deriveEncoder[PlayerRankResponse]
  given Decoder[PlayerRankResponse] = deriveDecoder[PlayerRankResponse]

package services.leaderboard.objects.apiTypes

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

final case class LeaderboardResponse(
  levelId: String,
  entries: List[LeaderboardEntry]
)

object LeaderboardResponse:
  given Encoder[LeaderboardResponse] = deriveEncoder[LeaderboardResponse]
  given Decoder[LeaderboardResponse] = deriveDecoder[LeaderboardResponse]

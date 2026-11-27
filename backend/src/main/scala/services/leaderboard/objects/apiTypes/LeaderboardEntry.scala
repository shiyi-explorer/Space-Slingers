package services.leaderboard.objects.apiTypes

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

final case class LeaderboardEntry(
  rank: Int,
  username: String,
  score: Long,
  birdsUsed: Int
)

object LeaderboardEntry:
  given Encoder[LeaderboardEntry] = deriveEncoder[LeaderboardEntry]
  given Decoder[LeaderboardEntry] = deriveDecoder[LeaderboardEntry]

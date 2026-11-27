package services.leaderboard.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.leaderboard.objects.apiTypes.PlayerRankResponse
import services.records.tables.LevelResultTable.LevelResultTable
import services.system.api.APIWithTokenMessage
import services.users.objects.UserId

import java.sql.Connection

/** 查询自己在某关的名次与最好成绩。 */
final case class GetPlayerRankMessage(
  userId: UserId,
  levelId: String
) extends APIWithTokenMessage[PlayerRankResponse]:

  override def plan(connection: Connection): IO[PlayerRankResponse] =
    for
      rank <- LevelResultTable.rankOf(connection, levelId, userId)
      best <- LevelResultTable.bestScore(connection, userId, levelId)
    yield PlayerRankResponse(levelId, rank, best)

object GetPlayerRankMessage:
  given Encoder[GetPlayerRankMessage] = deriveEncoder[GetPlayerRankMessage]
  given Decoder[GetPlayerRankMessage] = deriveDecoder[GetPlayerRankMessage]

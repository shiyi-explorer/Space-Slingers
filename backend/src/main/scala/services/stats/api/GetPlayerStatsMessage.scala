package services.stats.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.stats.objects.apiTypes.PlayerStatsResponse
import services.stats.tables.StatsTable.StatsTable
import services.system.api.APIWithTokenMessage
import services.users.objects.UserId

import java.sql.Connection

/** 汇总当前玩家的整体统计：总局数、通关数、总用鸟、总分、最高分。 */
final case class GetPlayerStatsMessage(
  userId: UserId
) extends APIWithTokenMessage[PlayerStatsResponse]:

  override def plan(connection: Connection): IO[PlayerStatsResponse] =
    StatsTable.findByUser(connection, userId).map {
      case Some((totalRuns, completedRuns, birds, totalScore, bestScore)) =>
        PlayerStatsResponse(totalRuns, completedRuns, birds, totalScore, bestScore)
      case None =>
        PlayerStatsResponse(totalRuns = 0, completedRuns = 0, totalBirdsUsed = 0, totalScore = 0L, bestScore = 0L)
    }

object GetPlayerStatsMessage:
  given Encoder[GetPlayerStatsMessage] = deriveEncoder[GetPlayerStatsMessage]
  given Decoder[GetPlayerStatsMessage] = deriveDecoder[GetPlayerStatsMessage]

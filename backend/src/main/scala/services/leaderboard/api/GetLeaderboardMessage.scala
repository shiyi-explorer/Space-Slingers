package services.leaderboard.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.leaderboard.objects.apiTypes.{LeaderboardEntry, LeaderboardResponse}
import services.records.tables.LevelResultTable.LevelResultTable
import services.system.api.APIMessage

import java.sql.Connection

/** 关卡排行榜：读模型 API，数据来自 records 服务的公开表方法（规则 34：成绩表归属 records），
  * 本服务提供真实领域逻辑——并列名次计算（同分同名次，此后跳号）。 */
final case class GetLeaderboardMessage(
  levelId: String,
  limit: Int
) extends APIMessage[LeaderboardResponse]:

  override def plan(connection: Connection): IO[LeaderboardResponse] =
    val safeLimit = math.min(50, math.max(1, limit))
    LevelResultTable.topByLevel(connection, levelId, safeLimit).map { rows =>
      LeaderboardResponse(levelId, assignRanks(rows))
    }

  /** 并列名次：同分同名次（dense 风格但跳号，如 1,2,2,4）。 */
  private def assignRanks(rows: List[(String, String, Long, Int)]): List[LeaderboardEntry] =
    val indexed = rows.zipWithIndex
    indexed.map { case ((userId, username, score, birds), position) =>
      val rank = indexed.count { case ((_, _, other, _), _) => other > score } + 1
      LeaderboardEntry(rank, username, score, birds)
    }.sortBy(entry => (entry.rank, entry.username))

object GetLeaderboardMessage:
  given Encoder[GetLeaderboardMessage] = deriveEncoder[GetLeaderboardMessage]
  given Decoder[GetLeaderboardMessage] = deriveDecoder[GetLeaderboardMessage]

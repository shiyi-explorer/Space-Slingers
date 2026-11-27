package services.progress.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.levels.objects.LevelId
import services.levels.tables.LevelTable.LevelTable
import services.progress.objects.apiTypes.ProgressResponse
import services.progress.tables.ProgressTable.ProgressTable
import services.records.tables.LevelResultTable.LevelResultTable
import services.system.api.APIWithTokenMessage
import services.system.HttpError
import services.users.objects.UserId

import java.sql.Connection

/** 读取玩家某关的进度：解锁规则 = 通过的最大章节 + 1，首关恒解锁。 */
final case class LoadProgressMessage(
  userId: UserId,
  levelId: LevelId
) extends APIWithTokenMessage[ProgressResponse]:

  override def plan(connection: Connection): IO[ProgressResponse] =
    for
      level <- LevelTable.findById(connection, levelId).flatMap {
        case Some(found) => IO.pure(found)
        case None => IO.raiseError(HttpError.NotFound(s"关卡不存在：${levelId.value}"))
      }
      maxChapter <- ProgressTable.maxCompletedChapter(connection, userId)
      progress <- ProgressTable.findByUserAndLevel(connection, userId, levelId)
      fewest <- LevelResultTable.minCompletedBirdsUsed(connection, userId, levelId.value)
      unlocked = level.chapter <= maxChapter + 1
      bestScore = progress.map(_.bestScore).getOrElse(0L)
      completed = progress.map(_.completed).getOrElse(false)
    yield ProgressResponse(unlocked, completed, bestScore, fewest)

object LoadProgressMessage:
  given Encoder[LoadProgressMessage] = deriveEncoder[LoadProgressMessage]
  given Decoder[LoadProgressMessage] = deriveDecoder[LoadProgressMessage]

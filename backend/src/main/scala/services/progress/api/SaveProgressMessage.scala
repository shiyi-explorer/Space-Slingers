package services.progress.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.levels.objects.LevelId
import services.levels.tables.LevelTable.LevelTable
import services.progress.objects.PlayerProgress
import services.progress.objects.apiTypes.SaveProgressResponse
import services.progress.tables.ProgressTable.ProgressTable
import services.system.api.APIWithTokenMessage
import services.system.HttpError
import services.users.objects.UserId

import java.sql.Connection

/** 手动保存进度（一般由 records 提交成绩时联动更新，此接口供调试与补录）。 */
final case class SaveProgressMessage(
  userId: UserId,
  levelId: LevelId,
  unlocked: Boolean,
  completed: Boolean,
  bestScore: Long
) extends APIWithTokenMessage[SaveProgressResponse]:

  override def plan(connection: Connection): IO[SaveProgressResponse] =
    for
      _ <- LevelTable.findById(connection, levelId).flatMap {
        case Some(_) => IO.unit
        case None => IO.raiseError(HttpError.NotFound(s"关卡不存在：${levelId.value}"))
      }
      _ <- IO.raiseWhen(bestScore < 0L)(HttpError.BadRequest("分数不能为负。"))
      _ <- ProgressTable.save(connection, PlayerProgress(userId, levelId, unlocked, completed, bestScore))
    yield SaveProgressResponse(saved = true)

object SaveProgressMessage:
  given Encoder[SaveProgressMessage] = deriveEncoder[SaveProgressMessage]
  given Decoder[SaveProgressMessage] = deriveDecoder[SaveProgressMessage]

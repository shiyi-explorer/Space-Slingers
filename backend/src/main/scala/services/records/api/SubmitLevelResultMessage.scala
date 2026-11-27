package services.records.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.levels.objects.LevelId
import services.levels.tables.LevelTable.LevelTable
import services.progress.objects.PlayerProgress
import services.progress.tables.ProgressTable.ProgressTable
import services.records.objects.LevelResult
import services.records.objects.apiTypes.SubmitLevelResultResponse
import services.records.tables.LevelResultTable.LevelResultTable
import services.stats.tables.StatsTable.StatsTable
import services.system.api.APIWithTokenMessage
import services.system.HttpError
import services.users.objects.UserId

import java.sql.Connection
import java.time.Instant

/** 提交成绩：服务端合理性校验（理论满分上限、用鸟数上限、时长窗口）后写入，
  * 并联动 progress（完成标记 + 解锁下一关 + 最好分）与 stats（聚合增量）。 */
final case class SubmitLevelResultMessage(
  userId: UserId,
  levelId: LevelId,
  completed: Boolean,
  score: Long,
  birdsUsed: Int,
  durationSeconds: Double
) extends APIWithTokenMessage[SubmitLevelResultResponse]:

  override def plan(connection: Connection): IO[SubmitLevelResultResponse] =
    for
      level <- LevelTable.findById(connection, levelId).flatMap {
        case Some(found) => IO.pure(found)
        case None => IO.raiseError(HttpError.NotFound(s"关卡不存在：${levelId.value}"))
      }
      _ <- validate(level.birds, level.maxScore)
      _ <- LevelResultTable.insert(connection, LevelResult(
        userId, levelId, completed, score, birdsUsed, durationSeconds, Instant.now()))
      best <- LevelResultTable.bestScore(connection, userId, levelId.value)
      _ <- ProgressTable.save(connection, PlayerProgress(userId, levelId,
        unlocked = true, completed = completed, bestScore = best))
      _ <- StatsTable.increment(connection, userId, birdsUsed, score, if completed then 1 else 0)
    yield SubmitLevelResultResponse(accepted = true, bestScore = best)

  /** 物理弹道服务端不可复验，只做合理性边界：防粗制滥造的假成绩。 */
  private def validate(levelBirds: Int, maxScore: Long): IO[Unit] =
    for
      _ <- IO.raiseWhen(birdsUsed < 1 || birdsUsed > levelBirds)(
        HttpError.BadRequest(s"用鸟数必须在 1 ~ $levelBirds 之间。"))
      _ <- IO.raiseWhen(score < 0L || score > maxScore)(
        HttpError.BadRequest(s"分数超出理论满分上限（$maxScore）。"))
      _ <- IO.raiseWhen(durationSeconds <= 0.0 || durationSeconds > 3600.0)(
        HttpError.BadRequest("游戏时长超出合理范围。"))
    yield ()

object SubmitLevelResultMessage:
  given Encoder[SubmitLevelResultMessage] = deriveEncoder[SubmitLevelResultMessage]
  given Decoder[SubmitLevelResultMessage] = deriveDecoder[SubmitLevelResultMessage]

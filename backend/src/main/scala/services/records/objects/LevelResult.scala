package services.records.objects

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.levels.objects.LevelId
import services.users.objects.UserId

import java.time.Instant

final case class LevelResult(
  userId: UserId,
  levelId: LevelId,
  completed: Boolean,
  score: Long,
  birdsUsed: Int,
  durationSeconds: Double,
  createdAt: Instant
)

object LevelResult:
  given Encoder[LevelResult] = deriveEncoder[LevelResult]
  given Decoder[LevelResult] = deriveDecoder[LevelResult]

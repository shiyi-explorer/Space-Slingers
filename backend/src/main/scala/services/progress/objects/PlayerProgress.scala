package services.progress.objects

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.levels.objects.LevelId
import services.users.objects.UserId

final case class PlayerProgress(
  userId: UserId,
  levelId: LevelId,
  unlocked: Boolean,
  completed: Boolean,
  bestScore: Long
)

object PlayerProgress:
  given Encoder[PlayerProgress] = deriveEncoder[PlayerProgress]
  given Decoder[PlayerProgress] = deriveDecoder[PlayerProgress]

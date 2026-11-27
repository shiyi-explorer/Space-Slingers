package services.levels.objects

import io.circe.{Decoder, Encoder, Json}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}

/** 关卡定义：几何结构整体存于 data（JSONB），maxScore 由服务端按理论满分算好供成绩校验。 */
final case class LevelDefinition(
  id: LevelId,
  chapter: Int,
  name: String,
  birds: Int,
  maxScore: Long,
  data: Json
)

object LevelDefinition:
  given Encoder[LevelDefinition] = deriveEncoder[LevelDefinition]
  given Decoder[LevelDefinition] = deriveDecoder[LevelDefinition]

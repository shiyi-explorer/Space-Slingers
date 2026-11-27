package services.levels.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.levels.objects.LevelDefinition
import services.levels.objects.LevelId
import services.levels.tables.LevelTable.LevelTable
import services.system.api.APIMessage
import services.system.HttpError

import java.sql.Connection

/** 读取关卡定义：几何数据由后端统一下发，前端不做本地配置。 */
final case class GetLevelDefinitionMessage(
  levelId: LevelId
) extends APIMessage[LevelDefinition]:

  override def plan(connection: Connection): IO[LevelDefinition] =
    LevelTable.findById(connection, levelId).flatMap {
      case Some(definition) => IO.pure(definition)
      case None => IO.raiseError(HttpError.NotFound(s"关卡不存在：${levelId.value}"))
    }

object GetLevelDefinitionMessage:
  given Encoder[GetLevelDefinitionMessage] = deriveEncoder[GetLevelDefinitionMessage]
  given Decoder[GetLevelDefinitionMessage] = deriveDecoder[GetLevelDefinitionMessage]

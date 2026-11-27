package services.users.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.system.api.APIWithTokenMessage
import services.system.HttpError
import services.users.objects.UserId
import services.users.objects.apiTypes.CurrentUserResponse
import services.users.tables.UserTable.UserTable

import java.sql.Connection

/** 查询当前登录用户：路由器已将 userToken 解析为可信 userId。 */
final case class GetCurrentUserMessage(
  userId: UserId
) extends APIWithTokenMessage[CurrentUserResponse]:

  override def plan(connection: Connection): IO[CurrentUserResponse] =
    for
      user <- UserTable.findById(connection, userId)
      response <- user match
        case Some(found) => IO.pure(CurrentUserResponse(found.id, found.username))
        case None => IO.raiseError(HttpError.Unauthorized("登录状态已失效，请重新登录。"))
    yield response

object GetCurrentUserMessage:
  given Encoder[GetCurrentUserMessage] = deriveEncoder[GetCurrentUserMessage]
  given Decoder[GetCurrentUserMessage] = deriveDecoder[GetCurrentUserMessage]

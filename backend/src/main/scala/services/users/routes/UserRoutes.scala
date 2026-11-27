package services.users.routes

import cats.effect.IO
import io.circe.Json
import io.circe.syntax.*
import services.system.api.{APIMessageRouter, RegisteredAPIMessage}
import services.system.HttpError
import services.users.api.{GetCurrentUserMessage, LoginMessage}
import services.users.objects.apiTypes.{CurrentUserResponse, LoginResponse}
import services.users.tables.SessionTable.SessionTable
import services.users.utils.UsersCrypto

import java.sql.Connection

object UserRoutes:

  /** 路由器令牌解析入口：将前端令牌转换为可信 userId（规则 28）。 */
  def resolveUserToken(token: String, connection: Connection): IO[Json] =
    SessionTable.findUserIdByToken(connection, UsersCrypto.hashSecret(token)).flatMap {
      case Some(userId) => IO.pure(userId.asJson)
      case None => IO.raiseError(HttpError.Unauthorized("登录状态已失效，请重新登录。"))
    }

  def apiMessages: List[RegisteredAPIMessage] = List(
    RegisteredAPIMessage.api[LoginMessage, LoginResponse],
    RegisteredAPIMessage.apiWithToken[GetCurrentUserMessage, CurrentUserResponse],
  )

  val routes = APIMessageRouter.routes(apiMessages, resolveUserToken)

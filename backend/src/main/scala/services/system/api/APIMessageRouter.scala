package services.system.api

import cats.effect.IO
import io.circe.Json
import io.circe.syntax.*
import org.http4s.{HttpRoutes, InvalidMessageBodyFailure, Response, Status}
import org.http4s.circe.CirceEntityCodec.*
import org.http4s.circe.CirceEntityEncoder.*
import org.http4s.dsl.io.*
import services.system.objects.apiTypes.ErrorResponse
import services.system.{DatabaseSession, HttpError}

import java.sql.Connection

object APIMessageRouter:

  def routes(
    apiMessages: List[RegisteredAPIMessage],
    resolveUserToken: (String, Connection) => IO[Json]
  ): HttpRoutes[IO] =
    val apiMessagesByName = apiMessages.map(apiMessage => normalize(apiMessage.apiName) -> apiMessage).toMap

    HttpRoutes.of[IO] {
      case request @ POST -> Root / "api" / apiName =>
        handleErrors {
          for
            apiMessage <- IO.fromOption(apiMessagesByName.get(normalize(apiName)))(
              HttpError.NotFound(s"不支持的 API：$apiName")
            )
            payload <- request.as[Json]
            backendPayload <- preparePayload(apiMessage, payload, resolveUserToken)
            response <- DatabaseSession.withTransaction(connection => apiMessage.planJson(backendPayload, connection))
            httpResponse <- Ok(response)
          yield httpResponse
        }
    }

  private def preparePayload(
    apiMessage: RegisteredAPIMessage,
    payload: Json,
    resolveUserToken: (String, Connection) => IO[Json]
  ): IO[Json] =
    if apiMessage.requiresUserToken then
      DatabaseSession.withConnection { connection =>
        for
          userToken <- extractUserToken(payload)
          userIdJson <- resolveUserToken(userToken, connection)
        yield replaceUserTokenWithUserId(payload, userIdJson)
      }
    else IO.pure(payload)

  private def extractUserToken(payload: Json): IO[String] =
    payload.hcursor.get[String]("userToken") match
      case Right(value) if value.trim.nonEmpty => IO.pure(value.trim)
      case _ => IO.raiseError(HttpError.Unauthorized("请先登录。"))

  private def replaceUserTokenWithUserId(payload: Json, userIdJson: Json): Json =
    payload.asObject match
      case Some(value) => Json.fromJsonObject(value.remove("userToken").add("userId", userIdJson))
      case None => payload

  private def normalize(apiName: String): String =
    apiName.trim.toLowerCase

  private def handleErrors(action: IO[Response[IO]]): IO[Response[IO]] =
    action.handleErrorWith {
      case error: InvalidMessageBodyFailure =>
        BadRequest(ErrorResponse(error.getMessage).asJson)
      case error: HttpError.BadRequest =>
        BadRequest(ErrorResponse(error.message).asJson)
      case error: HttpError.Unauthorized =>
        IO.pure(Response[IO](Status.Unauthorized).withEntity(ErrorResponse(error.message).asJson))
      case error: HttpError.Forbidden =>
        Forbidden(ErrorResponse(error.message).asJson)
      case error: HttpError.NotFound =>
        NotFound(ErrorResponse(error.message).asJson)
      case error: HttpError.Conflict =>
        Conflict(ErrorResponse(error.message).asJson)
      case error =>
        IO.println(s"API failure: ${error.getClass.getName}") *>
          InternalServerError(ErrorResponse("服务器暂时无法处理请求，请稍后重试。").asJson)
    }

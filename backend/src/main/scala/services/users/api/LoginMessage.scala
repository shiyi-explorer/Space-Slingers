package services.users.api

import cats.effect.IO
import cats.syntax.all.*
import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto.{deriveDecoder, deriveEncoder}
import services.system.api.APIMessage
import services.system.{DatabaseSession, HttpError}
import services.users.objects.apiTypes.LoginResponse
import services.users.objects.{User, UserId}
import services.users.tables.SessionTable.SessionTable
import services.users.tables.UserTable.UserTable
import services.users.utils.UsersCrypto

import java.sql.Connection
import java.time.Instant
import java.util.UUID

/** 登录：用户名不存在则注册并登录；已存在则校验通行密钥，通过后签发 24 小时令牌。 */
final case class LoginMessage(
  username: String,
  password: String
) extends APIMessage[LoginResponse]:

  override def plan(connection: Connection): IO[LoginResponse] =
    for
      username <- IO.fromEither(normalizeUsername)
      _ <- validatePassword
      userId <- loginOrRegister(connection, username)
      token <- UsersCrypto.generateToken()
      _ <- SessionTable.save(connection, UsersCrypto.hashSecret(token), userId)
    yield LoginResponse(userId, username, token)

  private def normalizeUsername: Either[HttpError.BadRequest, String] =
    val trimmed = username.trim
    if trimmed.length < 2 then
      Left(HttpError.BadRequest("研究员代号至少 2 个字符"))
    else if trimmed.length > 32 then
      Left(HttpError.BadRequest("研究员代号不能超过 32 个字符"))
    else
      Right(trimmed)

  private def validatePassword: IO[Unit] =
    if password.length < 4 then
      IO.raiseError(HttpError.BadRequest("通行密钥至少 4 位"))
    else IO.unit

  private def loginOrRegister(connection: Connection, name: String): IO[UserId] =
    UserTable.findByUsername(connection, name).flatMap {
      case Some(user) =>
        UserTable.verifyPasswordHash(connection, name, UsersCrypto.hashSecret(password)).flatMap {
          case Some(userId) => IO.pure(userId)
          case None => IO.raiseError(HttpError.Unauthorized("通行密钥不正确。"))
        }
      case None =>
        val user = User(UserId(UUID.randomUUID().toString), name, Instant.now())
        UserTable.insert(connection, user, UsersCrypto.hashSecret(password)).map(_.id)
    }

object LoginMessage:
  given Encoder[LoginMessage] = deriveEncoder[LoginMessage]
  given Decoder[LoginMessage] = deriveDecoder[LoginMessage]

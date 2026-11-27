package services.system.api

import java.sql.Connection
import cats.effect.IO

trait APIMessage[Response]:
  def plan(connection: Connection): IO[Response]

object APIMessage:

  private[api] def apiNameFromClassName(className: String): String =
    className.stripSuffix("$").stripSuffix("Message").toLowerCase

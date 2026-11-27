package services.system

import cats.effect.IO

import java.sql.{Connection, DriverManager}

object DatabaseSession:
  private val config = DatabaseConfig.fromEnvironment
  private val url = s"jdbc:postgresql://${config.host}:${config.port}/${config.databaseName}"

  def withConnection[A](action: Connection => IO[A]): IO[A] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(DriverManager.getConnection(url, config.username, config.password))).use(action)

  def withTransaction[A](action: Connection => IO[A]): IO[A] =
    withConnection { connection =>
      for
        _ <- IO.blocking(connection.setAutoCommit(false))
        result <- action(connection).attempt
        value <- result match
          case Right(value) => IO.blocking(connection.commit()).as(value)
          case Left(error) => IO.blocking(connection.rollback()) *> IO.raiseError(error)
      yield value
    }

package services.users.tables.UserTable

import cats.effect.IO
import services.users.objects.{User, UserId}

import java.sql.Connection

object UserTable:

  private val findByUsernameSql = "SELECT id, username, created_at FROM ss_users WHERE username = ?"
  def findByUsername(connection: Connection, username: String): IO[Option[User]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findByUsernameSql))).use { statement =>
      for
        _ <- IO.blocking(statement.setString(1, username))
        user <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use(cursor =>
          IO.blocking(
            if cursor.next() then
              Some(User(UserId(cursor.getString("id")), cursor.getString("username"), cursor.getTimestamp("created_at").toInstant))
            else None
          )
        )
      yield user
    }

  private val insertSql = "INSERT INTO ss_users (id, username, password_hash, created_at) VALUES (?, ?, ?, ?)"
  def insert(connection: Connection, user: User, passwordHash: String): IO[User] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(insertSql))).use { statement =>
      IO.blocking {
        statement.setString(1, user.id.value)
        statement.setString(2, user.username)
        statement.setString(3, passwordHash)
        statement.setTimestamp(4, java.sql.Timestamp.from(user.createdAt))
        statement.executeUpdate()
        user
      }
    }

  private val findByIdSql = "SELECT id, username, created_at FROM ss_users WHERE id = ?"
  def findById(connection: Connection, userId: UserId): IO[Option[User]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findByIdSql))).use { statement =>
      for
        _ <- IO.blocking(statement.setString(1, userId.value))
        user <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use(cursor =>
          IO.blocking(
            if cursor.next() then
              Some(User(UserId(cursor.getString("id")), cursor.getString("username"), cursor.getTimestamp("created_at").toInstant))
            else None
          )
        )
      yield user
    }

  private val findPasswordHashSql = "SELECT id, password_hash FROM ss_users WHERE username = ?"
  def verifyPasswordHash(connection: Connection, username: String, expectedHash: String): IO[Option[UserId]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findPasswordHashSql))).use { statement =>
      for
        _ <- IO.blocking(statement.setString(1, username))
        found <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use(cursor =>
          IO.blocking(
            if cursor.next() && cursor.getString("password_hash") == expectedHash then
              Some(UserId(cursor.getString("id")))
            else None
          )
        )
      yield found
    }

  private val findUserIdByUsernameSql = "SELECT id FROM ss_users WHERE username = ?"
  def findUserIdByUsername(connection: Connection, username: String): IO[Option[UserId]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findUserIdByUsernameSql))).use { statement =>
      for
        _ <- IO.blocking(statement.setString(1, username))
        found <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use(cursor =>
          IO.blocking(if cursor.next() then Some(UserId(cursor.getString("id"))) else None)
        )
      yield found
    }

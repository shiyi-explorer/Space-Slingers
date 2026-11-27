package services.users.tables.SessionTable

import cats.effect.IO
import services.users.objects.UserId

import java.sql.Connection

object SessionTable:

  private val insertSql =
    "INSERT INTO ss_sessions (token_hash, user_id, expires_at) VALUES (?, ?, CURRENT_TIMESTAMP + INTERVAL '24 hours') ON CONFLICT (token_hash) DO UPDATE SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at"
  def save(connection: Connection, tokenHash: String, userId: UserId): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(insertSql))).use { statement =>
      IO.blocking {
        statement.setString(1, tokenHash)
        statement.setString(2, userId.value)
        statement.executeUpdate()
        ()
      }
    }

  private val findUserIdByTokenSql =
    "SELECT user_id FROM ss_sessions WHERE token_hash = ? AND expires_at > CURRENT_TIMESTAMP"
  def findUserIdByToken(connection: Connection, tokenHash: String): IO[Option[UserId]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findUserIdByTokenSql))).use { statement =>
      for
        _ <- IO.blocking(statement.setString(1, tokenHash))
        found <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use(cursor =>
          IO.blocking(if cursor.next() then Some(UserId(cursor.getString("user_id"))) else None)
        )
      yield found
    }

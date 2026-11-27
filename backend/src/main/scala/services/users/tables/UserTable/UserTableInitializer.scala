package services.users.tables.UserTable

import cats.effect.IO

import java.sql.Connection

object UserTableInitializer:

  private val createTableSql =
    """CREATE TABLE IF NOT EXISTS ss_users (
      |  id VARCHAR(64) PRIMARY KEY,
      |  username TEXT NOT NULL UNIQUE,
      |  password_hash TEXT NOT NULL,
      |  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      |)""".stripMargin

  private val createUsernameIndexSql = "CREATE INDEX IF NOT EXISTS ss_users_username_idx ON ss_users (username)"

  def initialize(connection: Connection): IO[Unit] =
    for
      _ <- cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.createStatement())).use { statement =>
        IO.blocking { statement.execute(createTableSql); statement.execute(createUsernameIndexSql); () }
      }
    yield ()

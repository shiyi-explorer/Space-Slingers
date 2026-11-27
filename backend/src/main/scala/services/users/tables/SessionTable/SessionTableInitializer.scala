package services.users.tables.SessionTable

import cats.effect.IO

import java.sql.Connection

object SessionTableInitializer:

  private val createTableSql =
    """CREATE TABLE IF NOT EXISTS ss_sessions (
      |  token_hash VARCHAR(128) PRIMARY KEY,
      |  user_id VARCHAR(64) NOT NULL REFERENCES ss_users (id) ON DELETE CASCADE,
      |  expires_at TIMESTAMPTZ NOT NULL
      |)""".stripMargin

  private val createUserIdIndexSql = "CREATE INDEX IF NOT EXISTS ss_sessions_user_idx ON ss_sessions (user_id)"

  def initialize(connection: Connection): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.createStatement())).use { statement =>
      IO.blocking { statement.execute(createTableSql); statement.execute(createUserIdIndexSql); () }
    }

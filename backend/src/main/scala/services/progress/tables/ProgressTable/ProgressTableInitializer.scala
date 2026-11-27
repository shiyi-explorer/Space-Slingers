package services.progress.tables.ProgressTable

import cats.effect.IO

import java.sql.Connection

object ProgressTableInitializer:

  private val createTableSql =
    """CREATE TABLE IF NOT EXISTS ss_progress (
      |  user_id VARCHAR(64) NOT NULL REFERENCES ss_users (id) ON DELETE CASCADE,
      |  level_id VARCHAR(64) NOT NULL REFERENCES ss_levels (id) ON DELETE CASCADE,
      |  unlocked BOOLEAN NOT NULL DEFAULT FALSE,
      |  completed BOOLEAN NOT NULL DEFAULT FALSE,
      |  best_score BIGINT NOT NULL DEFAULT 0,
      |  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      |  PRIMARY KEY (user_id, level_id)
      |)""".stripMargin

  def initialize(connection: Connection): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.createStatement())).use { statement =>
      IO.blocking { statement.execute(createTableSql); () }
    }

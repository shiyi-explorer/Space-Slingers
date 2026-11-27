package services.records.tables.LevelResultTable

import cats.effect.IO

import java.sql.Connection

object LevelResultTableInitializer:

  private val createTableSql =
    """CREATE TABLE IF NOT EXISTS ss_level_results (
      |  id BIGSERIAL PRIMARY KEY,
      |  user_id VARCHAR(64) NOT NULL REFERENCES ss_users (id) ON DELETE CASCADE,
      |  level_id VARCHAR(64) NOT NULL REFERENCES ss_levels (id) ON DELETE CASCADE,
      |  completed BOOLEAN NOT NULL DEFAULT FALSE,
      |  score BIGINT NOT NULL DEFAULT 0,
      |  birds_used INT NOT NULL DEFAULT 0,
      |  duration_seconds DOUBLE PRECISION NOT NULL DEFAULT 0,
      |  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      |)""".stripMargin

  private val createIndexesSql = List(
    "CREATE INDEX IF NOT EXISTS ss_level_results_user_idx ON ss_level_results (user_id)",
    "CREATE INDEX IF NOT EXISTS ss_level_results_score_idx ON ss_level_results (level_id, score DESC)")

  def initialize(connection: Connection): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.createStatement())).use { statement =>
      IO.blocking {
        statement.execute(createTableSql)
        createIndexesSql.foreach(statement.execute)
        ()
      }
    }

package services.stats.tables.StatsTable

import cats.effect.IO

import java.sql.Connection

object StatsTableInitializer:

  private val createTableSql =
    """CREATE TABLE IF NOT EXISTS ss_stats (
      |  user_id VARCHAR(64) PRIMARY KEY REFERENCES ss_users (id) ON DELETE CASCADE,
      |  total_runs INT NOT NULL DEFAULT 0,
      |  completed_runs INT NOT NULL DEFAULT 0,
      |  total_birds_used INT NOT NULL DEFAULT 0,
      |  total_score BIGINT NOT NULL DEFAULT 0,
      |  best_score BIGINT NOT NULL DEFAULT 0,
      |  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      |)""".stripMargin

  def initialize(connection: Connection): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.createStatement())).use { statement =>
      IO.blocking { statement.execute(createTableSql); () }
    }

package services.stats.tables.StatsTable

import cats.effect.IO
import services.users.objects.UserId

import java.sql.Connection

object StatsTable:

  /** 聚合增量更新：records 提交成绩时调用（公开方法，规则 5/6）。 */
  private val upsertSql =
    """INSERT INTO ss_stats (user_id, total_runs, completed_runs, total_birds_used, total_score, best_score, updated_at)
      |VALUES (?, 1, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      |ON CONFLICT (user_id) DO UPDATE SET
      |  total_runs = ss_stats.total_runs + 1,
      |  completed_runs = ss_stats.completed_runs + EXCLUDED.completed_runs,
      |  total_birds_used = ss_stats.total_birds_used + EXCLUDED.total_birds_used,
      |  total_score = ss_stats.total_score + EXCLUDED.total_score,
      |  best_score = GREATEST(ss_stats.best_score, EXCLUDED.best_score),
      |  updated_at = CURRENT_TIMESTAMP""".stripMargin
  def increment(connection: Connection, userId: UserId, birdsUsed: Int, score: Long, completedDelta: Int): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(upsertSql))).use { statement =>
      IO.blocking {
        statement.setString(1, userId.value)
        statement.setInt(2, completedDelta)
        statement.setInt(3, birdsUsed)
        statement.setLong(4, score)
        statement.setLong(5, score)
        statement.executeUpdate()
        ()
      }
    }

  private val findByUserSql =
    "SELECT total_runs, completed_runs, total_birds_used, total_score, best_score FROM ss_stats WHERE user_id = ?"
  def findByUser(connection: Connection, userId: UserId): IO[Option[(Int, Int, Int, Long, Long)]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findByUserSql))).use { statement =>
      for
        _ <- IO.blocking(statement.setString(1, userId.value))
        row <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
          IO.blocking {
            if cursor.next() then
              Some((cursor.getInt("total_runs"), cursor.getInt("completed_runs"),
                cursor.getInt("total_birds_used"), cursor.getLong("total_score"), cursor.getLong("best_score")))
            else None
          }
        }
      yield row
    }

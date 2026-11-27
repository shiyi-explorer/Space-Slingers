package services.records.tables.LevelResultTable

import cats.effect.IO
import services.records.objects.LevelResult
import services.users.objects.UserId

import java.sql.Connection

object LevelResultTable:

  private val insertSql =
    """INSERT INTO ss_level_results (user_id, level_id, completed, score, birds_used, duration_seconds, created_at)
      |VALUES (?, ?, ?, ?, ?, ?, ?)""".stripMargin
  def insert(connection: Connection, result: LevelResult): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(insertSql))).use { statement =>
      IO.blocking {
        statement.setString(1, result.userId.value)
        statement.setString(2, result.levelId.value)
        statement.setBoolean(3, result.completed)
        statement.setLong(4, result.score)
        statement.setInt(5, result.birdsUsed)
        statement.setDouble(6, result.durationSeconds)
        statement.setTimestamp(7, java.sql.Timestamp.from(result.createdAt))
        statement.executeUpdate()
        ()
      }
    }

  private val bestScoreSql =
    "SELECT COALESCE(MAX(score), 0) AS best FROM ss_level_results WHERE user_id = ? AND level_id = ?"
  def bestScore(connection: Connection, userId: UserId, levelId: String): IO[Long] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(bestScoreSql))).use { statement =>
      for
        _ <- IO.blocking { statement.setString(1, userId.value); statement.setString(2, levelId) }
        best <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
          IO.blocking(if cursor.next() then cursor.getLong("best") else 0L)
        }
      yield best
    }

  private val minCompletedBirdsUsedSql =
    """SELECT MIN(birds_used) AS fewest FROM ss_level_results
      |WHERE user_id = ? AND level_id = ? AND completed AND birds_used > 0""".stripMargin

  def minCompletedBirdsUsed(connection: Connection, userId: UserId, levelId: String): IO[Option[Int]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(minCompletedBirdsUsedSql))).use { statement =>
      IO.blocking {
        statement.setString(1, userId.value)
        statement.setString(2, levelId)
      }.flatMap { _ =>
        cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
          IO.blocking(if cursor.next() then Option(cursor.getObject("fewest", classOf[java.lang.Integer])).map(_.intValue()) else None)
        }
      }
    }

  /** 排行榜读模型的数据源：每用户每关取最好成绩，按分数降序（公开方法，供 leaderboard 服务调用）。 */
  private val topByLevelSql =
    """SELECT r.user_id, u.username, MAX(r.score) AS best_score, MIN(r.birds_used) AS birds_used
      |FROM ss_level_results r JOIN ss_users u ON u.id = r.user_id
      |WHERE r.level_id = ? AND r.completed
      |GROUP BY r.user_id, u.username
      |ORDER BY best_score DESC
      |LIMIT ?""".stripMargin
  def topByLevel(connection: Connection, levelId: String, limit: Int): IO[List[(String, String, Long, Int)]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(topByLevelSql))).use { statement =>
      for
        _ <- IO.blocking { statement.setString(1, levelId); statement.setInt(2, limit) }
        rows <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
          IO.blocking {
            val buffer = scala.collection.mutable.ListBuffer.empty[(String, String, Long, Int)]
            while cursor.next() do
              buffer.append((cursor.getString("user_id"), cursor.getString("username"),
                cursor.getLong("best_score"), cursor.getInt("birds_used")))
            buffer.toList
          }
        }
      yield rows
    }

  /** 某玩家在某关的名次（同表最好成绩比较），无名次时为 0。 */
  private val rankSql =
    """SELECT COUNT(*) + 1 AS rank FROM (
      |  SELECT user_id, MAX(score) AS best FROM ss_level_results
      |  WHERE level_id = ? AND completed GROUP BY user_id
      |) ranked
      |WHERE ranked.best > (
      |  SELECT COALESCE(MAX(score), 0) FROM ss_level_results
      |  WHERE level_id = ? AND user_id = ? AND completed)""".stripMargin
  def rankOf(connection: Connection, levelId: String, userId: UserId): IO[Int] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(rankSql))).use { statement =>
      for
        _ <- IO.blocking {
          statement.setString(1, levelId)
          statement.setString(2, levelId)
          statement.setString(3, userId.value)
        }
        rank <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
          IO.blocking(if cursor.next() then cursor.getInt("rank") else 0)
        }
      yield rank
    }

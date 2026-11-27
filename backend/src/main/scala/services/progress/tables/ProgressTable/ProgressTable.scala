package services.progress.tables.ProgressTable

import cats.effect.IO
import services.levels.objects.LevelId
import services.progress.objects.PlayerProgress
import services.users.objects.UserId

import java.sql.Connection

object ProgressTable:

  /** 解锁规则：通过第 N 章即解锁第 N+1 章（首关恒解锁）。 */
  private val findByUserAndLevelSql =
    """SELECT p.user_id, p.level_id, p.unlocked, p.completed, p.best_score
      |FROM ss_progress p JOIN ss_levels l ON l.id = p.level_id
      |WHERE p.user_id = ? AND p.level_id = ?""".stripMargin
  def findByUserAndLevel(connection: Connection, userId: UserId, levelId: LevelId): IO[Option[PlayerProgress]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findByUserAndLevelSql))).use { statement =>
      for
        _ <- IO.blocking { statement.setString(1, userId.value); statement.setString(2, levelId.value) }
        found <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
          IO.blocking {
            if cursor.next() then
              Some(PlayerProgress(
                userId = UserId(cursor.getString("user_id")),
                levelId = LevelId(cursor.getString("level_id")),
                unlocked = cursor.getBoolean("unlocked"),
                completed = cursor.getBoolean("completed"),
                bestScore = cursor.getLong("best_score")))
            else None
          }
        }
      yield found
    }

  private val maxCompletedChapterSql =
    """SELECT COALESCE(MAX(l.chapter), 0) AS max_chapter
      |FROM ss_progress p JOIN ss_levels l ON l.id = p.level_id
      |WHERE p.user_id = ? AND p.completed""".stripMargin
  def maxCompletedChapter(connection: Connection, userId: UserId): IO[Int] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(maxCompletedChapterSql))).use { statement =>
      for
        _ <- IO.blocking(statement.setString(1, userId.value))
        chapter <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
          IO.blocking(if cursor.next() then cursor.getInt("max_chapter") else 0)
        }
      yield chapter
    }

  private val upsertSql =
    """INSERT INTO ss_progress (user_id, level_id, unlocked, completed, best_score, updated_at)
      |VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      |ON CONFLICT (user_id, level_id) DO UPDATE SET
      |  unlocked = ss_progress.unlocked OR EXCLUDED.unlocked,
      |  completed = ss_progress.completed OR EXCLUDED.completed,
      |  best_score = GREATEST(ss_progress.best_score, EXCLUDED.best_score),
      |  updated_at = CURRENT_TIMESTAMP""".stripMargin
  def save(connection: Connection, progress: PlayerProgress): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(upsertSql))).use { statement =>
      IO.blocking {
        statement.setString(1, progress.userId.value)
        statement.setString(2, progress.levelId.value)
        statement.setBoolean(3, progress.unlocked)
        statement.setBoolean(4, progress.completed)
        statement.setLong(5, progress.bestScore)
        statement.executeUpdate()
        ()
      }
    }

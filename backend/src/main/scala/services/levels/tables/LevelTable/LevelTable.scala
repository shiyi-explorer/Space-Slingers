package services.levels.tables.LevelTable

import cats.effect.IO
import io.circe.Json
import services.levels.objects.{LevelDefinition, LevelId}

import java.sql.Connection

object LevelTable:

  private val findByIdSql = "SELECT id, chapter, name, birds, max_score, data FROM ss_levels WHERE id = ?"
  def findById(connection: Connection, levelId: LevelId): IO[Option[LevelDefinition]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findByIdSql))).use { statement =>
      for
        _ <- IO.blocking(statement.setString(1, levelId.value))
        found <- cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
          IO.blocking {
            if cursor.next() then
              Some(LevelDefinition(
                id = LevelId(cursor.getString("id")),
                chapter = cursor.getInt("chapter"),
                name = cursor.getString("name"),
                birds = cursor.getInt("birds"),
                maxScore = cursor.getLong("max_score"),
                data = io.circe.parser.parse(cursor.getString("data")).getOrElse(Json.Null)
              ))
            else None
          }
        }
      yield found
    }

  private val insertSql =
    "INSERT INTO ss_levels (id, chapter, name, birds, max_score, data) VALUES (?, ?, ?, ?, ?, ?::jsonb) ON CONFLICT (id) DO UPDATE SET chapter = EXCLUDED.chapter, name = EXCLUDED.name, birds = EXCLUDED.birds, max_score = EXCLUDED.max_score, data = EXCLUDED.data"
  def insert(connection: Connection, definition: LevelDefinition): IO[Unit] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(insertSql))).use { statement =>
      IO.blocking {
        statement.setString(1, definition.id.value)
        statement.setInt(2, definition.chapter)
        statement.setString(3, definition.name)
        statement.setInt(4, definition.birds)
        statement.setLong(5, definition.maxScore)
        statement.setString(6, definition.data.noSpaces)
        statement.executeUpdate()
        ()
      }
    }

  private val findAllSql = "SELECT id, chapter, name, birds, max_score, data FROM ss_levels ORDER BY chapter"
  def findAll(connection: Connection): IO[List[LevelDefinition]] =
    cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.prepareStatement(findAllSql))).use { statement =>
      cats.effect.Resource.fromAutoCloseable(IO.blocking(statement.executeQuery())).use { cursor =>
        IO.blocking {
          val buffer = scala.collection.mutable.ListBuffer.empty[LevelDefinition]
          while cursor.next() do
            buffer.append(LevelDefinition(
              id = LevelId(cursor.getString("id")),
              chapter = cursor.getInt("chapter"),
              name = cursor.getString("name"),
              birds = cursor.getInt("birds"),
              maxScore = cursor.getLong("max_score"),
              data = io.circe.parser.parse(cursor.getString("data")).getOrElse(Json.Null)
            ))
          buffer.toList
        }
      }
    }

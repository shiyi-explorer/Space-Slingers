package services.levels.tables.LevelTable

import cats.effect.IO
import cats.syntax.all.*
import io.circe.Json
import io.circe.parser.parse
import services.levels.objects.{LevelDefinition, LevelId}

import java.nio.charset.StandardCharsets
import java.nio.file.{Files, Path, Paths}
import java.sql.Connection

/** 关卡种子数据源：仓库根的 data/levels.json —— 与 Godot 离线关卡是同一份文件。
  * 改关卡只改那一处，后端启动时读它 upsert 进库，线上线下天然一致。
  * 可用环境变量 SS_LEVELS_JSON 指定其他路径。
  * maxScore = 猪×5000 + 方块分值和 + 未用鸟×(birds-1)×10000（成绩校验的理论满分上限）。 */
object LevelTableInitializer:

  private val candidatePaths: List[String] =
    sys.env.get("SS_LEVELS_JSON").toList ++ List("../data/levels.json", "data/levels.json")

  private def findLevelsFile: Path =
    candidatePaths
      .map(Paths.get(_))
      .find(Files.isRegularFile(_))
      .getOrElse(throw new IllegalStateException(
        s"找不到关卡数据 levels.json，尝试过：${candidatePaths.mkString(", ")}"))

  private def loadLevelsJson: Json =
    val text = new String(Files.readAllBytes(findLevelsFile), StandardCharsets.UTF_8)
    parse(text).fold(err => throw new IllegalStateException(s"关卡 JSON 解析失败：${err.message}"), identity)

  private def blockScore(material: String): Long = material match
    case "stone" => 800L
    case "glass" => 300L
    case _       => 500L

  private def toDefinition(level: Json): LevelDefinition =
    val cursor = level.hcursor
    def field[A](name: String)(using d: io.circe.Decoder[A]): A =
      cursor.get[A](name).fold(err => throw new IllegalStateException(s"关卡缺字段 $name：${err.message}"), identity)
    val id = field[String]("id")
    val chapter = field[Int]("chapter")
    val name = field[String]("name")
    val birds = field[Int]("birds")
    val pigs = cursor.get[List[Json]]("pigs").getOrElse(Nil)
    val blocks = cursor.get[List[Json]]("blocks").getOrElse(Nil)
    val blockSum = blocks.map(b => blockScore(b.hcursor.get[String]("material").getOrElse("wood"))).sum
    val maxScore = pigs.size.toLong * 5000L + blockSum + (birds - 1).toLong * 10000L
    LevelDefinition(LevelId(id), chapter, name, birds, maxScore, level)

  private def allLevels: List[LevelDefinition] =
    loadLevelsJson.hcursor.get[List[Json]]("levels").fold(
      err => throw new IllegalStateException(s"关卡 JSON 缺 levels 数组：${err.message}"),
      _.map(toDefinition))

  private val createTableSql =
    """CREATE TABLE IF NOT EXISTS ss_levels (
      |  id VARCHAR(64) PRIMARY KEY,
      |  chapter INT NOT NULL UNIQUE,
      |  name TEXT NOT NULL,
      |  birds INT NOT NULL,
      |  max_score BIGINT NOT NULL,
      |  data JSONB NOT NULL
      |)""".stripMargin

  def initialize(connection: Connection): IO[Unit] =
    for
      _ <- cats.effect.Resource.fromAutoCloseable(IO.blocking(connection.createStatement())).use { statement =>
        IO.blocking { statement.execute(createTableSql); () }
      }
      // 每次启动都从同一份 JSON 刷新种子（upsert），保证服务端关卡与文件定义一致
      seeds <- IO.blocking(allLevels)
      _ <- seeds.traverse(definition => LevelTable.insert(connection, definition))
    yield ()

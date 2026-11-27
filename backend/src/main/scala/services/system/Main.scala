package services.system

import cats.effect.{IO, IOApp}
import cats.syntax.all.*
import com.comcast.ip4s.{host, port}
import org.http4s.ember.server.EmberServerBuilder
import services.leaderboard.routes.LeaderboardRoutes
import services.levels.tables.LevelTable.LevelTableInitializer
import services.progress.tables.ProgressTable.ProgressTableInitializer
import services.records.tables.LevelResultTable.LevelResultTableInitializer
import services.stats.tables.StatsTable.StatsTableInitializer
import services.system.routes.ApiRouter
import services.users.tables.SessionTable.SessionTableInitializer
import services.users.tables.UserTable.UserTableInitializer

object Main extends IOApp.Simple:

  private val initializeTables: IO[Unit] = DatabaseSession.withConnection { connection =>
    for
      _ <- UserTableInitializer.initialize(connection)
      _ <- SessionTableInitializer.initialize(connection)
      _ <- LevelTableInitializer.initialize(connection)
      _ <- ProgressTableInitializer.initialize(connection)
      _ <- LevelResultTableInitializer.initialize(connection)
      _ <- StatsTableInitializer.initialize(connection)
    yield ()
  }

  override def run: IO[Unit] =
    for
      _ <- initializeTables
      _ <- EmberServerBuilder.default[IO]
        .withHost(host"0.0.0.0")
        .withPort(port"8091")
        .withHttpApp(ApiRouter.routes.orNotFound)
        .build
        .useForever
    yield ()

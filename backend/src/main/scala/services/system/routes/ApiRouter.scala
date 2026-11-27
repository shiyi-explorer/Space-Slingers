package services.system.routes

import cats.effect.IO
import cats.syntax.all.*
import org.http4s.HttpRoutes
import services.leaderboard.routes.LeaderboardRoutes
import services.levels.routes.LevelRoutes
import services.progress.routes.ProgressRoutes
import services.records.routes.RecordsRoutes
import services.stats.routes.StatsRoutes
import services.system.api.APIMessageRouter
import services.users.routes.UserRoutes

/** 全局路由器：合并各服务注册的面向前端 API（规则 33：顶层合并，单一路由器）。 */
object ApiRouter:

  val routes: HttpRoutes[IO] = APIMessageRouter.routes(
    UserRoutes.apiMessages
      ++ LevelRoutes.apiMessages
      ++ ProgressRoutes.apiMessages
      ++ RecordsRoutes.apiMessages
      ++ LeaderboardRoutes.apiMessages
      ++ StatsRoutes.apiMessages,
    UserRoutes.resolveUserToken
  )

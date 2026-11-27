package services.leaderboard.routes

import services.leaderboard.api.{GetLeaderboardMessage, GetPlayerRankMessage}
import services.leaderboard.objects.apiTypes.{LeaderboardResponse, PlayerRankResponse}
import services.system.api.{APIMessageRouter, RegisteredAPIMessage}
import services.users.routes.UserRoutes

object LeaderboardRoutes:

  def apiMessages: List[RegisteredAPIMessage] = List(
    RegisteredAPIMessage.api[GetLeaderboardMessage, LeaderboardResponse],
    RegisteredAPIMessage.apiWithToken[GetPlayerRankMessage, PlayerRankResponse],
  )

  val routes = APIMessageRouter.routes(apiMessages, UserRoutes.resolveUserToken)

package services.stats.routes

import services.stats.api.GetPlayerStatsMessage
import services.stats.objects.apiTypes.PlayerStatsResponse
import services.system.api.{APIMessageRouter, RegisteredAPIMessage}
import services.users.routes.UserRoutes

object StatsRoutes:

  def apiMessages: List[RegisteredAPIMessage] = List(
    RegisteredAPIMessage.apiWithToken[GetPlayerStatsMessage, PlayerStatsResponse],
  )

  val routes = APIMessageRouter.routes(apiMessages, UserRoutes.resolveUserToken)

package services.levels.routes

import services.levels.api.GetLevelDefinitionMessage
import services.levels.objects.LevelDefinition
import services.system.api.{APIMessageRouter, RegisteredAPIMessage}
import services.users.routes.UserRoutes

object LevelRoutes:

  def apiMessages: List[RegisteredAPIMessage] = List(
    RegisteredAPIMessage.api[GetLevelDefinitionMessage, LevelDefinition],
  )

  val routes = APIMessageRouter.routes(apiMessages, UserRoutes.resolveUserToken)

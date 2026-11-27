package services.progress.routes

import services.progress.api.{LoadProgressMessage, SaveProgressMessage}
import services.progress.objects.apiTypes.{ProgressResponse, SaveProgressResponse}
import services.system.api.{APIMessageRouter, RegisteredAPIMessage}
import services.users.routes.UserRoutes

object ProgressRoutes:

  def apiMessages: List[RegisteredAPIMessage] = List(
    RegisteredAPIMessage.apiWithToken[LoadProgressMessage, ProgressResponse],
    RegisteredAPIMessage.apiWithToken[SaveProgressMessage, SaveProgressResponse],
  )

  val routes = APIMessageRouter.routes(apiMessages, UserRoutes.resolveUserToken)

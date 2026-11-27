package services.records.routes

import services.records.api.SubmitLevelResultMessage
import services.records.objects.apiTypes.SubmitLevelResultResponse
import services.system.api.{APIMessageRouter, RegisteredAPIMessage}
import services.users.routes.UserRoutes

object RecordsRoutes:

  def apiMessages: List[RegisteredAPIMessage] = List(
    RegisteredAPIMessage.apiWithToken[SubmitLevelResultMessage, SubmitLevelResultResponse],
  )

  val routes = APIMessageRouter.routes(apiMessages, UserRoutes.resolveUserToken)

package services.system.api

import java.sql.Connection
import cats.effect.IO

/** 无业务请求输入的可执行操作：路由器收到空请求体后直接执行 plan。 */
trait NoRequestMessage[Response] extends APIMessage[Response]

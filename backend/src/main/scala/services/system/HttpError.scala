package services.system

object HttpError:
  final case class BadRequest(message: String) extends RuntimeException(message)
  final case class Unauthorized(message: String) extends RuntimeException(message)
  final case class Forbidden(message: String) extends RuntimeException(message)
  final case class NotFound(message: String) extends RuntimeException(message)
  final case class Conflict(message: String) extends RuntimeException(message)

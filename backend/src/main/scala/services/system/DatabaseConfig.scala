package services.system

final case class DatabaseConfig(host: String, port: Int, databaseName: String, username: String, password: String)

object DatabaseConfig:
  def fromEnvironment: DatabaseConfig = DatabaseConfig(
    sys.env.getOrElse("DB_HOST", "127.0.0.1"),
    sys.env.get("DB_PORT").flatMap(_.toIntOption).getOrElse(5432),
    sys.env.getOrElse("DB_NAME", "space_slingers"),
    sys.env.getOrElse("DB_USER", "shiyi"),
    sys.env.getOrElse("DB_PASSWORD", "")
  )

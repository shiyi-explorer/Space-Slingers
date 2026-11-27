package services.users.utils

import cats.effect.IO

import java.security.MessageDigest
import java.util.UUID

/** 用户服务内部工具：口令散列与令牌生成，仅供 users 服务使用。 */
object UsersCrypto:

  private[users] def hashSecret(secret: String): String =
    MessageDigest.getInstance("SHA-256")
      .digest(secret.getBytes(java.nio.charset.StandardCharsets.UTF_8))
      .map(byte => f"$byte%02x").mkString

  private[users] def generateToken(): IO[String] =
    IO.blocking(UUID.randomUUID().toString)

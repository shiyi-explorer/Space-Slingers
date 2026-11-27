ThisBuild / scalaVersion := "3.4.2"
ThisBuild / organization := "com.spaceslingers"
ThisBuild / version := "0.1.0-SNAPSHOT"
lazy val root = (project in file(".")).settings(
  name := "space-slingers-backend",
  libraryDependencies ++= Seq(
    "org.typelevel" %% "cats-effect" % "3.5.7",
    "org.http4s" %% "http4s-dsl" % "0.23.30",
    "org.http4s" %% "http4s-ember-server" % "0.23.30",
    "org.http4s" %% "http4s-circe" % "0.23.30",
    "io.circe" %% "circe-generic" % "0.14.10",
    "io.circe" %% "circe-parser" % "0.14.10",
    "org.postgresql" % "postgresql" % "42.7.8"
  ),
  Compile / run / mainClass := Some("services.system.Main"),
  Compile / run / fork := true,
  Test / fork := true
)

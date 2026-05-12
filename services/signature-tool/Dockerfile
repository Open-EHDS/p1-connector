FROM gradle:8.10.2-jdk21 AS build

WORKDIR /app
COPY --chown=gradle:gradle . .
RUN gradle bootJar --no-daemon

FROM eclipse-temurin:21-jre

WORKDIR /app
COPY --from=build /app/build/libs/*.jar /app/signature-tool.jar

EXPOSE 8080

CMD ["java", "--add-opens=java.base/java.lang=ALL-UNNAMED", "-jar", "/app/signature-tool.jar"]

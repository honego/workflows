FROM eclipse-temurin:21.0.10_7-jre-alpine
ARG JAR_FILE
COPY $JAR_FILE app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

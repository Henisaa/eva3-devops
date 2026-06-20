FROM maven:3.9-eclipse-temurin-17-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY mvnw .
COPY .mvn .mvn
RUN chmod +x mvnw && sed -i 's/\r$//' mvnw && \
    ./mvnw dependency:go-offline -B --no-transfer-progress
COPY src src
RUN ./mvnw package -DskipTests --no-transfer-progress
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]

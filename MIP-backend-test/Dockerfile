#######################################################
# Build the spring boot maven project
#######################################################
FROM maven:3.9.11-amazoncorretto-21@sha256:82d98fbed447e3f7dfbf1089840a51bfaeb5651cb47a9c5820139d054db3dde1 AS mvn-build-env
LABEL maintainer="Thanasis Karampatsis <tkarabatsis@athenarc.gr>"

ENV CODE_PATH="/opt/code"
WORKDIR $CODE_PATH

COPY pom.xml $CODE_PATH/

RUN mvn -B -ntp dependency:go-offline

COPY src/ $CODE_PATH/src

RUN mvn -B -ntp clean package

#######################################################
# Setup the running container
#######################################################
FROM amazoncorretto:21-alpine3.21@sha256:392b286e53c7f4cd366bd2f752f509b7e24de9f414564bccd7d152a58214a8b6

ENV TZ=Etc/GMT
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV APP_CONFIG_TEMPLATE="/opt/config/application.tmpl"
ENV APP_CONFIG_LOCATION="/opt/config/application.yml"
ENV SPRING_CONFIG_LOCATION="file:/opt/config/application.yml"

ENV SERVICE="platform-backend"
ENV FEDERATION="default"
ENV LOG_LEVEL="INFO"
ENV FRAMEWORK_LOG_LEVEL="INFO"

WORKDIR /opt

RUN apk add --no-cache curl

# renovate: datasource=github-releases depName=jwilder/dockerize
ENV DOCKERIZE_VERSION=v0.14.0
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

COPY config/application.tmpl $APP_CONFIG_TEMPLATE
COPY --from=mvn-build-env /opt/code/target/platform-backend.jar /usr/share/jars/

ENV DISABLED_ALGORITHMS_CONFIG_PATH="/opt/platform/algorithms/disabledAlgorithms.json"
COPY config/disabledAlgorithms.json $DISABLED_ALGORITHMS_CONFIG_PATH
VOLUME /opt/platform/api

RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && mkdir -p /opt/config /opt/platform/api \
    && chown -R appuser:appgroup /opt/config /opt/platform/api /usr/share/jars

USER appuser
ENTRYPOINT ["sh", "-ec", "exec dockerize -template ${APP_CONFIG_TEMPLATE}:${APP_CONFIG_LOCATION} java --add-opens java.base/java.io=ALL-UNNAMED -Daeron.term.buffer.length -jar /usr/share/jars/platform-backend.jar"]
EXPOSE 8080
HEALTHCHECK --start-period=60s CMD ["sh", "-c", "curl --fail --silent --show-error http://localhost:8080/services/actuator/health | grep -q '\"status\":\"UP\"'"]

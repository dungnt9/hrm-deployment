ARG KEYCLOAK_VERSION=23.0

FROM quay.io/keycloak/keycloak:$KEYCLOAK_VERSION as builder

# Enable health check and metrics
ENV KC_DB=postgres
ENV KC_FEATURES="token-exchange,scripts,preview"
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Build optimized Keycloak
RUN /opt/keycloak/bin/kc.sh build --cache=ispn --health-enabled=true --metrics-enabled=true

FROM quay.io/keycloak/keycloak:$KEYCLOAK_VERSION

COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Copy custom themes (if exists)
COPY themes/hrm /opt/keycloak/themes/hrm

WORKDIR /opt/keycloak

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]

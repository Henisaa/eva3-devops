# Guion de presentación / defensa técnica (10–15 min)

> Defensa **individual**: debes poder explicar TODA la solución. Cubre IE8 (fundamentos),
> IE9 (pipeline), IE10 (defensa) e IE11 (claridad).

## Estructura sugerida (con tiempos)

### 1. Contexto y arquitectura — 3 min (IE8)
- "Innovatech pasa de contenedores en EC2 (EVA2/EP2) a **orquestación en EKS** (EP3)."
- Mostrar el diagrama (README / ARQUITECTURA.md): frontend + 2 microservicios + MySQL.
- Justificar **EKS** (microservicios, autoscaling y autorecuperación declarativos, portable).
- Recorrer: VPC multi-AZ, públicas (ELB) vs privadas (nodos), NAT, SG, roles IAM (`LabRole`).

### 2. Despliegue de servicios — 3 min (IE2 / IE8)
- Imágenes en **ECR** (4 repos).
- **Deployments** (no Task Definitions: usamos EKS): réplicas, probes, requests/limits.
- Variables de entorno de los backends: `DB_ENDPOINT=tienda-db` (DNS interno), password por **Secret**.
- **Frontend público** vía Service `LoadBalancer` → mostrar URL en vivo.
- **Front → Back:** NGINX hace proxy de `/api/v1/ventas`→`:8080` y `/api/v1/despachos`→`:8081`.

### 3. Autoscaling — 2 min (IE3)
- HPA ventas y despachos (70% CPU, 2–10) y frontend (60% CPU, 2–6).
- Por qué esos umbrales (comentados en los `*-hpa.yaml`).
- Demostrar con la prueba de carga (`VALIDACION_Y_METRICAS.md`).

### 4. Pipeline CI/CD — 3 min (IE9 / IE4)
- 4 pipelines **build → push (ECR) → deploy (EKS)**, uno por microservicio.
- Tag por **commit SHA** (trazabilidad). Migración desde el deploy por SSM/EC2 de EVA2.
- Mostrar un run real: cambio menor en un backend, commit/push, deploy automático.

### 5. Demostración en vivo — 2 min (IE7)
- SPA cargando ventas y despachos (Front→Back→DB).
- `kubectl get pods/svc/hpa -n tienda`.
- Matar un pod → se recrea solo (autorecuperación).
- Logs: `kubectl logs` y/o CloudWatch.

### 6. Análisis crítico — 2 min (IE6 / IE10)
- **Problemas y solución** (reales de esta migración):
  - *nginx con IP fija:* el frontend apuntaba a `10.0.137.73` (IP de EC2 de EVA2); en EKS
    no sirve. **Fix:** usar DNS interno de Services (`tienda-backend-ventas`, `...-despachos`).
  - *Backends sin actuator:* no hay `/actuator/health`; se usaron **probes tcpSocket** +
    `startupProbe` amplio porque la JVM tarda en arrancar.
  - *Credenciales de Academy* caducan → pipeline con `ExpiredToken`; documentado refrescar
    los 3 secrets.
  - *HPA sin métricas:* requiere **Metrics Server** + `resources.requests`; se instala en `deploy.sh`.
  - *Password en claro:* EVA2 la pasaba en el `docker run`; ahora sale del **Secret**.
- **Lecciones / proyección productiva:** RDS gestionado en vez de pod MySQL con `emptyDir`,
  OIDC en vez de claves estáticas, ALB Ingress + HTTPS, ambientes dev/prod, roles IAM mínimos.

## Preguntas típicas del docente (IE10)
- ¿Diferencia entre escalar **pods** (HPA) y **nodos** (Node Group)?
- ¿Por qué los backends son `ClusterIP` y el frontend `LoadBalancer`?
- ¿Cómo encuentra el frontend a cada backend? (CoreDNS / nombre del Service).
- ¿Qué pasa si se cae una AZ? (réplicas en la otra AZ siguen).
- ¿Por qué probes tcpSocket y no httpGet en los backends? (no hay actuator).
- ¿Dónde viven las contraseñas y por qué no en el código? (Secrets / GitHub Secrets).
- ¿Qué impide que un deploy roto llegue a producción? (`rollout status` + probes).
- ¿Por qué tag por commit SHA? (trazabilidad y rollback).

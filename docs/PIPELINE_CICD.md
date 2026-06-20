# Pipeline CI/CD con GitHub Actions (apoyo IE4 / IE9)

## 1. Flujo (4 pipelines independientes)

```
 git push (main)
      │  trigger por paths:
      │  frontend/**  |  backend-ventas/**  |  backend-despachos/**  |  db/**
      ▼
 ┌──────────────────────────────────────────────┐
 │ Job: build-and-deploy (ubuntu-latest)        │
 │ 1. checkout                                  │
 │ 2. configure-aws-credentials (+ session tok) │
 │ 3. login Amazon ECR                          │
 │ 4. docker build + push  (tag = commit SHA)   │  ← CI
 │ 5. aws eks update-kubeconfig                 │
 │ 6. kubectl set image  (rolling update)       │  ← CD
 │ 7. kubectl rollout status (espera readiness) │
 │ 8. evidencia: kubectl get pods               │
 └──────────────────────────────────────────────┘
```

4 workflows: `ci-cd-frontend.yml`, `ci-cd-backend-ventas.yml`,
`ci-cd-backend-despachos.yml`, `ci-cd-db.yml`. Cada microservicio se construye y despliega
de forma **independiente** (un cambio en ventas no reconstruye despachos).

## 2. Diferencia clave vs EVA2

| | EVA2 | EP3 |
|--|------|-----|
| Deploy | `aws ssm send-command` → `docker run` en EC2 | `kubectl set image` en EKS |
| Tag | `:latest` / `:ventas-latest` | **commit SHA** (trazable) + `latest` |
| Password DB | en texto plano en el `docker run` | desde **Secret** de Kubernetes |
| Escalado / recuperación | ninguno | rolling update + probes + HPA |

## 3. Secrets requeridos (GitHub → Settings → Secrets → Actions)

| Secret | Origen |
|--------|--------|
| `AWS_ACCESS_KEY_ID` | AWS Details → AWS CLI (Learner Lab) |
| `AWS_SECRET_ACCESS_KEY` | idem |
| `AWS_SESSION_TOKEN` | idem (**obligatorio** en credenciales temporales) |

> Las credenciales de Academy **caducan** al cerrar el lab. Si el pipeline falla con
> `ExpiredToken`, actualiza los 3 secrets con los valores del lab reiniciado.

## 4. Acceso del pipeline al clúster

El clúster `devopseks` fue creado por `LabRole`/`voclabs`. Las credenciales que usa
GitHub Actions son del **mismo rol**, por lo que `kubectl` queda autenticado como admin
del clúster sin tocar `aws-auth`. Con otro usuario IAM habría que agregarlo como
*access entry*.

## 5. Recuperación ante redeploy / fallos

- `kubectl rollout status` **bloquea** hasta que los pods nuevos estén Ready; si no, el
  job **falla** (no se promueve un deploy roto).
- Rolling update: pods nuevos arriba antes de bajar los viejos → **sin downtime**.
- Una readinessProbe fallida deja el pod fuera de balanceo hasta recuperarse.

## 6. Métricas a mostrar en la defensa (IE9)

- **Tiempo** de cada run (pestaña Actions → duración por step).
- **Logs** de build/push/deploy.
- **Fallos** (runs en rojo) y su corrección (ver `GUION_PRESENTACION.md`).
- Correlación **commit ↔ imagen (SHA) ↔ pod** para auditoría/rollback.

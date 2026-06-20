# EP3 — Orquestación y Automatización en AWS (EKS + ECR + GitHub Actions)

**Asignatura:** Introducción a Herramientas DevOps (ISY1101)
**Caso:** Innovatech Chile — Tienda Semestral (microservicios **Ventas** + **Despachos**)
**Aplicación:** Frontend React/Vite (NGINX) + 2 backends Spring Boot + MySQL, desplegada
en **AWS EKS**, con imágenes en **Amazon ECR**, **autoscaling (HPA)** y **pipeline CI/CD
con GitHub Actions**.

> **Continuidad EVA2 → EP3.** En EVA2 (EP2) la app se contenerizó y se desplegó en
> **3 instancias EC2** mediante **SSM** (un contenedor por host). En EP3 se migra a un
> entorno **orquestado en EKS**: los mismos contenedores corren como pods con réplicas,
> autoscaling, autorecuperación, balanceo y despliegue continuo.

---

## 1. Estructura del proyecto (autónomo)

Repositorio **autónomo y completo**: contiene el código fuente de la app **y** toda la
capa de orquestación EP3. Listo para `git init`, push a GitHub y entregar.

```
EP3-tienda-semestral/
├── frontend/                 # App React/Vite + nginx (default.conf ya apunta a EKS)
├── backend-ventas/           # Microservicio Spring Boot :8080
├── backend-despachos/        # Microservicio Spring Boot :8081
├── db/                       # MySQL 8 + init.sql (semilla)
├── k8s/                      # Manifests Kubernetes (4 servicios + mysql + HPA)
├── infra/                    # CloudFormation: VPC + ECR + EKS
├── scripts/deploy.sh         # Bootstrap (despliegue inicial completo)
├── app/frontend/default.conf # Copia de referencia del nginx adaptado a EKS
├── docs/                     # Material de apoyo para la defensa
└── .github/workflows/        # 4 pipelines CI/CD hacia EKS
```

> El `frontend/default.conf` ya está adaptado a EKS (proxy por DNS interno a los Services,
> no a la IP de EC2 de EVA2). Los 4 workflows de `.github/workflows/` despliegan en EKS y
> sustituyen el esquema EC2/SSM de EVA2.

> 📘 **¿Quieres entender TODO el proyecto de 0 a experto** (qué hace cada línea de Docker,
> cada comando, cada manifest)? Lee **[`docs/GUIA_COMPLETA.md`](docs/GUIA_COMPLETA.md)**.

---

## 2. Arquitectura

```
                          Internet
                             │
                   ┌─────────▼──────────┐
                   │  AWS ELB (público) │   ← Service LoadBalancer (frontend)
                   └─────────┬──────────┘
                             │ :80
        ┌────────────────────▼──────────────────────────────┐
        │                  EKS (devopseks)                   │
        │                namespace: tienda                   │
        │                                                    │
        │   ┌──────────────┐                                 │
        │   │  frontend    │  /api/v1/ventas    ┌──────────┐ │
        │   │ (nginx) x2   │───────────────────▶│ ventas   │ │
        │   │  HPA 2..6    │                     │ :8080 x2 │ │
        │   │              │  /api/v1/despachos  │ HPA 2..10│ │
        │   │              │──────────┐          └────┬─────┘ │
        │   └──────────────┘          ▼               │       │
        │                       ┌──────────┐          │ :3306 │
        │                       │despachos │          │       │
        │                       │ :8081 x2 │──────────┤       │
        │                       │ HPA 2..10│          │       │
        │                       └──────────┘   ┌──────▼─────┐ │
        │                                       │ tienda-db  │ │
        │                                       │ (mysql 8)  │ │
        │                                       └────────────┘ │
        └────────────────────────────────────────────────────┘
                   Nodos en subredes privadas (2 AZ)
```

- **Frontend** (`nginx`): sirve la SPA y hace **reverse-proxy** por DNS interno:
  `/api/v1/ventas` → `tienda-backend-ventas:8080`, `/api/v1/despachos` →
  `tienda-backend-despachos:8081`. Único componente público (Service `LoadBalancer`).
- **Backend Ventas** (Spring Boot, `:8080`) y **Backend Despachos** (`:8081`): Services
  `ClusterIP` (no expuestos a Internet).
- **MySQL** (`tienda_semestral`): Service *headless*, solo interno.
- **Front → Back → DB** todo por DNS interno de Kubernetes (CoreDNS).

Detalle y justificación: [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md).

---

## 3. Requisitos previos

- Cuenta **AWS Academy Learner Lab** iniciada.
- **AWS CloudShell** (trae `aws`, `kubectl`, `docker`, `git`).
- Repo en **GitHub** con el código + estos archivos.

---

## 4. Despliegue paso a paso

### Paso 1 — Infraestructura (VPC + ECR + EKS)

Consola AWS → **CloudFormation → Create stack → Upload template** → subir
`infra/duoc-devops-ep3.yaml`. Parámetros (en AWS Academy ambos = `LabRole`):

| Parámetro | Valor |
|-----------|-------|
| `EksClusterRoleName` | `LabRole` |
| `EksNodeRoleName` | `LabRole` |

Crea: VPC multi-AZ (2 públicas + 4 privadas) + NAT, **4 repos ECR**
(`tienda-frontend`, `tienda-backend-ventas`, `tienda-backend-despachos`, `tienda-db`),
clúster **`devopseks`** y Node Group (2× `t3.large`). *(~15–20 min.)*

### Paso 2 — Despliegue inicial (bootstrap)

Desde **CloudShell**, en la **raíz del repo**:

```bash
export DB_PASSWORD='UnaClaveSegura123'   # opcional; por defecto admin123
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

Configura `kubectl`, instala Metrics Server, aplica el nginx adaptado, construye y
sube las **4 imágenes**, crea el **Secret** de MySQL, despliega todo en orden
(DB → backends → frontend) y entrega la **URL pública** al final.

### Paso 3 — Activar CI/CD (GitHub Actions)

GitHub → **Settings → Secrets and variables → Actions** (valores de *AWS Details → AWS CLI*):

| Secret | Descripción |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | Access key temporal del lab |
| `AWS_SECRET_ACCESS_KEY` | Secret key temporal del lab |
| `AWS_SESSION_TOKEN` | **Session token** (obligatorio en Academy) |

Cada push a `main` que toque `frontend/**`, `backend-ventas/**`, `backend-despachos/**`
o `db/**` dispara el pipeline correspondiente: *build → push ECR → deploy EKS*.

Detalle: [`docs/PIPELINE_CICD.md`](docs/PIPELINE_CICD.md).

---

## 5. Uso y verificación

```bash
kubectl get pods -n tienda -o wide
kubectl get svc  -n tienda         # DNS público del ELB (frontend)
kubectl get hpa  -n tienda
kubectl logs -f deploy/tienda-backend-ventas -n tienda
kubectl top pods -n tienda
```

Abrir la URL del ELB → la SPA carga ventas y despachos (CRUD por los 2 microservicios).
Pruebas funcionales, carga (HPA) y recuperación: [`docs/VALIDACION_Y_METRICAS.md`](docs/VALIDACION_Y_METRICAS.md).

---

## 6. Seguridad (secrets)

- Secret de MySQL **fuera de git** (`.gitignore` + `mysql-secret.example.yaml`); se crea
  en el despliegue (`deploy.sh`) o desde GitHub Secrets.
- Credenciales AWS solo como **GitHub Secrets**.
- Los backends reciben `DB_PASSWORD` por `secretKeyRef` (no en texto plano en manifests).
- **Mejora vs EVA2:** los workflows de EVA2 tenían la password (`admin123`) escrita en el
  `docker run`. En EP3 la password sale del Secret de Kubernetes.

---

## 7. Convención de commits

- `feat: deployment + service + hpa de backend-ventas en EKS`
- `fix: nginx del frontend apuntaba a IP de EC2; ahora usa DNS interno del Service`
- `ci: pipeline ventas build→push ECR→deploy EKS (reemplaza SSM/EC2)`
- `docs: README y guía de despliegue EP3`

# Mapeo: cada indicador de la pauta oficial EFT 2025 → dónde se resuelve

> Ajustado a la pauta **"EFT_Instrucciones y Pauta EP_Encargo_Estudiante_2025"** y
> **"EFT_Instrucciones y Pauta_Presentacion_Estudiante_2025"** (ISY1101, semana 18).
> La numeración de indicadores de este documento es la oficial: **IE1–IE6** para la
> dimensión Encargo (20% del EFT) e **IE8–IE11** para la dimensión Defensa (80% del EFT).

## Dimensión: Encargo (20% del EFT)

| IE | Indicador | % dentro del Encargo | Dónde se evidencia |
|----|-----------|----------------------|---------------------|
| **IE1** | Gestión de Versiones y Arquitectura | 10% | Historial de commits en GitHub + diagrama de arquitectura en `README.md` y `docs/ARQUITECTURA.md`. **Pendiente:** limpiar mensajes de commit poco descriptivos y trabajar con ramas de feature antes de la entrega (ver checklist abajo). |
| **IE2** | Contenerización para Desarrollo Local | 10% | `docker-compose.yml` (raíz del repo): levanta frontend + backend-ventas + backend-despachos + MySQL con una red (`tienda-net`) y un volumen (`db-data`) propios. Dockerfiles multietapa por componente + `.dockerignore`. Verificado end-to-end con `docker compose up -d --build` (frontend → proxy → ambos backends → MySQL con la semilla de `init.sql`). |
| **IE3** | Configuración del Pipeline de CI/CD | 20% | `.github/workflows/ci-cd-*.yml` (4 pipelines). Etapas **build → test → push (ECR) → deploy (EKS)**: los backends corren `mvnw test` con perfil H2 en memoria, el frontend corre `npm run lint`, y `db` construye la imagen y valida la semilla de datos antes de publicar. Ver `docs/PIPELINE_CICD.md`. |
| **IE4** | Despliegue y Orquestación en la Nube (AWS EKS) | 20% | `infra/duoc-devops-ep3.yaml` (VPC, subredes, NAT, roles IAM, clúster EKS, Node Group) + `k8s/*-deployment.yaml` + `*-service.yaml` + `*-hpa.yaml`. Ver `docs/ARQUITECTURA.md`. |
| **IE5** | Verificación y Funcionalidad del Sistema | 20% | `docs/VALIDACION_Y_METRICAS.md`: pruebas curl end-to-end (ventas/despachos), logs (`kubectl logs`, CloudWatch), prueba de autoscaling con carga, autorecuperación (`kubectl delete pod`), redeploy sin downtime. |
| **IE6** | Presentación y Defensa Técnica | 20% | Guion y estructura en `docs/GUION_PRESENTACION.md`. **Pendiente:** grabar/preparar el material de presentación (diapositivas PPT/PDF) — el archivo `PRESENTACION DEVOPS.pdf` existente es de una entrega anterior (EVA2/EC2) y debe reemplazarse por uno que hable de EKS/CI-CD. |

## Dimensión: Defensa (80% del EFT, individual)

| IE | Indicador | % dentro de la Defensa | Apoyo |
|----|-----------|--------------------------|-------|
| **IE8** | Explicación de fundamentos de orquestación (clúster, nodos, autoscaling, balanceo) | 25% | `docs/ARQUITECTURA.md` + `GUION_PRESENTACION.md` §1–3 |
| **IE9** | Demostración del pipeline CI/CD (build → push → deploy) | 25% | `docs/PIPELINE_CICD.md` + demo en vivo (§4 del guion) |
| **IE10** | Defensa técnica (responde preguntas del docente) | 25% | Banco de preguntas típicas en `GUION_PRESENTACION.md` |
| **IE11** | Claridad, estructura y calidad de la presentación | 25% | Estructura con tiempos (10–15 min) en `GUION_PRESENTACION.md` |

## Checklist de entrega (AVA)

- [x] Repositorio en GitHub con código + capa EP3 (K8s/CloudFormation) + `docker-compose.yml` para desarrollo local.
- [ ] Historial de commits limpio: evitar mensajes como "." o texto sin sentido; usar `feat:`/`fix:`/`ci:`/`docs:` y, si se puede, una rama por funcionalidad antes del merge a `main`.
- [x] `README.md` que explica funcionamiento, uso y **cómo levantar el entorno local** (✓ incluido, sección 4bis).
- [x] Infra reproducible (CloudFormation) + bootstrap (`deploy.sh`).
- [x] 4 pipelines CI/CD con etapa de **test** antes del push/deploy.
- [ ] Confirmar que el repositorio esté marcado como **público** en GitHub (Settings → General → Danger Zone → Change visibility).
- [ ] **Informe en Word** (nuevo, específico de esta EFT) que cubra los 8 puntos de la pauta: integración del sistema, contenedores, registro de imágenes (ECR + tags), CI/CD, infraestructura AWS, secretos, observabilidad, seguridad y orquestación/escalabilidad — con diagrama de arquitectura incluido. El contenido ya redactado en `docs/GUIA_COMPLETA.md`, `ARQUITECTURA.md`, `PIPELINE_CICD.md` y `VALIDACION_Y_METRICAS.md` sirve de base directa; falta consolidarlo en el formato Word pedido.
- [ ] **Presentación** (PPT/PDF) actualizada a EKS, subida al AVA — reemplaza a `PRESENTACION DEVOPS.pdf` (esa es de EVA2/EC2).
- [ ] Evidencias para la defensa: URL pública del ELB, `kubectl get ...`, logs, runs en verde de Actions, escaneo de vulnerabilidades de imágenes (ECR "scan on push", opcional pero suma para el ítem de seguridad básica de la pauta).

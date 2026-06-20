# Mapeo: cada indicador de la rúbrica → dónde se resuelve

## Dimensión Encargo (repositorio)

| IE | Indicador | % | Dónde se evidencia |
|----|-----------|---|--------------------|
| **IE1** | Configuración del clúster AWS (EKS) | 25% | `infra/duoc-devops-ep3.yaml` (VPC, subredes, SG, NAT, roles IAM, EKS, Node Group, addons) · `docs/ARQUITECTURA.md` |
| **IE2** | Despliegue Frontend + Backends | 25% | `k8s/*-deployment.yaml` + `*-service.yaml` (frontend, ventas, despachos, mysql), imágenes ECR, env vars, ELB público, proxy Front→Back |
| **IE3** | Autoscaling | 10% | `k8s/*-hpa.yaml` (ventas/despachos 70%, frontend 60%), Metrics Server en `scripts/deploy.sh`, prueba en `docs/VALIDACION_Y_METRICAS.md` |
| **IE4** | Pipeline CI/CD build→push→deploy | 15% | `.github/workflows/ci-cd-*.yml` (4) · `docs/PIPELINE_CICD.md` |
| **IE5** | Gestión de secrets y credenciales | 5% | Secret fuera de git (`.gitignore` + `mysql-secret.example.yaml`), creado en deploy; AWS como GitHub Secrets; `secretKeyRef` en backends |
| **IE6** | Análisis de logs, métricas y tiempos | 10% | `docs/VALIDACION_Y_METRICAS.md` (logs, CloudWatch, top, tiempos pipeline) |
| **IE7** | Validación funcional Front→Back | 10% | `docs/VALIDACION_Y_METRICAS.md` (curl end-to-end ventas/despachos, autorecuperación, redeploy) |

## Dimensión Presentación (defensa individual)

| IE | Indicador | % | Apoyo |
|----|-----------|---|-------|
| **IE8** | Fundamentos de orquestación | 25% | `docs/ARQUITECTURA.md` + `GUION_PRESENTACION.md` §1–3 |
| **IE9** | Demostración del pipeline CI/CD | 25% | `docs/PIPELINE_CICD.md` + demo en vivo (§4 del guion) |
| **IE10** | Defensa técnica (preguntas) | 25% | Banco de preguntas en `GUION_PRESENTACION.md` |
| **IE11** | Claridad y calidad de la presentación | 25% | Estructura con tiempos en `GUION_PRESENTACION.md` |

## Checklist de entrega (AVA)

- [ ] Repositorio en GitHub con código + capa EP3 + **commits explicativos** (feat/fix/ci/docs).
- [ ] `README.md` que explica funcionamiento y uso (✓ incluido).
- [ ] Infra reproducible (CloudFormation) + bootstrap (`deploy.sh`).
- [ ] 4 pipelines CI/CD funcionando (run en verde con deploy a EKS).
- [ ] Workflows antiguos de EVA2 (EC2/SSM) reemplazados por los de EKS.
- [ ] Secrets configurados (GitHub) y NO expuestos en el código.
- [ ] Evidencias para la defensa: URL pública, `kubectl get ...`, logs, runs de Actions.
- [ ] Presentación (PPT/PDF) subida al AVA.

# Arquitectura y configuración del clúster (apoyo IE1 / IE8)

## 1. Decisión: EKS vs ECS

Se eligió **AWS EKS** (Kubernetes administrado):

- **Microservicios:** la app son 2 backends Spring Boot + frontend + DB; Kubernetes
  modela bien cada uno como Deployment/Service independiente con su propio escalado.
- **Estándar / portabilidad:** los manifests corren igual en cualquier Kubernetes.
- **Autoscaling declarativo** (HPA + Metrics Server) y **autorecuperación** nativa.
- **Despliegue continuo** con `kubectl set image` + rolling updates sin downtime.

Contrapartida: más complejidad que ECS/Fargate; se asume por el valor formativo y porque
EVA2 ya dejaba contenedores listos.

## 2. De EVA2 (EC2) a EP3 (EKS)

| Aspecto | EVA2 (EP2) | EP3 |
|---------|------------|-----|
| Cómputo | 3 EC2 (frontend, backends, db) | Pods en nodos EKS (2 AZ) |
| Despliegue | `docker run` vía SSM | Deployments + rolling update |
| Escalado | manual (1 contenedor) | HPA (2→10 pods) + Node Group (2→4 nodos) |
| Red Front→Back | IP fija `10.0.137.73` | DNS interno de Services (CoreDNS) |
| Recuperación | reinicio manual | ReplicaSet + probes automáticos |

## 3. Red (VPC)

| Recurso | CIDR | Rol |
|---------|------|-----|
| VPC `devopsvpc` | `10.0.0.0/16` | Red del proyecto |
| 2 subredes públicas | `10.0.1/2.0/24` | **ELB público** del frontend |
| 4 subredes privadas (2×AZ) | `10.0.11/12/21/22.0/24` | **Nodos** del clúster |
| Internet Gateway | — | Salida de subredes públicas |
| NAT Gateway | — | Salida de subredes privadas (pull de ECR) |

**Multi-AZ** (2 zonas) ⇒ **alta disponibilidad**: si cae una AZ, los pods de la otra siguen.

## 4. Security Groups

- SG del clúster (gestionado por EKS): control plane ↔ nodos.
- ELB del frontend: abre **puerto 80** a Internet.
- Backends (8080/8081) y MySQL (3306): **solo tráfico interno** (ClusterIP / headless).

## 5. Roles IAM

| Rol | Uso |
|-----|-----|
| **Cluster role** (`LabRole`) | EKS gestiona ENIs y balanceadores. |
| **Node role** (`LabRole`) | Nodos se unen al clúster y hacen **pull desde ECR**. |

En AWS Academy se reutiliza `LabRole`. En producción: roles dedicados con permisos mínimos.

## 6. Cómo se garantizan los 4 atributos

| Atributo | Mecanismo |
|----------|-----------|
| **Escalabilidad** | HPA por CPU en frontend y ambos backends; Node Group 2→4. |
| **Alta disponibilidad** | 2 réplicas mínimas por servicio en 2 AZ. |
| **Tolerancia a fallos** | ReplicaSet recrea pods; probes TCP/HTTP; rolling updates. |
| **Automatización** | CloudFormation (infra) + 4 pipelines GitHub Actions + `deploy.sh`. |

## 7. Healthchecks (nota técnica)

Los backends Spring Boot **no** incluyen `spring-boot-actuator`, por eso las probes son
**tcpSocket** sobre el puerto (8080/8081) + un `startupProbe` amplio porque la JVM tarda
en arrancar. El frontend usa probe HTTP en `/`.

## 8. Addons

`vpc-cni`, `coredns` (DNS Front→Back→DB), `kube-proxy`, `eks-pod-identity-agent`,
`amazon-cloudwatch-observability` (logs/métricas a CloudWatch → base de IE6).

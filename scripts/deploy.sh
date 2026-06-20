#!/bin/bash
#
# Bootstrap / despliegue inicial completo en EKS desde AWS CloudShell.
# Construye y sube las 4 imágenes a ECR (frontend, backend-ventas,
# backend-despachos, db), crea el Secret de MySQL y aplica todos los manifests.
#
# IMPORTANTE: ejecutar desde la RAÍZ del repo (donde están las carpetas
#   frontend/  backend-ventas/  backend-despachos/  db/  k8s/  app/ )
#
# Uso:
#   chmod +x scripts/deploy.sh && ./scripts/deploy.sh
#
# La contraseña de la BD se toma de la variable de entorno DB_PASSWORD
# (por defecto admin123, igual que EVA2). Cambiar en producción:
#   export DB_PASSWORD='MiClaveSegura' && ./scripts/deploy.sh

set -e

REGION="us-east-1"
CLUSTER_NAME="devopseks"
NAMESPACE="tienda"
IMAGE_TAG="eks-v1"
DB_PASSWORD="${DB_PASSWORD:-admin123}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "===================================="
echo "Account ID : ${ACCOUNT_ID}"
echo "Cluster    : ${CLUSTER_NAME}"
echo "Region     : ${REGION}"
echo "ECR URL    : ${ECR_URL}"
echo "===================================="

echo ""
echo ">> Actualizando kubeconfig..."
aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}"

echo ""
echo ">> Instalando Metrics Server (necesario para el HPA)..."
kubectl apply -f \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo ""
echo ">> Aplicando config NGINX adaptada a EKS al frontend..."
cp ./app/frontend/default.conf ./frontend/default.conf

echo ""
echo ">> Reemplazando placeholder {{ECR_URL}} en los manifests..."
find ./k8s -type f -name "*.yaml" \
  -exec sed -i "s|{{ECR_URL}}|${ECR_URL}|g" {} \;

echo ""
echo ">> Login en ECR..."
aws ecr get-login-password --region "${REGION}" | \
  docker login --username AWS --password-stdin "${ECR_URL}"

####################################################
# BUILD + PUSH de las 4 imágenes
####################################################
echo ""
echo ">> Build & push tienda-frontend..."
docker build \
  --build-arg VITE_API_VENTAS_URL="" \
  --build-arg VITE_API_DESPACHOS_URL="" \
  -t tienda-frontend ./frontend
docker tag  tienda-frontend:latest "${ECR_URL}/tienda-frontend:${IMAGE_TAG}"
docker push "${ECR_URL}/tienda-frontend:${IMAGE_TAG}"

echo ""
echo ">> Build & push tienda-backend-ventas..."
docker build -t tienda-backend-ventas ./backend-ventas
docker tag  tienda-backend-ventas:latest "${ECR_URL}/tienda-backend-ventas:${IMAGE_TAG}"
docker push "${ECR_URL}/tienda-backend-ventas:${IMAGE_TAG}"

echo ""
echo ">> Build & push tienda-backend-despachos..."
docker build -t tienda-backend-despachos ./backend-despachos
docker tag  tienda-backend-despachos:latest "${ECR_URL}/tienda-backend-despachos:${IMAGE_TAG}"
docker push "${ECR_URL}/tienda-backend-despachos:${IMAGE_TAG}"

echo ""
echo ">> Build & push tienda-db..."
docker build -t tienda-db ./db
docker tag  tienda-db:latest "${ECR_URL}/tienda-db:${IMAGE_TAG}"
docker push "${ECR_URL}/tienda-db:${IMAGE_TAG}"

####################################################
# KUBERNETES
####################################################
echo ""
echo ">> Creando namespace..."
kubectl apply -f ./k8s/namespace.yaml

echo ""
echo ">> Creando Secret de MySQL (no versionado en git)..."
kubectl create secret generic mysql-secret \
  --namespace "${NAMESPACE}" \
  --from-literal=MYSQL_ROOT_PASSWORD="${DB_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo ">> Desplegando MySQL..."
kubectl apply -f ./k8s/mysql-deployment.yaml
kubectl apply -f ./k8s/mysql-service.yaml
kubectl rollout status deployment/tienda-db -n "${NAMESPACE}" --timeout=300s

echo ""
echo ">> Desplegando Backend Ventas..."
kubectl apply -f ./k8s/backend-ventas-deployment.yaml
kubectl apply -f ./k8s/backend-ventas-service.yaml
kubectl apply -f ./k8s/backend-ventas-hpa.yaml

echo ""
echo ">> Desplegando Backend Despachos..."
kubectl apply -f ./k8s/backend-despachos-deployment.yaml
kubectl apply -f ./k8s/backend-despachos-service.yaml
kubectl apply -f ./k8s/backend-despachos-hpa.yaml

echo ""
echo ">> Esperando que los backends queden Ready (la JVM tarda en arrancar)..."
kubectl rollout status deployment/tienda-backend-ventas    -n "${NAMESPACE}" --timeout=420s
kubectl rollout status deployment/tienda-backend-despachos -n "${NAMESPACE}" --timeout=420s

echo ""
echo ">> Desplegando Frontend..."
kubectl apply -f ./k8s/frontend-deployment.yaml
kubectl apply -f ./k8s/frontend-service.yaml
kubectl apply -f ./k8s/frontend-hpa.yaml
kubectl rollout status deployment/tienda-frontend -n "${NAMESPACE}" --timeout=300s

echo ""
echo ">> Estado actual:"
kubectl get pods -n "${NAMESPACE}"
kubectl get svc  -n "${NAMESPACE}"
kubectl get hpa  -n "${NAMESPACE}"

####################################################
# LOAD BALANCER (URL pública)
####################################################
echo ""
echo ">> Esperando DNS público del LoadBalancer..."
for i in {1..40}; do
  HOSTNAME=$(kubectl get svc tienda-frontend -n "${NAMESPACE}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  if [ -n "$HOSTNAME" ]; then
    echo ""
    echo "===================================="
    echo "APLICACIÓN DISPONIBLE EN:"
    echo "http://${HOSTNAME}"
    echo "===================================="
    exit 0
  fi
  echo "Esperando IP/DNS público... (${i}/40)"
  sleep 15
done

echo ""
echo "No fue posible obtener el DNS público automáticamente."
echo "Verificar con: kubectl get svc tienda-frontend -n ${NAMESPACE}"

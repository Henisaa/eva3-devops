# Validación funcional, métricas y pruebas (apoyo IE6 / IE7)

## 1. Validación funcional Front → Back → DB (IE7)

```bash
# 1) Frontend público responde (200)
curl -I http://<DNS_DEL_ELB>

# 2) Microservicio Ventas (a través del proxy del frontend)
curl http://<DNS_DEL_ELB>/api/v1/ventas
# -> JSON con las 3 ventas semilla (init.sql)

# 3) Microservicio Despachos
curl http://<DNS_DEL_ELB>/api/v1/despachos
# -> JSON (lista de despachos; vacía al inicio)

# 4) Escritura (CRUD) en Ventas
curl -X POST http://<DNS_DEL_ELB>/api/v1/ventas \
  -H "Content-Type: application/json" \
  -d '{"direccionCompra":"Calle Falsa 123","valorCompra":12990,"fechaCompra":"2024-02-01","despachoGenerado":false}'
```

Si los 4 pasos responden, queda demostrada la comunicación end-to-end (frontend → ambos
microservicios → MySQL) y la persistencia.

## 2. Logs (IE6)

```bash
kubectl logs -f deploy/tienda-backend-ventas    -n tienda
kubectl logs -f deploy/tienda-backend-despachos -n tienda
kubectl logs -f deploy/tienda-frontend          -n tienda
kubectl get events -n tienda --sort-by=.lastTimestamp
```

**CloudWatch:** el addon `amazon-cloudwatch-observability` + el logging del control plane
envían a CloudWatch (Container Insights y log groups `/aws/eks/devopseks/...`).

## 3. Prueba de autoscaling / carga (IE3 / IE7)

```bash
kubectl get hpa -n tienda

# Generar carga sobre el backend de ventas desde un pod temporal
kubectl run carga --rm -it --image=busybox -n tienda --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://tienda-backend-ventas:8080/api/v1/ventas; done"

# Observar el escalado en vivo (otra terminal)
kubectl get hpa  -n tienda -w
kubectl get pods -n tienda -w
```

**Esperado:** al superar el 70% de CPU, el HPA de ventas sube réplicas (2 → … → 10); al
cesar la carga, baja. Evidencia: capturas del `-w`.

## 4. Autorecuperación / recuperación ante fallos (IE7)

```bash
# Matar un pod: Kubernetes lo recrea solo
kubectl delete pod -l app=tienda-backend-ventas -n tienda
kubectl get pods -n tienda -w

# Redeploy sin downtime
kubectl rollout restart deployment/tienda-backend-despachos -n tienda
kubectl rollout status  deployment/tienda-backend-despachos -n tienda
```

## 5. Tabla de métricas para la presentación

| Métrica | Comando / fuente | Valor (rellenar en demo) |
|---------|------------------|---------------------------|
| Tiempo de pipeline (build→deploy) | GitHub Actions → run | ___ s |
| Réplicas ventas en reposo / carga | `kubectl get hpa` | 2 / ___ |
| CPU por pod bajo carga | `kubectl top pods -n tienda` | ___ m |
| Tiempo de recuperación de un pod | `kubectl get pods -w` | ___ s |
| Disponibilidad durante redeploy | `curl` en bucle | sin caídas |

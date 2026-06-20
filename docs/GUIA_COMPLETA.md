
Este documento explica **absolutamente todo** el proyecto: qué hace, cómo funciona, y
qué significa **cada línea** de los Dockerfiles, comandos y manifests.

Está escrito en **capas**. Cada sección marca su nivel:

- 🟢 **Básico** — para alguien de informática que no sabe programar ni de nube.
- 🟡 **Intermedio** — conoce Docker/Linux por encima.
- 🔴 **Avanzado** — quiere el detalle fino.

Puedes leer solo los 🟢 y entender el panorama, o leerlo todo para dominar cada detalle.

---

## Índice

1. [¿Qué es este proyecto? (analogía)](#1-qué-es-este-proyecto-analogía)
2. [Glosario mínimo](#2-glosario-mínimo)
3. [Las 4 piezas de la aplicación](#3-las-4-piezas-de-la-aplicación)
4. [El viaje de un clic (cómo viaja una petición)](#4-el-viaje-de-un-clic)
5. [Docker explicado línea por línea](#5-docker-explicado-línea-por-línea)
6. [Kubernetes explicado (manifests)](#6-kubernetes-explicado-manifests)
7. [La infraestructura en AWS (CloudFormation)](#7-la-infraestructura-en-aws-cloudformation)
8. [El script de despliegue (deploy.sh) comando por comando](#8-el-script-de-despliegue-deploysh)
9. [El pipeline CI/CD (GitHub Actions) paso por paso](#9-el-pipeline-cicd-github-actions)
10. [El ciclo de vida de un cambio (todo junto)](#10-el-ciclo-de-vida-de-un-cambio)
11. [Comandos de operación que usarás](#11-comandos-de-operación)
12. [Preguntas frecuentes](#12-preguntas-frecuentes)

---

## 1. ¿Qué es este proyecto? (analogía)

🟢 Imagina una **tienda** con tres empleados especializados:

- Un **vitrinista** que muestra los productos al público (el **Frontend**).
- Un **cajero de ventas** que registra las compras (el **Backend de Ventas**).
- Un **encargado de despachos** que gestiona los envíos (el **Backend de Despachos**).
- Y una **bodega con un cuaderno** donde todo queda anotado (la **Base de Datos**).

El cliente solo habla con el vitrinista. El vitrinista, por dentro, le pregunta al cajero
o al encargado según lo que el cliente quiera. Ellos anotan/consultan en el cuaderno.

🟡 Técnicamente: es una aplicación **web de microservicios**. Un frontend (React) y dos
APIs REST (Spring Boot) que guardan datos en MySQL. Todo **empaquetado en contenedores
Docker** y ejecutado de forma **orquestada en Kubernetes (AWS EKS)**, con despliegue
automático mediante **GitHub Actions**.

🔴 Es la evolución de un despliegue previo (EVA2) que corría 1 contenedor por máquina
virtual (EC2). Aquí se migra a un clúster Kubernetes que aporta réplicas, autoescalado
horizontal, autorecuperación, balanceo de carga y entrega continua.

---

## 2. Glosario mínimo

🟢 Lee esto una vez; el resto del documento lo usa constantemente.

| Término | Explicación sencilla |
|---------|----------------------|
| **Servidor** | Un computador encendido siempre, esperando peticiones. |
| **Imagen (Docker)** | Una "fotografía" congelada de un programa + todo lo que necesita para correr (sistema, librerías, código). Como un molde. |
| **Contenedor** | Una imagen **en ejecución**. Como una galleta hecha con el molde. Puedes crear muchas galletas (contenedores) iguales del mismo molde (imagen). |
| **Docker** | La herramienta que crea imágenes y ejecuta contenedores. |
| **Dockerfile** | La **receta** de texto que dice cómo construir una imagen, paso a paso. |
| **Registro / ECR** | Un "almacén de imágenes" en la nube. **ECR** = Elastic Container Registry, el almacén de imágenes de AWS. |
| **Kubernetes (k8s)** | El "director de orquesta" que ejecuta contenedores: decide en qué máquina corren, los reinicia si mueren, crea copias si hay mucha carga. |
| **EKS** | Kubernetes **administrado por AWS** (Elastic Kubernetes Service). AWS te da el clúster listo. |
| **Pod** | La unidad mínima que ejecuta Kubernetes: 1 (o más) contenedores juntos. Piensa "pod ≈ una galleta corriendo". |
| **Nodo** | Una máquina virtual (EC2) donde Kubernetes coloca pods. |
| **Clúster** | El conjunto de nodos + el cerebro que los coordina. |
| **Deployment** | Una receta de Kubernetes que dice "quiero N copias de este pod corriendo siempre". |
| **Service** | Un "nombre y puerta de entrada" estable para llegar a un grupo de pods (los pods cambian de IP; el Service no). |
| **HPA** | Horizontal Pod Autoscaler: crea o elimina pods automáticamente según la carga (CPU). |
| **CI/CD** | Integración/Entrega continua: automatizar construir → publicar → desplegar cuando cambias el código. |
| **VPC** | Tu red privada dentro de AWS. |
| **Load Balancer (ELB)** | Repartidor de tráfico: recibe las visitas de Internet y las distribuye entre los pods. |

---

## 3. Las 4 piezas de la aplicación

### 3.1 Frontend (carpeta `frontend/`) 🟢
- **Qué es:** la página web que ve el usuario. Hecha con **React + Vite** (un framework
  de JavaScript). Muestra tablas de ventas y despachos y formularios.
- **Cómo se sirve:** una vez "construida", son archivos estáticos (HTML/CSS/JS) que
  entrega **NGINX** (un servidor web muy liviano).
- **Truco clave:** NGINX además hace de **intermediario** (*reverse proxy*). Cuando el
  navegador pide `/api/v1/ventas`, NGINX reenvía esa petición al backend de ventas dentro
  del clúster. Así el navegador nunca habla directo con los backends.
- **Puerto:** 80 (HTTP).

### 3.2 Backend de Ventas (`backend-ventas/`) 🟢🟡
- **Qué es:** una **API REST** en **Java con Spring Boot**. Gestiona ventas (crear, listar,
  modificar, borrar).
- **Rutas:** todas bajo `api/v1/ventas` (lo define `@RequestMapping("api/v1/ventas")` en
  `VentaController.java`). Ejemplo: `GET /api/v1/ventas` lista todas.
- **Puerto:** 8080.
- **Datos:** se conecta a MySQL usando variables de entorno (`DB_ENDPOINT`, `DB_PORT`, etc.).

### 3.3 Backend de Despachos (`backend-despachos/`) 🟢🟡
- Igual que Ventas pero para **despachos** (envíos). Rutas bajo `api/v1/despachos`.
- **Puerto:** 8081 (lo fija `server.port=8081` en su `application.properties`).

### 3.4 Base de datos (`db/`) 🟢
- **Qué es:** un **MySQL 8** con la base `tienda_semestral`.
- **Semilla:** el archivo `init.sql` crea la tabla `venta` y mete 3 filas de ejemplo la
  primera vez que arranca.
- **Puerto:** 3306 (puerto estándar de MySQL).

🔴 Nota: los backends usan JPA con `spring.jpa.hibernate.ddl-auto=update`, así que crean/
actualizan las tablas que falten automáticamente al arrancar (p. ej. la de despachos).

---

## 4. El viaje de un clic

🟢 Qué pasa cuando un usuario abre la web y pide la lista de ventas:

```
1. Usuario abre  http://<DNS-del-LoadBalancer>           (en su navegador)
2. El Load Balancer (ELB) de AWS recibe la visita y la manda a un pod del Frontend
3. NGINX (frontend) devuelve la página web (HTML/JS)
4. El JavaScript de la página pide  GET /api/v1/ventas
5. NGINX ve que empieza por /api/v1/ventas  ->  la reenvía a  tienda-backend-ventas:8080
6. El Backend de Ventas recibe la petición, consulta MySQL (tienda-db:3306)
7. MySQL devuelve las filas; el backend las convierte a JSON y responde
8. NGINX devuelve ese JSON al navegador; la tabla se pinta en pantalla
```

🟡 Los nombres `tienda-backend-ventas`, `tienda-backend-despachos` y `tienda-db` **no son
IPs**: son nombres de **Services** de Kubernetes. El DNS interno del clúster (CoreDNS) los
traduce a la IP del pod correcto en ese momento. Por eso, aunque un pod muera y nazca otro
con otra IP, el nombre sigue funcionando.

🔴 Diagrama de red: solo el Frontend tiene un Service de tipo `LoadBalancer` (expuesto a
Internet). Ventas, Despachos y MySQL son `ClusterIP` (solo alcanzables **dentro** del
clúster). Esto reduce la superficie de ataque: la BD y las APIs nunca quedan públicas.

---

## 5. Docker explicado línea por línea

🟢 Recordatorio: un **Dockerfile** es la receta para construir una **imagen**. Cada línea
es una instrucción. Las instrucciones en MAYÚSCULAS (`FROM`, `COPY`, `RUN`…) son palabras
clave de Docker.

### 5.1 Dockerfile de los backends (Java / Spring Boot)

`backend-ventas/Dockerfile` (el de despachos es idéntico salvo el puerto):

```dockerfile
FROM maven:3.9-eclipse-temurin-17-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY mvnw .
COPY .mvn .mvn
RUN chmod +x mvnw && sed -i 's/\r$//' mvnw && \
    ./mvnw dependency:go-offline -B --no-transfer-progress
COPY src src
RUN ./mvnw package -DskipTests --no-transfer-progress
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Este es un **build multi-etapa** (dos `FROM`): una etapa "constructora" pesada y una etapa
final liviana. Línea por línea:

| Línea | Qué hace | Detalle |
|-------|----------|---------|
| `FROM maven:3.9-eclipse-temurin-17-alpine AS builder` | 🟢 Parte de una imagen base que ya trae **Maven** (compilador de Java) y **Java 17**. La apoda `builder`. | 🔴 `alpine` = Linux mínimo (~5 MB), imagen ligera. `AS builder` nombra esta etapa para referenciarla luego. |
| `WORKDIR /app` | 🟢 Crea y entra en la carpeta `/app` dentro de la imagen. Todo lo siguiente ocurre ahí. | Equivale a `mkdir /app && cd /app`. |
| `COPY pom.xml .` | 🟢 Copia el `pom.xml` (lista de dependencias del proyecto) al contenedor. | El `.` = "aquí" (`/app`). |
| `COPY mvnw .` | Copia el "Maven Wrapper" (`mvnw`), un script que ejecuta Maven sin instalarlo aparte. | |
| `COPY .mvn .mvn` | Copia la carpeta de configuración del wrapper. | |
| `RUN chmod +x mvnw && sed -i 's/\r$//' mvnw && ./mvnw dependency:go-offline ...` | 🟢 Da permiso de ejecución al script y **descarga todas las dependencias** por adelantado. | 🟡 `chmod +x` = hazlo ejecutable. `sed -i 's/\r$//'` = quita los retornos de carro de Windows (CRLF) que romperían el script en Linux. `dependency:go-offline` baja librerías ahora para aprovechar la **caché** de Docker. `-B` = modo batch (sin colores), `--no-transfer-progress` = sin barra de progreso (logs limpios). |
| `COPY src src` | 🟢 Ahora sí copia el **código fuente** (`src/`). | 🔴 Se copia **después** de las dependencias a propósito: si solo cambias código y no el `pom.xml`, Docker reutiliza la capa cacheada de dependencias y el build es mucho más rápido. |
| `RUN ./mvnw package -DskipTests --no-transfer-progress` | 🟢 **Compila** la app y genera el `.jar` (el programa Java empaquetado). | `-DskipTests` = no corre los tests durante el build de la imagen (se asume que ya pasaron en CI). |
| `FROM eclipse-temurin:17-jre-alpine` | 🟢 **Empieza una segunda imagen, limpia**, que solo trae el **JRE** (lo justo para *ejecutar* Java, sin Maven ni el compilador). | 🔴 Esto descarta toda la "cocina" pesada de la etapa anterior. La imagen final pesa decenas de MB en vez de cientos. |
| `WORKDIR /app` | Carpeta de trabajo en la imagen final. | |
| `COPY --from=builder /app/target/*.jar app.jar` | 🟢 Trae **solo el .jar ya compilado** desde la etapa `builder` y lo renombra `app.jar`. | `--from=builder` = "copia desde la otra etapa". |
| `EXPOSE 8080` | 🟢 Documenta que la app escucha en el puerto **8080**. | 🟡 Es informativo: no abre el puerto por sí solo, lo declara para quien use la imagen. (Despachos usa `EXPOSE 8081`.) |
| `ENTRYPOINT ["java", "-jar", "app.jar"]` | 🟢 El comando que se ejecuta al **arrancar** el contenedor: lanza la app Java. | 🔴 Forma "exec" (lista JSON): el proceso Java es PID 1 y recibe las señales del sistema (apagado limpio). |

### 5.2 Dockerfile del Frontend (React + NGINX)

`frontend/Dockerfile`:

```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
ARG VITE_API_VENTAS_URL
ARG VITE_API_DESPACHOS_URL
ENV VITE_API_VENTAS_URL=$VITE_API_VENTAS_URL
ENV VITE_API_DESPACHOS_URL=$VITE_API_DESPACHOS_URL
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /app/dist /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

También es multi-etapa: una etapa **Node** que compila el React, y una etapa **NGINX** que
sirve el resultado.

| Línea | Qué hace |
|-------|----------|
| `FROM node:18-alpine AS builder` | 🟢 Imagen con **Node.js 18** (necesario para construir apps de JavaScript). Apodada `builder`. |
| `WORKDIR /app` | Carpeta de trabajo. |
| `ARG VITE_API_VENTAS_URL` / `ARG VITE_API_DESPACHOS_URL` | 🟡 Declara **argumentos de build**: valores que se pueden pasar al construir (`--build-arg`). Aquí van vacíos a propósito (ver más abajo). |
| `ENV VITE_API_VENTAS_URL=$VITE_API_VENTAS_URL` (y la otra) | 🟡 Convierte esos argumentos en **variables de entorno** para que Vite las "incruste" en el JavaScript al compilar. |
| `COPY package*.json ./` | 🟢 Copia `package.json` y `package-lock.json` (la lista de librerías JS). |
| `RUN npm install` | 🟢 Descarga esas librerías. |
| `COPY . .` | 🟢 Copia el resto del código del frontend. |
| `RUN npm run build` | 🟢 **Compila** el React: genera la carpeta `dist/` con HTML/CSS/JS optimizados y estáticos. |
| `FROM nginx:alpine` | 🟢 Segunda imagen, con el servidor web **NGINX**. |
| `RUN rm -rf /usr/share/nginx/html/*` | 🟢 Borra la página por defecto de NGINX. | 
| `COPY --from=builder /app/dist /usr/share/nginx/html` | 🟢 Copia la web ya compilada (de la etapa `builder`) a la carpeta que NGINX publica. |
| `COPY default.conf /etc/nginx/conf.d/default.conf` | 🟢 Copia **nuestra configuración** de NGINX (la que define el proxy a los backends). |
| `EXPOSE 80` | Declara que NGINX escucha en el puerto 80. |

🔴 **¿Por qué los `VITE_API_*` van vacíos?** En el código React, las llamadas usan rutas
**relativas** (`/api/v1/ventas`). Con la variable vacía, `${import.meta.env.VITE_API_DESPACHOS_URL}/api/v1/despachos`
se vuelve simplemente `/api/v1/despachos`. Esa ruta relativa la captura NGINX y la
reenvía al Service interno. Resultado: el frontend no necesita saber IPs ni dominios de
los backends; todo se resuelve dentro del clúster.

### 5.3 Configuración de NGINX (`frontend/default.conf`) — el proxy

```nginx
server {
    listen 80;
    server_name _;
    charset utf-8;
    root /usr/share/nginx/html;
    index index.html;

    location /api/v1/ventas {
        proxy_pass http://tienda-backend-ventas:8080/api/v1/ventas;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
    }

    location /api/v1/despachos {
        proxy_pass http://tienda-backend-despachos:8081/api/v1/despachos;
        ...
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

| Línea | Qué hace |
|-------|----------|
| `listen 80;` | 🟢 NGINX escucha el puerto 80 (HTTP). |
| `server_name _;` | 🟡 Responde a cualquier nombre de dominio (`_` = comodín). |
| `root /usr/share/nginx/html;` | 🟢 Carpeta donde están los archivos web. |
| `index index.html;` | Archivo que se sirve por defecto. |
| `location /api/v1/ventas { ... }` | 🟢 "Si la URL empieza por `/api/v1/ventas`, haz esto". |
| `proxy_pass http://tienda-backend-ventas:8080/...;` | 🟢🟡 **Reenvía** la petición al Service de ventas (nombre interno) en el puerto 8080. Aquí ocurre la comunicación Frontend→Backend. |
| `proxy_set_header ...` | 🔴 Reenvía cabeceras útiles (host original, IP real del cliente) para que el backend sepa de dónde vino la petición. |
| `location / { try_files $uri $uri/ /index.html; }` | 🟡 Para cualquier otra ruta, intenta servir el archivo; si no existe, devuelve `index.html`. Esto hace que el **enrutado de React** (SPA) funcione al recargar la página. |

### 5.4 Dockerfile de la base de datos (`db/Dockerfile`)

```dockerfile
FROM mysql:8
ENV MYSQL_ROOT_PASSWORD=admin123
ENV MYSQL_DATABASE=tienda_semestral
ENV MYSQL_USER=alumno
ENV MYSQL_PASSWORD=alumno123
COPY init.sql /docker-entrypoint-initdb.d/
EXPOSE 3306
```

| Línea | Qué hace |
|-------|----------|
| `FROM mysql:8` | 🟢 Parte de la imagen oficial de **MySQL 8**. |
| `ENV MYSQL_ROOT_PASSWORD=admin123` | 🟢 Contraseña del usuario `root` de MySQL. **(En el clúster la sobreescribe el Secret de Kubernetes, ver §6.)** |
| `ENV MYSQL_DATABASE=tienda_semestral` | 🟢 Crea automáticamente esta base de datos al arrancar. |
| `ENV MYSQL_USER=alumno` / `MYSQL_PASSWORD=alumno123` | 🟡 Crea un usuario extra (no se usa en este proyecto, los backends entran como `root`). |
| `COPY init.sql /docker-entrypoint-initdb.d/` | 🟢🔴 Copia el script de inicio. **Magia de la imagen MySQL:** todo `.sql` en esa carpeta se ejecuta **la primera vez** que arranca un contenedor con datos vacíos. Así se crean tablas y datos semilla. |
| `EXPOSE 3306` | Declara el puerto de MySQL. |

🔴 **Importante sobre los datos:** en el clúster usamos almacenamiento `emptyDir` (ver
§6.3), que es temporal. Si el pod de MySQL se reinicia, los datos vuelven a la semilla de
`init.sql`. En producción se usaría un volumen persistente o una base gestionada (RDS).

### 5.5 ¿Qué es `.dockerignore`?
🟡 Cada módulo tiene un `.dockerignore`: lista de archivos que Docker **no** copia al
construir (p. ej. `node_modules`, `target`, `.git`). Acelera el build y evita meter basura
en la imagen.

---

## 6. Kubernetes explicado (manifests)

🟢 Los archivos en `k8s/` son **manifests**: archivos YAML que le dicen a Kubernetes "qué
quieres que exista". Tú describes el **estado deseado** ("quiero 2 copias de ventas") y
Kubernetes se encarga de lograrlo y mantenerlo.

🟡 Todo recurso YAML tiene 4 campos comunes:
- `apiVersion`: qué versión de la API de Kubernetes usar.
- `kind`: qué tipo de objeto es (Deployment, Service, etc.).
- `metadata`: nombre y namespace (carpeta lógica).
- `spec`: la especificación / lo que quieres.

### 6.1 Namespace (`namespace.yaml`)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tienda
```
🟢 Crea un **namespace** llamado `tienda`: una "carpeta" lógica donde viven todos nuestros
recursos, separados de los del sistema. Mantiene orden.

### 6.2 Secret de MySQL (`mysql-secret.example.yaml`)
🟢 Un **Secret** guarda datos sensibles (contraseñas). El archivo `.example` es solo una
**plantilla**: el Secret real **no se sube a git** (estaría expuesto). Se crea en el
despliegue con un comando (ver §8). Los pods leen la contraseña desde el Secret, nunca
escrita en el código.

🔴 Cumple el indicador IE5 (gestión de secrets): credencial fuera del repositorio,
inyectada en runtime vía `secretKeyRef`.

### 6.3 Deployment de MySQL (`mysql-deployment.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tienda-db
  namespace: tienda
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tienda-db
  template:
    metadata:
      labels:
        app: tienda-db
    spec:
      containers:
        - name: mysql
          image: {{ECR_URL}}/tienda-db:eks-v1
          ports:
            - containerPort: 3306
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: MYSQL_ROOT_PASSWORD
            - name: MYSQL_DATABASE
              value: "tienda_semestral"
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
      volumes:
        - name: data
          emptyDir: {}
```

| Campo | Qué significa |
|-------|---------------|
| `kind: Deployment` | 🟢 "Mantén corriendo estos pods siempre". |
| `replicas: 1` | 🟢 Quiero **1** copia de MySQL (la BD no se replica aquí por simplicidad). |
| `selector.matchLabels.app: tienda-db` | 🟡 El Deployment "adopta" los pods con la etiqueta `app: tienda-db`. |
| `template` | 🟢 La **plantilla del pod**: cómo es cada copia. |
| `image: {{ECR_URL}}/tienda-db:eks-v1` | 🟢🔴 Qué imagen usar. `{{ECR_URL}}` es un **marcador**: `deploy.sh` lo reemplaza por la dirección real de tu ECR (ver §8). `:eks-v1` es la etiqueta de versión. |
| `containerPort: 3306` | 🟢 El contenedor escucha en 3306. |
| `env` → `MYSQL_ROOT_PASSWORD` → `valueFrom.secretKeyRef` | 🟢🟡 La contraseña **no está escrita aquí**: se lee del Secret `mysql-secret`, clave `MYSQL_ROOT_PASSWORD`. |
| `volumeMounts` + `volumes` → `emptyDir: {}` | 🟡🔴 Monta una carpeta para los datos de MySQL. `emptyDir` = espacio temporal que vive mientras viva el pod. Si el pod muere, los datos se pierden (lab). |

### 6.4 Service de MySQL (`mysql-service.yaml`)
```yaml
kind: Service
spec:
  selector:
    app: tienda-db
  ports:
    - port: 3306
      targetPort: 3306
  clusterIP: None
```
🟢 Da un **nombre estable** (`tienda-db`) para alcanzar al pod de MySQL en el puerto 3306.
🟡 `clusterIP: None` lo hace **headless** (sin IP virtual propia): se usa para servicios de
estado como bases de datos. Los backends se conectan a `tienda-db:3306`.

### 6.5 Deployment de un backend (`backend-ventas-deployment.yaml`)
Lo más importante del proyecto. Campos nuevos respecto a MySQL:

```yaml
spec:
  replicas: 2
  ...
  containers:
    - name: backend-ventas
      image: {{ECR_URL}}/tienda-backend-ventas:eks-v1
      ports:
        - containerPort: 8080
      env:
        - name: DB_ENDPOINT
          value: "tienda-db"
        - name: DB_PORT
          value: "3306"
        - name: DB_NAME
          value: "tienda_semestral"
        - name: DB_USERNAME
          value: "root"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: MYSQL_ROOT_PASSWORD
      resources:
        requests:
          cpu: "250m"
          memory: "384Mi"
        limits:
          cpu: "1000m"
          memory: "768Mi"
      startupProbe:
        tcpSocket:
          port: 8080
        initialDelaySeconds: 20
        periodSeconds: 10
        failureThreshold: 18
      readinessProbe:
        tcpSocket:
          port: 8080
        periodSeconds: 10
      livenessProbe:
        tcpSocket:
          port: 8080
        initialDelaySeconds: 60
        periodSeconds: 15
```

| Campo | Qué significa |
|-------|---------------|
| `replicas: 2` | 🟢 Quiero **2 copias** del backend corriendo (alta disponibilidad: si una cae, la otra atiende). |
| `env: DB_ENDPOINT = "tienda-db"` | 🟢🟡 Le dice al backend dónde está la BD: el **nombre del Service** de MySQL. Spring Boot arma la URL `jdbc:mysql://tienda-db:3306/tienda_semestral` con estas variables. |
| `DB_PASSWORD` desde `secretKeyRef` | 🟢 La contraseña entra desde el Secret, no escrita en el YAML. |
| `resources.requests` | 🟡🔴 Lo **mínimo garantizado** para el pod: 250 milésimas de CPU (0,25 núcleos) y 384 MB de RAM. **El HPA necesita `requests` para calcular el % de uso.** |
| `resources.limits` | 🟡 El **máximo** que el pod puede consumir: 1 núcleo y 768 MB. Si se pasa de memoria, lo reinician. |
| `startupProbe` (tcpSocket:8080) | 🔴 "¿Ya arrancó?" Comprueba que el puerto 8080 responde. `failureThreshold: 18` × `periodSeconds: 10` ≈ **hasta 3 minutos** de margen, porque una app Java (JVM) tarda en levantar. Hasta que no pasa, no se aplican las otras probes. |
| `readinessProbe` | 🟢🔴 "¿Está listo para recibir tráfico?" Si falla, el Service **deja de enviarle peticiones** (pero no lo mata). |
| `livenessProbe` | 🟢🔴 "¿Sigue vivo?" Si falla repetidamente, Kubernetes **reinicia** el pod (autorecuperación). |

🔴 Se usan probes `tcpSocket` (revisar que el puerto abra) y no `httpGet /actuator/health`
porque el proyecto no incluye la dependencia `spring-boot-actuator`. Es una decisión
consciente para no modificar el `pom.xml`.

El de **despachos** es idéntico pero con puerto **8081**.

### 6.6 Service de un backend (`backend-ventas-service.yaml`)
```yaml
kind: Service
spec:
  selector:
    app: tienda-backend-ventas
  ports:
    - port: 8080
      targetPort: 8080
  type: ClusterIP
```
🟢 Nombre estable `tienda-backend-ventas` en el puerto 8080.
🟡 `type: ClusterIP` = **solo accesible dentro del clúster** (no público). Lo llama el
NGINX del frontend. `targetPort` es el puerto del contenedor; `port` el del Service.

### 6.7 Service del Frontend (`frontend-service.yaml`)
```yaml
spec:
  type: LoadBalancer
  selector:
    app: tienda-frontend
  ports:
    - port: 80
      targetPort: 80
```
🟢🟡 `type: LoadBalancer` es la diferencia clave: AWS crea automáticamente un **balanceador
público (ELB)** con un DNS de Internet. Esa URL es la puerta de entrada de los usuarios.
Es el **único** componente expuesto a Internet.

### 6.8 HPA — Autoescalado (`backend-ventas-hpa.yaml`)
```yaml
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    kind: Deployment
    name: tienda-backend-ventas
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```
| Campo | Qué significa |
|-------|---------------|
| `scaleTargetRef` | 🟢 A qué Deployment controla (ventas). |
| `minReplicas: 2` / `maxReplicas: 10` | 🟢 Nunca menos de 2 pods, nunca más de 10. |
| `averageUtilization: 70` | 🟢🔴 Objetivo: mantener el uso de CPU promedio en ~70% del `request` (250m). Si sube de ahí, **crea pods**; si baja, los elimina (hasta el mínimo). |

🟡 El frontend tiene su HPA al 60% (NGINX consume poca CPU, reacciona antes). El HPA
necesita el **Metrics Server** instalado para leer el uso de CPU (lo instala `deploy.sh`).

🔴 Diferencia importante: el **HPA escala PODS**; el **Node Group** (en CloudFormation)
escala **NODOS** (máquinas). Si hay muchos pods y no caben, hacen falta más nodos.

---

## 7. La infraestructura en AWS (CloudFormation)

🟢 `infra/duoc-devops-ep3.yaml` es una **plantilla de CloudFormation**: un archivo que
describe toda la infraestructura de AWS. Al "subirla", AWS crea **todo automáticamente**
(en vez de hacerlo a mano clic por clic). Esto se llama **Infraestructura como Código**.

🟡 Qué crea, en bloques:

| Bloque | Qué crea | Para qué |
|--------|----------|----------|
| **VPC** (`10.0.0.0/16`) | Una red privada propia. | Aislar el proyecto. |
| **2 subredes públicas** | Zonas con salida directa a Internet. | Alojar el Load Balancer del frontend. |
| **4 subredes privadas** (2 por zona) | Zonas sin acceso directo desde Internet. | Alojar los **nodos** (más seguro). |
| **Internet Gateway** | Puerta de la VPC hacia Internet. | Que lo público salga/entre. |
| **NAT Gateway** | Salida a Internet *de una vía* para lo privado. | Que los nodos privados descarguen imágenes de ECR sin ser accesibles desde fuera. |
| **Tablas de rutas** | Reglas de "por dónde sale el tráfico". | Conectar subredes con IGW/NAT. |
| **4 repositorios ECR** | Almacenes de imágenes: frontend, ventas, despachos, db. | Guardar las imágenes Docker. |
| **Clúster EKS** (`devopseks`) | El Kubernetes administrado. | Orquestar los contenedores. |
| **Node Group** (2× `t3.large`, hasta 4) | Las máquinas (EC2) donde corren los pods. | Capacidad de cómputo. |
| **Addons** (vpc-cni, coredns, kube-proxy, cloudwatch…) | Componentes internos del clúster. | Red de pods, DNS interno, métricas/logs. |

🔴 Conceptos finos:
- **Multi-AZ:** las subredes están en 2 *Availability Zones* (centros de datos físicos
  distintos). Si una zona cae, la app sigue en la otra → alta disponibilidad.
- **Roles IAM (`LabRole`):** permisos. El *cluster role* permite a EKS gestionar recursos;
  el *node role* permite a los nodos unirse al clúster y descargar de ECR. En AWS Academy
  ambos son `LabRole` (rol preexistente del laboratorio).
- **Logging del control plane → CloudWatch:** habilita registros del "cerebro" del clúster.
- `Version: "1.31"` es la versión de Kubernetes; se puede subir si el laboratorio lo exige.

---

## 8. El script de despliegue (deploy.sh)

🟢 `scripts/deploy.sh` hace el **primer despliegue completo** de una sola vez, desde AWS
CloudShell. Es un script de Bash (Linux). Lo lees de arriba a abajo; se ejecuta así.

```bash
#!/bin/bash
set -e
```
| Línea | Qué hace |
|-------|----------|
| `#!/bin/bash` | 🟢 "Shebang": indica que el archivo se ejecuta con Bash. |
| `set -e` | 🟡 "Si **cualquier** comando falla, **detente** inmediatamente". Evita seguir desplegando sobre un error. |

```bash
REGION="us-east-1"
CLUSTER_NAME="devopseks"
NAMESPACE="tienda"
IMAGE_TAG="eks-v1"
DB_PASSWORD="${DB_PASSWORD:-admin123}"
```
🟢 Define **variables** (valores reutilizables). 🟡 `${DB_PASSWORD:-admin123}` significa
"usa la variable de entorno `DB_PASSWORD` si existe; si no, usa `admin123`". Así puedes
inyectar una contraseña segura sin tocar el script.

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
```
🟡 Pregunta a AWS **cuál es tu número de cuenta** y arma la dirección de tu ECR. `$(...)`
ejecuta un comando y guarda su salida en la variable.

```bash
aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
```
🟢🟡 Configura `kubectl` (la herramienta de Kubernetes) para que apunte a **tu clúster**.
Sin esto, `kubectl` no sabría a qué clúster hablarle.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
🟢🔴 Instala el **Metrics Server**, que mide CPU/memoria de los pods. **Sin él, el HPA no
puede escalar** (no tendría datos de uso).

```bash
cp ./app/frontend/default.conf ./frontend/default.conf
```
🟡 Copia la configuración de NGINX adaptada a EKS sobre la del frontend, antes de construir
la imagen (asegura que el proxy apunte a los Services internos).

```bash
find ./k8s -type f -name "*.yaml" -exec sed -i "s|{{ECR_URL}}|${ECR_URL}|g" {} \;
```
🔴 Busca todos los `.yaml` en `k8s/` y **reemplaza el marcador `{{ECR_URL}}`** por la
dirección real de tu ECR. Así los manifests apuntan a tus imágenes. `sed` = editor de texto
por línea de comandos; `s|A|B|g` = sustituye A por B (global).

```bash
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_URL}
```
🟢🟡 **Inicia sesión en ECR** para poder subir imágenes. Pide una clave temporal a AWS y se
la pasa a `docker login` por la entrada estándar (`|` = "tubería", conecta la salida de un
comando con la entrada del siguiente).

```bash
docker build --build-arg VITE_API_VENTAS_URL="" --build-arg VITE_API_DESPACHOS_URL="" -t tienda-frontend ./frontend
docker tag  tienda-frontend:latest ${ECR_URL}/tienda-frontend:${IMAGE_TAG}
docker push ${ECR_URL}/tienda-frontend:${IMAGE_TAG}
```
🟢 Para cada servicio (aquí el frontend; igual para los 3 backends/db):
- `docker build ... -t tienda-frontend ./frontend` → **construye la imagen** desde el
  Dockerfile en `./frontend`. `-t` = ponle nombre (tag) local.
- `docker tag ...` → le pone la **etiqueta completa de ECR** (dirección + versión).
- `docker push ...` → **sube** la imagen a ECR.

```bash
kubectl apply -f ./k8s/namespace.yaml
```
🟢 Crea el namespace `tienda`. `kubectl apply -f` = "aplica este archivo" (crea o actualiza
lo que describe).

```bash
kubectl create secret generic mysql-secret \
  --namespace ${NAMESPACE} \
  --from-literal=MYSQL_ROOT_PASSWORD="${DB_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
```
🟡🔴 Crea el **Secret** con la contraseña, **sin escribirla en ningún archivo del repo**.
`--dry-run=client -o yaml | kubectl apply -f -` es un truco para que el comando sea
**idempotente**: genera el YAML del Secret y lo aplica; si ya existe, lo actualiza en vez
de fallar.

```bash
kubectl apply -f ./k8s/mysql-deployment.yaml
kubectl apply -f ./k8s/mysql-service.yaml
kubectl rollout status deployment/tienda-db -n ${NAMESPACE} --timeout=300s
```
🟢 Despliega MySQL y **espera** (`rollout status`) hasta que esté listo (máx. 300 s). Se
hace primero porque los backends la necesitan.

```bash
kubectl apply -f ./k8s/backend-ventas-deployment.yaml
kubectl apply -f ./k8s/backend-ventas-service.yaml
kubectl apply -f ./k8s/backend-ventas-hpa.yaml
# (lo mismo para despachos)
kubectl rollout status deployment/tienda-backend-ventas -n ${NAMESPACE} --timeout=420s
```
🟢 Despliega cada backend (Deployment + Service + HPA) y espera a que arranquen (420 s
porque la JVM es lenta).

```bash
kubectl apply -f ./k8s/frontend-deployment.yaml
kubectl apply -f ./k8s/frontend-service.yaml
kubectl apply -f ./k8s/frontend-hpa.yaml
kubectl rollout status deployment/tienda-frontend -n ${NAMESPACE} --timeout=300s
```
🟢 Finalmente el frontend (el último, porque es la cara visible).

```bash
for i in {1..40}; do
  HOSTNAME=$(kubectl get svc tienda-frontend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  if [ -n "$HOSTNAME" ]; then echo "http://${HOSTNAME}"; exit 0; fi
  sleep 15
done
```
🟡🔴 **Bucle de espera:** AWS tarda en asignar el DNS público del balanceador. Pregunta cada
15 s (hasta 40 veces = 10 min) por el `hostname`; cuando aparece, imprime la **URL final** y
termina. `jsonpath` extrae un dato puntual de la respuesta de Kubernetes.

---

## 9. El pipeline CI/CD (GitHub Actions)

🟢 Un **pipeline** automatiza el despliegue: cada vez que subes (push) código a GitHub, una
máquina de GitHub construye la imagen, la sube a ECR y actualiza el clúster. Sin tocar nada
a mano. Hay **4 pipelines** (uno por servicio) en `.github/workflows/`.

🟡 Estructura de un workflow (ejemplo `ci-cd-backend-ventas.yml`):

```yaml
on:
  push:
    branches: [ main ]
    paths:
      - "backend-ventas/**"
  workflow_dispatch:
```
| Línea | Qué hace |
|-------|----------|
| `on:` | 🟢 "¿Cuándo se dispara este pipeline?" |
| `push: branches: [ main ]` | 🟢 Cuando hay un push a la rama `main`. |
| `paths: backend-ventas/**` | 🔴 **Solo** si cambió algo dentro de `backend-ventas/`. Así un cambio en ventas no reconstruye despachos (despliegues independientes). |
| `workflow_dispatch:` | 🟡 Permite además lanzarlo **a mano** desde la pestaña Actions. |

```yaml
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```
🟢 Define un **trabajo** que corre en una máquina Ubuntu de GitHub. `checkout` = **descarga
tu código** en esa máquina.

```yaml
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-session-token: ${{ secrets.AWS_SESSION_TOKEN }}
          aws-region: us-east-1
```
🟢🟡 **Configura las credenciales de AWS** desde los *Secrets* de GitHub (valores ocultos
que tú configuras en el repo). `${{ secrets.X }}` lee un secreto. El **session token** es
obligatorio en AWS Academy (credenciales temporales).

```yaml
      - id: ecr
        uses: aws-actions/amazon-ecr-login@v2
```
🟢 Inicia sesión en ECR (igual que en deploy.sh, pero automático).

```yaml
      - run: |
          docker build -t "$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" \
                       -t "$REGISTRY/$ECR_REPOSITORY:latest" ./backend-ventas
          docker push "$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
          docker push "$REGISTRY/$ECR_REPOSITORY:latest"
```
🟢🔴 **Construye y sube la imagen** con dos etiquetas:
- `$IMAGE_TAG` = el **identificador del commit** (`github.sha`). Es **único e inmutable**:
  cada cambio produce una imagen distinta y trazable (sirve para auditoría y rollback).
- `latest` = "la más reciente".

```yaml
      - run: aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
      - run: |
          kubectl set image deployment/$DEPLOYMENT \
            $CONTAINER=$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -n $NAMESPACE
          kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=420s
```
🟢🟡 **Despliega en EKS:**
- `update-kubeconfig` → conecta `kubectl` al clúster.
- `kubectl set image` → le dice al Deployment "usa la **nueva imagen**". Kubernetes hace un
  **rolling update**: levanta pods nuevos, espera a que estén sanos y recién entonces apaga
  los viejos → **sin caída del servicio**.
- `rollout status` → **espera** y verifica que terminó bien; si los pods nuevos no quedan
  sanos en el tiempo dado, el pipeline **falla** (no se promueve un despliegue roto).

🔴 ¿Por qué funciona el `kubectl` desde GitHub sin más permisos? Porque el clúster lo creó
el rol `LabRole`, y las credenciales que usa GitHub Actions son de ese **mismo rol**, que es
administrador del clúster.

---

## 10. El ciclo de vida de un cambio

🟢 Junta todo. Imagina que corriges un bug en el backend de ventas:

```
1. Editas un archivo en  backend-ventas/src/...
2. git commit -m "fix: corrige cálculo de total"   +   git push
3. GitHub detecta el push en backend-ventas/  ->  dispara ci-cd-backend-ventas.yml
4. GitHub: build de la imagen  ->  push a ECR (tag = SHA del commit)
5. GitHub: kubectl set image  ->  EKS hace rolling update
6. EKS: levanta pods nuevos con la imagen nueva, verifica readinessProbe
7. EKS: apaga los pods viejos. Tráfico sin interrupción.
8. Listo: el cambio está en producción, automáticamente.
```

🟡 Y si llega mucho tráfico mientras tanto, el **HPA** crea más pods; si no caben, el
**Node Group** añade nodos. Si un pod se cuelga, la **livenessProbe** lo reinicia. Nadie
interviene a mano. Eso es **orquestación**.

---

## 11. Comandos de operación

🟢 Los que usarás para revisar/demostrar el sistema (requieren `kubectl` ya configurado):

| Comando | Qué muestra / hace |
|---------|--------------------|
| `kubectl get pods -n tienda` | Lista los pods y su estado (Running, Pending…). |
| `kubectl get pods -n tienda -o wide` | Igual + en qué nodo e IP está cada pod. |
| `kubectl get svc -n tienda` | Los Services; aquí ves el **DNS público** del frontend (columna EXTERNAL-IP). |
| `kubectl get hpa -n tienda` | El autoescalado: uso de CPU actual y réplicas. |
| `kubectl top pods -n tienda` | Consumo real de CPU/memoria por pod (necesita Metrics Server). |
| `kubectl logs -f deploy/tienda-backend-ventas -n tienda` | Los **logs** (registros) del backend en vivo (`-f` = sigue mostrando). |
| `kubectl describe pod <nombre> -n tienda` | Detalle completo de un pod (eventos, errores, por qué no arranca). |
| `kubectl rollout restart deployment/tienda-backend-ventas -n tienda` | Reinicia el servicio con un rolling update (sin downtime). |
| `kubectl delete pod <nombre> -n tienda` | Borra un pod a mano → Kubernetes crea otro solo (demuestra autorecuperación). |
| `kubectl get events -n tienda --sort-by=.lastTimestamp` | Historial de eventos (útil para diagnosticar). |

🔴 Atajos mentales para la defensa:
- "¿Está corriendo?" → `get pods`
- "¿Cuál es la URL?" → `get svc`
- "¿Escala?" → `get hpa` + generar carga
- "¿Qué pasó?" → `logs` / `describe` / `events`

---

## 12. Preguntas frecuentes

**🟢 ¿Por qué tantos archivos para una app simple?**
Porque separamos responsabilidades: el código (qué hace la app), Docker (cómo se empaqueta),
Kubernetes (cómo se ejecuta y escala), CloudFormation (qué infraestructura hay) y los
workflows (cómo se despliega). Cada capa es independiente y reemplazable.

**🟢 ¿Diferencia entre imagen y contenedor?**
La imagen es el molde (estática, en ECR). El contenedor es el molde en ejecución (un pod).
De una imagen salen muchos contenedores iguales.

**🟡 ¿Por qué microservicios y no todo junto?**
Ventas y despachos escalan y se despliegan por separado. Si despachos recibe mucha carga,
solo crece despachos. Si cambias ventas, solo se redespliega ventas.

**🟡 ¿Por qué el frontend es público y los backends no?**
Seguridad. El usuario solo necesita la web; las APIs y la BD quedan ocultas dentro del
clúster (`ClusterIP`), accesibles solo por quien debe (el frontend).

**🔴 ¿Qué pasa con los datos si se reinicia MySQL?**
Con `emptyDir` se pierden y se recargan de `init.sql`. Es aceptable en laboratorio. En
producción se usaría un `PersistentVolume` o Amazon RDS (base gestionada).

**🔴 ¿Cómo se hace rollback si un deploy sale mal?**
Como cada imagen lleva el tag del commit (SHA), puedes volver a la anterior con
`kubectl set image ... =<repo>:<sha-anterior>` o `kubectl rollout undo deployment/<nombre> -n tienda`.

---

### Resumen en una frase
🟢 **Empaquetamos la app en imágenes Docker, las guardamos en ECR, y Kubernetes (EKS) las
ejecuta de forma escalable y auto-reparable; GitHub Actions automatiza todo el camino desde
que escribes código hasta que está funcionando en la nube.**

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${app_name}
  namespace: ${namespace}
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app: ${app_name}
  template:
    metadata:
      labels:
        app: ${app_name}
    spec:
      containers:
      - name: ${app_name}
        image: ${image}
        ports:
        - containerPort: ${container_port}
        resources:
          requests:
            memory: "${memory_request}"
            cpu: "${cpu_request}"
          limits:
            memory: "${memory_limit}"
            cpu: "${cpu_limit}" 
apiVersion: v1
kind: Service
metadata:
  name: ${app_name}
  namespace: ${namespace}
spec:
  type: ${service_type}
  ports:
  - port: ${service_port}
    targetPort: ${container_port}
    nodePort: ${node_port}
  selector:
    app: ${app_name} 
# чувствительные переменные вынесены в secret.auto.tfvars и исключены в .gitignore

###cloud vars
variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
  sensitive   = true
}

# id облака
variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
  sensitive   = true
}

# id каталога
variable "folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
  sensitive   = true
}

# зона
variable "default_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

# имя vpc
variable "vpc_name" {
  type        = string
  default     = "develop"
  description = "VPC network&subnet name"
}

# подсети
variable "subnets" {
  type = list(object({
    zone = string
    cidr = string
  }))
  default = [
    { zone = "ru-central1-a", cidr = "10.0.1.0/24" },
    { zone = "ru-central1-b", cidr = "10.0.2.0/24" },
    { zone = "ru-central1-d", cidr = "10.0.3.0/24" },
  ]
}

# vm vars
variable "default_vm" {
  type = map(object({
    image_family         = string
    vm_name              = string
    platform_id          = string
    cpu                  = number
    ram                  = number
    core_fraction        = number
    disk_volume          = number
    nat                  = bool
    preemptible          = bool
    serial-port-enable   = number
  }))
  default = {
    "standart" = {
      #image_family         = "centos-7"
      image_family         = "ubuntu-2404-lts-oslogin"
      vm_name              = "kube"
      platform_id          = "standard-v3"
      cpu                  = 2
      ram                  = 2
      core_fraction        = 20
      disk_volume          = 15
      nat                  = true
      preemptible          = true
      serial-port-enable    = 1
    }

    "k8s_cp" = {  
      image_family        = "ubuntu-2404-lts-oslogin"
      vm_name             = "kube-cp"
      platform_id         = "standard-v3"
      cpu                 = 2
      ram                 = 2
      core_fraction       = 20
      disk_volume         = 15
      nat                 = true
      preemptible         = true
      serial-port-enable  = 1
    }

    "k8s_nodes" = {  
      image_family        = "ubuntu-2404-lts-oslogin"
      vm_name             = "kube-nodes"
      platform_id         = "standard-v3"
      cpu                 = 2
      ram                 = 2
      core_fraction       = 20
      disk_volume         = 15
      nat                 = true
      preemptible         = true
      serial-port-enable  = 1
    }
  }
  
}

# количество cp
variable "kube-k8s_cp_count" {
  type        = number
  default     = 1
  description = "Count of k8s cp"
}

# количество нод
variable "kube-k8s_nodes_count" {
  type        = number
  default     = 2
  description = "Count of k8s nodes"
}

# путь к приватному ключу для ansible
variable "ssh_private_key_path" {
  description = "Path to SSH private key for Ansible"
  type        = string
  sensitive   = true
}
# пароль для grafana
variable "grafana_admin_password" {
  description = "Password for Grafana admin user"
  type        = string
  sensitive   = true
}

# app   
variable "app_config" {
  type = object({
    name           = string
    namespace      = string
    replicas       = number
    image          = string
    container_port = number
    service_type   = string
    service_port   = number
    node_port      = number
    domain         = string
    resources = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    name           = "barmaq-app"
    namespace      = "app"
    replicas       = 2
    image          = "barmaq/barmaq-dapp"
    container_port = 80
    service_type   = "NodePort"
    service_port   = 80
    node_port      = 30080
    domain         = "app.barmaq.ru"
    resources = {
      requests = {
        cpu    = "100m"
        memory = "32Mi"
      }
      limits = {
        cpu    = "250m"
        memory = "64Mi"
      }
    }
  }
}
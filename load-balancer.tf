# Создание Target Group для Network Load Balancer
# использовался в тестах
# resource "yandex_lb_target_group" "app_target_group" {
#   depends_on = [yandex_compute_instance.kube-cp]
#   name = "${var.app_config.name}-target-group"
# 
#   target {
#     subnet_id  = yandex_compute_instance.kube-cp[0].network_interface.0.subnet_id
#     address    = yandex_compute_instance.kube-cp[0].network_interface.0.ip_address
#   }
# }
# 
# # Создание Network Load Balancer для приложения
# resource "yandex_lb_network_load_balancer" "app_balancer" {
#   name = "${var.app_config.name}-load-balancer"
# 
#   # HTTP listener
#   listener {
#     name = "${var.app_config.name}-http-listener"
#     port = 80
#     target_port = var.app_config.node_port
#     external_address_spec {
#       ip_version = "ipv4"
#     }
#   }
# 
#   attached_target_group {
#     target_group_id = yandex_lb_target_group.app_target_group.id
#     healthcheck {
#       name = "http"
#       http_options {
#         port = var.app_config.node_port
#         path = "/"
#       }
#     }
#   }
# }



# DNS
# вынесено в блок с создаием бакета.
# видимо лучше это вынести в блок с создаием бакета. даже с учетом долгого времени создания k8s кластера у меня не успел выпуститься сертификат.( буквально на vbyene )
# Создание DNS зоны для основного домена. указываем корневой домен!
# resource "yandex_dns_zone" "main_zone" {
#   name        = "barmaq-ru"
#   description = "DNS zone for barmaq.ru"
#   zone        = "barmaq.ru."
#   public      = true
# }

# Получаем ID DNS зоны по имени. имя указано в bucket/variables.tf
data "yandex_dns_zone" "main_zone" {
  name = "barmaq-ru"
}

# Создание A-записи для поддомена app внутри основной зоны
resource "yandex_dns_recordset" "app_record" {
  zone_id = data.yandex_dns_zone.main_zone.id
  name    = "app"
  type    = "A"
  ttl     = 200
  data    = [yandex_alb_load_balancer.app_alb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address]
}

# Создание A-записи для поддомена grafana внутри основной зоны
resource "yandex_dns_recordset" "grafana_record" {
  zone_id = data.yandex_dns_zone.main_zone.id
  name    = "grafana"
  type    = "A"
  ttl     = 200
  data    = [
    for listener in yandex_lb_network_load_balancer.grafana_balancer.listener :
    tolist(listener.external_address_spec)[0].address
    if listener.name == "grafana-http-listener"
  ][0]
}

# вынесено в предварительный этап
# Создание SSL сертификата
# resource "yandex_cm_certificate" "app_cert" {
#   name    = "${var.app_config.name}-cert"
#   domains = ["app.barmaq.ru"]

#   managed {
#     challenge_type = "DNS_CNAME"
#   }
# }

# Создание CNAME записи для подтверждения SSL сертификата
# resource "yandex_dns_recordset" "cert_validation" {
#   zone_id = yandex_dns_zone.main_zone.id
#   name    = yandex_cm_certificate.app_cert.challenges[0].dns_name
#   type    = "CNAME"
#   ttl     = 60
#   data    = [yandex_cm_certificate.app_cert.challenges[0].dns_value]
# }

# Получаем сертификат по имени
data "yandex_cm_certificate" "app_cert" {
  name = "barmaq-dapp-cert"
}

# ALB
# Создание Target Group для Application Load Balancer
resource "yandex_alb_target_group" "app_alb_target_group" {
  depends_on = [yandex_compute_instance.kube-cp]
  name       = "${var.app_config.name}-alb-target-group"

  target {
    subnet_id  = yandex_compute_instance.kube-cp[0].network_interface.0.subnet_id
    ip_address = yandex_compute_instance.kube-cp[0].network_interface.0.ip_address
  }
}

# Создание Backend Group для ALB
resource "yandex_alb_backend_group" "app_backend_group" {
  depends_on = [yandex_alb_target_group.app_alb_target_group]
  name       = "${var.app_config.name}-backend-group"

  http_backend {
    name             = "${var.app_config.name}-backend"
    weight           = 1
    port             = var.app_config.node_port
    target_group_ids = [yandex_alb_target_group.app_alb_target_group.id]
    healthcheck {
      timeout  = "10s"
      interval = "2s"
      http_healthcheck {
        path = "/"
      }
    }
  }
}

# Создание HTTP Router для ALB
resource "yandex_alb_http_router" "app_router" {
  name = "${var.app_config.name}-router"
}

# Создание Virtual Host для ALB
resource "yandex_alb_virtual_host" "app_virtual_host" {
  depends_on     = [yandex_alb_backend_group.app_backend_group]
  name           = "${var.app_config.name}-virtual-host"
  http_router_id = yandex_alb_http_router.app_router.id
  route {
    name = "app-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.app_backend_group.id
      }
    }
  }
}

# Создание Application Load Balancer для HTTPS
resource "yandex_alb_load_balancer" "app_alb" {
  depends_on = [
    yandex_alb_virtual_host.app_virtual_host
  ]
  name       = "${var.app_config.name}-alb"
  network_id = yandex_vpc_network.develop.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnet["ru-central1-a"].id
    }
  }

  listener {
    name = "https-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [443]
    }
    tls {
      default_handler {
        certificate_ids = [data.yandex_cm_certificate.app_cert.id]
        http_handler {
          http_router_id = yandex_alb_http_router.app_router.id
        }
      }
    }
  }
}

# NLB для Grafana
# Создание Target Group для Network Load Balancer
resource "yandex_lb_target_group" "grafana_target_group" {
  depends_on = [yandex_compute_instance.kube-cp]
  name       = "grafana-target-group"

  target {
    subnet_id = yandex_compute_instance.kube-cp[0].network_interface.0.subnet_id
    address   = yandex_compute_instance.kube-cp[0].network_interface.0.ip_address
  }
}

# Создание Network Load Balancer для Grafana
resource "yandex_lb_network_load_balancer" "grafana_balancer" {
  name = "grafana-load-balancer"

  # HTTP listener
  listener {
    name        = "grafana-http-listener"
    port        = 80
    target_port = 30000 # NodePort для Grafana
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.grafana_target_group.id
    healthcheck {
      name = "http"
      http_options {
        port = 30000
        path = "/api/health"
      }
    }
  }
}

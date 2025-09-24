terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.84"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = "y0__xCX*******2-D****8W--SwGS2X0*******tSKX_bW********8"
  cloud_id  = "b1ggh*******gbt4jj"
  folder_id = "b1gjqn*******g4o909dr4"
  zone      = "ru-central1-a"
}

# ---------------------------
# Service Account и роли
# ---------------------------

resource "yandex_iam_service_account" "sa" {
  name = "sa-for-terraform"
}

# Роль Storage
resource "yandex_resourcemanager_folder_iam_member" "sa-storage-admin" {
  folder_id = "b1gjq*******909dr4"
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

# Роль для работы с VPC и Compute
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = "b1gjqn*******o909dr4"
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

# Статический ключ для Object Storage
resource "yandex_iam_service_account_static_access_key" "sa-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static key for terraform object storage"
}

# ---------------------------
# Object Storage
# ---------------------------

resource "yandex_storage_bucket" "my_bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-key.secret_key

  bucket = "bodarev23092025"

  anonymous_access_flags {
    read        = true
    list        = false
    config_read = false
  }
}

resource "yandex_storage_object" "public_image" {
  access_key = yandex_iam_service_account_static_access_key.sa-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-key.secret_key

  bucket = yandex_storage_bucket.my_bucket.bucket
  key    = "picture.jpg"
  source = "picture.jpg"
  acl    = "public-read"
}

output "public_url" {
  value = "https://${yandex_storage_bucket.my_bucket.bucket}.storage.yandexcloud.net/${yandex_storage_object.public_image.key}"
}

# ---------------------------
# VPC и подсеть
# ---------------------------

resource "yandex_vpc_network" "net" {
  name = "web-net"
}

resource "yandex_vpc_gateway" "egress" {
  name = "shared-egress"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt-public" {
  network_id = yandex_vpc_network.net.id
  name       = "public-rt"

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.egress.id
  }
}

resource "yandex_vpc_subnet" "subnet_public_a" {
  name           = "subnet-public-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.10.0.0/24"]
  route_table_id = yandex_vpc_route_table.rt-public.id
}

resource "yandex_vpc_security_group" "sg_web" {
  name       = "sg-web"
  network_id = yandex_vpc_network.net.id

  ingress {
    protocol       = "TCP"
    description    = "HTTP from any"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "NLB health checks"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# Instance Group с LAMP
# ---------------------------

locals {
  image_url = "https://${yandex_storage_bucket.my_bucket.bucket}.storage.yandexcloud.net/${yandex_storage_object.public_image.key}"
  index_html = <<-EOT
    <!doctype html>
    <html lang="ru">
      <head>
        <meta charset="utf-8"/>
        <title>YC LAMP demo</title>
        <style>
          body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu; margin:2rem;}
          img{max-width:600px;height:auto;display:block;margin-top:1rem;border-radius:8px;}
          a{word-break:break-all;}
        </style>
      </head>
      <body>
        <h1>Instance Group LAMP</h1>
        <p>Image Object Storage:</p>
        <p><a href="${local.image_url}" target="_blank">${local.image_url}</a></p>
        <img src="${local.image_url}" alt="image from bucket"/>
        <p>Hostname: <?php echo gethostname(); ?></p>
      </body>
    </html>
  EOT
}

resource "yandex_compute_instance_group" "web_group" {
  name               = "web-group"
  folder_id          = "b1gjqnfsuh6g4o909dr4"
  service_account_id = yandex_iam_service_account.sa.id
  deletion_protection = false

  instance_template {
    platform_id = "standard-v1"
    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      initialize_params {
        image_id = "fd827b91d99psvq5fjit" # LAMP образ
        size     = 10
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.subnet_public_a.id]
      nat        = true
    }

    metadata = {
  user-data = <<-EOT
    #cloud-config
    runcmd:
      - rm -f /var/www/html/index.html
      - echo '<!DOCTYPE html><html><head><title>My Web Page</title></head><body><h1>Hello from Yandex.Cloud!</h1><p><a href="https://${yandex_storage_bucket.my_bucket.bucket}.storage.yandexcloud.net/${yandex_storage_object.public_image.key}" target="_blank">Link image bucket</a></p><p><img src="https://${yandex_storage_bucket.my_bucket.bucket}.storage.yandexcloud.net/${yandex_storage_object.public_image.key}" alt="My image"></p></body></html>' > /var/www/html/index.php
      - chown www-data:www-data /var/www/html/index.php
      - systemctl enable apache2
      - systemctl restart apache2
  EOT
}
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 1
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  health_check {
    http_options {
      port = 80
      path = "/"
    }
  }

  load_balancer {
    target_group_name = "web-group-targets"
  }

  depends_on = [
    yandex_storage_object.public_image
  ]
}

# ---------------------------
# Network Load Balancer
# ---------------------------

resource "yandex_lb_network_load_balancer" "nlb" {
  name = "nlb-http"

  listener {
    name = "http"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.web_group.load_balancer[0].target_group_id

    healthcheck {
      name = "hc-http"
      http_options {
        port = 80
        path = "/"
      }
      interval            = 10
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2
    }
  }

  depends_on = [yandex_compute_instance_group.web_group]
}

# ---------------------------
# Outputs
# ---------------------------

output "nlb_public_ip" {
  value = one([for l in yandex_lb_network_load_balancer.nlb.listener :
    one([for e in l.external_address_spec : e.address])
  ])
}

output "nlb_http_url" {
  value = "http://${one([for l in yandex_lb_network_load_balancer.nlb.listener :
    one([for e in l.external_address_spec : e.address])
  ])}"
}

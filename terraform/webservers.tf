terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "key.json"
  folder_id = "b1gpvlrjjtg97lrvcd2q"
}

resource "yandex_compute_instance" "ws1" {
  name = "webserver1"
  zone = "ru-central1-a"
  hostname = "ws1"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd87q4jvf0vdho41nnvr"
	  size = 5
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-3.id
	security_group_ids = [yandex_vpc_security_group.vm_group_webservers.id]
    nat       = true
	ip_address = "192.168.12.100"
  }

  metadata = {
    user-data = "${file("c:/terraform/meta.yaml")}"
  }
}

resource "yandex_compute_instance" "ws2" {
  name = "webserver2"
  zone = "ru-central1-b"
  hostname = "ws2"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd87q4jvf0vdho41nnvr"
	  size = 5
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-2.id
	security_group_ids = [yandex_vpc_security_group.vm_group_webservers.id]
    nat       = true
	ip_address = "192.168.11.100"
  }

  metadata = {
    user-data = "${file("c:/terraform/meta.yaml")}"
  }
}

resource "yandex_compute_instance" "elk1" {
  name = "elk1"
  zone = "ru-central1-a"
  hostname = "elk1"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd80jdh4pvsj48qftb3d"
	  size = 5
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-3.id
	security_group_ids = [yandex_vpc_security_group.vm_group_elk.id]
    nat       = true
	ip_address = "192.168.12.51"
  }

  metadata = {
    user-data = "${file("c:/terraform/meta.yaml")}"
  }
}

resource "yandex_compute_instance" "kib1" {
  name = "kib1"
  zone = "ru-central1-a"
  hostname = "kib1"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd80jdh4pvsj48qftb3d"
	  size = 5
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
	security_group_ids = [yandex_vpc_security_group.vm_group_kibana.id]
    nat       = true
	ip_address = "192.168.10.50"
  }

  metadata = {
    user-data = "${file("c:/terraform/meta.yaml")}"
  }
}

resource "yandex_compute_instance" "zab1" {
  name = "zab1"
  zone = "ru-central1-a"
  hostname = "zab1"

  resources {
    cores  = 2
    memory = 6
  }

  boot_disk {
    initialize_params {
      image_id = "fd80eup4e4h7mmodr9d4"
	  size = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
	security_group_ids = [yandex_vpc_security_group.vm_group_zabbix.id]
    nat       = true
	ip_address = "192.168.10.55"
  }

  metadata = {
    user-data = "${file("c:/terraform/meta.yaml")}"
  }
  connection {
    type        = "ssh"
    user        = "artem"
    private_key = "${file("mysshkey.key")}"
    host        = "${ yandex_compute_instance.bast1.network_interface.0.nat_ip_address }"
  }
  
  provisioner "file" {
    source      = "conf/installzabbix.sh"
    destination = "/home/artem/installzabbix.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
	  "sudo chmod +x /home/artem/installzabbix.sh",
	  "/home/artem/installzabbix.sh"
	  ]
  }
}

resource "yandex_compute_instance" "bast1" {
  name = "bast1"
  zone = "ru-central1-a"
  hostname = "bast1"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd80eup4e4h7mmodr9d4"
	  size = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
	security_group_ids = [yandex_vpc_security_group.vm_group_bastion.id]
    nat       = true
	ip_address = "192.168.10.10"
  }

  metadata = {
    user-data = "${file("c:/terraform/meta.yaml")}"
  }
  connection {
    type        = "ssh"
    user        = "artem"
    private_key = "${file("mysshkey.key")}"
    host        = "${ yandex_compute_instance.bast1.network_interface.0.nat_ip_address }"
  }
  
  provisioner "file" {
    source      = "mysshkey.key"
    destination = "/home/artem/.ssh/mysshkey.key"
  }
  
  provisioner "file" {
    source      = "conf/ansible.cfg"
    destination = "/home/artem/ansible.cfg"
  }
  
  provisioner "file" {
    source      = "conf/config"
    destination = "/home/artem/.ssh/config"
  }
  
    connection {
    type        = "ssh"
    user        = "artem"
    private_key = "${file("mysshkey.key")}"
    host        = "${ yandex_compute_instance.bast1.network_interface.0.nat_ip_address }"
  }
  
  provisioner "file" {
    source      = "conf/installzabbix.sh"
    destination = "/home/artem/play-all.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
	  "sudo chmod +x /home/artem/play-all.sh"
	  ]
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y git gnupg2 wget python3 python3-pip mc",
	  "sudo pip install ansible",
	  "sudo apt install sshpass -y",
	  "git clone https://github.com/artem-senkov/cloudproject.git",
	  "sudo chmod 600 ~/.ssh/mysshkey.key",
	  "export ANSIBLE_HOST_KEY_CHECKING=False",
	  "sudo mv /home/artem/ansible.cfg /etc/ansible.cfg"
	  ]
  }
}

resource "yandex_alb_target_group" "foo" {
  name           = "webservers"

  target {
    subnet_id    = yandex_vpc_subnet.subnet-3.id
    ip_address   = yandex_compute_instance.ws1.network_interface.0.ip_address
  }

  target {
    subnet_id    = yandex_vpc_subnet.subnet-2.id
    ip_address   = yandex_compute_instance.ws2.network_interface.0.ip_address
  }

}

resource "yandex_alb_backend_group" "webservers-backend-group" {
  name                     = "webserversbackend"
  session_affinity {
    connection {
      source_ip = true
    }
  }

  http_backend {
    name                   = "webserversbackend"
    weight                 = 1
    port                   = 80
    target_group_ids       = [yandex_alb_target_group.foo.id]
    load_balancing_config {
      panic_threshold      = 90
    }    
    healthcheck {
      timeout              = "10s"
      interval             = "2s"
      healthy_threshold    = 10
      unhealthy_threshold  = 15 
      http_healthcheck {
        path               = "/"
      }
    }
  } 
}

resource "yandex_alb_http_router" "http-router" {
  name          = "http-router"
  labels        = {
    http-label    = "http-label-value"
    empty-label = ""
  }
}

resource "yandex_alb_virtual_host" "http-virtual-host" {
  name                    = "http-router-vh"
  http_router_id          = yandex_alb_http_router.http-router.id
  route {
    name                  = "way2backend"
    http_route {
      http_route_action {
        backend_group_id  = yandex_alb_backend_group.webservers-backend-group.id
        timeout           = "60s"
      }
    }
  }
}    

# L7 балансировщик https://cloud.yandex.ru/docs/application-load-balancer/operations/application-load-balancer-create

resource "yandex_alb_load_balancer" "load-balancer" {
  name        = "load-balancer"
  network_id  = yandex_vpc_network.network-1.id
  security_group_ids = []

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnet-1.id
    }
  }

  listener {
    name = "httplistener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.http-router.id
      }
    }
  }

#  log_options {
#    log_group_id = "<идентификатор_лог-группы>"
#    discard_rule {
#      http_codes          = ["<HTTP-код>"]
#      http_code_intervals = ["<класс_HTTP-кодов>"]
#      grpc_codes          = ["<gRPC-код>"]
#      discard_percent     = <доля_отбрасываемых_логов>
#    }
#  }
}

output "internal_ip_address_ws1" {
  value = yandex_compute_instance.ws1.network_interface.0.ip_address
}

output "internal_ip_address_ws2" {
  value = yandex_compute_instance.ws2.network_interface.0.ip_address
}

output "internal_ip_address_elk1" {
  value = yandex_compute_instance.elk1.network_interface.0.ip_address
}

output "internal_ip_address_kib1" {
  value = yandex_compute_instance.kib1.network_interface.0.ip_address
}

output "internal_ip_address_zab1" {
  value = yandex_compute_instance.zab1.network_interface.0.ip_address
}

output "internal_ip_address_bast1" {
  value = yandex_compute_instance.bast1.network_interface.0.ip_address
}

output "external_ip_address_ws1" {
  value = yandex_compute_instance.ws1.network_interface.0.nat_ip_address
}

output "external_ip_address_ws2" {
  value = yandex_compute_instance.ws2.network_interface.0.nat_ip_address
}

output "external_ip_address_elk1" {
  value = yandex_compute_instance.elk1.network_interface.0.nat_ip_address
}

output "external_ip_address_kib1" {
  value = yandex_compute_instance.kib1.network_interface.0.nat_ip_address
}

output "external_ip_address_zab1" {
  value = yandex_compute_instance.zab1.network_interface.0.nat_ip_address
}

output "external_ip_address_bast1" {
  value = yandex_compute_instance.bast1.network_interface.0.nat_ip_address
}

output "external_ip_address_load-balancer" {
  value = yandex_alb_load_balancer.load-balancer.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
}
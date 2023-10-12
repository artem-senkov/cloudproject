resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet2"
  zone = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.11.0/24"]
}

resource "yandex_vpc_subnet" "subnet-3" {
  name           = "subnet3"
  zone = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.12.0/24"]
}



# security group for webservers TCP  80, 443
resource yandex_vpc_security_group vm_group_webservers {
  name        = "vm_group_webservers"
  description = "vm_group_webservers"
  network_id  = "${yandex_vpc_network.network-1.id}"
  labels = {
    my-label = "webservers"
  }

  ingress {
    description    = "Allow HTTP protocol from local subnets"
    protocol       = "TCP"
    port           = "80"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]
  }

  ingress {
    description    = "Allow HTTPS protocol from local subnets"
    protocol       = "TCP"
    port           = "443"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]
  }

  ingress {
    description = "Health checks from NLB"
    protocol = "TCP"
    predefined_target = "loadbalancer_healthchecks" 
  }

  ingress {
    description = "SSH from BAST1"
    protocol       = "TCP"
    port           = "22"
	security_group_id = yandex_vpc_security_group.vm_group_bastion.id
  }
  
  ingress {
    description    = "Allow TCP protocol ZABBIX ports from local groups"
    protocol       = "TCP"
    from_port      = "10050"
    to_port        = "10053"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


# security group for lasticsearch, Logstash TCP 9200, 5044

resource yandex_vpc_security_group vm_group_elk {
  name        = "vm_group_elk"
  description = "vm_group_elk"
  network_id  = "${yandex_vpc_network.network-1.id}"
  labels = {
    my-label = "elk"
  }
  
  ingress {
    description    = "Allow HTTP protocol from local subnets"
    protocol       = "TCP"
    port           = "9200"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]
  }

  ingress {
    description    = "Allow HTTPS protocol from local subnets"
    protocol       = "TCP"
    port           = "5044"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]
  }

  ingress {
    description = "SSH from BAST1"
    protocol       = "TCP"
    port           = "22"
    security_group_id = yandex_vpc_security_group.vm_group_bastion.id
  }

  ingress {
    description    = "Allow TCP protocol ZABBIX ports from local groups"
    protocol       = "TCP"
    from_port      = "10050"
    to_port        = "10053"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# security group for Kibana TCP  5601
resource yandex_vpc_security_group vm_group_kibana {
  name        = "vm_group_kibana"
  description = "vm_group_kibana"
  network_id  = "${yandex_vpc_network.network-1.id}"
  labels = {
    my-label = "kibana"
  }
  
  ingress {
    description    = "Allow HTTP protocol from any"
    protocol       = "TCP"
    port           = "5601"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow TCP protocol ZABBIX ports from local groups"
    protocol       = "TCP"
    from_port      = "10050"
    to_port        = "10053"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]
  }

  ingress {
    description = "SSH from BAST1"
    protocol       = "TCP"
    port           = "22"
    security_group_id = yandex_vpc_security_group.vm_group_bastion.id
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# security group for Zabbix TCP  8080, 1050, 1051, 1052,  1053, 80, 443
resource yandex_vpc_security_group vm_group_zabbix {
  name        = "vm_group_zabbix"
  description = "vm_group_zabbix"
  network_id  = "${yandex_vpc_network.network-1.id}"
  labels = {
    my-label = "zabbix"
  }
  
  ingress {
    description    = "Allow HTTP protocol from any"
    protocol       = "TCP"
    port           = "80"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTP protocol from any"
    protocol       = "TCP"
    port           = "8080"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTPS protocol from any"
    protocol       = "TCP"
    port           = "443"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow TCP protocol from local groups"
    protocol       = "TCP"
    from_port      = "10050"
    to_port        = "10053"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]
  }

  ingress {
    description = "SSH from BAST1"
    protocol       = "TCP"
    port           = "22"
    security_group_id = yandex_vpc_security_group.vm_group_bastion.id
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# security group for bastion
resource yandex_vpc_security_group vm_group_bastion {
  name        = "vm_group_bastion"
  description = "vm_group_bastion"
  network_id  = "${yandex_vpc_network.network-1.id}"
  labels = {
    my-label = "bastion"
  }
  
  ingress {
    description = "SSH"
    protocol       = "TCP"
    port           = "22"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
# Дипломный проект NETOLOGY system administrator Артем Сеньков 

Решаем задачу поставленную в дипломном проекте


[Дипломное задание](https://github.com/netology-code/sys-diplom/blob/diplom-zabbix/README.md)

### Создаю инфраструктуру с помощью TERRAFORM 

[Сеть и группы безопасности networks.tf](https://github.com/artem-senkov/cloudproject/blob/main/terraform/networks.tf)


[Основной файл webserver.tf](https://github.com/artem-senkov/cloudproject/blob/main/terraform/webserver.tf)

Для авторизации на облаке сгенерировал токен key.json

На вирт машины заливается ключ доступа и создается пользователь с помощью файла meta.yaml

```yaml
#cloud-config
users:
  - name: artem
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:

```
На бастион автоматом ставлю ansible и заливаю ключ, конфиги и репозиторий проекта

```yaml
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
```

применяю terraform apply

![terraform apply](https://github.com/artem-senkov/cloudproject/blob/main/img/tfapply01.png)

На выходе получаем ip адреса виртуальных машин и load balancer

#### Установка ПО через ANSIBLE 

**В проекте использованы роли с просторов интернета, практически все не заработали сходу, адаптированы и скомбинированы под задачу** 

Редактирую host на машине bast1 с ansible
```
[webservers]
ws1 ansible_ssh_host=192.168.12.21
ws2 ansible_ssh_host=192.168.11.8

[elk]
elk1 ansible_ssh_host=192.168.12.30
kib1 ansible_ssh_host=192.168.10.29

[other]
zab1 ansible_ssh_host=192.168.10.16
bast1  ansible_ssh_host=192.168.10.6

[all:vars]
ansible_ssh_private_key_file=~/.ssh/mysshkey.key
ansible_user=artem
```
Приватный ключ в файле/.ssh/mysshkey.key


Для развертования ПО подготовил следующие роли:

1. firewall and fail2ban 
Заметил по журналу что на машины сразу ломяться недруги и пытаются подобрать пароль, принимаю меры

[fail2ban role](https://github.com/artem-senkov/cloudproject/tree/main/fail2ban/roles/fail2ban)

```yaml
---
#
# Playbook to install fail2ban
#
- hosts: webservers, bast1, zab1 ,kib1, elk1
  become: yes
  become_user: root
  roles:
  - { role: ufw }
  - { role: fail2ban }
```

Запускаю роль

ansible-playbook -v -i ~/cloudproject/hosts  ~/cloudproject/fail2ban/fail2ban.yml

![fail2ban apply](https://github.com/artem-senkov/cloudproject/blob/main/img/fail2ban.png)

На виртмашинах где нужно открыть доп порты дрбавляю в роли открытие порта 

1. Zabbix TCP  8080, 1050, 1051, 1052,  1053, 80, 443
2. Kibana TCP  5601
3. ApacheTCP  80, 443
4. Elasticsearch, Logstash 9200, 5044
   
```yaml
    - name: "UFW - Allow HTTP on port {{ http_port }}"
      ufw:
        rule: allow
        port: "{{ http_port }}"
        proto: tcp
      tags: [ system ]
```
я сделал для разных типов серверов разные roles ufw-kibana, ufw-zabbix итд с доп портами для открытия.


2. webservers установка Apache Mysql PHP и wordpress
Решил усложнить задание установкой MYSQL, PHP и CMS Wordpress, на будущее пригодиться такой вариант для моего сайта

 [Ссылка на роль по установке web сервера](https://github.com/artem-senkov/cloudproject/tree/main/wplamp)

Переменные роли в файле /vars/default.yml
```
---
#System Settings
php_modules: [ 'php-curl', 'php-gd', 'php-mbstring', 'php-xml', 'php-xmlrpc', 'php-soap', 'php-intl', 'php-zip' ]

#MySQL Settings
mysql_root_password: "password"
mysql_db: "wordpressDB1"
mysql_user: "mysqluser"
mysql_password: "password"

#HTTP Settings
http_host: "itadmin.spb.ru"
http_conf: "itadmin.spb.ru.conf"
http_port: "80"
ssh_port: "22"
```
Запускаю роль на группу webservers
ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/wplamp/playbook.yml

![lamp apply](https://github.com/artem-senkov/cloudproject/blob/main/img/lamp.png)

Захожу на web сервера через IP loadbalancer

![LAMP installed](https://github.com/artem-senkov/cloudproject/blob/main/img/lampresult.png)

3. Установка Elasticsearch Kibana Filebeats
   
   C этип процессом возникли самые большие проблемы. Официальные репозитории не доступны из yandex cloud, плэйбуки не устанавливаются. Первым решением было установить из стороннего репозитория по прекрасной статье [https://serveradmin.ru/ustanovka-i-nastroyka-elasticsearch-logstash-kibana-elk-stack/](https://serveradmin.ru/ustanovka-i-nastroyka-elasticsearch-logstash-kibana-elk-stack/) Прописал в плэйбуки установку репозитория, ключа все взлетело, но возникли сложности с сертификатами для подключения filebeats и kibana к elasticsearch. В итоге принял решение переделать на установку deb пакетов из доступных ресурсов для 7 версии и задача была успешно решена.

Kibana ставиться на отдельный сервер с внешним IP

[Ссылка на роли по установке ELK](https://github.com/artem-senkov/cloudproject/tree/main/elk)

Переменные для подстановки в конф. файлы находяться в /group_vars/all
```
---
# servers IP
kibanaserver_ip: 192.168.10.30
elkserver_ip: 192.168.10.28
```

Конфиг filebeat настроен на передачу логов apache и fail2ban в elastisearch
```
filebeat.inputs:
- type: log
  enabled: true
  paths:
      -  /var/log/apache2/access.log
  fields:
    type: nginx_access
  fields_under_root: true
  scan_frequency: 5s

- type: log
  enabled: true
  paths:
      - /var/log/apache2/error.log
  fields:
    type: apache_error
  fields_under_root: true
  scan_frequency: 5s

- type: log
  enabled: true
  paths:
      - /var/log/fail2ban.log
  fields:
    type: fail2ban
  fields_under_root: true
  scan_frequency: 5s

output.elasticsearch:
  hosts: ["{{ elkserver_ip  }}:9200"]
```
Устанавливаю ELASTICSEARCH

ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/elk/el.yml


Устанавливаю KIBANA


ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/elk/kib7.yml


Устанавливаю FILEBEAT на webservers


ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/elk/filebeat-web.yml


Проверяю статус ELASTICSEARCH http://84.201.129.219:9200/_cluster/health?pretty
![ELK status](https://github.com/artem-senkov/cloudproject/blob/main/img/elstatus.png)

Захожу на kibana ip http://158.160.47.220:5601/ настраиваю индекс и вижу данные с webservers
![KIBANA status](https://github.com/artem-senkov/cloudproject/blob/main/img/kib1.png)
![KIBANA status](https://github.com/artem-senkov/cloudproject/blob/main/img/kib2.png)
![KIBANA status](https://github.com/artem-senkov/cloudproject/blob/main/img/kib3.png)


4. Установка ZABBIX 6.4 на сервер

Ставлю POSTGRESQL
```
sudo apt -y install gnupg
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt update
sudo apt -y install postgresql
```

Далее по инструкции
https://www.zabbix.com/download?zabbix=6.4&os_distribution=debian&os_version=11&components=server_frontend_agent&db=pgsql&ws=nginx

![ZABBIX status](https://github.com/artem-senkov/cloudproject/blob/main/img/zab1.png)

5. Группы безопасности

(https://cloud.yandex.ru/docs/vpc/concepts/security-groups)

Открываем только следующие порты для своих подсетей
1. Zabbix TCP  8080, 1050, 1051, 1052,  1053, 80, 443
2. Kibana TCP  5601
3. Apache TCP  80, 443
4. Elasticsearch, Logstash TCP 9200, 5044

```yaml
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
    from_port      = "1050"
    to_port        = "1053"
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
```


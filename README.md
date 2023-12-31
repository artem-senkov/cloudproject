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

~~Редактирую host на машине bast1 с ansible~~ Назначил вручную IP адреса, редактировать hosts не требуется
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

Проверяю доступность хостов

ansible all -i ~/cloudproject/hosts -m ping


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

1. Zabbix TCP  8080, 10050, 10051, 10052,  10053, 80, 443
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

Ставлю POSTGRESQL через скрипт для автоматизированой установки после поднятия виртуалки

копирование скрипта на виртуалку и запуск
```
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
```

скрипт
```
#!/bin/sh
# -------------------------------------------------
# Add repos and install postgres15
# -------------------------------------------------
sudo apt -y install gnupg
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt update
sudo apt -y install postgresql-15
# -------------------------------------------------
# Add repos and install zabbix
# -------------------------------------------------
sudo wget https://repo.zabbix.com/zabbix/6.4/debian/pool/main/z/zabbix-release/zabbix-release_6.4-1+debian11_all.deb
sudo dpkg -i zabbix-release_6.4-1+debian11_all.deb
sudo apt update
sudo apt -y install zabbix-server-pgsql zabbix-frontend-php php7.4-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent
sudo -u postgres psql -c "CREATE USER zabbix WITH PASSWORD 'zabbixDBpassword';"
#sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix
sudo zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix
# -------------------------------------------------
# Edit file /etc/zabbix/zabbix_server.conf DBPassword=password
# Edit file /etc/zabbix/nginx.conf uncomment and set 'listen' and 'server_name' directives.
# -------------------------------------------------
sudo sed -i 's/# DBPassword=/DBPassword=zabbixDBpassword/g' /etc/zabbix/zabbix_server.conf
sudo sed -i 's/#        listen          8080;/        listen          8080;/g' /etc/zabbix/nginx.conf
sudo sed -i 's/#        server_name     example.com;/        server_name     myzabbix.net;/g' /etc/zabbix/nginx.conf
```

https://www.zabbix.com/documentation/current/en/manual/installation/requirements#default-port-numbers

5. Zabbix agent

Использую роль для установки: https://github.com/zabbix/ansible-collection/blob/main/roles/zabbix_agent/README.md

ansible-galaxy collection install zabbix.zabbix

файл для установки на серверы zabbix-agent.yml

```yaml
- hosts: all
  roles:
    - role: zabbix.zabbix.zabbix_agent
      run_host_tasks: True                             # enable Zabbix API host tasks;
      ### Zabbix API properties
      zabbix_api_host: 192.168.10.38                   # Zabbix frontend server;
      zabbix_api_port: 80                             # Zabbix fronted connection port;
      zabbix_api_user: Admin                           # Zabbix user name for API connection;
      zabbix_api_password: zabbix                      # Zabbix user password for API connection;
      zabbix_api_use_ssl: False                         # Use secure connection;
      ### Zabbix host configuration
      zabbix_host_templates: ["Linux by Zabbix agent"]  # Assign list of templates to the host;
      ### Zabbix agent configuration
      param_server: 192.168.10.38                     # address of Zabbix server to accept connections from;
      firewall_allow_from: 192.168.10.38              # address of Zabbix server to allow connections from using firewalld;
```
ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/zabbix-agent.yml

![ZABBIX hosts](https://github.com/artem-senkov/cloudproject/blob/main/img/zab1.png)

Настроил дашборд для мониторинга основных показателей и доступности webservers
![ZABBIX dashboard](https://github.com/artem-senkov/cloudproject/blob/main/img/zabbix_dash1.png)

Скрипт для запуска ролей после развертывания инфраструктуры, прописал запуск в terraform

копирование скрипта на виртуалку и запуск
```yaml
    connection {
    type        = "ssh"
    user        = "artem"
    private_key = "${file("mysshkey.key")}"
    host        = "${ yandex_compute_instance.bast1.network_interface.0.nat_ip_address }"
  }
  
  provisioner "file" {
    source      = "conf/play-all.sh"
    destination = "/home/artem/play-all.sh"
  }

  provisioner "remote-exec" {
    inline = [
	  "sudo chmod +x /home/artem/play-all.sh"
	  ]
  }
```
скрипт ansible playbooks
```bash
#!/bin/sh
# -------------------------------------------------
# Play all ansible playbooks
# -------------------------------------------------
ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/fail2ban/fail2ban.yml > ~/fail2ban.log
ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/wplamp/playbook.yml > ~/wplamp.log
ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/elk/el.yml > ~/el.log
ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/elk/kib7.yml > ~/kib7.log
ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/elk/filebeat-web.yml > ~/filebeat-web.log
ansible-galaxy collection install zabbix.zabbix > ~/filebeat-web.log > ~/zabbix-agent.log
ansible-playbook -v -i ~/cloudproject/hosts ~/cloudproject/zabbix-agent.yml > ~/zabbix-agent.log
```


6. Группы безопасности

(https://cloud.yandex.ru/docs/vpc/concepts/security-groups)

Открываем только следующие порты для своих подсетей
1. Zabbix TCP  8080, 10050, 10051, 10052,  10053, 80, 443
2. Kibana TCP  5601
3. Apache TCP  80, 443
4. Elasticsearch, Logstash TCP 9200, 5044

```yaml
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

  ingress {
    description    = "Allow TCP protocol from local groups"
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
```
7. Резервное копирование
В yandex cloud console создал политику и применил к дискам ВМ
![Backup settings](https://github.com/artem-senkov/cloudproject/blob/main/img/backup1.png)

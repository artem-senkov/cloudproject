# Дипломный проект NETOLOGY system administrator Артем Сеньков 

Решаем задачу поставленную в дипломном проекте


[Дипломное задание](https://github.com/netology-code/sys-diplom/blob/diplom-zabbix/README.md)

### Создаю инфраструктуру с помощью TERRAFORM 

https://github.com/artem-senkov/cloudproject/blob/main/terraform/webserver.tf

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

применяю terraform apply

![terraform apply](https://github.com/artem-senkov/cloudproject/blob/main/img/tfapply01.png)

На выходе получаем ip адреса виртуальных машин и load balancer

#### Установка ПО через ANSIBLE 

**В проекте использованы роли с просторов интернета, практически все не заработали с ходу, адаптированы и скомбинированы под задачу** 

Редактирую host на машине с ansible
```
[webservers]
ws1 ansible_ssh_host=158.160.110.182
ws2 ansible_ssh_host=158.160.79.117

[elk]
elk1 ansible_ssh_host=158.160.116.86
kib1 ansible_ssh_host=158.160.124.98

[other]
zab1 ansible_ssh_host=158.160.97.122
bast1  ansible_ssh_host=158.160.125.178

[all:vars]
ansible_ssh_private_key_file=~/.ssh/mysshkey
ansible_user=artem
```
Приватный ключ в файле/.ssh/mysshkey


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

ansible-playbook -v -i ~/ansible/hosts ~/cloudproject/fail2ban/fail2ban.yml

![fail2ban apply](https://github.com/artem-senkov/cloudproject/blob/main/img/fail2ban.png)

На виртмашинах где нужно открыть доп порты дрбавляю в роли открытие порта 

1. Zabbix TCP  80, 1050, 1051, 1052,  1053, 80, 443
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
ansible-playbook -v -i ~/ansible/hosts ~/cloudproject/wplamp/playbook.yml

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


ansible-playbook -v -i ~/ansible/hosts ~/cloudproject/elk/el.yml


Устанавливаю KIBANA


ansible-playbook -v -i ~/ansible/hosts ~/cloudproject/elk/kib7.yml


Устанавливаю FILEBEAT на webservers


ansible-playbook -v -i ~/ansible/hosts ~/cloudproject/elk/filebeat-web.yml


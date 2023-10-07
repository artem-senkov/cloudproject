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

Для развертования ПО подготовил следующие роли

#### 1. firewall and fail2ban 
Заметил по журналу что на машины сразу ломяться и пытаются подобрать пароль, принимаю меры

[](https://github.com/artem-senkov/cloudproject/tree/main/fail2ban/roles/fail2ban)



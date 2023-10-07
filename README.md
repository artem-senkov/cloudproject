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
Заметил по журналу что на машины сразу ломяться и пытаются подобрать пароль, принимаю меры

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

![fail2ban apply](https://github.com/artem-senkov/cloudproject/blob/main/img/fail2ban01.png)




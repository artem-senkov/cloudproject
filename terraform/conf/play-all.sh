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


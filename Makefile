.PHONY: up status provision ping destroy reload sync-keys registry-test registry-smoke app-test sherlock-test observability monitoring-status monitoring-logs jenkins-url jenkins-logs jenkins-status jenkins-restore rollback image-tags deployed-images discord-test security-check ssh-negative-test

up:
	vagrant up --no-parallel

status:
	vagrant status

sync-keys:
	./scripts/sync-vagrant-keys.sh

ping:
	ansible all -i ansible/inventory.ini -m ping

provision:
	./scripts/provision.sh

observability:
	ansible-playbook -i ansible/inventory.ini ansible/observability.yml -e ansible_user=devops

reload:
	vagrant reload

destroy:
	vagrant destroy -f

registry-test:
	curl -fsS http://192.168.56.14:5000/v2/_catalog

registry-smoke:
	ansible cicd -i ansible/inventory.ini -m shell -a "docker pull busybox:latest && docker tag busybox:latest 192.168.56.14:5000/test-busybox:latest && docker push 192.168.56.14:5000/test-busybox:latest"
	ansible app -i ansible/inventory.ini -m shell -a "docker pull 192.168.56.14:5000/test-busybox:latest"
	curl -fsS http://192.168.56.14:5000/v2/_catalog

app-test:
	./scripts/healthcheck.sh

sherlock-test:
	./scripts/smoke-test-sherlock.sh

monitoring-status:
	ansible monitoring -i ansible/inventory.ini -m shell -a "cd /opt/sherlock-logs && docker compose ps"

monitoring-logs:
	ansible monitoring -i ansible/inventory.ini -m shell -a "cd /opt/sherlock-logs && docker compose logs --tail=100"

jenkins-url:
	@echo "Jenkins: http://192.168.56.14:8080"
	@echo "Login: admin"
	@echo "Password: admin"

jenkins-logs:
	ansible cicd -i ansible/inventory.ini -m shell -a "docker logs --tail=100 automation-jenkins"

jenkins-status:
	ansible cicd -i ansible/inventory.ini -m shell -a "docker ps --filter name=automation-jenkins"

jenkins-restore:
	ansible-playbook -i ansible/inventory.ini ansible/site.yml -e ansible_user=devops --start-at-task "Copy Jenkins Configuration as Code file"

image-tags:
	curl -fsS http://192.168.56.14:5000/v2/automation-backend/tags/list
	@echo
	curl -fsS http://192.168.56.14:5000/v2/automation-frontend/tags/list
	@echo

deployed-images:
	ansible app -i ansible/inventory.ini -m shell -a "{% raw %}docker ps --filter name=automation-backend --format '{{.Names}} {{.Image}} {{.Status}}'{% endraw %}"
	ansible web -i ansible/inventory.ini -m shell -a "{% raw %}docker ps --filter name=automation-frontend --format '{{.Names}} {{.Image}} {{.Status}}'{% endraw %}"

rollback:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make rollback VERSION=<tag>"; exit 1; fi
	ansible-playbook -i ansible/inventory.ini ansible/rollback.yml -e image_tag=$(VERSION)
	$(MAKE) app-test

security-check:
	ansible all -i ansible/inventory.ini -m shell -a "grep devops /etc/passwd && groups devops && umask"
	ansible all -i ansible/inventory.ini -m shell -a "sudo -l -U devops" --become

ssh-negative-test:
	@echo "Testing blocked root login..."
	-ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@192.168.56.10 true
	@echo "Testing blocked random user login..."
	-ssh -o BatchMode=yes -o StrictHostKeyChecking=no linus_torvalds@192.168.56.10 true
	@echo "Testing blocked vagrant login after hardening..."
	-ssh -o BatchMode=yes -o StrictHostKeyChecking=no vagrant@192.168.56.10 true

discord-test:
	./scripts/notify-discord.sh "Automation Alchemy Discord notification test"

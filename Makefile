# --- Variables ---
CLUSTER_NAME=mycluster
IMAGE_NAME=custom-nginx
TAG=v1
NAMESPACE=demo-space
DEPLOYMENT=nginx-deployment

# --- Commandes principales ---

setup: install-tools all

# La commande par défaut (lance tout sauf la création du cluster)
all: init-cluster build import deploy check

#installation des dépendances !
install-tools:
	@echo "🔧 [0/5] Installation des dépendances système..."
	# Installation des paquets apt
	sudo rm -f /etc/apt/sources.list.d/yarn.list
	curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
	sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" -y
	sudo apt-get update
	sudo apt-get install -y packer ansible python3-pip curl python3-kubernetes
	# Installation K3d
	@if ! command -v k3d >/dev/null; then curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; fi

build:
	@echo "Build de l'image Packer..."
	packer init image.pkr.hcl
	packer build image.pkr.hcl

# 2. Crée le cluster (ignore l'erreur s'il existe déjà)
init-cluster:
	@echo "Loading  du cluster K3d..."
	k3d cluster create $(CLUSTER_NAME) -p "8080:80@loadbalancer" || echo "Le cluster existe déjà, on continue."

# 3. Importe l'image dans K3d
import:
	@echo "Import de l'image dans K3d..."
	k3d image import $(IMAGE_NAME):$(TAG) -c $(CLUSTER_NAME)

# 4. Déploie via Ansible
deploy:
	@echo "deploy via Ansible..."
	ansible-playbook playbook.yml

# 5. COMMANDE MAGIQUE : Met à jour l'appli après modification du HTML
update: build import
	@echo "🔄 Mise à jour des Pods..."
	kubectl rollout restart deployment $(DEPLOYMENT) -n $(NAMESPACE)
	@echo "✅ Mise à jour terminée ! Testez avec : curl localhost:8080"

# 6. Vérification rapide
check:
	@echo "Vérification des pods..."
	kubectl get pods -n $(NAMESPACE)
	@echo "Test de l'URL..."
	curl -I localhost:8080

# 7. Nettoyage complet
clean:
	@echo "Suppression du cluster..."
	k3d cluster delete $(CLUSTER_NAME)
	@echo "Suppression de l'image Docker locale..."
	docker rmi $(IMAGE_NAME):$(TAG) -f || true

.PHONY: all build init-cluster import deploy update check clean

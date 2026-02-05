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
	# Correction de la clé Yarn (souvent bloquante sur Codespaces)
	curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - || true
	# Ajout repo Hashicorp (Packer)
	curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
	sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" -y
	# Installation des paquets apt
	sudo apt-get update
	sudo apt-get install -y packer ansible python3-pip curl
	# Installation lib Python K8s (nécessaire pour Ansible)
	sudo pip3 install kubernetes openshift --break-system-packages
	# Installation K3d
	@if ! command -v k3d >/dev/null; then curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; fi
	# Installation Kubectl
	@if ! command -v kubectl >/dev/null; then \
		curl -LO "https://dl.k8s.io/release/$(shell curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
		sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; \
		rm kubectl; \
	fi

# 1. Construit l'image avec Packer
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

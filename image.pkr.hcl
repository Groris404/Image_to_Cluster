packer {
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "nginx" {
  image  = "nginx:alpine"
  commit = true
  changes = [
    "EXPOSE 80",
    "CMD [\"nginx\", \"-g\", \"daemon off;\"]"
  ]
}

build {
  name = "learn-packer"
  sources = [
    "source.docker.nginx"
  ]

  # Copie du fichier index.html dans le conteneur
  provisioner "file" {
    source      = "index.html"
    destination = "/usr/share/nginx/html/index.html"
  }
  
  # Tag final de l'image
  post-processors {
    post-processor "docker-tag" {
      repository = "custom-nginx"
      tag        = ["v1"]
    }
  }
}

terraform {
  # Версия terraform
  required_version = " ~>0.12.8"
}

provider "google" {
  # Версия провайдера
  version = "2.15"

  # ID проекта
  project = var.project

  region = var.region
}

/*resource "google_compute_project_metadata_item" "project_ssh" {
  key     = "ssh-keys"
  value   = "appuser1:${file(var.public_key_path)}"
}*/

resource "google_compute_project_metadata" "project_ssh_users" {
  metadata = {
  	"ssh-keys"   = "gcp:${file(var.public_key_path)}"
  }
}

resource "google_compute_instance" "app" {
  count = var.instance_count
  name         = "reddit-app-${count.index}"
  machine_type = "g1-small"
  zone         = var.gcp_zone
  tags         = ["reddit-app"]
  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }

  metadata = {
    # путь до публичного ключа
    ssh-keys = "gcp:${file(var.public_key_path)}"
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
  }

  # Provisioners connection
  connection {
    type  = "ssh"
    host  = self.network_interface[0].access_config[0].nat_ip
    user  = "gcp"
    agent = false
    # путь до приватного ключа
    private_key = file(var.provisioner_ssh_key)
  }

  # Provisioners
  provisioner "file" {
    source      = "files/puma.service"
    destination = "/tmp/puma.service"
  }

  provisioner "remote-exec" {
    script = "files/deploy.sh"
  }

}

resource "google_compute_firewall" "firewall_puma" {
  name = "allow-puma-default"
  # Название сети, в которой действует правило
  network = "default"
  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }
  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]
  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["reddit-app"]
}

resource "google_compute_firewall" "firewall_ssh" {
  name = "default-allow-ssh"
  network = "default"
  description = "Default allow ssh connections"

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip"
}

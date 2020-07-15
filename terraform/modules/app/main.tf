resource "google_compute_instance" "app" {
  name         = "reddit-app"
  machine_type = "g1-small"
  zone         = var.gcp_zone
  tags         = ["reddit-app"]
  boot_disk {
    initialize_params { image = var.app_disk_image }
  }
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
  }
  metadata = {
    ssh-keys = "gcp:${file(var.public_key_path)}"
  }
}

resource "null_resource" "app" {

  count = var.enable_provisioners ? 1 : 0

  triggers = {
    cluster_instance_ids = "${join(",", google_compute_instance.app.*.id)}"
  }

  # Provisioners connection
  connection {
    type  = "ssh"
    host  = google_compute_instance.app.network_interface[0].access_config[0].nat_ip
    user  = "gcp"
    agent = false
    # путь до приватного ключа
    private_key = file(var.provisioner_ssh_key)
  }
  # Provisioners
  provisioner "file" {
    source      = "${path.module}/files/puma.service"
    destination = "/tmp/puma.service"
  }

  provisioner "remote-exec" {
    inline = [
      "echo export DATABASE_URL=${var.db_url} >> ~/.profile",
      ". ~/.profile",
    ]
  }

  provisioner "remote-exec" {
    script = "${path.module}/files/deploy.sh"
  }
}

resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip"
}

resource "google_compute_firewall" "firewall_puma" {
  name    = "allow-puma-default"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["9292", "80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["reddit-app"]
}

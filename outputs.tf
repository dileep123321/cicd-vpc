output "private_vm_ip" {
  value = google_compute_instance.private_vm.network_interface[0].network_ip
}


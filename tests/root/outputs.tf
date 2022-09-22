output "pet_name" {
  value = random_pet.name
}

output "cert_pem" {
  value = resource.tls_self_signed_cert.example.cert_pem
}
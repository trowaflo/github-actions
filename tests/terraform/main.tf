terraform {
  required_version = ">= 1.0"
}

output "hello" {
  value       = "Hello, World!"
  description = "A friendly greeting"
}

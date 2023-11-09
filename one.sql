data "external" "import_role" {
  program = ["sh", "-c", "echo '{\"arn\":\"arn:aws:iam::YOUR_ACCOUNT_ID:role/ROLE_NAME\"}'"]  # Replace YOUR_ACCOUNT_ID and ROLE_NAME
}

output "imported_role_arn" {
  value = jsondecode(data.external.import_role.result).arn
}

resource "aws_lambda_layer_version" "postgres_utils_layer" {
  filename            = "${path.module}/postgres_utils/postgres_utils.zip"
  layer_name          = "postgres_utils"
  source_code_hash    = filebase64sha256("${path.module}/postgres_utils/postgres_utils.zip")
  compatible_runtimes = ["python3.9"]
  tags                = local.common-tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lambda_layer_version" "csv2pdf_layer" {
  filename            = "${path.module}/csv2pdf/csv2pdf.zip"
  layer_name          = "csv2pdf"
  source_code_hash    = filebase64sha256("${path.module}/csv2pdf/csv2pdf.zip")
  compatible_runtimes = ["python3.9"]
  tags                = local.common-tags

  lifecycle {
    prevent_destroy = true
  }
}

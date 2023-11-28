##################################################################################
# DATA INPUTS
##################################################################################
data "aws_region" "current" {}
#data "aws_caller_identity" "current" {}
data "aws_vpc" "default" {}

##################################################################################
# RESOURCES
##################################################################################

locals {
  common-tags = {}

  # Execution role name of the lambda
  lambda_role_name = "drift_detection"

  # SG associated with the lambda - Default SG in the account
  sg_ids = var.base_environment == "prod" ? ["sg-0feec7f0e08cc0424"] : ["sg-0feec7f0e08cc0424"]

  # subnets associated with the lambda - sn-mgmt-0,sn-mgmt-1,sn-mgmt-2
  subnet_ids = var.base_environment == "prod" ? [
          "subnet-0ea3f4f294cfc2bc9",
          "subnet-06a8b91adc83ec457",
          "subnet-0d8539cf62a78684c"] : [
          "subnet-0ea3f4f294cfc2bc9",
          "subnet-06a8b91adc83ec457",
          "subnet-0d8539cf62a78684c"]

 
  # lambda function to create bigid user in a different account
  lambda_function_map = [
    {
      function_name = "rds-drift-detection"
      file_name     = "drift_detection_new_test_pattern1/modules/drift_detection/driftdetection.zip"
      policy        = "rds_drift_detection_access"
      timeout       = 900
      reserved_concurrent_executions = 5
    }
  ]

  # Seems like the layer and version has to be hardcoded for now -https://stackoverflow.com/questions/65735878/how-to-configure-cloudwatch-lambda-insights-in-terraform
  # Tried to make it dynamic by using the aws_lambda_layer_version module but could not make it work
  # This is the latest version for us-east-1,2 regions
  lambda_insights_layer_name = "arn:aws:lambda:${data.aws_region.current.name}:580247275435:layer:LambdaInsightsExtension:38"
}

# Layers will create the postgres_utils layer and athena layer
module "lambda_layers" {
  source = "./drift_detection_new_test_pattern1/modules/lambda_layer"
}


# Loop through the lambda function map and call module to create them
module "edm_lambda" {
  for_each = { for lambdas in local.lambda_function_map : lambdas.function_name => lambdas }
  source             = "git@github.info53.com:fitb-edm-dba/prashant_lambdas.git?ref=feature/create_lambda"
  function_name      = "edm-pattern1-${each.value["function_name"]}"
  #handler            = "drift_detection.lambda_function.lambda_handler"
  handler            = "driftdetection.lambda_handler"
  python_runtime     = "python3.9"
  security_group_ids = local.sg_ids
  subnet_ids         = local.subnet_ids
  layer_arns = [module.lambda_layers.postgres_utils_layer_arn,module.lambda_layers.csv2pdf_layer_arn,
    local.lambda_insights_layer_name
  ]
  file_name                 = "${path.module}/${each.value["file_name"]}"
  iam_policy_arn_to_attach  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${each.value["policy"]}"
  invoke_function_principal = ["secretsmanager.amazonaws.com"]
  timeout                   = each.value["timeout"]
  environment_variables     = { 
    SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    environment = "prod"
    db_secret_arn = "arn:aws:secretsmanager:us-east-2:838286658908:secret:/secret/edm-pg/rds-password-ITxCQn"
    secrets_environments = "prod,nonprod,sandbox,dev,uat,branch,development,dr,production,staging,test,stage"
    account_ids = "838286658908,997779447400,482539298668"
    db_secret_pattern = "" 
  }
  reserved_concurrent_executions = each.value["reserved_concurrent_executions"]
  lambda_role_name = local.lambda_role_name
}
      
import {
  to = module.edm_lambda["rds-drift-detection"].aws_iam_role.lambda_role[0]
  id = "drift_detection"
}

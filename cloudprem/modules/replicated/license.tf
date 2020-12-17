data "aws_ssm_parameter" "dozuki_license" {
  name = var.dozuki_license_parameter_name
}

resource "kubernetes_config_map" "replicated_config" {
  metadata {
    name = "replicated-config"
  }

  data = {
    "replicated.conf" = <<-EOF
      {
        "LicenseFileLocation": "/tmp/license.rli"
      }
    EOF
  }
}

resource "kubernetes_secret" "replicated_license" {
  metadata {
    name = "replicated-license"
  }

  data = {
    "license.rli" = data.aws_ssm_parameter.dozuki_license.value
  }
}
module "container_insights" {
  source = "./modules/container-insights"

  cluster_name = module.eks_cluster.cluster_id

  aws_region = data.aws_region.current.name
}

module "replicated" {
  source = "./modules/replicated"

  dozuki_license_parameter_name = var.dozuki_license_parameter_name
}

resource "kubernetes_config_map" "dozuki_resources" {
  metadata {
    name      = "dozuki-resources-configmap"
    namespace = "default"
  }

  data = {
    "memcached.json" = <<-EOF
      {
        "localCluster": {
          "servers": [
            {
              "hostname": "${module.memcached.cluster_address}",
              "port": ${module.memcached.port}
            }
          ]
        },
        "globalCluster": {
          "servers": [
            {
              "hostname": "${module.memcached.cluster_address}",
              "port": ${module.memcached.port}
            }
          ]
        }
      }
    EOF

    "aws-resources.json" = <<-EOF
      {
        "S3.enabled": true,
        "Ec2.enabled": true,
        "CloudFront.enabled": false,
        "LH.localFileSystem": false,
        "CdnUrls.alwaysRelative": false
      }
    EOF

    "s3.json" = <<-EOF
      {
        "region": "${data.aws_region.current.name}",
        "encryptionKeyId": "${data.aws_kms_key.s3.arn}"
      }
    EOF

    "buckets.json" = <<-EOF
      {
        "default": {
          "guide-images": "${module.guide_images_s3_bucket.this_s3_bucket_id}",
          "guide-pdfs": "${module.guide_pdfs_s3_bucket.this_s3_bucket_id}",
          "documents": "${module.documents_s3_bucket.this_s3_bucket_id}",
          "guide-objects": "${module.guide_objects_s3_bucket.this_s3_bucket_id}"
        }
      }
    EOF

    "db.json" = <<-EOF
      {
        "generic": {
          "hostname": "${module.primary_database.this_db_instance_endpoint}",
          "user": "dozuki",
          "password": "REDACTED",
          "CAFile": "/etc/dozuki/rds-ca.pem"
        },
        "master": {
          "hostname": "${module.primary_database.this_db_instance_endpoint}",
          "user": "dozuki",
          "password": "REDACTED",
          "CAFile": "/etc/dozuki/rds-ca.pem"
        },
        "slave": {
          "hostname": "${module.primary_database.this_db_instance_endpoint}",
          "user": "dozuki",
          "password": "REDACTED",
          "CAFile": "/etc/dozuki/rds-ca.pem"
        },
        "sphinx": {
          "hostname": "${module.primary_database.this_db_instance_endpoint}",
          "user": "dozuki",
          "password": "REDACTED",
          "CAFile": "/etc/dozuki/rds-ca.pem"
        }
      }
    EOF

    "rds-ca.pem" = file("vendor/rds-ca-2019-root.pem")

    "index.json" = <<-EOF
      {
        "index": {
          "legacy": {
            "filename": "legacy.json"
          },
          "s3": {
            "filename": "s3.json"
          },
          "buckets": {
            "filename": "buckets.json"
          },
          "db": {
            "filename": "db.json"
          },
          "memcached": {
            "filename": "memcached.json"
          },
          "aws-resources": {
            "filename": "aws-resources.json"
          }
        }
      }
    EOF
  }

}
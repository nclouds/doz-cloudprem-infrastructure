resource "kubernetes_persistent_volume_claim" "replicated_pv_claim" {
  wait_until_bound = false

  metadata {
    name = "replicated-pv-claim"

    labels = {
      app = "replicated"

      tier = "master"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "10Gi"
      }
    }

    storage_class_name = "gp2"
  }
}

resource "kubernetes_persistent_volume_claim" "replicated_premkit_data_volume" {
  wait_until_bound = false

  metadata {
    name = "replicated-premkit-data-volume"

    labels = {
      app = "replicated"

      tier = "premkit"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    storage_class_name = "gp2"
  }
}

resource "kubernetes_persistent_volume_claim" "replicated_statsd_graphite_storage" {
  wait_until_bound = false

  metadata {
    name = "replicated-statsd-graphite-storage"

    labels = {
      app = "replicated"

      tier = "statsd"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "10Gi"
      }
    }

    storage_class_name = "gp2"
  }
}

resource "kubernetes_cluster_role_binding" "replicated_admin" {
  metadata {
    name = "replicated-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}

resource "kubernetes_deployment" "replicated" {
  metadata {
    name = "replicated"

    labels = {
      app = "replicated"

      tier = "master"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "replicated"

        tier = "master"
      }
    }

    template {
      metadata {
        labels = {
          app = "replicated"

          tier = "master"
        }
      }

      spec {
        automount_service_account_token = true

        volume {
          name = "replicated-persistent"

          persistent_volume_claim {
            claim_name = "replicated-pv-claim"
          }
        }

        volume {
          name = "replicated-socket"
          empty_dir {}
        }

        volume {
          name = "docker-socket"

          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "replicated-conf"

          config_map {
            name = kubernetes_config_map.replicated_config.metadata.0.name
          }
        }

        volume {
          name = "replicated-license"

          secret {
            secret_name = kubernetes_secret.replicated_license.metadata.0.name
          }
        }

        volume {
          name = "proc"

          host_path {
            path = "/proc"
          }
        }

        container {
          name  = "replicated"
          image = "quay.io/replicated/replicated:stable-2.40.4"

          port {
            container_port = 9874
          }

          port {
            container_port = 9876
          }

          port {
            container_port = 9877
          }

          port {
            container_port = 9878
          }

          env {
            name  = "SCHEDULER_ENGINE"
            value = "kubernetes"
          }

          env {
            name  = "RELEASE_CHANNEL"
            value = "stable"
          }

          env {
            name = "RELEASE_SEQUENCE"
          }

          env {
            name = "RELEASE_PATCH_SEQUENCE"
          }

          env {
            name = "COMPONENT_IMAGES_REGISTRY_ADDRESS_OVERRIDE"
          }

          env {
            name = "LOCAL_ADDRESS"

            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          env {
            name = "K8S_MASTER_ADDRESS"

            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "K8S_HOST_IP"

            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "K8S_POD_IP"

            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          env {
            name = "K8S_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "K8S_STORAGECLASS"
            value = "gp2"
          }

          env {
            name  = "LOG_LEVEL"
            value = "info"
          }

          env {
            name = "AIRGAP"
          }

          env {
            name  = "MAINTAIN_ROOK_STORAGE_NODES"
            value = "0"
          }

          volume_mount {
            name       = "replicated-persistent"
            mount_path = "/var/lib/replicated"
          }

          volume_mount {
            name       = "replicated-socket"
            mount_path = "/var/run/replicated"
          }

          volume_mount {
            name       = "docker-socket"
            mount_path = "/host/var/run/docker.sock"
          }

          volume_mount {
            name       = "replicated-conf"
            mount_path = "/etc/replicated.conf"
            sub_path   = "replicated.conf"
          }

          volume_mount {
            name       = "replicated-license"
            mount_path = "/tmp/license.rli"
            sub_path   = "license.rli"
          }

          volume_mount {
            name       = "proc"
            read_only  = true
            mount_path = "/host/proc"
          }

          image_pull_policy = "IfNotPresent"
        }

        container {
          name  = "replicated-ui"
          image = "quay.io/replicated/replicated-ui:stable-2.40.4"

          port {
            container_port = 8800
          }

          env {
            name  = "RELEASE_CHANNEL"
            value = "stable"
          }

          env {
            name  = "LOG_LEVEL"
            value = "info"
          }

          volume_mount {
            name       = "replicated-socket"
            mount_path = "/var/run/replicated"
          }

          image_pull_policy = "IfNotPresent"
        }
      }
    }

    strategy {
      type = "Recreate"
    }
  }
}

resource "kubernetes_service" "replicated" {
  metadata {
    name = "replicated"

    labels = {
      app = "replicated"

      tier = "master"
    }
  }

  spec {
    port {
      name     = "replicated-iapi"
      protocol = "TCP"
      port     = 9877
    }

    port {
      name     = "replicated-snapshots"
      protocol = "TCP"
      port     = 9878
    }

    port {
      name     = "replicated-support"
      protocol = "TCP"
      port     = 9881
    }

    selector = {
      app = "replicated"

      tier = "master"
    }
  }
}

resource "kubernetes_service" "replicated_ui" {
  metadata {
    name = "replicated-ui"

    labels = {
      app = "replicated"

      tier = "master"
    }
  }

  spec {
    port {
      name      = "replicated-ui"
      protocol  = "TCP"
      port      = 8800
      node_port = 32001
    }

    selector = {
      app = "replicated"

      tier = "master"
    }

    type = "NodePort"
  }
}

data "aws_ssm_parameter" "dozuki_license" {
  name = var.dozuki_license
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

resource "kubernetes_namespace" "amazon_cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"

    labels = {
      name = "amazon-cloudwatch"
    }
  }
}

resource "kubernetes_service_account" "cloudwatch_agent" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role" "cloudwatch_agent_role" {
  metadata {
    name = "cloudwatch-agent-role"
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = [""]
    resources  = ["pods", "nodes", "endpoints"]
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = ["apps"]
    resources  = ["replicasets"]
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = ["batch"]
    resources  = ["jobs"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["nodes/proxy"]
  }

  rule {
    verbs      = ["create"]
    api_groups = [""]
    resources  = ["nodes/stats", "configmaps", "events"]
  }

  rule {
    verbs          = ["get", "update"]
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cwagent-clusterleader"]
  }
}

resource "kubernetes_cluster_role_binding" "cloudwatch_agent_role_binding" {
  metadata {
    name = "cloudwatch-agent-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cloudwatch_agent.metadata.0.name
    namespace = kubernetes_service_account.cloudwatch_agent.metadata.0.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cloudwatch_agent_role.metadata.0.name
  }
}

resource "kubernetes_config_map" "cwagentconfig" {
  metadata {
    name      = "cwagentconfig"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
  }

  data = {
    "cwagentconfig.json" = "{\n  \"agent\": {\n    \"region\": \"${module.eks_cluster.cluster_id}\"\n  },\n  \"logs\": {\n    \"metrics_collected\": {\n      \"kubernetes\": {\n        \"cluster_name\": \"${data.aws_region.current.name}\",\n        \"metrics_collection_interval\": 60\n      }\n    },\n    \"force_flush_interval\": 5\n  }\n}\n"
  }
}

resource "kubernetes_daemonset" "cloudwatch_agent" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
  }

  spec {
    selector {
      match_labels = {
        name = "cloudwatch-agent"
      }
    }

    template {
      metadata {
        labels = {
          name = "cloudwatch-agent"
        }
      }

      spec {
        automount_service_account_token = true

        volume {
          name = "cwagentconfig"

          config_map {
            name = kubernetes_config_map.cwagentconfig.metadata.0.name
          }
        }

        volume {
          name = "rootfs"

          host_path {
            path = "/"
          }
        }

        volume {
          name = "dockersock"

          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "varlibdocker"

          host_path {
            path = "/var/lib/docker"
          }
        }

        volume {
          name = "sys"

          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "devdisk"

          host_path {
            path = "/dev/disk/"
          }
        }

        container {
          name  = "cloudwatch-agent"
          image = "amazon/cloudwatch-agent:1.247346.0b249609"

          env {
            name = "HOST_IP"

            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "HOST_NAME"

            value_from {
              field_ref {
                field_path = "spec.nodeName"
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
            name  = "CI_VERSION"
            value = "k8s/1.2.4"
          }

          resources {
            limits {
              cpu    = "200m"
              memory = "200Mi"
            }

            requests {
              memory = "200Mi"
              cpu    = "200m"
            }
          }

          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }

          volume_mount {
            name       = "rootfs"
            read_only  = true
            mount_path = "/rootfs"
          }

          volume_mount {
            name       = "dockersock"
            read_only  = true
            mount_path = "/var/run/docker.sock"
          }

          volume_mount {
            name       = "varlibdocker"
            read_only  = true
            mount_path = "/var/lib/docker"
          }

          volume_mount {
            name       = "sys"
            read_only  = true
            mount_path = "/sys"
          }

          volume_mount {
            name       = "devdisk"
            read_only  = true
            mount_path = "/dev/disk"
          }
        }

        termination_grace_period_seconds = 60
        service_account_name             = kubernetes_service_account.cloudwatch_agent.metadata.0.name
      }
    }
  }
}

resource "kubernetes_config_map" "cluster_info" {
  metadata {
    name      = "cluster-info"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
  }

  data = {
    "cluster.name" = module.eks_cluster.cluster_id

    "logs.region" = data.aws_region.current.name
  }
}

resource "kubernetes_service_account" "fluentd" {
  metadata {
    name      = "fluentd"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role" "fluentd_role" {
  metadata {
    name = "fluentd-role"
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["namespaces", "pods", "pods/logs"]
  }
}

resource "kubernetes_cluster_role_binding" "fluentd_role_binding" {
  metadata {
    name = "fluentd-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluentd.metadata.0.name
    namespace = kubernetes_service_account.fluentd.metadata.0.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluentd_role.metadata.0.name
  }
}

resource "kubernetes_config_map" "fluentd_config" {
  metadata {
    name      = "fluentd-config"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name

    labels = {
      k8s-app = "fluentd-cloudwatch"
    }
  }

  data = {
    "containers.conf" = "<source>\n  @type tail\n  @id in_tail_container_logs\n  @label @containers\n  path /var/log/containers/*.log\n  exclude_path [\"/var/log/containers/cloudwatch-agent*\", \"/var/log/containers/fluentd*\"]\n  pos_file /var/log/fluentd-containers.log.pos\n  tag *\n  read_from_head true\n  <parse>\n    @type json\n    time_format %Y-%m-%dT%H:%M:%S.%NZ\n  </parse>\n</source>\n\n<source>\n  @type tail\n  @id in_tail_cwagent_logs\n  @label @cwagentlogs\n  path /var/log/containers/cloudwatch-agent*\n  pos_file /var/log/cloudwatch-agent.log.pos\n  tag *\n  read_from_head true\n  <parse>\n    @type json\n    time_format %Y-%m-%dT%H:%M:%S.%NZ\n  </parse>\n</source>\n\n<source>\n  @type tail\n  @id in_tail_fluentd_logs\n  @label @fluentdlogs\n  path /var/log/containers/fluentd*\n  pos_file /var/log/fluentd.log.pos\n  tag *\n  read_from_head true\n  <parse>\n    @type json\n    time_format %Y-%m-%dT%H:%M:%S.%NZ\n  </parse>\n</source>\n\n<label @fluentdlogs>\n  <filter **>\n    @type kubernetes_metadata\n    @id filter_kube_metadata_fluentd\n  </filter>\n\n  <filter **>\n    @type record_transformer\n    @id filter_fluentd_stream_transformer\n    <record>\n      stream_name $${tag_parts[3]}\n    </record>\n  </filter>\n\n  <match **>\n    @type relabel\n    @label @NORMAL\n  </match>\n</label>\n\n<label @containers>\n  <filter **>\n    @type kubernetes_metadata\n    @id filter_kube_metadata\n  </filter>\n\n  <filter **>\n    @type record_transformer\n    @id filter_containers_stream_transformer\n    <record>\n      stream_name $${tag_parts[3]}\n    </record>\n  </filter>\n\n  <filter **>\n    @type concat\n    key log\n    multiline_start_regexp /^\\S/\n    separator \"\"\n    flush_interval 5\n    timeout_label @NORMAL\n  </filter>\n\n  <match **>\n    @type relabel\n    @label @NORMAL\n  </match>\n</label>\n\n<label @cwagentlogs>\n  <filter **>\n    @type kubernetes_metadata\n    @id filter_kube_metadata_cwagent\n  </filter>\n\n  <filter **>\n    @type record_transformer\n    @id filter_cwagent_stream_transformer\n    <record>\n      stream_name $${tag_parts[3]}\n    </record>\n  </filter>\n\n  <filter **>\n    @type concat\n    key log\n    multiline_start_regexp /^\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}/\n    separator \"\"\n    flush_interval 5\n    timeout_label @NORMAL\n  </filter>\n\n  <match **>\n    @type relabel\n    @label @NORMAL\n  </match>\n</label>\n\n<label @NORMAL>\n  <match **>\n    @type cloudwatch_logs\n    @id out_cloudwatch_logs_containers\n    region \"#{ENV.fetch('AWS_REGION')}\"\n    log_group_name \"/aws/containerinsights/#{ENV.fetch('CLUSTER_NAME')}/application\"\n    log_stream_name_key stream_name\n    remove_log_stream_name_key true\n    auto_create_stream true\n    <buffer>\n      flush_interval 5\n      chunk_limit_size 2m\n      queued_chunks_limit_size 32\n      retry_forever true\n    </buffer>\n  </match>\n</label>\n"

    "fluent.conf" = "@include containers.conf\n@include systemd.conf\n@include host.conf\n\n<match fluent.**>\n  @type null\n</match>\n"

    "host.conf" = "<source>\n  @type tail\n  @id in_tail_dmesg\n  @label @hostlogs\n  path /var/log/dmesg\n  pos_file /var/log/dmesg.log.pos\n  tag host.dmesg\n  read_from_head true\n  <parse>\n    @type syslog\n  </parse>\n</source>\n\n<source>\n  @type tail\n  @id in_tail_secure\n  @label @hostlogs\n  path /var/log/secure\n  pos_file /var/log/secure.log.pos\n  tag host.secure\n  read_from_head true\n  <parse>\n    @type syslog\n  </parse>\n</source>\n\n<source>\n  @type tail\n  @id in_tail_messages\n  @label @hostlogs\n  path /var/log/messages\n  pos_file /var/log/messages.log.pos\n  tag host.messages\n  read_from_head true\n  <parse>\n    @type syslog\n  </parse>\n</source>\n\n<label @hostlogs>\n  <filter **>\n    @type kubernetes_metadata\n    @id filter_kube_metadata_host\n  </filter>\n\n  <filter **>\n    @type record_transformer\n    @id filter_containers_stream_transformer_host\n    <record>\n      stream_name $${tag}-$${record[\"host\"]}\n    </record>\n  </filter>\n\n  <match host.**>\n    @type cloudwatch_logs\n    @id out_cloudwatch_logs_host_logs\n    region \"#{ENV.fetch('AWS_REGION')}\"\n    log_group_name \"/aws/containerinsights/#{ENV.fetch('CLUSTER_NAME')}/host\"\n    log_stream_name_key stream_name\n    remove_log_stream_name_key true\n    auto_create_stream true\n    <buffer>\n      flush_interval 5\n      chunk_limit_size 2m\n      queued_chunks_limit_size 32\n      retry_forever true\n    </buffer>\n  </match>\n</label>\n"

    "systemd.conf" = "<source>\n  @type systemd\n  @id in_systemd_kubelet\n  @label @systemd\n  filters [{ \"_SYSTEMD_UNIT\": \"kubelet.service\" }]\n  <entry>\n    field_map {\"MESSAGE\": \"message\", \"_HOSTNAME\": \"hostname\", \"_SYSTEMD_UNIT\": \"systemd_unit\"}\n    field_map_strict true\n  </entry>\n  path /var/log/journal\n  <storage>\n    @type local\n    persistent true\n    path /var/log/fluentd-journald-kubelet-pos.json\n  </storage>\n  read_from_head true\n  tag kubelet.service\n</source>\n\n<source>\n  @type systemd\n  @id in_systemd_kubeproxy\n  @label @systemd\n  filters [{ \"_SYSTEMD_UNIT\": \"kubeproxy.service\" }]\n  <entry>\n    field_map {\"MESSAGE\": \"message\", \"_HOSTNAME\": \"hostname\", \"_SYSTEMD_UNIT\": \"systemd_unit\"}\n    field_map_strict true\n  </entry>\n  path /var/log/journal\n  <storage>\n    @type local\n    persistent true\n    path /var/log/fluentd-journald-kubeproxy-pos.json\n  </storage>\n  read_from_head true\n  tag kubeproxy.service\n</source>\n\n<source>\n  @type systemd\n  @id in_systemd_docker\n  @label @systemd\n  filters [{ \"_SYSTEMD_UNIT\": \"docker.service\" }]\n  <entry>\n    field_map {\"MESSAGE\": \"message\", \"_HOSTNAME\": \"hostname\", \"_SYSTEMD_UNIT\": \"systemd_unit\"}\n    field_map_strict true\n  </entry>\n  path /var/log/journal\n  <storage>\n    @type local\n    persistent true\n    path /var/log/fluentd-journald-docker-pos.json\n  </storage>\n  read_from_head true\n  tag docker.service\n</source>\n\n<label @systemd>\n  <filter **>\n    @type kubernetes_metadata\n    @id filter_kube_metadata_systemd\n  </filter>\n\n  <filter **>\n    @type record_transformer\n    @id filter_systemd_stream_transformer\n    <record>\n      stream_name $${tag}-$${record[\"hostname\"]}\n    </record>\n  </filter>\n\n  <match **>\n    @type cloudwatch_logs\n    @id out_cloudwatch_logs_systemd\n    region \"#{ENV.fetch('AWS_REGION')}\"\n    log_group_name \"/aws/containerinsights/#{ENV.fetch('CLUSTER_NAME')}/dataplane\"\n    log_stream_name_key stream_name\n    auto_create_stream true\n    remove_log_stream_name_key true\n    <buffer>\n      flush_interval 5\n      chunk_limit_size 2m\n      queued_chunks_limit_size 32\n      retry_forever true\n    </buffer>\n  </match>\n</label>\n"
  }
}

resource "kubernetes_daemonset" "fluentd_cloudwatch" {
  metadata {
    name      = "fluentd-cloudwatch"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata.0.name
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "fluentd-cloudwatch"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app = "fluentd-cloudwatch"
        }

        annotations = {
          configHash = "8915de4cf9c3551a8dc74c0137a3e83569d28c71044b0359c2578d2e0461825"
        }
      }

      spec {
        automount_service_account_token = true

        volume {
          name = "config-volume"

          config_map {
            name = kubernetes_config_map.fluentd_config.metadata.0.name
          }
        }

        volume {
          name = "fluentdconf"
          empty_dir {}
        }

        volume {
          name = "varlog"

          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "varlibdockercontainers"

          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        volume {
          name = "runlogjournal"

          host_path {
            path = "/run/log/journal"
          }
        }

        volume {
          name = "dmesg"

          host_path {
            path = "/var/log/dmesg"
          }
        }

        init_container {
          name    = "copy-fluentd-config"
          image   = "busybox"
          command = ["sh", "-c", "cp /config-volume/..data/* /fluentd/etc"]

          volume_mount {
            name       = "config-volume"
            mount_path = "/config-volume"
          }

          volume_mount {
            name       = "fluentdconf"
            mount_path = "/fluentd/etc"
          }
        }

        init_container {
          name    = "update-log-driver"
          image   = "busybox"
          command = ["sh", "-c", ""]
        }

        container {
          name  = "fluentd-cloudwatch"
          image = "fluent/fluentd-kubernetes-daemonset:v1.7.3-debian-cloudwatch-1.0"

          env {
            name = "AWS_REGION"

            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.cluster_info.metadata.0.name
                key  = "logs.region"
              }
            }
          }

          env {
            name = "CLUSTER_NAME"

            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.cluster_info.metadata.0.name
                key  = "cluster.name"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/1.2.4"
          }

          resources {
            limits {
              memory = "400Mi"
            }

            requests {
              cpu    = "100m"
              memory = "200Mi"
            }
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/config-volume"
          }

          volume_mount {
            name       = "fluentdconf"
            mount_path = "/fluentd/etc"
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
          }

          volume_mount {
            name       = "varlibdockercontainers"
            read_only  = true
            mount_path = "/var/lib/docker/containers"
          }

          volume_mount {
            name       = "runlogjournal"
            read_only  = true
            mount_path = "/run/log/journal"
          }

          volume_mount {
            name       = "dmesg"
            read_only  = true
            mount_path = "/var/log/dmesg"
          }
        }

        termination_grace_period_seconds = 30
        service_account_name             = kubernetes_service_account.fluentd.metadata.0.name
      }
    }
  }
}

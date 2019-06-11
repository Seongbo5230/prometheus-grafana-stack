#!/bin/bash

# user data for setting up the server

#########################################
# initial prometheus and promtool setup #
#########################################
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus

cd /tmp/
wget https://github.com/prometheus/prometheus/releases/download/v2.7.1/prometheus-2.7.1.linux-amd64.tar.gz
tar -xvf prometheus-2.7.1.linux-amd64.tar.gz

sudo mv console* /etc/prometheus
sudo mv prometheus.yml /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus

sudo mv prometheus /usr/local/bin/
sudo mv promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

sudo cat << EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target

EOF
# visit prometheus page at PUBLICIP:9090



##################################
# alertmanager setup - port 9093 #
##################################
sudo useradd --no-create-home --shell /bin/false alertmanager
sudo mkdir /etc/alertmanager

cd /tmp/
wget https://github.com/prometheus/alertmanager/releases/download/v0.16.1/alertmanager-0.16.1.linux-amd64.tar.gz
tar -xvf alertmanager-0.16.1.linux-amd64.tar.gz

cd alertmanager-0.16.1.linux-amd64
sudo mv alertmanager /usr/local/bin/
sudo mv amtool /usr/local/bin/

sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/amtool
sudo mv alertmanager.yml /etc/alertmanager/
sudo chown -R alertmanager:alertmanager /etc/alertmanager/

sudo cat << EOF > /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
WorkingDirectory=/etc/alertmanager/
ExecStart=/usr/local/bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml
[Install]
WantedBy=multi-user.target

EOF
# look at PUBLICIP:9093 to view alertmanager



#################
# grafana setup #
#################
sudo apt-get install libfontconfig -y

wget https://dl.grafana.com/oss/release/grafana_5.4.3_amd64.deb
sudo dpkg -i grafana_5.4.3_amd64.deb
# access grafana via IPADDRESS:3000



#################
# Node Exporter #
#################
sudo useradd --no-create-home --shell /bin/false node_exporter
cd /tmp/
wget https://github.com/prometheus/node_exporter/releases/download/v0.17.0/node_exporter-0.17.0.linux-amd64.tar.gz
tar -xvf node_exporter-0.17.0.linux-amd64.tar.gz

cd node_exporter-0.17.0.linux-amd64/
sudo mv node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat into /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target



############
# cAdvisor #
############
sudo docker run \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8000:8080 \
  --detach=true \
  --name=cadvisor \
  google/cadvisor:latest

sudo cat << EOF > /etc/prometheus/prometheus.yml
# my global config
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - localhost:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'

  # metrics_path defaults to '/metrics'
  # scheme defaults to 'http'.

    static_configs:
    - targets: ['localhost:9090']
  - job_name: 'alertmanager'
    static_configs:
    - targets: ['localhost:9093']
  - job_name: 'grafana'
    static_configs:
    - targets: ['localhost:3000']
  - job_name: 'node_exporter'
    static_configs:
    - targets: ['localhost:9100']
  - job_name: 'cadvisor'
    static_configs:
    - targets: ['localhost:8000']

EOF



## cpu examples... using stress -c 5
# irate(node_cpu_seconds_total{mode="user"}[1m]) * 100
# avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

## mem examples... using stress -m 2
# node_memory_MemTotal_bytes - node_memory_MemFree_bytes

## disk examples... sudo apt install sysstat - use iostat
# irate(node_disk_io_time_seconds_total[30s])
# irate(node_disk_read_time_seconds_total[30s]) / irate(node_disk_io_time_seconds_total[30s])
# irate(node_disk_write_time_seconds_total[30s]) / irate(node_disk_io_time_seconds_total[30s])
# node_disk_io_now

## filesystem examples
# node_filesystem_avail_bytes{fstype="tmpfs"}

## network
# rate(node_network_transmit_bytes_total[30s])
# rate(node_network_receive_bytes_total[30s])

#### use snmp_exporter for more network data...

## container metrics examples...
# container_memory_usage_bytes{names="ft-app"}



sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl start alertmanager
sudo systemctl start node_exporter
sudo systemctl enable prometheus
sudo systemctl enable alertmanager
sudo systemctl enable --now grafana-server
sudo systemctl enable node_exporter
sudo systemctl restart prometheus

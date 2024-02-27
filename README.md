# OpenWEC

Notes:
```
### ON LOGSTASH SERVER ###
### Look into containers instead:
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg
sudo apt-get install apt-transport-https
echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-8.x.list
sudo apt-get update && sudo apt-get install logstash
nano pipeline.conf
### SOF ###
input {
  beats {
    port => 5044
  }
}
output {
  stdout { codec => rubydebug }
}
### EOF ###
sudo /usr/share/logstash/bin/logstash -f pipeline.conf

### OPEN NEW SSH TO OPENWEC ###
sudo adduser dcadmin
sudo usermod -a -G sudo dcadmin
su dcadmin
sudo apt update && sudo apt install libclang-dev cargo pkg-config libssl-dev libkrb5-dev build-essential && 
sudo apt install krb5-user krb5-config #CASE SENSITIVE - DOMAIN NAME IN CAPS
sudo nano /etc/krb5.conf
sudo apt install realmd
sudo hostnamectl set-hostname openwec.democorp.com
sudo realm join -v -U dcadmin democorp.com
sudo pam-auth-update
sudo nano /etc/filebeat/filebeat.yml
###SOF###
filebeat.inputs:
- type: unix
  socket_type: datagram
  path: "/run/filebeat.sock"
parsers:
- multiline:
    type: pattern
    pattern: '^<Event '
    negate: true
    match: after
output.logstash:
  hosts: ["logstash.democorp.com:5044"]
processors:
  - rename:
      fields:
        - from: message
          to: event.original
  - decode_xml_wineventlog:
      field: event.original
      target_field: winlog
###EOF###
filebeat -e -v

### Run these commands on the DC ###
setspn -A HTTP/openwec.democorp.com@democorp.com openwec
# create an AD user named owec - find powershell to create this automatically
ktpass /princ HTTP/openwec.democorp.com@DEMOCORP.COM /mapuser owec /crypto ALL /ptype KRB5_NT_PRINCIPAL /pass strong_1337_PASSWORD /target dc.democorp.com /out owec.keytab
scp owec.keytab dcadmin@openwec.democorp.com:/home/dcadmin/openwec

### OPEN NEW SSH TO OPENWEC ###
git clone https://github.com/cea-sec/openwec
cd openwec
cargo build --release
mkdir /var/log/openwec # check if this is needed
nano query.xml #copy from source
nano openwec.conf.toml #copy from source
./target/release/openwec -c openwec.conf.toml db init
./target/release/openwec -c openwec.conf.toml subscriptions new openwec_sub query.xml
./target/release/openwec -c openwec.conf.toml subscriptions edit openwec_sub outputs add --format raw unixdatagram /run/filebeat.sock
./target/release/openwec -c openwec.conf.toml subscriptions enable openwec_sub
./target/release/openwecd -c openwec.conf.toml # wait 60 sec for: WARN server::outputs::unix - Failed to connect to /run/filebeat.sock: No such file or directory (os error 2) - this means filebeat is not running or listening on that socket
```

1. docker->containers->so-logstash->port_bindings->add 0.0.0.0:10070:10070
1. firewall->hostgroups->manager->add 10.103.0.105 (openwec)  (apply to node: manager)
1. firewall->portgroups->customportgroup0->tcp->add 10070  (apply to node: manager)
1. firewall->role->manager->chain->DOCKER-USER->hostgroups->manager->portgroups->customportgroup0  (apply to node: manager)
1. firewall->role->manager->chain->INPUT->hostgroups->customhostgroup->portgroups->customportgroup0  (apply to node: manager)
1. logstash->defined_pipelines->custom0
```
  input {
    tcp {
      port => 10070
      codec => json_lines
    }
  }
```
1. logstash->assigned_pipelines->roles->manager->add custom0


OpenWEC is a free and open source (GPLv3) implementation of a Windows Event Collector server running on GNU/Linux and written in Rust.

OpenWEC collects Windows event logs from a Linux machine without the need for a third-party local agent running on Windows machines.

OpenWEC implements the Windows Event Forwarding protocol ([MS-WSMV](https://winprotocoldoc.blob.core.windows.net/productionwindowsarchives/MS-WSMV/%5BMS-WSMV%5D.pdf)), which is derived from WS-Management ([DSP0226](https://www.dmtf.org/sites/default/files/standards/documents/DSP0226_1.0.0.pdf)). The same protocol is used by the built-in Windows Event Forwarding plugin. As it speaks the same protocol, OpenWEC can be used with the built-in Windows Event Forwarding plugin. Only the source-initiated mode (Push) is supported for now.

OpenWEC is composed of two binaries:
- `openwecd`: OpenWEC server
- `openwec`: OpenWEC CLI, used to manage the OpenWEC server

The OpenWEC configuration is read from a file (by default `/etc/openwec.conf.toml`). See available parameters in [openwec.conf.sample.toml](openwec.conf.sample.toml).
Subscriptions and their parameters are stored in a [database](doc/database.md) and can be managed using `openwec` (see [CLI](doc/cli.md) documentation).

# Documentation

- [Getting started](doc/getting_started.md)
- [TLS authentication](doc/tls.md)
- [Command Line Interface](doc/cli.md)
- [Database](doc/database.md)
- [Subscription query](doc/query.md)
- [Outputs](doc/outputs.md)
- [Output formats](doc/formats.md)
- [How does OpenWEC works ?](doc/how_it_works.md)
- [WEF protocol analysis](doc/protocol.md)
- [Monitoring](doc/monitoring.md)
- [Known issues](doc/issues.md)
- [Talk at SSTIC 2023 (in french)](https://www.sstic.org/2023/presentation/openwec/)

# Contributing

Any contribution is welcome, be it code, bug report, packaging, documentation or translation.

# License

OpenWEC is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

OpenWEC is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with OpenWEC. If not, see the gnu.org web site.

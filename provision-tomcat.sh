#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

# Set a real approved Tomcat 9.x version before vagrant up.
TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.XX}"
JAVA8_DIR="/opt/java8"

if [[ "${TOMCAT_VERSION}" == *XX* ]]; then
  echo "Set TOMCAT_VERSION to an approved real Tomcat 9.x version before provisioning." >&2
  exit 2
fi

apt-get update
apt-get install -y curl ca-certificates jq tar gzip

JAVA8_URL="$(curl -fsSL \
  'https://api.adoptium.net/v3/assets/latest/8/hotspot?architecture=x64&image_type=jdk&jvm_impl=hotspot&os=linux&vendor=eclipse' \
  | jq -r '.[0].binary.package.link')"
test -n "${JAVA8_URL}" && test "${JAVA8_URL}" != "null"
mkdir -p "${JAVA8_DIR}"
curl -fL "${JAVA8_URL}" -o /tmp/java8.tar.gz
tar -xzf /tmp/java8.tar.gz -C "${JAVA8_DIR}" --strip-components=1
ln -sfn "${JAVA8_DIR}" /opt/java8-current

id -u tomcat >/dev/null 2>&1 || useradd --system --home-dir /opt/tomcat --create-home --shell /usr/sbin/nologin tomcat
curl -fL -o /tmp/tomcat.tar.gz \
  "https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
mkdir -p /opt/tomcat
tar -xzf /tmp/tomcat.tar.gz -C /opt/tomcat --strip-components=1
chown -R tomcat:tomcat /opt/tomcat
chmod +x /opt/tomcat/bin/*.sh
sed -i 's/port="8080" protocol="HTTP\/1.1"/port="7070" protocol="HTTP\/1.1"/' /opt/tomcat/conf/server.xml

cat >/etc/systemd/system/tomcat.service <<'UNIT'
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment="JAVA_HOME=/opt/java8-current"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms256m -Xmx1024m -Djava.awt.headless=true"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=on-failure
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now tomcat
systemctl --no-pager --full status tomcat

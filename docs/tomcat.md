# مسودة تقنية: Tomcat وJVM — تقييم ProgressSoft

## 1. المصطلحات والبنية

### JVM

**JVM (Java Virtual Machine)** هي البيئة التي تنفّذ الـ bytecode الناتج من ترجمة Java. فهي تعزل التطبيق عن نظام التشغيل إلى حد كبير، وتوفر:

- **Class loading** لتحميل أصناف التطبيق والمكتبات.
- **Garbage collection** لإدارة الذاكرة تلقائياً.
- **JIT compilation** لتحويل الأجزاء الساخنة من bytecode إلى تعليمات أصلية أثناء التشغيل.
- مساحات ذاكرة مثل **heap** و**metaspace** وذاكرة الـ thread stacks.

تطبيق Java لا يتخاطب عادةً مع Linux مباشرة؛ بل يعمل داخل JVM. لذلك يجب اختيار JDK/JRE متوافق مع إصدار التطبيق، ومعمارية الجهاز، وإصدار نظام التشغيل. في بيئة الإنتاج ينبغي أيضاً تحديد حدود الذاكرة ومراقبة heap والـ GC بدلاً من تركها تعتمد كلياً على التخمين التلقائي.

### Application server

**Application server** هو برنامج يستضيف تطبيقات الخادم ويقدم لها خدمات مشتركة، مثل:

- دورة حياة التطبيق وبدء التشغيل والإيقاف.
- استقبال اتصالات HTTP/HTTPS وإدارة الـ threads.
- إدارة الجلسات والـ cookies.
- تحميل المكتبات وملفات الإعداد.
- تسجيل الأحداث، وموارد JDBC، والأمان، والتكامل مع مكونات أخرى بحسب المنتج.

المصطلح أوسع من web server التقليدي. فـ Nginx ممتاز لتقديم الملفات وكونه reverse proxy، لكنه لا يشغّل Java Servlet/WAR. Tomcat هو **Servlet container** (وغالباً يُسمّى application server في الاستخدام العملي) ويشغّل تطبيقات Java المبنية على Servlet/JSP. أما خوادم Jakarta EE الكاملة مثل WildFly أو Payara فتقدم مجموعة أكبر من مواصفات المؤسسة.

### WAR وTomcat

ملف **WAR (Web Application Archive)** هو أرشيف ZIP منظم لتطبيق ويب Java، وغالباً يحتوي على:

- `WEB-INF/web.xml` عند استخدام واصف نشر تقليدي.
- `WEB-INF/classes/` للـ classes الخاصة بالتطبيق.
- `WEB-INF/lib/` لملفات JAR التابعة.
- ملفات HTML وCSS وJavaScript والموارد الثابتة.

يُنسخ ملف `app.war` إلى مجلد `webapps/` في Tomcat. عند تفعيل `autoDeploy` يفك Tomcat الأرشيف إلى مجلد باسم التطبيق ويجعله متاحاً عادةً على `/app`. ويمكن استخدام `ROOT.war` للتطبيق الافتراضي على `/`. في الإنتاج يجب الانتباه إلى استراتيجية النشر، والتحقق من checksum للملف، وعدم ترك التطبيق الافتراضي أو أمثلة Tomcat مكشوفة بلا حاجة.

المسار المنطقي في هذا التصميم هو:

```text
Client -> DNS name:80 -> Nginx (reverse proxy) -> Tomcat:7070 -> JVM -> WAR
```

## 2. تثبيت Tomcat 9 على Ubuntu (تثبيت مباشر)

الأوامر التالية تفترض Ubuntu حديثاً وحساباً يملك `sudo`. يُفضّل تثبيت إصدار Tomcat 9 محدد ومختبر في بيئة المؤسسة بدلاً من الاعتماد على كلمة `latest` غير القابلة لإعادة الإنتاج.

### 2.1 المتطلبات والمستخدم

```bash
sudo apt update
sudo apt install -y curl ca-certificates jq tar gzip

sudo useradd --system --home-dir /opt/tomcat --create-home \
  --shell /usr/sbin/nologin tomcat
```

### 2.2 Java

إذا كان التطبيق يدعم Java حديثة، استخدم الإصدار المتوافق معه من مستودع Ubuntu، مثلاً:

```bash
sudo apt install -y openjdk-17-jdk
java -version
```

Tomcat 9 نفسه يمكنه العمل على إصدارات Java حديثة، لكن **التطبيق الموجود داخل WAR هو الذي يحدد الحد الأدنى الحقيقي**. لا ينبغي استنتاج توافق التطبيق من توافق Tomcat وحده.

إذا كان WAR يتطلب Java 8، راجع القسم الخاص بقيود Ubuntu 24.04 أدناه؛ لا تفترض أن الأمر التالي سينجح:

```bash
sudo apt install openjdk-8-jdk   # قد يفشل على Ubuntu 24.04؛ ليس حلاً مضموناً
```

### 2.3 تنزيل Tomcat 9 وفكّه

حدّد إصداراً معتمداً من فريق التطبيق. المثال التالي يوضح الفكرة باستخدام متغير إصدار؛ استبدل القيمة بإصدار 9.x مختبر ومتاح من مصدر Apache الموثوق:

```bash
export TOMCAT_VERSION="9.0.XX"
export CATALINA_HOME=/opt/tomcat

curl -fL -o /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
  https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz

# في الإنتاج: نزّل أيضاً ملف sha512 من Apache وتحقق منه قبل فك الأرشيف.
sudo tar -xzf /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
  -C /opt/tomcat --strip-components=1
sudo chown -R tomcat:tomcat /opt/tomcat
sudo chmod +x /opt/tomcat/bin/*.sh
```

يمكن اختيار آخر مجلد 9.x منشور من دليل Apache، لكن تثبيت النسخة في configuration management أفضل للتدقيق وإعادة البناء. لا تستخدم مرآة عشوائية أو رابطاً غير HTTPS.

### 2.4 خدمة systemd وتشغيل WAR

```bash
sudo tee /etc/systemd/system/tomcat.service >/dev/null <<'EOF'
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512m -Xmx1024m -Djava.awt.headless=true"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=on-failure
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now tomcat
sudo systemctl status tomcat --no-pager
```

إذا استُخدم JDK 8 من مسار مخصص، يجب تغيير `JAVA_HOME` إلى ذلك المسار، لا إلى مسار OpenJDK 17.

للتطبيق:

```bash
sudo install -o tomcat -g tomcat -m 0644 app.war /opt/tomcat/webapps/app.war
sudo journalctl -u tomcat -f
```

## 3. تغيير منفذ Tomcat إلى 7070

ملف الإعداد الأساسي هو `/opt/tomcat/conf/server.xml`. خذ نسخة احتياطية ثم غيّر منفذ Connector HTTP (غالباً 8080) إلى 7070:

```bash
sudo cp /opt/tomcat/conf/server.xml \
  /opt/tomcat/conf/server.xml.$(date +%Y%m%d%H%M%S).bak
sudo sed -i 's/port="8080" protocol="HTTP\/1.1"/port="7070" protocol="HTTP\/1.1"/' \
  /opt/tomcat/conf/server.xml
sudo systemctl restart tomcat
sudo ss -ltnp | grep ':7070'
```

الـ `sed` يفترض أن شكل Connector مطابق للنص المعتاد. في بيئة حقيقية افحص الملف بعد التعديل، لأن وجود أكثر من Connector أو اختلاف ترتيب السمات قد يجعل الاستبدال لا يطابق شيئاً. لا تفتح 7070 للعامة إذا كان Nginx هو نقطة الدخول؛ اسمح به محلياً أو من شبكة Nginx فقط عبر firewall.

## 4. Nginx كـ reverse proxy على DNS والمنفذ 80

افترض أن اسم DNS هو `app.example.com` وأن Nginx وTomcat على نفس الخادم. سجّل A/AAAA record يشير إلى عنوان الخادم، ثم:

```bash
sudo apt update
sudo apt install -y nginx
sudo tee /etc/nginx/sites-available/app.example.com >/dev/null <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name app.example.com;

    location / {
        proxy_pass http://127.0.0.1:7070;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 60s;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/app.example.com \
  /etc/nginx/sites-enabled/app.example.com
sudo nginx -t
sudo systemctl reload nginx
```

اختبر محلياً وعبر DNS:

```bash
curl -I http://127.0.0.1:7070/
curl -I -H 'Host: app.example.com' http://127.0.0.1/
```

في الإنتاج يجب إضافة HTTPS (مثلاً عبر Certbot/Let's Encrypt)، وتقييد جدار الحماية بحيث يكون 80/443 عاماً و7070 غير عام. إذا كان Tomcat على جهاز آخر، استبدل `127.0.0.1` بعنوانه الخاص، واضبط security group/firewall accordingly.

## 5. Vagrantfile: Bento Ubuntu 24.04، منفذ 7070 إلى 9090، وRAM 2 GB

المطلوب هنا هو تشغيل Ubuntu 24.04 داخل Vagrant، مع تحويل منفذ المضيف `9090` إلى منفذ الضيف `7070`. **لن يتم تشغيل الـ VM ضمن هذه المسودة.** احفظ النص التالي باسم `Vagrantfile` عند الحاجة:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "tomcat9-ubuntu2404"

  # host:9090 -> guest:7070
  config.vm.network "forwarded_port", guest: 7070, host: 9090, protocol: "tcp"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end

  config.vm.provision "shell", path: "provision-tomcat.sh"
end
```

ضع بجانبه `provision-tomcat.sh` التالي. السكربت يتجنب الادعاء بأن `openjdk-8-jdk` متاح على 24.04: يحاول الحصول على JDK 8 من Adoptium/Eclipse Temurin كأرشيف ثنائي، ثم يثبت Tomcat 9. يجب تثبيت checksum وسياسة المصدر في الإنتاج؛ المثال يستخدم API لاكتشاف أحدث حزمة JDK 8 فقط لتقليل تقادم الرابط.

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.XX}"
JAVA8_DIR="/opt/java8"

apt-get update
apt-get install -y curl ca-certificates jq tar gzip

# Ubuntu 24.04 (noble) لا يوفّر عادةً openjdk-8-jdk من مستودعاته القياسية.
# ننزّل JDK 8 ثنائيّاً متوافقاً من Temurin بدلاً من أمر apt مضلل.
JAVA8_URL="$(curl -fsSL \
  'https://api.adoptium.net/v3/assets/latest/8/hotspot?architecture=x64&image_type=jdk&jvm_impl=hotspot&os=linux&vendor=eclipse' \
  | jq -r '.[0].binary.package.link')"

test -n "${JAVA8_URL}" && test "${JAVA8_URL}" != "null"
mkdir -p "${JAVA8_DIR}"
curl -fL "${JAVA8_URL}" -o /tmp/java8.tar.gz

tar -xzf /tmp/java8.tar.gz -C "${JAVA8_DIR}" --strip-components=1
ln -sfn "${JAVA8_DIR}" /opt/java8-current
/opt/java8-current/bin/java -version

id -u tomcat >/dev/null 2>&1 || useradd --system --home-dir /opt/tomcat \
  --create-home --shell /usr/sbin/nologin tomcat

# استبدل XX بإصدار 9.x معتمد. لا تستخدم قيمة وهمية في التنفيذ الفعلي.
if [[ "${TOMCAT_VERSION}" == *XX* ]]; then
  echo "Set TOMCAT_VERSION to a real, approved Tomcat 9.x version" >&2
  exit 2
fi
curl -fL -o /tmp/tomcat.tar.gz \
  "https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
mkdir -p /opt/tomcat
tar -xzf /tmp/tomcat.tar.gz -C /opt/tomcat --strip-components=1
chown -R tomcat:tomcat /opt/tomcat
chmod +x /opt/tomcat/bin/*.sh

# تغيير Connector HTTP من 8080 إلى 7070.
sed -i 's/port="8080" protocol="HTTP\/1.1"/port="7070" protocol="HTTP\/1.1"/' \
  /opt/tomcat/conf/server.xml

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
```

قبل `vagrant up` يجب استبدال `9.0.XX` في السكربت بإصدار حقيقي، ثم تنفيذ `chmod +x provision-tomcat.sh` عند إنشاء الملفات. لا تقوم هذه المسودة بتشغيل الآلة الافتراضية.

## 6. مشكلة Java 8 على Ubuntu 24.04: الحل والقيود

Ubuntu 24.04 (Noble) لا يضمن وجود حزمة `openjdk-8-jdk` في مستودعاته القياسية؛ Java 8 قديمة مقارنةً بإصدارات المنصة، كما أن بعض حزمها تعتمد على مكتبات أو بنية packaging لم تعد متاحة افتراضياً. لذلك فإن وصفة `apt install openjdk-8-jdk` ليست وصفة موثوقة، وقد تفشل برسالة عدم العثور على الحزمة أو dependency conflict.

الخيارات العملية، بالترتيب:

1. **الترقية إلى Java مدعومة من التطبيق** (مثل 17 إن كان WAR وتوابعه متوافقين). هذا أبسط وأفضل تشغيلياً.
2. **استخدام توزيعة/صورة أساس أقدم يدعمها مورد التطبيق**، مثل Ubuntu 20.04/22.04 عند وجود سبب توافق واضح، مع مراعاة دورة الدعم والتحديثات الأمنية. لا ينبغي اختيارها لمجرد إخفاء مشكلة dependency.
3. **تثبيت JDK 8 مدعوم من موزع معروف كأرشيف tar.gz** (مثل Temurin أو توزيعة تجارية لها دعم مؤسسي) في مسار مستقل، وضبط `JAVA_HOME` للخدمة. يجب التحقق من checksum، وترخيص الاستخدام، وتحديثات أمن Java، وتوافق glibc، ومعمارية CPU.
4. **استخدام حاوية/صورة runtime Java 8 رسمية أو مؤسسية** إذا كانت بيئة التشغيل تعتمد containers؛ يجب تثبيت digest للصورة وعدم استخدام tag متحرك فقط.

تثبيت JDK 8 من PPA غير رسمي أو نسخ ملفات من Ubuntu قديم إلى 24.04 قد ينجح مؤقتاً لكنه ليس حلاً إنتاجياً موصى به. كذلك لا يكفي أن يبدأ Tomcat؛ يجب اختبار WAR نفسه (bytecode، JAXB، TLS، native libraries، ونسخ مكتبات التطبيق) واختبار التسجيل والـ health checks. سكربت Vagrant أعلاه يوضح مساراً واقعياً باستخدام JDK 8 ثنائي، لكنه ما زال يحتاج إلى pinning/checksum ومراجعة قانونية وأمنية قبل الإنتاج.

## 7. نقاط تحقق وتسليم

- `java -version` يعرض النسخة التي يتوقعها التطبيق، وليس بالضرورة نسخة النظام الافتراضية.
- `systemctl is-active tomcat` و`ss -ltnp | grep 7070` يؤكدان تشغيل Tomcat وربطه بالمنفذ الصحيح.
- `curl http://127.0.0.1:7070/` يختبر Tomcat مباشرة، بينما `curl http://app.example.com/` يختبر DNS وNginx معاً.
- `nginx -t` يجب أن ينجح قبل reload.
- تفعيل HTTPS، حذف أمثلة Tomcat، تغيير كلمات مرور Manager، وتقييد المنفذ 7070 هي متطلبات hardening وليست تحسينات اختيارية في الإنتاج.
- يلزم تثبيت إصدارات Java وTomcat والـ WAR والتحقق من checksums، مع خطة rollback وسجلات `journalctl` و`/opt/tomcat/logs`.

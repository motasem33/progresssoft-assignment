# مسودة تقييم Linux — ProgressSoft

> **نطاق المسودة:** أوامر وأمثلة عملية قابلة للتنفيذ على Ubuntu Server. لم تُنفَّذ الأوامر الواردة هنا على المضيف، ولا ينبغي تشغيل أوامر إدارة المستخدمين أو الجدار الناري أو كلمات المرور قبل مراجعتها والتأكد من صلاحيات الوصول وخطة الرجوع.

## 1. معلومات النظام ديناميكيًا: `system_info.sh`

السكربت التالي لا يضع قيمًا ثابتة لمعلومات النظام؛ بل يقرأها من أدوات النظام وملفات `/proc` و`/etc`. يُفضَّل تشغيله بحساب عادي، مع استخدام `sudo` فقط إذا كانت بعض القيم تحتاج صلاحيات إضافية.

```bash
#!/usr/bin/env bash
set -u

# system_info.sh — عرض معلومات أساسية عن النظام دون hardcode للقيم

get_value() {
    local label="$1"
    local value="$2"
    printf '%-24s %s\n' "$label" "${value:-N/A}"
}

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
fi

HOSTNAME_VALUE="$(hostname 2>/dev/null || true)"
KERNEL_VALUE="$(uname -r 2>/dev/null || true)"
ARCH_VALUE="$(uname -m 2>/dev/null || true)"
UPTIME_VALUE="$(uptime -p 2>/dev/null || true)"
CPU_VALUE="$(nproc 2>/dev/null || true) logical CPU(s)"
MEM_VALUE="$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 " used / " $2 " total"}')"
DISK_VALUE="$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " used / " $2 " total (" $5 ")"}')"
IPV4_VALUE="$(hostname -I 2>/dev/null | awk '{print $1}')"

printf '%s\n' '=== Linux system information ==='
get_value 'Hostname:' "$HOSTNAME_VALUE"
get_value 'Distribution:' "${PRETTY_NAME:-${NAME:-N/A}}"
get_value 'Kernel:' "$KERNEL_VALUE"
get_value 'Architecture:' "$ARCH_VALUE"
get_value 'Uptime:' "$UPTIME_VALUE"
get_value 'CPU:' "$CPU_VALUE"
get_value 'Memory:' "$MEM_VALUE"
get_value 'Root filesystem:' "$DISK_VALUE"
get_value 'Primary IPv4:' "$IPV4_VALUE"
get_value 'Current user:' "$(id -un 2>/dev/null || true)"
get_value 'Current UID/GID:' "$(id -u 2>/dev/null || true)/$(id -g 2>/dev/null || true)"

printf '\n%s\n' '=== Filesystems ==='
if command -v lsblk >/dev/null 2>&1; then
    lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
else
    printf '%s\n' 'lsblk is not available'
fi

printf '\n%s\n' '=== Listening sockets ==='
if command -v ss >/dev/null 2>&1; then
    ss -tuln
else
    printf '%s\n' 'ss is not available'
fi
```

حفظ الملف وتشغيله:

```bash
mkdir -p ~/bin
nano ~/bin/system_info.sh
chmod 0755 ~/bin/system_info.sh
~/bin/system_info.sh
```

لجمع تفاصيل أكثر عند الحاجة، يمكن إضافة `lscpu`, `lsmem`, `ip -brief address`, و`systemctl --failed`، مع مراعاة أن مخرجاتها تختلف حسب التوزيعة والصلاحيات.

## 2. إنشاء مستخدم `PS` والمجموعات

يُفضَّل استخدام اسم مستخدم Linux بحروف صغيرة (`ps`) لأن أسماء الحسابات الحساسة لحالة الأحرف قد تسبب التباسًا. إذا كان المطلوب حرفيًا هو `PS`، يمكن تمرير الاسم كما هو، لكن يجب اعتماد سياسة تسمية موحّدة في بيئة الإنتاج.

### خيار موصى به: المستخدم `ps`

```bash
# أنشئ المجموعات فقط إذا لم تكن موجودة
sudo groupadd --force psapp
sudo groupadd --force psdb
sudo groupadd --force psops

# أنشئ المستخدم مع home وshell ومنحه المجموعات المطلوبة
sudo useradd --create-home --shell /bin/bash --groups psapp,psdb,psops ps
sudo passwd ps

# تحقق دون طباعة كلمة المرور
id ps
getent group psapp psdb psops
```

إذا كان الحساب موجودًا مسبقًا، لا تُعد تشغيل `useradd`؛ استخدم:

```bash
sudo usermod --append --groups psapp,psdb,psops ps
id ps
```

### إذا كان الاسم المطلوب حرفيًا `PS`

```bash
sudo groupadd --force psapp
sudo groupadd --force psdb
sudo groupadd --force psops
sudo useradd --create-home --shell /bin/bash --groups psapp,psdb,psops PS
sudo passwd PS
id PS
```

لا تمنح صلاحيات `sudo` إلا عند الحاجة. وإذا كانت هناك حاجة إدارية موثقة، فالأفضل إنشاء ملف محدود في `/etc/sudoers.d/` والتحقق منه قبل تفعيله:

```bash
# مثال توضيحي؛ راجع الأوامر المسموحة حسب السياسة قبل الحفظ
sudo visudo -f /etc/sudoers.d/ps
# ثم تحقق:
sudo visudo -cf /etc/sudoers.d/ps
```

## 3. تغيير كلمة مرور root — تحذير أمني

تغيير كلمة مرور `root` عملية حساسة وقد تقطع الوصول إذا فُقدت الكلمة الجديدة. على Ubuntu قد يكون دخول `root` عبر SSH معطّلًا افتراضيًا، وهذا يُعد خيارًا أمنيًا جيدًا. لا تفعّل `PermitRootLogin yes` لمجرد تغيير كلمة المرور.

نفّذ الأمر التالي فقط من جلسة إدارية موثوقة، وبعد التأكد من وجود وسيلة دخول بديلة:

```bash
sudo passwd root
```

سيطلب النظام كلمة المرور الجديدة مرتين ولن يعرضها على الشاشة. بعد ذلك راجع إعداد SSH:

```bash
sudo sshd -T | grep -i '^permitrootlogin'
```

الإعداد الموصى به عادةً هو `PermitRootLogin prohibit-password` أو `no`، مع استخدام حساب إداري محدود وSSH keys. لا تعدّل `/etc/ssh/sshd_config` دون اختبار الصياغة وفتح جلسة بديلة:

```bash
sudo sshd -t
# لا تعِد تشغيل SSH إلا بعد نجاح الاختبار ووجود جلسة بديلة
sudo systemctl reload ssh
```

## 4. تثبيت MySQL على Ubuntu

حدّث فهرس الحزم ثم ثبّت حزمة Ubuntu الرسمية. الإصدار الفعلي سيعتمد على إصدار Ubuntu والمستودعات المفعّلة؛ لذلك لا يُفترض إصدار رقم نسخة ثابت.

```bash
sudo apt update
sudo apt install -y mysql-server mysql-client
sudo systemctl enable --now mysql
sudo systemctl status mysql --no-pager
```

شغّل أداة التقوية التفاعلية بعد مراجعة تأثير كل سؤال:

```bash
sudo mysql_secure_installation
```

تحقق من الخدمة والاتصال المحلي:

```bash
sudo systemctl is-active mysql
sudo mysql -e "SELECT VERSION(), CURRENT_USER();"
```

إذا احتاج التطبيق اتصالًا شبكيًا، لا تفتح MySQL للعالم. اضبط `bind-address` على عنوان واجهة داخلية أو استخدم شبكة خاصة، وقيّد المصدر في الجدار الناري وقواعد MySQL. بعد أي تعديل، اختبر الصياغة وأعد تشغيل الخدمة وفق نافذة تغيير معتمدة:

```bash
sudo grep -R "^[[:space:]]*bind-address" /etc/mysql/ 2>/dev/null
# بعد تعديل ملف الإعداد المناسب:
sudo systemctl restart mysql
sudo ss -ltnp | grep ':3306' || true
```

## 5. تثبيت HAProxy على Ubuntu

```bash
sudo apt update
sudo apt install -y haproxy
sudo systemctl enable haproxy
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl start haproxy
sudo systemctl status haproxy --no-pager
```

ملف الإعداد الرئيسي هو `/etc/haproxy/haproxy.cfg`. قبل أي تغيير، احتفظ بنسخة:

```bash
sudo cp -a /etc/haproxy/haproxy.cfg "/etc/haproxy/haproxy.cfg.$(date +%Y%m%d-%H%M%S).bak"
```

بعد تحرير الإعداد، تحقّق من الصياغة قبل إعادة التشغيل:

```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
```

يجب تصميم `frontend` و`backend` وفق عناوين الخدمة الفعلية، وعدم وضع كلمات مرور أو أسرار مباشرة في ملف الإعداد. إذا كان HAProxy يمرر MySQL، استخدم وضع TCP (`mode tcp`) ومنافذ ومصادر محددة، مع اختبار الاتصال من شبكة مسموحة فقط.

## 6. جدار ناري: السماح بـ TCP/UDP 3306 فقط

> **تحذير وصول:** تطبيق سياسة "3306 فقط" قبل السماح بـ SSH قد يغلق الجلسة الحالية ويمنع الإدارة عن بُعد. يجب معرفة واجهة الإدارة ومصدر SSH، وفتح جلسة بديلة أو استخدام console قبل تطبيق السياسة.

مثال باستخدام UFW. هذا المثال يسمح بـ TCP وUDP على 3306 من أي مصدر، وهو أقل أمانًا من تقييده بعنوان شبكة موثوق؛ استبدل `any` بشبكة التطبيق متى أمكن.

```bash
sudo apt update
sudo apt install -y ufw

# راجع الحالة والقواعد أولًا
sudo ufw status numbered

# ملاحظة مهمة: نفّذ قاعدة SSH قبل التفعيل إذا كانت الإدارة عبر SSH
sudo ufw allow OpenSSH

# السماح بالمطلوب فقط
sudo ufw allow 3306/tcp
sudo ufw allow 3306/udp

# سياسة افتراضية: منع الوارد والسماح بالصادر
sudo ufw default deny incoming
sudo ufw default allow outgoing

# فعّل فقط بعد مراجعة القواعد
sudo ufw enable
sudo ufw status verbose
```

إذا كان المقصود أن يكون 3306 متاحًا فقط من شبكة داخلية، فمثال أكثر أمانًا:

```bash
sudo ufw delete allow 3306/tcp
sudo ufw delete allow 3306/udp
sudo ufw allow from 10.20.0.0/16 to any port 3306 proto tcp
sudo ufw allow from 10.20.0.0/16 to any port 3306 proto udp
sudo ufw status numbered
```

> بروتوكول MySQL المعتاد هو TCP؛ لا تفتح UDP 3306 إلا إذا كان هناك متطلب موثق. يجب أن تتوافق سياسة UFW مع قواعد مزود السحابة أو security groups، إن وجدت.

## 7. نقل الملفات: SCP وSFTP وFTP

### SCP — نسخ آمن عبر SSH

```bash
# من الجهاز المحلي إلى الخادم
scp ./backup.sql ps@server.example:/var/tmp/

# من الخادم إلى الجهاز المحلي
scp ps@server.example:/var/tmp/backup.sql ./

# مجلد كامل
scp -r ./release/ ps@server.example:/var/tmp/release/
```

استخدم مفتاحًا محددًا عند الحاجة، وتحقق من البصمة أول مرة عبر قناة موثوقة:

```bash
scp -i ~/.ssh/id_ed25519 ./file ps@server.example:/var/tmp/
```

### SFTP — جلسة تفاعلية آمنة

```bash
sftp ps@server.example
# داخل الجلسة:
# put local-file /var/tmp/local-file
# get /var/tmp/remote-file ./remote-file
# put -r local-dir /var/tmp/local-dir
# ls, pwd, lpwd, exit
```

يمكن تقييد مستخدم نقل الملفات عبر `internal-sftp` و`ChrootDirectory` في SSH، لكن يجب اختبار الإعداد في جلسة منفصلة قبل إعادة تحميل الخدمة.

### FTP — غير مشفّر افتراضيًا

FTP التقليدي يرسل بيانات الاعتماد والبيانات دون تشفير، لذلك لا يُنصح به عبر الإنترنت. إذا فرض نظام قديم استخدامه، استخدم FTPS (TLS) أو استبدله بـ SFTP، وقيّد المصدر والجدار الناري وسجّل العمليات. لا تضع كلمة المرور في سطر الأوامر أو في ملفات نصية مكشوفة.

مثال عميل FTP تفاعلي (لشبكة موثوقة فقط وبعد اعتماد المخاطر):

```bash
ftp ftp.example.com
# ثم استخدم get/put، وأغلق الجلسة بـ bye
```

## 8. ملخص Architecture / Directories / Distributions

### Architecture

- **طبقة الوصول:** SSH للإدارة، وSFTP/SCP لنقل الملفات الآمن.
- **طبقة التوجيه/التوازن:** HAProxy يستقبل الاتصالات على الواجهة والمنفذ المحددين ويمررها إلى خوادم backend وفق health checks.
- **طبقة قاعدة البيانات:** MySQL؛ المنفذ المعتاد TCP/3306، ويجب تقييد الاستماع والمصادر والجدار الناري.
- **الأمان:** أقل صلاحية ممكنة، مفاتيح SSH، عدم تمكين دخول root عبر كلمة مرور، UFW أو جدار سحابي، وتسجيل ومراقبة الخدمات.
- **التشغيل:** `systemctl` لإدارة الخدمات، `journalctl` للسجلات، و`apt` للحزم.

### Directories المهمة

| المسار | الاستخدام |
|---|---|
| `/etc` | إعدادات النظام والخدمات؛ مثل `/etc/haproxy/` و`/etc/mysql/` و`/etc/ssh/` |
| `/var/log` | سجلات النظام والخدمات؛ يمكن استخدام `journalctl` مع systemd |
| `/var/lib/mysql` | بيانات MySQL؛ لا تُحذف أو تُنسخ أثناء التشغيل دون خطة نسخ احتياطي متسقة |
| `/var/lib` | بيانات حالة التطبيقات والخدمات |
| `/home/<user>` | ملفات المستخدمين ومفاتيح SSH في `.ssh/` |
| `/var/tmp` | ملفات مؤقتة تبقى عادةً بعد إعادة التشغيل؛ لا تستخدمه للأسرار طويلة الأجل |
| `/tmp` | ملفات مؤقتة؛ صلاحياته وسياسة تنظيفه تختلف حسب النظام |
| `/usr/bin`, `/usr/sbin` | برامج النظام التنفيذية |
| `/opt` | تطبيقات خارجية اختيارية |
| `/run` | بيانات تشغيل مؤقتة مثل PID وsockets |
| `/proc`, `/sys` | واجهات افتراضية لمعلومات النواة والأجهزة |

### Distributions

- **Ubuntu/Debian:** تستخدم `apt` و`.deb`، وUbuntu Server شائع للخوادم؛ أوامر هذه المسودة تستهدف Ubuntu.
- **RHEL/CentOS/Rocky/AlmaLinux:** تستخدم غالبًا `dnf`/`yum` و`.rpm`، وقد تستخدم SELinux بدل AppArmor؛ لا تنقل أوامر Ubuntu حرفيًا دون تكييف.
- **Alpine:** تستخدم `apk` وmusl libc، وقد تختلف مسارات الخدمات وإدارة init.
- **الفروق التشغيلية:** أسماء الحزم، ملفات إعداد MySQL/HAProxy، قواعد الجدار الناري (`ufw` مقابل `firewalld`/`nftables`)، واسم خدمة SSH قد تختلف. ابدأ دائمًا بتحديد التوزيعة عبر `/etc/os-release` وراجع وثائق الإصدار.

## 9. قائمة تحقق قبل التنفيذ

```bash
cat /etc/os-release
whoami
hostname
ip -brief address
sudo ss -tulpen
sudo ufw status verbose 2>/dev/null || true
```

- وثّق نافذة التغيير ووسيلة الرجوع.
- تأكد من وجود جلسة console أو جلسة SSH بديلة قبل تعديل SSH/UFW.
- استخدم أسرارًا خارج المستودع ودوّر كلمات المرور/المفاتيح عند الاشتباه بتسربها.
- اختبر إعدادات HAProxy وSSH قبل reload/restart.
- لا تعتبر مخرجات الأوامر دليلًا على نجاح التنفيذ إلا بعد تشغيلها فعليًا والتحقق من الحالة والسجلات.

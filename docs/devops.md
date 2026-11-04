# مسودة تقنية — قسم DevOps

> **نطاق المسودة:** هذه أمثلة تعليمية قابلة للتكييف مع بيئة ProgressSoft. جميع أسماء النطاقات والسجلات والصور والبيانات السرية أدناه placeholders، ولم يتم تنفيذ أي عملية `push` أو نشر `deploy` فعلي.

## 1. نظرة عامة على DevOps

**DevOps** هو مجموعة ممارسات وثقافة وأدوات تهدف إلى تقليل الفجوة بين فرق التطوير (Development) والتشغيل (Operations)، وتسريع تسليم البرمجيات مع تحسين الجودة والاستقرار والأمان. لا يقتصر DevOps على أداة واحدة؛ بل يشمل دورة حياة متكاملة:

1. **Plan:** تحديد المتطلبات والأولويات.
2. **Code:** إدارة الشفرة عبر Git ومراجعات Pull Request.
3. **Build:** إنشاء artifacts أو صور حاويات قابلة للتكرار.
4. **Test:** اختبارات الوحدة والتكامل والأمان والأداء.
5. **Release:** اعتماد الإصدار وإدارة الإصدارات.
6. **Deploy:** نشر آلي أو مضبوط إلى بيئات الاختبار والإنتاج.
7. **Operate:** تشغيل الخدمات ومراقبتها.
8. **Monitor/Feedback:** جمع المقاييس والسجلات والتنبيهات وتحسين النظام.

### ممارسات موصى بها

- Infrastructure as Code وتهيئة البيئات بطريقة قابلة لإعادة الإنتاج.
- CI/CD مع بوابات جودة ومراجعة بشرية قبل الإنتاج عند الحاجة.
- إدارة أسرار خارج الشفرة (Vault/Secrets Manager/Kubernetes Secrets مع ضوابط مناسبة).
- أقل صلاحية ممكنة، ومسح صور الحاويات والاعتماديات بحثاً عن الثغرات.
- Observability تشمل logs وmetrics وtraces، مع تعريف SLI/SLO ووقت الاستعادة.
- Rollback واضح وعمليات تغيير موثقة.

## 2. Docker

**Docker** منصة لتغليف التطبيق واعتمادياته داخل **حاويات Containers** معزولة نسبياً تشترك في نواة نظام التشغيل. الصورة Image قالب غير قابل للتغيير عادةً، والحاوية Container نسخة تشغيلية من الصورة.

### مفاهيم أساسية

- **Image:** طبقات ثابتة تُبنى من Dockerfile.
- **Container:** عملية معزولة تشغّل صورة.
- **Registry:** مستودع للصور، مثل Docker Hub أو سجل مؤسسي خاص.
- **Volume:** تخزين دائم خارج دورة حياة الحاوية.
- **Network:** شبكة لربط الحاويات.
- **Tag/Digest:** وسم وصفي أو بصمة immutable للصورة؛ يفضّل الإنتاج استخدام digest أو tag مُرقّم لا `latest`.

### Dockerfile لـ Tomcat 9 مع WAR placeholder

الملف التالي يفترض وجود artifact باسم `sample-app.war` في مجلد `app/`. هذا ملف placeholder ويجب استبداله بملف WAR حقيقي ناتج من build موثوق.

```dockerfile
# Dockerfile.tomcat9
FROM tomcat:9.0-jdk11-temurin

# لا نستخدم latest في صورة التطبيق؛ يمكن تثبيت digest في الإنتاج.
LABEL org.opencontainers.image.title="sample-tomcat-app"

# إزالة التطبيقات الافتراضية اختيارية حسب سياسة المؤسسة.
RUN rm -rf /usr/local/tomcat/webapps/*

# Placeholder: يجب وضع WAR الحقيقي في app/sample-app.war قبل البناء.
COPY app/sample-app.war /usr/local/tomcat/webapps/ROOT.war

# تشغيل Tomcat كمستخدم غير root إن كان متاحاً في الصورة/السياسة.
# راجع صلاحيات المجلدات قبل تفعيل ذلك في بيئة الإنتاج.
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -f http://127.0.0.1:8080/ || exit 1

CMD ["catalina.sh", "run"]
```

هيكل الملفات المقترح:

```text
.
├── Dockerfile.tomcat9
└── app/
    └── sample-app.war   # placeholder — ليس artifact فعلياً
```

ملاحظات أمنية وتشغيلية:

- لا تُضمّن كلمات المرور أو مفاتيح API في Dockerfile.
- ثبّت نسخ الصور واعمل image scanning قبل النشر.
- استخدم `.dockerignore` لاستبعاد `.git` وملفات الأسرار وسجلات التشغيل.
- راجع إعدادات JVM وذاكرة Tomcat وفق حدود الحاوية.

## 3. Docker Compose: Nginx وPostgreSQL

المثال التالي يشغّل Nginx كواجهة أمامية وPostgreSQL كقاعدة بيانات للتطوير أو الاختبار المحلي. ليس بديلاً عن تصميم HA لقاعدة البيانات في الإنتاج.

```yaml
# docker-compose.yml
services:
  nginx:
    image: nginx:1.27-alpine
    container_name: ps-nginx
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - ps-net

  postgres:
    image: postgres:16-alpine
    container_name: ps-postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-sampledb}
      POSTGRES_USER: ${POSTGRES_USER:-sampleuser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?set-in-.env}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - ps-net

volumes:
  postgres-data:

networks:
  ps-net:
    driver: bridge
```

مثال `nginx/default.conf`:

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://postgres:5432; # غير صالح كـ HTTP proxy؛ مثال توضيحي فقط
    }
}
```

> **تنبيه:** PostgreSQL ليس خادماً HTTP، لذلك لا ينبغي توجيه Nginx إليه بهذه الصورة في تطبيق حقيقي. في التصميم الفعلي يوجّه Nginx إلى خدمة ويب/ Tomcat، بينما يتصل التطبيق بـ PostgreSQL على المنفذ 5432 عبر شبكة داخلية. يمكن استخدام `nginx:alpine` مع `proxy_pass http://app:8080;` عند إضافة خدمة التطبيق.

أوامر التشغيل المحلي:

```bash
cp .env.example .env  # إن وُجد، ثم ضع كلمة مرور محلية غير إنتاجية
# لا تعرض .env ولا ترفعه إلى Git

docker compose config
docker compose up -d
docker compose ps
docker compose logs -f nginx
docker compose down
# لحذف البيانات أيضاً (تحذير: destructive): docker compose down -v
```

## 4. أوامر بناء الصور ووسمها ودفعها إلى Registry

القيم التالية placeholders. يجب تسجيل الدخول والمصادقة وفق سياسة المؤسسة، لكن **لم تُنفّذ هذه الأوامر هنا**.

```bash
export REGISTRY="registry.example.com"
export NAMESPACE="progresssoft-placeholder"
export VERSION="0.1.0"
export IMAGE="${REGISTRY}/${NAMESPACE}/sample-tomcat"

# Build محلياً:
docker build -f Dockerfile.tomcat9 -t "${IMAGE}:${VERSION}" .

# Tag إضافي اختياري للإشارة إلى commit:
export GIT_SHA="<commit-sha>"
docker tag "${IMAGE}:${VERSION}" "${IMAGE}:${GIT_SHA}"

# فحص محلي اختياري:
docker image inspect "${IMAGE}:${VERSION}"
# docker scout cves "${IMAGE}:${VERSION}"  # إذا كانت الأداة متاحة

# تسجيل الدخول — نفّذ فقط في بيئة مصرح بها:
# docker login "${REGISTRY}"

# Push — placeholder ولم يتم تنفيذه:
# docker push "${IMAGE}:${VERSION}"
# docker push "${IMAGE}:${GIT_SHA}"
```

في بيئة الإنتاج يُفضّل نشر digest الناتج عن registry بدلاً من الاعتماد على tag قابل لإعادة التوجيه، وتطبيق سياسات توقيع/تحقق للصور عند الإمكان.

## 5. Kubernetes

**Kubernetes** منصة orchestration لإدارة الحاويات على مجموعة من العقد. توفر جدولة الحاويات، الخدمة والاكتشاف، التوسعة، health checks، rolling updates، وإدارة configuration/secrets.

### Master/Control Plane وWorker

- **Control Plane (المسمى تاريخياً Master):** يدير الحالة المطلوبة للمجموعة. يتضمن عادةً API Server وScheduler وController Manager وetcd. في الإنتاج يُنصح بتوزيع مكونات control plane لتحقيق HA.
- **Worker Node:** يشغّل أحمال العمل عبر kubelet وcontainer runtime وkube-proxy/بدائله. تُجدول عليه Pods.
- **Pod:** أصغر وحدة نشر، وقد تحتوي حاوية واحدة أو أكثر تشترك في الشبكة والتخزين.
- **Deployment:** يصف عدد replicas واستراتيجية التحديث ويعيد إنشاء Pods غير السليمة.
- **Service:** عنوان ثابت واكتشاف لخدمة Pods؛ قد يكون ClusterIP أو NodePort أو LoadBalancer.

### Kubernetes Deployment وService sample

```yaml
# k8s/sample-tomcat.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-tomcat
  namespace: ps-demo
  labels:
    app: sample-tomcat
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: sample-tomcat
  template:
    metadata:
      labels:
        app: sample-tomcat
    spec:
      containers:
        - name: tomcat
          image: registry.example.com/progresssoft-placeholder/sample-tomcat:0.1.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 20
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 60
            periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: sample-tomcat
  namespace: ps-demo
spec:
  selector:
    app: sample-tomcat
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: http
```

> يجب إنشاء namespace وتوفير image في registry متاح للعنقود، أو إعداد `imagePullSecrets` وفقاً لذلك. الملف أعلاه نموذج فقط ولم يُطبّق على أي cluster.

### أوامر `kubectl` شائعة (غير منفذة)

```bash
# kubectl config current-context
# kubectl get nodes
# kubectl get namespaces
# kubectl create namespace ps-demo
# kubectl apply -f k8s/sample-tomcat.yaml
# kubectl get deployment,pods,svc -n ps-demo
# kubectl describe pod -n ps-demo <pod-name>
# kubectl logs -n ps-demo deploy/sample-tomcat
# kubectl rollout status deployment/sample-tomcat -n ps-demo
# kubectl rollout history deployment/sample-tomcat -n ps-demo
# kubectl rollout undo deployment/sample-tomcat -n ps-demo
# kubectl delete -f k8s/sample-tomcat.yaml
```

نقاط مهمة قبل الإنتاج: NetworkPolicies، Pod Security، RBAC، resource quotas، anti-affinity، PDB، إدارة الأسرار، ingress controller، autoscaling، backup لـ etcd، ومراقبة cluster وapplication.

## 6. Git

**Git** نظام موزع لإدارة إصدارات الشفرة. كل clone يحتوي تاريخاً محلياً، ما يسمح بالعمل دون اتصال ثم مشاركة التغييرات عبر remote.

مصطلحات: repository، working tree، staging area، commit، branch، merge/rebase، tag، remote، Pull Request.

سير عمل آمن نموذجي:

```bash
git clone https://github.com/<ORG>/<REPO>.git
cd <REPO>
git switch -c feat/devops-sample

# بعد إنشاء/تعديل الملفات:
git status
git diff
git add Dockerfile.tomcat9 docker-compose.yml k8s/sample-tomcat.yaml
git diff --cached
git commit -m "Add DevOps deployment samples"

# تحديث الفرع الأساسي قبل فتح PR:
git fetch origin
git rebase origin/main
# git push -u origin feat/devops-sample  # لم يُنفذ
```

لا تُضمّن أسراراً في Git. استخدم `.gitignore` وsecret scanning، واجعل commits صغيرة قابلة للمراجعة، واحمِ الفرع الأساسي بمراجعات وفحوص CI.

## 7. GitHub CLI (gh)

الأوامر الآتية أمثلة لأتمتة GitHub CLI؛ placeholders ولم تُنفّذ.

```bash
# gh auth status
# gh auth login

export ORG="<ORG>"
export REPO="<REPO>"
export BRANCH="feat/devops-sample"

# عرض المستودع والقضايا:
# gh repo view "${ORG}/${REPO}"
# gh issue list --repo "${ORG}/${REPO}"

# إنشاء Pull Request بعد push مصرح به:
# gh pr create --repo "${ORG}/${REPO}" \
#   --base main --head "${BRANCH}" \
#   --title "Add DevOps deployment samples" \
#   --body "Adds Docker, Compose, and Kubernetes examples."

# مراجعة حالة PR:
# gh pr status --repo "${ORG}/${REPO}"
# gh pr checks <PR_NUMBER> --repo "${ORG}/${REPO}"
# gh pr view <PR_NUMBER> --repo "${ORG}/${REPO}"
```

## 8. RAID والتخزين

**RAID (Redundant Array of Independent Disks)** يجمع عدة أقراص لتحسين التوافر أو الأداء أو تحمّل فشل قرص، لكنه **ليس بديلاً عن النسخ الاحتياطي**.

| المستوى | الفكرة | تحمّل الفشل/الملاحظات |
|---|---|---|
| RAID 0 | Striping بلا redundancy | أداء وسعة جيدان، لكن فشل قرص واحد يفقد المصفوفة كلها |
| RAID 1 | Mirroring | يتحمل عادة فشل قرص واحد؛ سعة فعالة تقريباً نصف الخام |
| RAID 5 | Striping مع parity | يتحمل فشل قرص واحد؛ rebuild قد يكون طويلاً |
| RAID 6 | Parity مزدوجة | يتحمل فشل قرصين؛ كتابة/إعادة بناء أعلى كلفة |
| RAID 10 | Mirroring + striping | أداء وتحمّل جيدان؛ يتطلب أربعة أقراص أو أكثر عادة |

ينبغي اختيار المستوى وفق IOPS والسعة وRTO/RPO ونوع الحمل، مع مراقبة SMART/health، spare مناسب، اختبارات استعادة، ونسخ احتياطي منفصل ومشفّر.

## 9. HA وDR

**High Availability (HA)** يهدف إلى تقليل الانقطاع داخل الموقع أو الخدمة، عبر التكرار وإزالة نقاط الفشل المفردة. أمثلة: عدة instances خلف load balancer، عقد control plane متعددة، قاعدة بيانات primary/standby أو cluster، وhealth checks مع failover.

**Disaster Recovery (DR)** يركز على استعادة الخدمة بعد كارثة أكبر مثل فقدان منطقة أو مركز بيانات أو فساد واسع للبيانات. يشمل موقعاً بديلاً، نسخاً احتياطية خارجية/غير قابلة للتغيير، replication، runbooks واختبارات دورية.

- **RTO:** أقصى زمن مقبول لاستعادة الخدمة.
- **RPO:** أقصى مقدار بيانات مقبول فقده زمنياً.
- لا يكفي قول "لدينا backup"؛ يجب اختبار restore وقياس RTO/RPO وتوثيق المسؤوليات.
- صمّم للـ failure domains، وافصل بيانات النسخ الاحتياطي عن الحساب/الشبكة الأساسية، واستخدم تشفيراً وإدارة مفاتيح مناسبة.

## 10. Cloud: SaaS / PaaS / IaaS

| النموذج | ما يديره مزود السحابة | ما يديره العميل | أمثلة عامة |
|---|---|---|---|
| **SaaS** | التطبيق، المنصة، البنية التحتية والتحديثات | المستخدمون والبيانات والإعدادات والصلاحيات | بريد مؤسسي أو نظام CRM مستضاف |
| **PaaS** | البنية التحتية ونظام التشغيل وruntime غالباً | شفرة التطبيق والبيانات والإعدادات | منصة تشغيل تطبيقات مُدارة |
| **IaaS** | مراكز البيانات والعتاد والافتراضية | نظام التشغيل، الشبكات المنطقية، middleware والتطبيق والبيانات | آلات افتراضية وشبكات وأقراص |

كلما انتقلنا من IaaS إلى SaaS تقل مسؤولية التشغيل اليومية، لكن تبقى مسؤولية العميل عن الهوية، الصلاحيات، تصنيف البيانات، الإعدادات، الامتثال، والنسخ الاحتياطي وفق نموذج المسؤولية المشتركة. يجب تقييم SLA، lock-in، موقع البيانات، التشفير، سجلات التدقيق والتكلفة.

## 11. DNS وLoad Balancers

**DNS** يحوّل أسماء النطاقات إلى عناوين أو خدمات. سجلات شائعة:

- `A` لعنوان IPv4 و`AAAA` لعنوان IPv6.
- `CNAME` اسم مستعار لاسم آخر.
- `MX` لخوادم البريد.
- `TXT` للتحقق وسياسات مثل SPF/DKIM/DMARC.
- `NS` لخوادم الأسماء.
- `TTL` يحدد مدة التخزين المؤقت، ويؤثر في سرعة انتشار التغييرات.

**Load Balancer** يوزع الطلبات على عدة backends، وقد يعمل في الطبقة 4 (TCP) أو الطبقة 7 (HTTP/HTTPS). وظائفه قد تشمل TLS termination، health checks، session persistence، rate limiting، WAF، وrouting حسب host/path.

تصميم نموذجي: `app.example.com` في DNS يشير إلى عنوان/اسم load balancer؛ يقوم الـLB بفحص صحة عدة instances أو Pods، ويرسل الطلبات إلى السليم منها. لا ينبغي اعتبار DNS وحده بديلاً عن health-aware failover، كما يجب ضبط TLS، timeouts، connection draining، سجلات الوصول، وX-Forwarded-* بعناية.

## 12. قائمة تحقق قبل اعتماد الحل

- [ ] استبدال كل placeholders بقيم معتمدة دون إدخال أسرار في Git.
- [ ] بناء الصور من مصدر موثوق ومسحها وتوقيعها عند الإمكان.
- [ ] إضافة CI لتشغيل الاختبارات وlint وscan والتحقق من manifests.
- [ ] اختبار Docker Compose محلياً، مع فصل إعدادات التطوير عن الإنتاج.
- [ ] مراجعة readiness/liveness والموارد والتوسعة وPDB في Kubernetes.
- [ ] توثيق RTO/RPO، النسخ الاحتياطي، والاستعادة واختبار DR.
- [ ] التحقق من HA عبر failure drills وعدم وجود single point of failure.
- [ ] تأمين DNS وTLS وload balancer ومراقبة السجلات والمقاييس.
- [ ] تنفيذ أي `push` أو `deploy` فقط من بيئة مصرح بها وبعد اعتماد التغيير؛ لم تُنفذ تلك العمليات ضمن هذه المسودة.

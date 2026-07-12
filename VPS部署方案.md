# 一人企业 VPS 部署方案：从零到上线

> 面向海外用户 | 月预算 ¥50-150 | 后端 + 数据库 + 移动端

---

## 一、你的企业微信域名：能用，但建议补一个

### 你手里的是什么？

企业微信给已验证企业的免费域名有两种：

| 类型 | 格式 | 能用于生产吗 |
|------|------|------------|
| **免费 .com 域名**（推荐） | `xxx.com` | ✅ 可以，过户到腾讯云后就是普通域名 |
| **试用/默认域名** | `xxx.wecom.work` | ❌ 不能，功能受限，只适合内部邮箱 |

你需要确认你是哪一种。进企业微信管理后台 → 协作 → 邮件 → 域名管理，如果显示的是 `.com` 结尾的独立域名，说明你拿的是第一种。

### 免费 .com 域名的利弊

**优点：**
- 免费，省了一笔域名注册费（约 ¥50-80/年）
- 可以过户到自己的腾讯云账号，拥有完整 DNS 管理权
- 可以正常绑定 VPS、配 A 记录、申请 SSL 证书
- 可以对接 Cloudflare（把 NS 服务器改过去即可）

**缺点：**
- 域名在腾讯云体系内，海外 DNS 解析速度不如 Cloudflare
- 第一年免费，续费按正常价格（.com 约 ¥70/年）
- 你面向海外用户，域名注册商在中国，管理上不如国际注册商方便

### 建议方案

**保留企业微信域名**用于邮箱和企业微信应用回调，**额外在 Cloudflare 买一个域名**用于对外服务。

Cloudflare 卖域名按成本价（零加价），.com 约 $9.5/年（¥70/年），好处是：
- 全球 CDN 免费，海外用户访问快
- DNS 解析全球最快
- 免费 DDoS 防护
- SSL 证书一键签发
- 跟你的 VPS 搭配无缝

如果你的企业微信域名过户后改到 Cloudflare 做 DNS，其实也可以一个域名通吃。**结论：域名这块问题不大，暂时用企业微信给的那个就行，后续觉得不好再补一个也不贵。**

---

## 二、VPS 推荐：先抢 Oracle Cloud，不行就 CloudCone 月付

按优先级排：

| | 🥇 Oracle Cloud | 🥈 CloudCone 月付 | 🥉 RackNerd 年付 |
|---|---|---|---|
| 月费 | **¥0（永久免费）** | ¥28（$3.91） | ¥18（$29.98/年付） |
| CPU | 4 核 ARM | 4 核 | 3 核 |
| 内存 | **24 GB** | 4 GB | 4 GB |
| 硬盘 | 200 GB | 55 GB | 65 GB |
| 流量 | 10 TB | 4 TB | 6.5 TB |
| 支付 | 需 Visa/MC 卡（验证不扣费） | **支付宝** | **支付宝** |
| 跑路风险 | 甲骨文倒闭≈零 | 月付，最多亏 ¥28 | 年付，亏 ¥215 |
| 机房 | 美西/美东/东京/首尔等 | 洛杉矶 | 美国多城市 |

### 策略：按顺序试，不锁死

**第一步：冲 Oracle Cloud（免费，24GB 内存，甲骨文级稳定）**

需要：一张 Visa 或 Mastercard 信用卡/储蓄卡（仅验证，不扣费）。

注册避坑清单：
- **邮箱**：用 Outlook 或 Gmail，别用 QQ 邮箱
- **网络**：家庭宽带真实 IP 或用手机 5G 热点，**绝对别挂代理**
- **浏览器**：Chrome 无痕模式，换着 Safari（iPad/iPhone）试成功率更高
- **姓名**：用拼音，和信用卡上的一致
- **密码**：≥12 位，含大小写+数字+符号，密码里**不能包含你姓名的拼音**
- **区域**：选美西（Phoenix/San Jose）或美东（Ashburn），别选东京/首尔（抢不到 ARM 机器）
- **邮编**：必须和城市匹配
- **信用卡**：招行 Visa/Mastercard 双币卡或储蓄卡（卡里存 900 块）成功率最高

注册地址：**signup.cloud.oracle.com**

注册时会扣 $1 预授权（验证后退回）。如果页面转圈后红色感叹号——这就是著名的 "ABC 错误"，即被风控直接拒了。被拒别连续重试，换网络/浏览器/半月后再试。同一张卡被拒 2 次以上进黑名单。

**第二步：Oracle 没过 → CloudCone 月付（¥28/月，随时跑）**

$3.91/月 = ¥28，4 核 4GB，支付宝，按小时计费，随时删机。跑路最多亏 ¥28。

为什么不是 RackNerd？RackNerd 月付要 $10/月反而贵，年付锁死 ¥215。CloudCone 月付既便宜又灵活。

**第三步：如果非要年付省钱 → RackNerd ¥18/月**

$29.98/年付，支付宝，3 核 4GB 65GB。要能接受 ¥215 年付锁死。

**备选：CloudCone $28.99/年**，配置类似（6 核/4GB/60GB），优势是支持按小时计费，方便临时测试。

### 支付方式说明

| 支付方式 | RackNerd | CloudCone | Hetzner | Vultr |
|----------|----------|-----------|---------|-------|
| **支付宝** | ✅ | ✅ | ❌ | ✅ |
| 微信支付 | ✅ | ❌ | ❌ | ⚠️ |
| PayPal | ✅ | ✅ | ✅ | ✅ |
| 信用卡 | ✅ | ✅ | ✅ | ✅ |

> **关键差异**：Hetzner 虽然便宜（€4.59/月），但需要 Visa/Mastercard 信用卡或 PayPal，没有支付宝/微信，且对中国用户有身份验证。RackNerd/CloudCone 支付宝扫个码就搞定，零门槛。

---

## 三、完整部署方案（从零到上线）

### 架构概览

```
用户（海外）
    │
    ▼
Cloudflare（DNS + CDN + SSL）
    │
    ▼
VPS（Oracle Cloud / CloudCone / RackNerd）
    ├── Nginx（反代 + HTTPS）
    ├── Docker Compose
    │   ├── 后端服务（Node.js / Python / Go）
    │   ├── PostgreSQL / MySQL
    │   ├── Redis（缓存，可选）
    │   └── 定时任务 / Bot
    └── 防火墙（UFW）
```

### 第一步：买机器（Oracle → CloudCone → RackNerd 按顺序试）

**优先：Oracle Cloud 免费（需信用卡验证）**

1. 打开 **signup.cloud.oracle.com**
2. 国家选 China，姓名用拼音（和信用卡一致），邮箱用 Outlook/Gmail
3. 选主区域：**US East (Ashburn)** 或 **US West (Phoenix)**——ARM 机器容易开到
4. 填信用卡：招行 Visa/MC 双币卡或储蓄卡（验证扣 $1，3-7 天退回）
5. 密码 ≥12 位，大小写+数字+符号，**密码里不能有你的姓名拼音**
6. 提交，等转圈——进控制台 = 成功，红色叹号 = ABC 被拒

**备选：CloudCone 月付（支付宝，$3.91/月）**

1. 打开 **cloudcone.com** → 注册 → Billing 充值（支付宝扫码）
2. 点 **Deploy Server** → 选 SC2 或 SSD VPS → 4GB 套餐
3. 操作系统：**Ubuntu 24.04**
4. 机房：**Los Angeles**
5. 点 **Deploy**，几分钟后邮箱收到 IP 和密码

**最后备选：RackNerd 年付（支付宝，$29.98/年）**

1. 打开 **racknerd.com** → Black Friday / Promotions
2. 找 4GB / 3 vCPU / 65GB / $29.98 年付套餐 → Order Now
3. 支付宝扫码 ¥215

机器拿到 IP 后，SSH 进去：

```bash
ssh root@你的VPS的IP
```

进去后先做安全基础配置：

```bash
# 更新系统
apt update && apt upgrade -y

# 创建普通用户（别用 root 日常操作）
adduser deploy
usermod -aG sudo deploy

# 配置 SSH 密钥登录（禁止密码登录）
# 把本机公钥复制过去后，编辑 /etc/ssh/sshd_config：
#   PermitRootLogin no
#   PasswordAuthentication no
systemctl restart sshd

# 开防火墙
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# 时区
timedatectl set-timezone UTC
```

### 第二步：装 Docker + Docker Compose（5 分钟）

```bash
# 官方一键脚本
curl -fsSL https://get.docker.com | sudo bash

# 把 deploy 用户加入 docker 组
sudo usermod -aG docker deploy

# 退出重新登录后测试
docker run hello-world
```

### 第三步：域名绑 VPS（10 分钟）

在域名 DNS 管理后台添加一条 A 记录：

| 类型 | 主机记录 | 记录值 |
|------|---------|--------|
| A | @ | VPS 的 IP |
| A | www | VPS 的 IP |

> 如果用的是 Cloudflare 做 DNS，建议开启代理（橙色云朵），免费获得 CDN 和 DDoS 防护。

### 第四步：Nginx + 免费 HTTPS（10 分钟）

```bash
# 装 Nginx
sudo apt install nginx certbot python3-certbot-nginx -y

# 创建站点配置
sudo nano /etc/nginx/sites-available/你的域名
```

Nginx 配置模板：

```nginx
server {
    listen 80;
    server_name 你的域名.com www.你的域名.com;

    # 后端 API 反代
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 静态前端（如果有的话）
    location / {
        root /var/www/html;
        index index.html;
    }
}
```

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/你的域名 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 申请免费 SSL 证书（Let's Encrypt）
sudo certbot --nginx -d 你的域名.com -d www.你的域名.com

# 证书会自动续期，验证一下
sudo certbot renew --dry-run
```

### 第五步：部署你的应用（用 Docker Compose）

在 `/home/deploy/app/` 下创建 `docker-compose.yml`：

```yaml
version: "3.8"

services:
  # PostgreSQL 数据库
  db:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: app_production
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"  # 只绑本地，不暴露公网

  # Redis（可选，做缓存/任务队列）
  redis:
    image: redis:7-alpine
    restart: always
    volumes:
      - redisdata:/data
    ports:
      - "127.0.0.1:6379:6379"

  # 你的后端服务（以 Node.js 为例）
  backend:
    build: ./backend
    restart: always
    environment:
      DATABASE_URL: postgresql://app:${DB_PASSWORD}@db:5432/app_production
      REDIS_URL: redis://redis:6379
      NODE_ENV: production
    ports:
      - "127.0.0.1:3000:3000"
    depends_on:
      - db
      - redis

  # 定时任务 / Bot（以 Go 为例）
  worker:
    build: ./worker
    restart: always
    environment:
      DATABASE_URL: postgresql://app:${DB_PASSWORD}@db:5432/app_production
    depends_on:
      - db

volumes:
  pgdata:
  redisdata:
```

配套的 `.env` 文件：

```bash
# 生成强密码：openssl rand -base64 32
DB_PASSWORD=改成你生成的随机密码
```

启动：

```bash
cd /home/deploy/app
docker compose up -d

# 查看运行状态
docker compose ps

# 查看日志
docker compose logs -f
```

### 第六步：自动部署（GitHub Actions CI/CD）

在项目仓库创建 `.github/workflows/deploy.yml`：

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: deploy
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd /home/deploy/app
            git pull origin main
            docker compose up -d --build
            docker compose exec -T backend npx prisma migrate deploy  # 如果有数据库迁移
```

在 GitHub 仓库的 Settings → Secrets → Actions 里添加：
- `VPS_HOST`：VPS 的 IP
- `VPS_SSH_KEY`：deploy 用户的私钥

以后 `git push main` 就自动部署。

### 第七步：日常维护

```bash
# 定时任务 crontab
crontab -e
# 每天凌晨 3 点备份数据库
0 3 * * * docker exec app-db-1 pg_dump -U app app_production > /home/deploy/backups/$(date +\%Y\%m\%d).sql

# 每周日凌晨 4 点清理旧日志和 Docker 垃圾
0 4 * * 0 docker system prune -af && journalctl --vacuum-time=7d
```

```bash
# 监控内存/CPU
htop

# 监控磁盘
df -h

# 查看 Docker 资源占用
docker stats
```

---

## 四、成本总览

| 项目 | 月费 |
|------|------|
| **Oracle Cloud**（4核/24GB/200GB） | **¥0** |
| 或 CloudCone（4核/4GB/55GB）月付 | ¥28 |
| Cloudflare CDN + DNS | 免费 |
| Let's Encrypt SSL | 免费 |
| **合计** | **¥0 ～ ¥28/月** |

不管哪种都远在 ¥50-150 预算之内。Oracle 免费层是梦幻配置——24GB 内存足够跑你所有服务加上一堆实验项目。

---

## 五、行动清单

按顺序来，别跳步：

1. ⬜ 确认企业微信域名的类型（.com 还是 wecom.work）
2. ⬜ 拿出你的 Visa/Mastercard 信用卡或储蓄卡
3. ⬜ 打开 **signup.cloud.oracle.com**，按避坑清单注册 Oracle Cloud
4. ⬜ 成了 → 创建免费 ARM 实例（4核/24GB）→ 跳到第 7 步
5. ⬜ ABC 被拒 → 开 **cloudcone.com**，支付宝充值，月付 $3.91 买 4GB 实例
6. ⬜ 收到服务器 IP 和密码 → SSH 登录
7. ⬜ 上传 deploy.sh 到服务器，一键跑完基础配置
8. ⬜ 域名配 A 记录指向 VPS IP → Nginx + HTTPS
9. ⬜ `docker compose up -d` → 前端/后端/数据库上线
10. ⬜ 配 GitHub Actions 自动部署 + 定时备份

搞定后月成本 **¥0（Oracle）或 ¥28（CloudCone）**，支付宝/信用卡搞定，不锁年付。

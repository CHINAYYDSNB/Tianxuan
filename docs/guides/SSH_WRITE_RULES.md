# SSH Write Rules (Non-Negotiable)

These rules apply to ALL SSH write operations in Tianxuan. Violations will cause data loss or shell injection. CI may not catch these — human review must.

## Rule 1: Multi-line File Writing

### The Correct Pattern
```bash
cat > "$path" <<'LANXI_EOF'
$content
LANXI_EOF
```

### Why Single Quotes on EOF?
- `<<'LANXI_EOF'` (single quotes) = **No shell expansion inside the body**.
- `<<LANXI_EOF` (no quotes) = **Shell WILL expand `$var`, `$(cmd)`, backticks**.
- If the file content contains `$PATH`, `$HOME`, or backticks, unquoted heredoc will corrupt the data.

### Wrong Examples
```bash
# ❌ WRONG: unquoted heredoc
cat > "$path" <<LANXI_EOF
export PATH=$PATH:/usr/local/bin  # becomes export PATH=/usr/bin:/usr/local/bin
LANXI_EOF

# ❌ WRONG: echo with single quotes won't interpolate path
ssh.exec('echo $path > file')  # Dart single quotes = no interpolation

# ❌ WRONG: using printf without proper escaping
printf "%s" "$content" > "$path"  # may break on special chars
```

### Right Examples
```bash
# ✅ RIGHT: quoted heredoc
ssh.exec("cat > \"$path\" <<'LANXI_EOF'\n$content\nLANXI_EOF")

# ✅ RIGHT: backup before write
ssh.exec("cp \"$path\" \"$path.bak.$(date +%s)\"")
ssh.exec("cat > \"$path\" <<'LANXI_EOF'\n$content\nLANXI_EOF")
```

## Rule 2: Backup Before Write

Every file modification must:
1. Create a timestamped backup: `$path.bak.$timestamp`
2. Then write the new content
3. If write fails, restore from backup

```dart
Future<void> writeFile(String path, String content) async {
  // 1. Backup
  await ssh.exec('cp "$path" "$path.bak.$(date +%s)"');
  
  // 2. Write (using quoted heredoc)
  final cmd = 'cat > "$path" <<\'LANXI_EOF\'\n$content\nLANXI_EOF';
  await ssh.exec(cmd);
  
  // 3. Verify (optional: compare file size or checksum)
}
```

## Rule 3: Large File Handling

### Thresholds
| Size | Behavior |
|------|----------|
| < 1MB | Normal edit mode |
| 1MB - 10MB | Show warning dialog: "Large file, may cause lag. Continue?" |
| > 10MB | Force paged mode |

### Paged Mode (Read)
```dart
// Read specific line range via SSH
Future<String> readChunk(String path, int startLine, int endLine) async {
  return await ssh.exec('sed -n "${startLine},${endLine}p" "$path"');
}
```

### Paged Mode (Write)
```dart
// Replace specific line range
Future<void> replaceChunk(String path, int lineNum, String newLine) async {
  await ssh.exec('cp "$path" "$path.bak.$(date +%s)"');
  await ssh.exec('sed -i "${lineNum}s|.*|$newLine|" "$path"');
}
```

### Local Paging (for files downloaded to device)
```dart
// Use RandomAccessFile for partial reads
final file = await File(tempPath).open();
await file.setPosition(offset);
final bytes = await file.read(chunkSize);
file.close();
```

## Rule 4: Special Character Escaping

When file content contains characters that have shell meaning:

| Character | Risk | Mitigation |
|-----------|------|------------|
| `$` | Variable expansion | Use `<<'EOF'` (quoted heredoc) |
| `!` | History expansion (bash) | Disable with `set +H` or use quoted heredoc |
| Backtick `` ` `` | Command substitution | Use quoted heredoc |
| `#` | Comment | Usually safe in quoted heredoc |
| `\n` | Newline | Heredoc handles naturally |
| `"` (double quote in content) | Quote conflict | Escape as `\"` or use heredoc |

**Best practice**: Always use `<<'LANXI_EOF'` (quoted heredoc). It neutralizes ALL of the above.

## Rule 5: Command Injection Prevention

### Never do this
```dart
// ❌ User input directly in command
ssh.exec('rm -rf $userInput');  // if userInput = "/ ; rm -rf /"
```

### Always do this
```dart
// ✅ Sanitize path
final safePath = sanitizePath(userInput);
ssh.exec('rm -rf "$safePath"');

// ✅ Or validate against whitelist
if (!path.startsWith('/allowed/dir/')) throw SecurityException();
```

## Rule 6: Dart String Interpolation

### SSH command strings MUST use double quotes
```dart
// ❌ WRONG: single quotes in Dart = no interpolation
ssh.exec('rm -rf $path');

// ✅ RIGHT: double quotes in Dart = interpolation works
ssh.exec("rm -rf \"$path\"");

// ✅ RIGHT: complex command with multiple variables
ssh.exec("cp \"$src\" \"$src.bak.$(date +%s)\" && cat > \"$dst\" <<'LANXI_EOF'\n$content\nLANXI_EOF");
```

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│  SSH WRITE COMMAND CHECKLIST                             │
├─────────────────────────────────────────────────────────┤
│  □ Uses double quotes in Dart string?                  │
│  □ Uses <<'LANXI_EOF' (quoted heredoc)?                │
│  □ Creates .bak timestamped backup first?              │
│  □ Path variables properly escaped with \"$path\"?      │
│  □ No user input directly concatenated?                │
│  □ Large file (>10MB) uses paged mode?                 │
│  □ Isolate used for heavy parsing?                     │
└─────────────────────────────────────────────────────────┘
```

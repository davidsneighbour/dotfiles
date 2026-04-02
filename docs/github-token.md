# Create token

## 0. Where to go

Open:

👉 [https://github.com/settings/personal-access-tokens](https://github.com/settings/personal-access-tokens)
→ click **"Fine-grained tokens"**
→ click **"Generate new token"**

## 1. General settings (same for all tokens)

For every token:

* **Name**
  Use clear names matching your `.env`, e.g.

  * `read-public`
  * `content-private`
  * `admin-public`

* **Resource owner**
  → Select your user (or org if needed later)

* **Expiration**
  → 90 days or 180 days (recommended)
  → do NOT set "no expiration"

## 2. Repository access scope

### For PUBLIC tokens

* Select:
  **"Public repositories"**

### For PRIVATE tokens

* Select:
  **"Only select repositories"**
  → choose all private repos you actually use

⚠️ Important:
Fine-grained tokens are repo-scoped.
If you forget one repo, scripts will fail later.

## 3. Permissions per token (this is the important part)

### 3.1 READ tokens

#### Token name:

```
GITHUB_TOKEN_READ_PUBLIC
GITHUB_TOKEN_READ_PRIVATE
```

#### Permissions:

##### Repository permissions:

* **Metadata** → Read (required, auto-selected)
* **Contents** → Read
* **Issues** → Read (optional but useful)
* **Pull requests** → Read (optional but useful)

##### Everything else:

→ **No access**

### 3.2 CONTENT tokens

#### Token name:

```
GITHUB_TOKEN_CONTENT_PUBLIC
GITHUB_TOKEN_CONTENT_PRIVATE
```

#### Permissions:

##### Repository permissions:

* **Contents** → Read and write ✅ (core permission)
* **Metadata** → Read (auto)
* **Pull requests** → Read and write (recommended)
* **Issues** → Read and write (optional, but practical)

##### Everything else:

→ **No access**

### 3.3 ADMIN token (public first)

#### Token name:

```
GITHUB_TOKEN_ADMIN_PUBLIC
```

#### Permissions:

##### Repository permissions:

* **Administration** → Read and write ✅ (critical)
* **Metadata** → Read (auto)
* **Contents** → Read (optional but safe)

This is what enables:

* label creation
* repo settings changes
* configuration APIs

### 3.4 ADMIN PRIVATE (only if needed later)

Do NOT create this yet unless you actually automate admin on private repos.

## 4. What NOT to enable

Do NOT enable:

* Actions (unless explicitly needed later)
* Packages
* Codespaces
* Discussions
* Webhooks
* Secrets (unless you explicitly automate them)

Keep tokens minimal.

## 5. Generate + store

After clicking **Generate token**:

* Copy immediately
* Put into `.env`:

```bash
GITHUB_TOKEN_READ_PUBLIC='...'
GITHUB_TOKEN_READ_PRIVATE='...'

GITHUB_TOKEN_CONTENT_PUBLIC='...'
GITHUB_TOKEN_CONTENT_PRIVATE='...'

GITHUB_TOKEN_ADMIN_PUBLIC='...'
```

## 6. Quick verification (important)

Test each token via your helper:

#### Read

```bash
github-token run --role read --visibility public -- gh repo view davidsneighbour/dotfiles
```

#### Content

```bash
github-token run --role content --visibility public -- gh api /repos/davidsneighbour/dotfiles/contents/
```

#### Admin

```bash
github-token run --role admin --visibility public -- gh api /repos/davidsneighbour/dotfiles/labels
```

## 7. Practical minimal setup (recommended for now)

Create ONLY these:

* `READ_PUBLIC`
* `READ_PRIVATE`
* `CONTENT_PUBLIC`
* `CONTENT_PRIVATE`
* `ADMIN_PUBLIC`

Skip:

* `ADMIN_PRIVATE` (until needed)

## 8. Common pitfalls (important)

### 1. Missing repo in private token

→ causes mysterious 404 or 403

### 2. Missing "Administration" permission

→ label creation fails with 403 (you already saw this)

### 3. Over-permissioning

→ defeats the whole system

### 4. Creating too many tokens

→ recreate clutter

## 9. Mental model

Think of tokens like this:

| Role    | What it means        |
| ------- | -------------------- |
| read    | "look only"          |
| content | "change files"       |
| admin   | "change repo itself" |

## 10. If something fails

Always check:

* wrong role?
* wrong visibility?
* missing repo in token scope?
* missing permission toggle?

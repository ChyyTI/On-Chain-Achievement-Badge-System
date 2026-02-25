# On-Chain-Achievement-Badge-System

A Stacks smart contract for issuing and managing on-chain achievement badges. Organizations can create badges with criteria and award windows; recipients compete by submitting scores.

## Features

- 🏅 Create badges with slug, criteria, tier, and fingerprint
- 🎯 Score-based competition — highest score earns lead recipient status
- ⏱️ Configurable award windows with early close support
- 🗄️ Archive empty badges cleanly
- 💸 Adjustable platform fee up to 10%

## Contract Functions

### Public

| Function | Description |
|---|---|
| `create-badge` | Issuer creates a new achievement badge |
| `submit-for-badge` | Recipient submits a score to earn a badge |
| `close-award-window` | Issuer ends the award period early |
| `archive-badge` | Issuer removes a badge with no submissions |
| `set-platform-fee` | Admin updates the platform fee |

### Read-Only

| Function | Description |
|---|---|
| `get-badge` | Fetch full badge record |
| `get-recipient-entry` | Fetch a recipient's submission |
| `award-window-open` | Is the badge currently awardable? |
| `badge-past-deadline` | Has the award window closed? |
| `estimate-platform-fee` | Preview fee on an amount |

## Error Reference

| Code | Meaning |
|---|---|
| u700 | Unauthorized |
| u701 | Badge already exists |
| u702 | Badge not found |
| u703 | Badge expired |
| u704 | Badge still active |
| u705 | Criteria mismatch |
| u706 | Not an inspector |
| u707 | Not the issuer |
| u708 | Recipient already registered |
| u709 | Invalid award window |
| u710 | Invalid fingerprint |
| u711 | Admin access only |
| u712 | Award window closed |
| u713 | Badge slug empty |
| u714 | Criteria empty |
| u715 | Tier empty |

## Deployment
```bash
clarinet contract publish badge-vault
```

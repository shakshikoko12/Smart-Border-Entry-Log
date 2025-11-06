# 🛂 Smart Border Entry Log

A decentralized cross-border movement tracking system built on Stacks blockchain that logs non-sensitive travel history immutably.

## 🌟 Features

- 🔒 **Immutable Records**: All border entries are permanently recorded on the blockchain
- 👮 **Authorized Agents**: Only authorized border agents can log entries and exits
- 📊 **Statistics Tracking**: Real-time statistics for entry points and traveler movements
- 🔍 **Travel History**: Query complete travel history for any traveler
- ⚡ **Status Updates**: Update entry status (active, flagged, cleared)
- 🚪 **Entry/Exit Tracking**: Complete journey tracking from entry to exit

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Run `clarinet check` to verify contract syntax
4. Use `clarinet console` to interact with the contract

## 📋 Contract Functions

### 🔐 Administrative Functions

#### `add-authorized-agent`
Adds a new authorized agent who can log border entries.
```clarity
(contract-call? .Smart-Border-Entry-Log add-authorized-agent 'SP1234567890)
```

#### `remove-authorized-agent`
Removes an authorized agent's permissions.
```clarity
(contract-call? .Smart-Border-Entry-Log remove-authorized-agent 'SP1234567890)
```

### 📝 Entry Management

#### `log-entry`
Records a new border entry for a traveler.
```clarity
(contract-call? .Smart-Border-Entry-Log log-entry 'SP1234567890 "Airport-NYC" "Business-District" "entry")
```

Parameters:
- `traveler`: Principal of the traveler
- `entry-point`: Name of the entry point (max 50 characters)
- `destination`: Destination location (max 50 characters)
- `entry-type`: "entry" or "transit"

#### `log-exit`
Records an exit for an existing entry.
```clarity
(contract-call? .Smart-Border-Entry-Log log-exit u1 "Airport-LAX")
```

#### `update-entry-status`
Updates the status of an existing entry.
```clarity
(contract-call? .Smart-Border-Entry-Log update-entry-status u1 "cleared")
```

Status options: "active", "flagged", "cleared"

### 🔍 Query Functions

#### `get-entry`
Retrieves details of a specific entry by ID.
```clarity
(contract-call? .Smart-Border-Entry-Log get-entry u1)
```

#### `get-traveler-entries`
Gets all entry IDs for a specific traveler.
```clarity
(contract-call? .Smart-Border-Entry-Log get-traveler-entries 'SP1234567890)
```

#### `get-entry-statistics`
Gets statistics for a specific entry point.
```clarity
(contract-call? .Smart-Border-Entry-Log get-entry-statistics "Airport-NYC")
```

#### `get-traveler-active-entries`
Gets all active entries for a traveler.
```clarity
(contract-call? .Smart-Border-Entry-Log get-traveler-active-entries 'SP1234567890)
```

#### `is-authorized-agent`
Checks if an address is an authorized agent.
```clarity
(contract-call? .Smart-Border-Entry-Log is-authorized-agent 'SP1234567890)
```

## 🏗️ Data Structures

### Border Entry Record
```clarity
{
    traveler: principal,
    entry-point: (string-ascii 50),
    destination: (string-ascii 50),
    entry-type: (string-ascii 10),
    timestamp: uint,
    block-height: uint,
    status: (string-ascii 10),
    exit-timestamp: (optional uint),
    exit-point: (optional (string-ascii 50))
}
```

### Entry Point Statistics
```clarity
{
    total-entries: uint,
    total-exits: uint,
    active-travelers: uint
}
```

## 🔧 Usage Examples

### Setting Up Border Agents
```clarity
;; Add authorized agents
(contract-call? .Smart-Border-Entry-Log add-authorized-agent 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
(contract-call? .Smart-Border-Entry-Log add-authorized-agent 'SP1114Z7S1J2RFQN4CZRBC4QMJXJP3XQBZF7VWXKH)
```

### Logging a Border Entry
```clarity
;; Log entry at JFK Airport
(contract-call? .Smart-Border-Entry-Log log-entry 
    'SP1234567890ABCDEF 
    "JFK-Airport-NYC" 
    "Manhattan-Business" 
    "entry")
```

### Tracking Exit
```clarity
;; Log exit at LAX Airport
(contract-call? .Smart-Border-Entry-Log log-exit u1 "LAX-Airport-LA")
```

### Querying Travel History
```clarity
;; Get all entries for a traveler
(contract-call? .Smart-Border-Entry-Log get-traveler-entries 'SP1234567890ABCDEF)

;; Get statistics for an entry point
(contract-call? .Smart-Border-Entry-Log get-entry-statistics "JFK-Airport-NYC")
```

## 🛡️ Security Features

- ✅ Only contract owner can manage authorized agents
- ✅ Only authorized agents can log entries/exits
- ✅ Immutable entry records (cannot be deleted)
- ✅ Entry validation prevents invalid data
- ✅ Status updates only allow valid states

## 📊 Statistics & Analytics

The contract provides real-time analytics for:
- Total entries per border point
- Total exits per border point
- Currently active travelers at each location
- Individual traveler movement history

## 🧪 Testing

Run the test suite with:
```bash
clarinet test
```

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.

---

Built with ❤️ on Stacks blockchain

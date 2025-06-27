# 🏠 Houselot - On-Chain Housing Lottery

A transparent blockchain-based housing allocation system for low-income families built on the Stacks blockchain.

## 🌟 Features

- 🎲 **Transparent Lottery System** - Fair and verifiable housing allocation
- 💰 **Income Verification** - Ensures only eligible low-income participants
- 🏘️ **Housing Unit Management** - Track available units and allocations
- 🔒 **Secure Winner Selection** - Blockchain-randomized selection process
- 📊 **Historical Records** - Complete audit trail of all lotteries

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testnet/mainnet deployment

### Installation
```bash
git clone <repository-url>
cd Houselot
clarinet check
```

## 📋 Usage Instructions

### For Contract Owners

#### 1. Initialize a New Lottery 🎯
```clarity
(contract-call? .Houselot initialize-lottery deadline-block drawing-block)
```
- `deadline-block`: Block height when registration closes
- `drawing-block`: Block height when lottery drawing occurs

#### 2. Add Housing Units 🏘️
```clarity
(contract-call? .Houselot add-housing-unit "123 Main St" u1200 u2)
```
- `address`: Property address (string)
- `rent`: Monthly rent amount
- `bedrooms`: Number of bedrooms

#### 3. Verify Participant Income ✅
```clarity
(contract-call? .Houselot verify-income participant-address true)
```

#### 4. Conduct Lottery Drawing 🎲
```clarity
(contract-call? .Houselot conduct-lottery)
```

#### 5. Allocate Housing to Winners 🏆
```clarity
(contract-call? .Houselot allocate-housing unit-id winner-address)
```

### For Participants

#### 1. Register for Lottery 📝
```clarity
(contract-call? .Houselot register-participant annual-income)
```
- `annual-income`: Must be ≤ $50,000 to qualify

#### 2. Claim Allocated Housing 🗝️
```clarity
(contract-call? .Houselot claim-housing unit-id)
```

### Read-Only Functions 👀

#### Check Lottery Status
```clarity
(contract-call? .Houselot get-lottery-info)
```

#### View Participant Information
```clarity
(contract-call? .Houselot get-participant-info participant-address)
```

#### Check Housing Unit Details
```clarity
(contract-call? .Houselot get-housing-unit unit-id)
```

#### Verify Winner Status
```clarity
(contract-call? .Houselot is-winner participant-address)
```

## 🔧 Contract Functions

| Function | Type | Description |
|----------|------|-------------|
| `initialize-lottery` | Public | Start new lottery with deadlines |
| `register-participant` | Public | Register eligible participant |
| `add-housing-unit` | Public | Add available housing unit |
| `conduct-lottery` | Public | Execute lottery drawing |
| `allocate-housing` | Public | Assign unit to winner |
| `claim-housing` | Public | Claim allocated housing |
| `verify-income` | Public | Verify participant eligibility |
| `get-lottery-info` | Read-Only | Get current lottery status |
| `get-participant-info` | Read-Only | Get participant details |
| `get-housing-unit` | Read-Only | Get housing unit info |
| `get-lottery-winner` | Read-Only | Get winner by index |
| `is-winner` | Read-Only | Check if address is winner |

## 📊 Error Codes

| Code | Description |
|------|-------------|
| `u100` | Owner only function |
| `u101` | Not eligible participant |
| `u102` | Already registered |
| `u103` | Lottery not active |
| `u104` | Lottery not ended |
| `u105` | No participants |
| `u106` | Invalid housing unit |
| `u107` | Unit already allocated |
| `u108` | Not a winner |
| `u109` | Already claimed |

## 🏗️ Architecture

The contract uses several key data structures:

- **Participants Map**: Stores registration and verification status
- **Housing Units Map**: Tracks available properties and allocations  
- **Lottery Winners Map**: Records selected winners
- **Winner Claims Map**: Tracks claimed housing units

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 🔐 Security Features

- ✅ Owner-only administrative functions
- ✅ Income eligibility verification ($50k cap)
- ✅ Blockchain-based randomization
- ✅ Double-claim prevention
- ✅ Registration deadline enforcement

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🆘 Support

For support and questions:
- Create an issue in this repository
- Contact the development team


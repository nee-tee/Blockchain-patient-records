# Blockchain-Based Patient Record Management System

A prototype patient record management system combining a **custom Python blockchain**
(built from scratch) and a **Solidity smart contract deployed to the Ethereum Sepolia
Testnet**. Built for a fictional healthcare organisation, HealthCare Innovations Ltd.,
as part of an MSc Blockchain module (LDS7006M). You can read the report [here](https://github.com/nee-tee/Blockchain-patient-records/blob/main/BLOCKCHAIN%20Project.pdf)

## Overview

The project demonstrates blockchain fundamentals in a healthcare context, split into two parts:

1. **Python blockchain (`notebooks/LDS7006M_Blockchain_Python.ipynb`)**
   A from-scratch blockchain implementation covering:
   - Block structure and SHA-256 cryptographic hashing
   - Genesis block creation
   - Proof-of-Work mining (configurable difficulty)
   - Patient record creation and transfer between providers
   - Chain validation and tampering detection
   - A simplified distributed consensus simulation (longest-chain rule)

2. **Solidity smart contract (`contracts/PatientRecordContract.sol`)**
   Deployed live to the **Ethereum Sepolia Testnet**, with role-based access control:
   - `authoriseProvider` / `revokeProvider` — admin-only provider management
   - `addRecord` — authorised providers create new patient records on-chain
   - `transferRecord` — transfer record custody between authorised providers
   - `getRecord` / `getPatientHistory` — read-only record retrieval
   - Only cryptographic hashes of clinical data are stored on-chain (`recordHash`),
     not raw patient information, to protect privacy

   Contract interaction and testing is in
   `notebooks/LDS7006M_Contract_Interaction.ipynb`, using `web3.py` to call the
   deployed contract on Sepolia.

Deployed contract address: `0x728F1cDc7934f7aD24A75425DC48b414F207d8d6`
(verified on [Sourceify](https://sourcify.dev) and [Blockscout](https://blockscout.com))

## Stack

| Component | Technology |
|---|---|
| Blockchain prototype | Python 3.x |
| Smart contract | Solidity ^0.8.0 |
| Network | Ethereum Sepolia Testnet |
| Contract interaction | web3.py |
| Development IDE | Remix IDE |
| Wallet | MetaMask |
| RPC / node provider | Alchemy |
| Verification | Sourceify, Blockscout |

## Repository structure

```
.
├── contracts/
│   └── PatientRecordContract.sol      # Solidity smart contract
├── notebooks/
│   ├── LDS7006M_Blockchain_Python.ipynb        # Python blockchain implementation
│   └── LDS7006M_Contract_Interaction.ipynb     # web3.py interaction with the deployed contract
├── .env.example                       # Template for required environment variables
├── .gitignore
├── LICENSE
└── README.md
```

## Running it yourself

**Python blockchain notebook** — no external dependencies beyond the standard library;
just open it in Jupyter and run the cells top to bottom.

**Contract interaction notebook** requires:

```bash
pip install web3 python-dotenv
```

Then create a `.env` file in the project root (see `.env.example`) with:

```
RPC_URL=<your Sepolia RPC endpoint, e.g. from Alchemy or Infura>
PRIVATE_KEY=<your wallet's private key>
```

**Never commit your `.env` file** — it's already excluded via `.gitignore`.

## Design notes

- Only SHA-256 hashes of clinical data are written on-chain — raw patient
  information stays off-chain, reducing privacy exposure and storage cost.
- Role-based access control (`onlyAdmin`, `onlyAuthorised`) ensures only
  authorised healthcare providers can create or transfer records.
- Deployed and tested on Sepolia rather than mainnet — this is a research
  prototype, not a production system.

## Limitations & future work

- Simulated peer-to-peer networking in the Python implementation (not a real
  distributed network)
- No off-chain storage layer implemented (e.g. IPFS) for the full clinical
  documents behind each hash
- Scalability, transaction cost, and regulatory compliance (e.g. GDPR) would
  need further work before any real-world deployment

## Author

Enitan S. Osibote — MSc student, York St John University

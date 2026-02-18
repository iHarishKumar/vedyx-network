# Vedyx Protocol

**Decentralized security consensus through stake-backed governance.**

Vedyx introduces a new primitive for on-chain security: **risk consensus**. By combining real-time threat detection with economic stake-weighted voting, Vedyx enables the DeFi community to collectively validate and respond to suspicious on-chain activity.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          ORIGIN CHAIN (e.g., Ethereum)                   │
│                                                                           │
│  ┌──────────────────┐         ┌──────────────────┐                      │
│  │  DeFi Protocol   │         │  Malicious Actor │                      │
│  │  (Uniswap, etc.) │         │                  │                      │
│  └────────┬─────────┘         └────────┬─────────┘                      │
│           │                             │                                │
│           │ Emits Events                │ Suspicious Transaction         │
│           └─────────────────────────────┘                                │
│                                 │                                        │
└─────────────────────────────────┼────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         REACTIVE NETWORK                                 │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │           VedyxExploitDetectorRSC (Singleton Hub)              │    │
│  │                                                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐     │    │
│  │  │           Detector Registry                          │     │    │
│  │  │  topic_0 → [Detector1, Detector2, Detector3, ...]   │     │    │
│  │  └──────────────────────────────────────────────────────┘     │    │
│  │                                                                 │    │
│  │  react(log) {                                                  │    │
│  │    detectors = registry[log.topic_0]                          │    │
│  │    for each detector:                                          │    │
│  │      if detector.detect(log) → emit Callback                  │    │
│  │  }                                                              │    │
│  └─────────────────────────────┬───────────────────────────────────┘    │
│                                │                                        │
│  ┌─────────────────┐  ┌────────┴────────┐  ┌──────────────────┐       │
│  │ LargeTransfer   │  │   FlashLoan     │  │  Reentrancy      │       │
│  │ Detector        │  │   Detector      │  │  Detector        │  ...  │
│  └─────────────────┘  └─────────────────┘  └──────────────────┘       │
│                                │                                        │
│                                │ Callback Payload                       │
└────────────────────────────────┼────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    DESTINATION CHAIN (e.g., Ethereum)                    │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                   VedyxVotingContract                           │    │
│  │                                                                 │    │
│  │  • Verdict-based auto-classification                           │    │
│  │  • Stake-weighted voting with karma system                     │    │
│  │  • Finalization rewards & penalty distribution                 │    │
│  │  • Role-based access control (RBAC)                            │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                      Staking Token (ERC20)                      │    │
│  │  • Users stake to gain voting power                             │    │
│  │  • Locked during active votes                                   │    │
│  │  • Slashed for incorrect votes                                  │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Voting Flow

```mermaid
sequenceDiagram
    participant Origin as Origin Chain<br/>(DeFi Protocol)
    participant RN as Reactive Network<br/>(VedyxExploitDetectorRSC)
    participant Detector as Attack Vector Detector
    participant VC as Destination Chain<br/>(VedyxVotingContract)
    participant Voters as Community Voters
    participant Finalizer as Finalizer

    Origin->>RN: Emit suspicious event
    RN->>Detector: react(log)
    Detector->>Detector: detect(log)
    
    alt Threat Detected
        Detector->>RN: return (true, address, payload)
        RN->>VC: emit Callback → tagSuspicious()
        
        VC->>VC: Check verdict history
        
        alt Previous Suspicious Verdict
            VC->>VC: Auto-mark (skip voting)
            VC->>VC: Increment incident count
        else No Verdict or Clean Verdict
            VC->>VC: Create new voting (votingId)
            VC->>Voters: Emit VotingStarted event
            
            loop Voting Period (e.g., 24 hours)
                Voters->>VC: stake(amount)
                Voters->>VC: castVote(votingId, true/false)
                VC->>VC: Lock stake & record vote
                VC->>VC: Calculate voting power<br/>(stake + karma bonus/penalty)
            end
            
            Finalizer->>VC: finalizeVoting(votingId)
            VC->>VC: Determine consensus (majority)
            VC->>VC: Record verdict for future
            
            alt Correct Voters
                VC->>Voters: +karma points
                VC->>Voters: Share of slashed stakes
                VC->>Voters: Unlock stake
            else Incorrect Voters
                VC->>Voters: -karma points
                VC->>Voters: Slash stake
                VC->>Voters: Unlock remaining stake
            end
            
            VC->>Finalizer: Finalization reward (2% of fees)
            VC->>Voters: Emit VotingFinalized event
        end
    else No Threat
        Detector->>RN: return (false, 0x0, "")
    end
```

## Core Components

| Component | Status | Description |
|-----------|--------|-------------|
| **VedyxVotingContract** | 🚧 In Progress | Stake-weighted voting with karma tracking & penalties |
| **VedyxExploitDetectorRSC** | 🚧 In Progress | Modular threat detection on Reactive Network |
| **Attack Vector Detectors** | 📋 Planned | Pluggable detection modules (flash loans, etc.) |

## Documentation

- **[Voting Contract Guide](./src/VOTING_CONTRACT_GUIDE.md)** - Complete guide to stake-based voting, karma system, penalties, and RBAC
- **[Reactive Contracts](./src/reactive-contracts/README.md)** - Singleton architecture for modular exploit detection

## Quick Start

```bash
# Install dependencies
forge install

# Run tests
forge test

# Deploy (configure RPC endpoints first)
forge script script/Deploy.s.sol --broadcast
```

## Key Features

- ✅ **Stake-based voting** with karma-weighted power
- ✅ **Exponential penalties** for incorrect votes
- ✅ **Verdict-based auto-classification** for repeat offenders
- ✅ **Role-based access control** (Governance, Parameter Admin, Treasury)
- ✅ **Modular detection system** with pluggable attack vector detectors
- ✅ **Finalization rewards** to incentivize timely vote resolution

## Built With

- [Foundry](https://book.getfoundry.sh/) - Smart contract development
- [Reactive Network](https://reactive.network/) - Cross-chain event detection
- [OpenZeppelin](https://www.openzeppelin.com/contracts) - Security & access control

---

**Status Legend:** ✅ Complete | 🚧 In Progress | 📋 Planned

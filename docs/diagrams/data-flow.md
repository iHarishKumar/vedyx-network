# Data Flow & State Management

```mermaid
graph TB
    subgraph "State Storage - Voting Contract"
        A[AddressVerdict Mapping]
        B[Voting Mapping]
        C[Staker Mapping]
        D[Active Votings Array]
        
        A --> A1[hasVerdict: bool]
        A --> A2[isSuspicious: bool]
        A --> A3[lastVotingId: uint256]
        A --> A4[verdictTimestamp: uint256]
        A --> A5[totalIncidents: uint256]
        
        B --> B1[votingId: uint256]
        B --> B2[report: SuspiciousReport]
        B --> B3[startTime/endTime: uint256]
        B --> B4[votesFor/Against: uint256]
        B --> B5[finalized: bool]
        B --> B6[voters: address array]
        
        C --> C1[stakedAmount: uint256]
        C --> C2[karmaPoints: int256]
        C --> C3[totalVotes: uint256]
        C --> C4[correctVotes: uint256]
        C --> C5[lockedAmount: uint256]
    end
    
    subgraph "State Storage - Risk Engine"
        E[Verdict Cache]
        F[Incident Counter]
        G[Detector Registry]
        
        E --> E1[Last queried verdict]
        F --> F2[Total incidents per address]
        G --> G3[Registered detector addresses]
    end
    
    subgraph "State Storage - Reactive Detector"
        H[Detector Registry]
        I[Subscription Registry]
        J[Detector State]
        
        H --> H1[topic → detector array]
        I --> I2[subscriptionKey → subscription]
        J --> J3[Detector-specific storage]
    end
    
    subgraph "Data Flow"
        K[Event on Origin Chain] --> L[Reactive Network]
        L --> M[VedyxExploitDetectorRSC]
        M --> N[Detector.detect]
        N --> O{Threat?}
        
        O -->|Yes| P[Emit Callback]
        P --> Q[VedyxVotingContract.tagSuspicious]
        
        Q --> R{Check AddressVerdict}
        R -->|Has Suspicious| S[Update totalIncidents]
        R -->|No/Clean| T[Create Voting]
        
        T --> U[Store in votings mapping]
        T --> V[Add to activeVotings array]
        
        W[Staker.castVote] --> X[Update Voting state]
        X --> Y[Lock stake in Staker]
        X --> Z[Record vote in Voting]
        
        AA[finalizeVoting] --> AB[Calculate result]
        AB --> AC[Update AddressVerdict]
        AC --> AD[Update Staker karma]
        AD --> AE[Unlock stakes]
        AE --> AF[Remove from activeVotings]
        
        AG[VedyxRiskHook.beforeSwap] --> AH[VedyxRiskEngine.getRiskAssessment]
        AH --> AI[Query VotingContract.getAddressVerdict]
        AI --> AJ[Calculate risk score]
        AJ --> AK[Return risk level]
        AK --> AL[Apply fee/block decision]
    end
    
    style A fill:#4ecdc4
    style B fill:#74b9ff
    style C fill:#96ceb4
    style E fill:#fdcb6e
    style H fill:#fd79a8
    style O fill:#ff6b6b
    style R fill:#ff6b6b
```

## State Transitions

### AddressVerdict State Machine

```mermaid
stateDiagram-v2
    [*] --> NoVerdict: Initial State
    
    NoVerdict --> VotingCreated: tagSuspicious() called
    VotingCreated --> Suspicious: Voting finalized (votesFor > votesAgainst)
    VotingCreated --> Clean: Voting finalized (votesAgainst >= votesFor)
    
    Suspicious --> Suspicious: tagSuspicious() called again<br/>(Auto-mark, increment incidents)
    Clean --> VotingCreated: tagSuspicious() with new evidence
    
    Suspicious --> Clean: clearVerdict() by governance
    Clean --> NoVerdict: clearVerdict() by governance
    
    note right of Suspicious
        totalIncidents NEVER resets
        Even if verdict cleared
    end note
```

### Voting Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Created: tagSuspicious() creates voting
    
    Created --> Active: Voting period starts
    Active --> Active: Stakers cast votes
    
    Active --> Ended: Voting duration expires
    Ended --> Finalized: finalizeVoting() called
    
    Finalized --> [*]: Verdict recorded
    
    note right of Active
        Duration: 7 days (configurable)
        Votes are stake-weighted
        Karma affects voting power
    end note
    
    note right of Finalized
        • Record verdict
        • Apply penalties
        • Distribute rewards
        • Update karma
        • Unlock stakes
    end note
```

### Staker Karma Evolution

```mermaid
stateDiagram-v2
    [*] --> Neutral: Initial karma = 0
    
    Neutral --> Positive: Correct votes
    Neutral --> Negative: Wrong votes
    
    Positive --> Positive: More correct votes<br/>(+10 karma each)
    Positive --> Neutral: Some wrong votes
    
    Negative --> Neutral: Correct votes recover karma
    Negative --> Blocked: Karma <= -50
    
    Blocked --> Negative: Cannot vote<br/>(Must wait for recovery)
    Negative --> Neutral: +6 correct votes needed
    
    note right of Positive
        Linear bonus:
        +1% voting power per 100 karma
    end note
    
    note right of Negative
        Exponential penalty:
        karma² reduces voting power
    end note
    
    note right of Blocked
        Hard threshold at -50 karma
        Cannot participate in voting
    end note
```

## Data Access Patterns

### Read Operations (View Functions)

```mermaid
graph LR
    A[External Query] --> B{Query Type}
    
    B -->|Verdict| C[getAddressVerdict]
    B -->|Voting| D[getVotingDetails]
    B -->|Staker| E[getStakerInfo]
    B -->|Risk| F[getRiskAssessment]
    
    C --> G[VotingContract Storage]
    D --> G
    E --> G
    
    F --> H[RiskEngine Calculation]
    H --> G
    H --> I[Detector Registry]
    
    style A fill:#4ecdc4
    style G fill:#74b9ff
    style H fill:#fdcb6e
```

### Write Operations (State Changes)

```mermaid
graph TB
    A[State Change Request] --> B{Operation Type}
    
    B -->|Tag| C[tagSuspicious]
    B -->|Vote| D[castVote]
    B -->|Finalize| E[finalizeVoting]
    B -->|Stake| F[stake/unstake]
    
    C --> G[Check Reentrancy]
    D --> G
    E --> G
    F --> G
    
    G --> H[Validate Permissions]
    H --> I[Update State]
    
    I --> J[Emit Events]
    J --> K[Return/Revert]
    
    style A fill:#4ecdc4
    style G fill:#fd79a8
    style H fill:#fdcb6e
    style I fill:#74b9ff
```

## Event Emission Flow

```mermaid
sequenceDiagram
    participant User
    participant Contract
    participant Indexer
    participant Frontend
    
    User->>Contract: State-changing transaction
    Contract->>Contract: Update storage
    Contract->>Contract: Emit event
    
    Contract-->>Indexer: Event log
    Indexer->>Indexer: Process event
    Indexer->>Indexer: Update subgraph
    
    Frontend->>Indexer: Query subgraph
    Indexer-->>Frontend: Return indexed data
    Frontend-->>User: Display updated state
```

## Key Events

### Voting Contract Events

- `VotingStarted(votingId, address, chainId, ...)`
- `VotingFinalized(votingId, isSuspicious, votesFor, votesAgainst)`
- `VoteCast(votingId, voter, voteSuspicious, votingPower)`
- `SuspiciousAddressAutoMarked(address, totalIncidents)`
- `VerdictRecorded(address, isSuspicious, votingId)`
- `Staked(user, amount, totalStaked)`
- `Unstaked(user, amount, remainingStaked)`
- `KarmaUpdated(user, oldKarma, newKarma)`

### Risk Hook Events

- `SwapBlocked(user, riskLevel, riskScore)`
- `LiquidityBlocked(user, isAdd, riskLevel)`
- `FeeConfigUpdated(safeFee, lowFee, mediumFee, highFee, criticalFee)`
- `HookConfigUpdated(dynamicFeesEnabled, blockHigh, blockCritical)`

### Detector Events

- `ThreatDetected(originChainId, suspiciousAddr, detectorId, txHash)`
- `DetectorRegistered(detectorId, detectorAddress, topic)`
- `DetectorUnregistered(detectorId, detectorAddress)`

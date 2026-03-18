# Vedyx Protocol - Overall Architecture

```mermaid
graph TB
    subgraph "Origin Chain (Ethereum, Polygon, etc.)"
        A[Exploit/Suspicious Activity] --> B[Event Emission]
        B --> C[Transfer Events]
        B --> D[Swap Events]
        B --> E[Approval Events]
    end

    subgraph "Reactive Network"
        F[ReactVM] --> G[VedyxExploitDetectorRSC]
        G --> H[Detector Registry]
        H --> I[LargeTransferDetector]
        H --> J[MixerInteractionDetector]
        H --> K[TracePeelChainDetector]
        H --> L[Future Detectors...]
        
        I --> M{Threat<br/>Detected?}
        J --> M
        K --> M
        L --> M
    end

    subgraph "Destination Chain (Ethereum, Polygon, etc.)"
        N[VedyxVotingContract] --> O{Has Suspicious<br/>Verdict?}
        O -->|Yes| P[Auto-Mark Suspicious]
        O -->|No| Q[Create Community Voting]
        
        Q --> R[Stake-Based Voting<br/>7 Days]
        R --> S[Finalize Voting]
        S --> T[Record Verdict]
        T --> U[Apply Penalties/Rewards]
        
        V[VedyxRiskEngine] --> W[Calculate Risk Score]
        W --> X[Risk Factors:<br/>• Verdict 0-40<br/>• Incidents 0-20<br/>• Detectors 0-20<br/>• Consensus 0-10<br/>• Recency 0-10]
        X --> Y[Risk Level:<br/>SAFE | LOW | MEDIUM<br/>HIGH | CRITICAL]
        
        Z[VedyxRiskHook<br/>Uniswap V4] --> AA[beforeSwap]
        AA --> V
        Y --> AB{Risk Level?}
        AB -->|SAFE| AC[1% Fee]
        AB -->|LOW| AD[3% Fee]
        AB -->|MEDIUM| AE[8% Fee]
        AB -->|HIGH| AF[15% Fee or Block]
        AB -->|CRITICAL| AG[30% Fee or Block]
        
        Z --> AH[beforeAddLiquidity]
        AH --> V
        Y --> AI{Risk Level?}
        AI -->|SAFE-MEDIUM| AJ[Allow]
        AI -->|HIGH-CRITICAL| AK[Block]
    end

    C --> F
    D --> F
    E --> F
    
    M -->|Yes| N
    
    T --> V
    P --> V

    style A fill:#ff6b6b
    style G fill:#4ecdc4
    style N fill:#45b7d1
    style V fill:#96ceb4
    style Z fill:#ffeaa7
    style M fill:#fd79a8
    style O fill:#fd79a8
    style AB fill:#fd79a8
    style AI fill:#fd79a8
```

## Flow Description

### 1. Detection Phase (Reactive Network)
1. **Event Monitoring**: Origin chain events captured by ReactVM
2. **Pattern Analysis**: VedyxExploitDetectorRSC routes to appropriate detectors
3. **Threat Detection**: Detectors analyze patterns and identify suspicious addresses
4. **Callback**: Suspicious addresses sent to destination chain

### 2. Validation Phase (Destination Chain)
1. **Callback Reception**: VedyxVotingContract receives suspicious address
2. **Verdict Check**: Auto-mark repeat offenders or create new voting
3. **Community Voting**: 7-day stake-weighted voting process
4. **Finalization**: Record verdict, apply penalties/rewards

### 3. Risk Assessment Phase
1. **Score Calculation**: VedyxRiskEngine calculates 0-100 risk score
2. **Multi-Factor Analysis**: Combines verdict, incidents, detectors, consensus, recency
3. **Risk Categorization**: Maps score to risk level

### 4. Integration Phase (DeFi)
1. **Hook Invocation**: Uniswap V4 calls VedyxRiskHook
2. **Risk Query**: Hook queries VedyxRiskEngine
3. **Dynamic Response**: Apply fees or block based on risk level

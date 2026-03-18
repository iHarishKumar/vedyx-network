# Voting Flow - Community Validation

```mermaid
sequenceDiagram
    participant RN as Reactive Network
    participant VC as VedyxVotingContract
    participant S1 as Staker 1
    participant S2 as Staker 2
    participant S3 as Staker 3
    participant RE as VedyxRiskEngine

    RN->>VC: tagSuspicious(address, chainId, ...)
    
    VC->>VC: Check AddressVerdict
    
    alt Has Suspicious Verdict
        VC->>VC: Auto-mark suspicious
        VC->>VC: Increment incident counter
        VC->>VC: Emit SuspiciousAddressAutoMarked
        Note over VC: 87% gas savings!
    else No Verdict or Clean
        VC->>VC: Create new voting
        VC->>VC: Set voting duration (7 days)
        VC->>VC: Emit VotingStarted
        
        Note over S1,S3: Voting Period (7 days)
        
        S1->>VC: castVote(votingId, true)
        VC->>VC: Calculate voting power<br/>(stake + karma bonus)
        VC->>VC: Lock stake
        VC->>VC: Record vote
        
        S2->>VC: castVote(votingId, false)
        VC->>VC: Calculate voting power<br/>(stake - karma penalty)
        VC->>VC: Lock stake
        VC->>VC: Record vote
        
        S3->>VC: castVote(votingId, true)
        VC->>VC: Calculate voting power
        VC->>VC: Lock stake
        VC->>VC: Record vote
        
        Note over VC: Voting Period Ends
        
        S1->>VC: finalizeVoting(votingId)
        
        VC->>VC: Check votesFor vs votesAgainst
        
        alt votesFor > votesAgainst
            VC->>VC: Mark address as SUSPICIOUS
            VC->>VC: Record verdict
            
            Note over VC: Process Penalties
            VC->>S2: Slash 10% stake (voted wrong)
            VC->>S2: -5 karma points
            
            Note over VC: Distribute Rewards
            VC->>S1: Share of slashed stakes
            VC->>S1: +10 karma points
            VC->>S3: Share of slashed stakes
            VC->>S3: +10 karma points
            
        else votesAgainst >= votesFor
            VC->>VC: Mark address as CLEAN
            VC->>VC: Record verdict
            
            Note over VC: Process Penalties
            VC->>S1: Slash 10% stake (voted wrong)
            VC->>S1: -5 karma points
            VC->>S3: Slash 10% stake (voted wrong)
            VC->>S3: -5 karma points
            
            Note over VC: Distribute Rewards
            VC->>S2: Share of slashed stakes
            VC->>S2: +10 karma points
        end
        
        VC->>VC: Unlock stakes for all voters
        VC->>S1: Finalization reward (2% of fees)
        VC->>VC: Emit VotingFinalized
    end
    
    VC->>RE: Verdict available for risk assessment
```

## Voting Power Calculation

```mermaid
graph LR
    A[Staker] --> B{Karma >= 0?}
    B -->|Yes| C[Linear Bonus]
    B -->|No| D[Exponential Penalty]
    
    C --> E[votingPower = stake + stake × karma / 10000]
    D --> F[penalty = stake × karma² / 100000]
    D --> G[votingPower = stake - penalty]
    
    E --> H[Final Voting Power]
    G --> H
    
    style A fill:#4ecdc4
    style B fill:#fd79a8
    style C fill:#96ceb4
    style D fill:#ff6b6b
    style H fill:#ffeaa7
```

## Karma System

```mermaid
graph TB
    A[New Staker<br/>Karma: 0] --> B{Vote Outcome}
    
    B -->|Correct Vote| C[+10 Karma]
    B -->|Wrong Vote| D[-5 Karma]
    
    C --> E{Karma Level}
    D --> E
    
    E -->|Positive| F[Linear Bonus<br/>+1% per 100 karma]
    E -->|Negative but > -50| G[Exponential Penalty<br/>karma²]
    E -->|<= -50| H[BLOCKED from Voting]
    
    H --> I[Recovery Path:<br/>+6 correct votes needed]
    I --> J[Karma > -50]
    J --> K[Can Vote Again]
    
    style A fill:#4ecdc4
    style B fill:#fd79a8
    style C fill:#96ceb4
    style D fill:#ff6b6b
    style H fill:#ff6b6b
    style K fill:#96ceb4
```

## Key Features

### Auto-Classification
- **Repeat Offenders**: Instantly marked without voting (87% gas savings)
- **Fresh Evaluation**: Clean addresses can be re-judged with new evidence
- **Incident Tracking**: Total incidents never reset (permanent record)

### Economic Incentives
- **Stake Penalties**: 10% slash for incorrect votes (configurable, max 50%)
- **Reward Distribution**: Correct voters share penalty pool
- **Finalization Rewards**: 2% of collected fees to finalizer (configurable, max 10%)
- **Karma Impact**: Affects future voting power

### Security Features
- **Self-Voting Prevention**: Users cannot vote on their own addresses
- **Minimum Karma**: -50 karma threshold blocks voting
- **Locked Stakes**: Prevents manipulation during active voting
- **Reentrancy Protection**: All state-changing functions protected

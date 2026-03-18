# Risk Assessment & DeFi Integration

```mermaid
graph TB
    subgraph "Risk Engine - Multi-Factor Scoring"
        A[User Address] --> B[VedyxRiskEngine]
        
        B --> C[Factor 1: Verdict Score<br/>0-40 points]
        B --> D[Factor 2: Incident History<br/>0-20 points]
        B --> E[Factor 3: Detector Severity<br/>0-20 points]
        B --> F[Factor 4: Voting Consensus<br/>0-10 points]
        B --> G[Factor 5: Time Recency<br/>0-10 points]
        
        C --> H{Has Verdict?}
        H -->|Suspicious| I[40 points]
        H -->|Clean| J[0 points]
        H -->|No Verdict| K[0 points]
        
        D --> L{Incident Count}
        L -->|0| M[0 points]
        L -->|1| N[5 points]
        L -->|2| O[10 points]
        L -->|3+| P[20 points]
        
        E --> Q{Detector Flags}
        Q -->|None| R[0 points]
        Q -->|Low Severity| S[5 points]
        Q -->|Medium Severity| T[10 points]
        Q -->|High Severity| U[20 points]
        
        F --> V{Voting Consensus}
        V -->|< 60%| W[0 points]
        V -->|60-80%| X[5 points]
        V -->|> 80%| Y[10 points]
        
        G --> Z{Days Since Incident}
        Z -->|< 7 days| AA[10 points]
        Z -->|7-30 days| AB[5 points]
        Z -->|> 30 days| AC[2 points]
        
        I --> AD[Total Score]
        J --> AD
        K --> AD
        M --> AD
        N --> AD
        O --> AD
        P --> AD
        R --> AD
        S --> AD
        T --> AD
        U --> AD
        W --> AD
        X --> AD
        Y --> AD
        AA --> AD
        AB --> AD
        AC --> AD
        
        AD --> AE{Score Range}
        AE -->|0| AF[SAFE]
        AE -->|1-29| AG[LOW]
        AE -->|30-49| AH[MEDIUM]
        AE -->|50-69| AI[HIGH]
        AE -->|70-100| AJ[CRITICAL]
    end
    
    subgraph "Uniswap V4 Hook Integration"
        AK[User Initiates Swap] --> AL[VedyxRiskHook.beforeSwap]
        AL --> B
        
        AF --> AM[1% Fee<br/>✅ Allow Swap]
        AG --> AN[3% Fee<br/>✅ Allow Swap]
        AH --> AO[8% Fee<br/>✅ Allow Swap]
        AI --> AP{Config:<br/>blockHigh?}
        AJ --> AQ{Config:<br/>blockCritical?}
        
        AP -->|Yes| AR[❌ Block Swap<br/>Revert]
        AP -->|No| AS[15% Fee<br/>✅ Allow Swap]
        
        AQ -->|Yes| AT[❌ Block Swap<br/>Revert]
        AQ -->|No| AU[30% Fee<br/>✅ Allow Swap]
        
        AV[User Adds Liquidity] --> AW[VedyxRiskHook.beforeAddLiquidity]
        AW --> B
        
        AF --> AX[✅ Allow]
        AG --> AY[✅ Allow]
        AH --> AZ[✅ Allow]
        AI --> BA[❌ Block<br/>Revert]
        AJ --> BB[❌ Block<br/>Revert]
    end
    
    style A fill:#4ecdc4
    style AD fill:#ffeaa7
    style AF fill:#96ceb4
    style AG fill:#74b9ff
    style AH fill:#fdcb6e
    style AI fill:#fd79a8
    style AJ fill:#ff6b6b
    style AR fill:#ff6b6b
    style AT fill:#ff6b6b
    style BA fill:#ff6b6b
    style BB fill:#ff6b6b
```

## Risk Score Breakdown

### Factor Weights

| Factor | Weight | Description |
|--------|--------|-------------|
| **Verdict** | 0-40 | Community voting result (highest weight) |
| **Incidents** | 0-20 | Historical incident count |
| **Detectors** | 0-20 | Severity of detector flags |
| **Consensus** | 0-10 | Voting agreement strength |
| **Recency** | 0-10 | Time decay factor |

### Risk Level Thresholds

```mermaid
graph LR
    A[0] -->|SAFE| B[1-29]
    B -->|LOW| C[30-49]
    C -->|MEDIUM| D[50-69]
    D -->|HIGH| E[70-100]
    E -->|CRITICAL| F[Max]
    
    style A fill:#96ceb4
    style B fill:#74b9ff
    style C fill:#fdcb6e
    style D fill:#fd79a8
    style E fill:#ff6b6b
```

## Uniswap V4 Hook Response Matrix

### Swap Operations

| Risk Level | Score | Default Fee | Configurable Blocking |
|------------|-------|-------------|----------------------|
| SAFE       | 0     | 1%          | ❌ Never blocked     |
| LOW        | 1-29  | 3%          | ❌ Never blocked     |
| MEDIUM     | 30-49 | 8%          | ❌ Never blocked     |
| HIGH       | 50-69 | 15%         | ✅ Can be blocked    |
| CRITICAL   | 70+   | 30%         | ✅ Can be blocked    |

### Liquidity Operations

| Risk Level | Add Liquidity | Remove Liquidity |
|------------|---------------|------------------|
| SAFE       | ✅ Allowed    | ✅ Allowed       |
| LOW        | ✅ Allowed    | ✅ Allowed       |
| MEDIUM     | ✅ Allowed    | ✅ Allowed       |
| HIGH       | ❌ Blocked    | ❌ Blocked       |
| CRITICAL   | ❌ Blocked    | ❌ Blocked       |

## Configuration Options

### Hook Config (Owner-Controlled)

```solidity
struct HookConfig {
    bool dynamicFeesEnabled;    // Enable/disable dynamic fees
    bool blockHigh;             // Block HIGH risk swaps
    bool blockCritical;         // Block CRITICAL risk swaps
    uint24 minFee;              // Minimum fee (e.g., 1%)
    uint24 maxFee;              // Maximum fee (e.g., 30%)
}
```

### Fee Config (Owner-Controlled)

```solidity
struct FeeConfig {
    uint24 safeFee;       // 1% (0.01 * 1e6)
    uint24 lowFee;        // 3% (0.03 * 1e6)
    uint24 mediumFee;     // 8% (0.08 * 1e6)
    uint24 highFee;       // 15% (0.15 * 1e6)
    uint24 criticalFee;   // 30% (0.30 * 1e6)
}
```

## Example Scenarios

### Scenario 1: Clean User
- **Verdict**: None
- **Incidents**: 0
- **Detectors**: None
- **Score**: 0
- **Risk Level**: SAFE
- **Swap Fee**: 1%
- **Liquidity**: ✅ Allowed

### Scenario 2: Flagged Once
- **Verdict**: Suspicious
- **Incidents**: 1
- **Detectors**: Low severity
- **Consensus**: 65%
- **Recency**: 10 days
- **Score**: 40 + 5 + 5 + 5 + 5 = 60
- **Risk Level**: HIGH
- **Swap Fee**: 15% (or blocked if configured)
- **Liquidity**: ❌ Blocked

### Scenario 3: Repeat Offender
- **Verdict**: Suspicious
- **Incidents**: 3+
- **Detectors**: High severity
- **Consensus**: 85%
- **Recency**: 3 days
- **Score**: 40 + 20 + 20 + 10 + 10 = 100
- **Risk Level**: CRITICAL
- **Swap Fee**: 30% (or blocked if configured)
- **Liquidity**: ❌ Blocked

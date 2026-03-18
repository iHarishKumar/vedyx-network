# Detection Flow - Reactive Network

```mermaid
sequenceDiagram
    participant OC as Origin Chain
    participant RN as Reactive Network
    participant RSC as VedyxExploitDetectorRSC
    participant LTD as LargeTransferDetector
    participant MID as MixerInteractionDetector
    participant TPC as TracePeelChainDetector
    participant DC as Destination Chain
    participant VC as VedyxVotingContract

    OC->>OC: Suspicious Activity Occurs
    OC->>OC: Emit Transfer/Swap Event
    
    OC->>RN: Event Log Propagated
    RN->>RSC: react(log)
    
    RSC->>RSC: Get detectors for topic_0
    
    par Parallel Detection
        RSC->>LTD: detect(log)
        LTD->>LTD: Check transfer amount vs threshold
        LTD-->>RSC: (detected, address, payload)
    and
        RSC->>MID: detect(log)
        MID->>MID: Check mixer interaction
        MID-->>RSC: (detected, address, payload)
    and
        RSC->>TPC: detect(log)
        TPC->>TPC: Analyze peel chain pattern
        TPC-->>RSC: (detected, address, payload)
    end
    
    alt Threat Detected
        RSC->>RSC: Emit ThreatDetected event
        RSC->>DC: Emit Callback
        DC->>VC: tagSuspicious(address, chainId, ...)
        VC->>VC: Process suspicious address
        VC-->>DC: VotingStarted or AutoMarked event
    else No Threat
        RSC->>RSC: Continue monitoring
    end
```

## Key Points

### Singleton Pattern
- **Single Entry Point**: All events routed through VedyxExploitDetectorRSC
- **Topic-Based Routing**: Efficient filtering based on event signatures
- **Parallel Detection**: Multiple detectors analyze same event simultaneously

### Detector Independence
- **Stateless Detection**: Each detector makes independent decisions
- **Pluggable Architecture**: Add/remove detectors without redeploying singleton
- **Custom Logic**: Each detector implements specific attack pattern recognition

### Gas Optimization
- **Early Exit**: Stop processing if no detectors registered for topic
- **Minimal Callback**: Only essential data sent to destination chain
- **Batch Processing**: Multiple threats can be detected in single transaction

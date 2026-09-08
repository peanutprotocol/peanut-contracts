# Rebasing recipient replacement (TASK-21983)

PeanutV4.5 is an undeployed replacement for V4.4. Its recipient-facing type-4 transfer sends the scaled tokens to the authorized recipient. Sender reclaim retains its original destination and authorization. Historical V4.2, V4.3, V4.4 and archived V5 sources and deployed addresses remain unchanged; their recipient-facing type-4 claims are unsafe. The zkSync copies share that defect.

The API must reject type-4 claims on affected immutable deployments using the authoritative on-chain deposit type. Creating new type-4 deposits on these deployments must stay disabled; the current app creates only type-1 USDC links. Do not advertise the replacement or add a deployment address until deployment and verification are separately approved and complete.

Before deployment: independently review the replacement, run the complete contract suite, choose target networks and ECO configuration, verify the intended bytecode and address, and update the API/UI allowlists only after on-chain verification. Production deployment is not performed by this patch.

The replacement also rejects nonzero ETH on token deposits before token transfers or EIP-3009 authorization consumption. All five approval entry points enforce this for token types 1-4; native deposits still require an exact ETH amount. A valid gasless authorization remains reusable after a rejected call carrying ETH.

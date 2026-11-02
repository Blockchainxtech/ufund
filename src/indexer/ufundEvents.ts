/// Event ABI of ERC-8318 (Tokenized fund lifecycle metadata), core + AUM/MultiClass/ProofOfReserves extensions.
export const UFUND_EVENT_ABI = [
  "event NavUpdated(uint256 previousNav,uint256 newNav,uint8 navDecimals,uint256 effectiveAt)",
  "event LifecycleStateChanged(uint8 indexed previousState,uint8 indexed newState,uint256 timestamp)",
  "event DistributionDeclared(uint256 indexed id,uint8 indexed distributionType,uint256 exDate,uint256 recordDate,uint256 paymentDate,uint256 amountPerShare,uint8 amountDecimals,bytes3 currency)",
  "event DistributionPaid(uint256 indexed id,uint256 totalAmount,uint8 amountDecimals,bytes3 currency,uint256 paidAt)",
  "event DistributionCancelled(uint256 indexed id,string reason)",
  "event AUMUpdated(uint256 previousAum,uint256 newAum,uint8 decimals,uint256 effectiveAt)",
  "event ShareClassAdded(bytes32 indexed id,string name,string symbol)",
  "event ClassNavUpdated(bytes32 indexed shareClassId,uint256 previousNav,uint256 newNav,uint8 navDecimals,uint256 effectiveAt)",
  "event ClassLifecycleStateChanged(bytes32 indexed shareClassId,uint8 indexed previousState,uint8 indexed newState,uint256 timestamp)",
  "event ClassDistributionDeclared(bytes32 indexed shareClassId,uint256 indexed id,uint8 indexed distributionType,uint256 exDate,uint256 recordDate,uint256 paymentDate,uint256 amountPerShare,uint8 amountDecimals,bytes3 currency)",
  "event ClassDistributionPaid(bytes32 indexed shareClassId,uint256 indexed id,uint256 totalAmount,uint8 amountDecimals,bytes3 currency,uint256 paidAt)",
  "event ClassDistributionCancelled(bytes32 indexed shareClassId,uint256 indexed id,string reason)",
  "event AttestationPublished(bytes32 indexed attestationHash,uint256 attestedAt,uint16 reservesToSupplyBps,string attestationURI)"
] as const;

export type UFundLifecycleState =
  | "Pending"
  | "SubscriptionOpen"
  | "SubscriptionClosed"
  | "Operating"
  | "RedemptionOnly"
  | "WindingDown"
  | "Closed"
  | "Paused";

export const LIFECYCLE_STATES: UFundLifecycleState[] = [
  "Pending",
  "SubscriptionOpen",
  "SubscriptionClosed",
  "Operating",
  "RedemptionOnly",
  "WindingDown",
  "Closed",
  "Paused"
];

export function lifecycleStateName(index: number): UFundLifecycleState {
  const state = LIFECYCLE_STATES[index];
  if (!state) throw new Error(`Unknown uFund lifecycle state: ${index}`);
  return state;
}

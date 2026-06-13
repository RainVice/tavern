export interface NetworkPolicyOptions {
  enabled: boolean;
  whitelist: Array<string>;
  allowUnresolvedHosts: boolean;
  logAllowed?: boolean;
  logBlocked?: boolean;
}

export interface NetworkPolicyDecision {
  host: string;
  address: string;
  allowed: boolean;
  reason: string;
  matchedRule: string;
}

export interface NetworkPolicyAllowedPayload {
  host: string;
  address: string;
  reason: string;
  matchedRule: string;
}

export interface NetworkPolicyBlockedPayload {
  host: string;
  address: string;
  reason: string;
  matchedRule: string;
}

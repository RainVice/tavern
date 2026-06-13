import type { ConnectionHeaderRecord } from '../connection/ConnectionProfileModels';

export interface NetworkHeaderOverrideRule {
  hosts: Array<string>;
  headers: Array<ConnectionHeaderRecord>;
}

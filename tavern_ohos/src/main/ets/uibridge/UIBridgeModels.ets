export interface UIRequestResponse {
  value: string;
  selectedValues: Array<string>;
  confirmed: boolean;
  cancelled: boolean;
  filePaths: Array<string>;
  metadataJson: string;
}

export interface UIRequestRecord {
  id: string;
  requestType: string;
  title: string;
  message: string;
  defaultValue: string;
  optionsJson: string;
  multiple: boolean;
  severity: string;
  visible: boolean;
  mediaType: string;
  mediaUri: string;
  target: string;
  progressCurrent: number;
  progressTotal: number;
  autoPlay: boolean;
  resolved: boolean;
  response: UIRequestResponse;
  createdAt: number;
  updatedAt: number;
}

export interface UIRequestEventPayload {
  request: UIRequestRecord;
}

export interface UIRequestResolvedPayload {
  request: UIRequestRecord;
}

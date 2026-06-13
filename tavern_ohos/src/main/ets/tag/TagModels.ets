export interface TagCreateParams {
  id?: string;
  name: string;
  folderType?: string;
  filterState?: string;
  sortOrder?: number;
  color?: string;
  color2?: string;
  hiddenOnCharacterCard?: boolean;
}

export interface TagRecord {
  id: string;
  name: string;
  folderType: string;
  filterState: string;
  sortOrder: number;
  color: string;
  color2: string;
  createDate: number;
  hiddenOnCharacterCard: boolean;
}

export interface TagImportResult {
  entityKey: string;
  imported: Array<TagRecord>;
  ignored: Array<string>;
  created: Array<TagRecord>;
}

export interface TagEventPayload {
  tag: TagRecord;
}

export interface TagMapEventPayload {
  entityKey: string;
  tagIds: Array<string>;
}

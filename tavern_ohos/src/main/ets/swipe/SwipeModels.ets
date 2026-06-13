export interface SwipeCreateParams {
  chatId: string;
  messageId: string;
  text: string;
}

export interface SwipeRecord {
  chatId: string;
  messageId: string;
  index: number;
  text: string;
  active: boolean;
  state: string;
  error: string;
  createdAt: number;
  updatedAt: number;
}

export interface SwipeStreamState {
  index: number;
  state: string;
  text: string;
  error: string;
}

export interface SwipeChangedPayload {
  chatId: string;
  messageId: string;
  swipeIndex: number;
  swipe: SwipeRecord;
}

export interface SwipeDeletedPayload {
  chatId: string;
  messageId: string;
  swipeIndex: number;
}

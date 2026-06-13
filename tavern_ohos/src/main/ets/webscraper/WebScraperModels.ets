export interface ScrapeRequest { url: string; extractText: boolean; extractImages: boolean; maxChars: number; }
export interface ScrapeResult { url: string; title: string; textContent: string; imageUrls: Array<string>; success: boolean; error: string; }
export interface ScrapeCompletedPayload { result: ScrapeResult; }

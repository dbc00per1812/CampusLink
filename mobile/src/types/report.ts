// Report Types - Converted from ReportModels.swift

export type ReportType = 
  | 'inappropriate_content'
  | 'scam'
  | 'harassment'
  | 'spam'
  | 'fake_profile'
  | 'other';

export type ReportStatus = 'pending' | 'reviewing' | 'resolved' | 'dismissed';

export interface Report {
  id: string;
  reporter_id: string;
  reported_user_id: string | null;
  reported_listing_id: string | null;
  report_type: ReportType;
  description: string;
  status: ReportStatus;
  created_at: string;
  updated_at: string | null;
}

export interface ReportCreate {
  reporter_id: string;
  reported_user_id?: string | null;
  reported_listing_id?: string | null;
  report_type: ReportType;
  description: string;
}

// Display helpers
export const ReportTypeDisplay: Record<ReportType, string> = {
  inappropriate_content: 'Inappropriate Content',
  scam: 'Scam or Fraud',
  harassment: 'Harassment or Bullying',
  spam: 'Spam',
  fake_profile: 'Fake Profile',
  other: 'Other',
};

export const ReportTypeDescription: Record<ReportType, string> = {
  inappropriate_content: 'Content that violates community guidelines',
  scam: 'Suspicious or fraudulent activity',
  harassment: 'Threatening or abusive behavior',
  spam: 'Repetitive or unwanted messages',
  fake_profile: 'Account impersonating someone else',
  other: 'Other violation not listed above',
};

export const REPORT_TYPES: ReportType[] = [
  'inappropriate_content',
  'scam',
  'harassment',
  'spam',
  'fake_profile',
  'other',
];

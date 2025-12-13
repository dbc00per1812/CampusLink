// Report Types

export type ReportType =
  | 'inappropriate_content'
  | 'scam'
  | 'harassment'
  | 'spam'
  | 'fake_profile'
  | 'other';

export type ReportStatus = 'pending' | 'reviewing' | 'resolved' | 'dismissed';

export const ReportTypeDisplay: Record<ReportType, string> = {
  inappropriate_content: 'Inappropriate Content',
  scam: 'Scam',
  harassment: 'Harassment',
  spam: 'Spam',
  fake_profile: 'Fake Profile',
  other: 'Other',
};

export const ReportStatusDisplay: Record<ReportStatus, string> = {
  pending: 'Pending',
  reviewing: 'Under Review',
  resolved: 'Resolved',
  dismissed: 'Dismissed',
};

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
  reported_user_id: string | null;
  reported_listing_id: string | null;
  report_type: ReportType;
  description: string;
}


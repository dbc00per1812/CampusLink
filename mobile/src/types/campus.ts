// Campus Types

export type Campus = 'Indiana University Bloomington' | 'Purdue University' | 'UIUC';

export const CampusList: Campus[] = [
  'Indiana University Bloomington',
  'Purdue University',
  'UIUC',
];

export const CampusShortName: Record<Campus, string> = {
  'Indiana University Bloomington': 'IU',
  'Purdue University': 'Purdue',
  'UIUC': 'UIUC',
};

export const CampusFullName: Record<Campus, string> = {
  'Indiana University Bloomington': 'Indiana University Bloomington',
  'Purdue University': 'Purdue University',
  'UIUC': 'University of Illinois Urbana-Champaign',
};

// Domain to campus mapping
export const DomainToCampus: Record<string, Campus> = {
  'iu.edu': 'Indiana University Bloomington',
  'indiana.edu': 'Indiana University Bloomington',
  'purdue.edu': 'Purdue University',
  'illinois.edu': 'UIUC',
};

// Get campus from email
export const getCampusFromEmail = (email: string): Campus | null => {
  const domain = email.split('@')[1]?.toLowerCase();
  if (!domain) return null;
  return DomainToCampus[domain] ?? null;
};


// Blocked User Types

export interface BlockedUser {
  id: string;
  blocker_id: string;
  blocked_id: string;
  created_at: string;
}

export interface BlockedUserCreate {
  blocker_id: string;
  blocked_id: string;
}


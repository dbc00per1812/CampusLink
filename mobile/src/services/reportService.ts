// Report Service - Handles report-related API calls
import { supabase } from '../config/supabase';
import { ReportCreate } from '../types/report';
import { getCurrentUserId } from './authService';

/**
 * Submit a report for a user or listing
 */
export const submitReport = async (
  report: Omit<ReportCreate, 'reporter_id'>
): Promise<void> => {
  const currentUserId = await getCurrentUserId();
  
  if (!currentUserId) {
    throw new Error('You must be logged in to submit a report');
  }

  const { error } = await supabase
    .from('reports')
    .insert({
      reporter_id: currentUserId,
      reported_user_id: report.reported_user_id,
      reported_listing_id: report.reported_listing_id,
      report_type: report.report_type,
      description: report.description,
    });

  if (error) {
    console.error('Error submitting report:', error);
    throw error;
  }
};

export default {
  submitReport,
};

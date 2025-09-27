// Vercel Cron Function - api/process-notifications.js

export const config = {
  schedule: "* * * * *" // Run every minute
};

export default async function handler(req, res) {
  // Only allow Vercel Cron to call this function
  if (req.headers['authorization'] !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const response = await fetch('https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({})
    });

    const result = await response.json();
    
    return res.status(200).json({
      success: true,
      processed: result.processed,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Failed to process notifications:', error);
    return res.status(500).json({ error: 'Processing failed' });
  }
}


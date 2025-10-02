// Test the delete_user edge function directly
const SUPABASE_URL = 'https://vnmzijluyctlufnzxast.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnphc3QiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTczNTQ0NzQ0MCwiZXhwIjoyMDUxMDIzNDQwfQ.8QZqJqJqJqJqJqJqJqJqJqJqJqJqJqJqJqJqJqJq';

async function testDeleteFunction() {
    const url = `${SUPABASE_URL}/functions/v1/delete_user`;
    
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer test-token' // This will fail auth, but we can see the response
            },
            body: JSON.stringify({})
        });
        
        const data = await response.text();
        console.log('Status:', response.status);
        console.log('Response:', data);
    } catch (error) {
        console.error('Error:', error);
    }
}

testDeleteFunction();

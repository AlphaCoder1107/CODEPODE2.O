// Simple Lambda that logs form data (no email required)
exports.handler = async (event) => {
    const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS'
    };
    
    if (event.httpMethod === 'OPTIONS') {
        return { statusCode: 200, headers };
    }
    
    try {
        const data = JSON.parse(event.body);
        
        // Log the form submission
        console.log('Contact Form Submission:', JSON.stringify(data, null, 2));
        
        // You can view these logs in CloudWatch
        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({ 
                message: 'Thank you! Your message has been received. We will contact you soon.',
                timestamp: new Date().toISOString()
            })
        };
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ message: 'Sorry, there was an error. Please try again.' })
        };
    }
};
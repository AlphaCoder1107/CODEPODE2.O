// AWS Lambda function for contact form
const AWS = require('aws-sdk');
const ses = new AWS.SES({ region: 'us-east-1' });

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
        
        const emailParams = {
            Source: 'noreply@YOUR_DOMAIN.com', // Replace with your domain
            Destination: {
                ToAddresses: ['hello@YOUR_DOMAIN.com'] // Replace with your email
            },
            Message: {
                Subject: {
                    Data: `New Contact Form: ${data.companyName}`
                },
                Body: {
                    Text: {
                        Data: `
Company: ${data.companyName}
Contact: ${data.contactName}
Email: ${data.email}
Phone: ${data.phone || 'Not provided'}
Website: ${data.website || 'Not provided'}
Industry: ${data.industry || 'Not provided'}
Employees: ${data.employees || 'Not provided'}
Address: ${data.address || 'Not provided'}
Message: ${data.message || 'Not provided'}
                        `
                    }
                }
            }
        };

        await ses.sendEmail(emailParams).promise();
        
        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({ message: 'Email sent successfully' })
        };
    } catch (error) {
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ message: 'Failed to send email' })
        };
    }
};
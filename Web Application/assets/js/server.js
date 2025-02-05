const express = require('express');
const oracledb = require('oracledb');
const path = require('path');
const cors = require('cors');  // Import the cors package
require('dotenv').config(); // Use environment variables

const app = express();
const port = 8000;

// Enable CORS for requests from http://127.0.0.1:5501
app.use(cors({
    origin: 'http://127.0.0.1:5501', // Allow only your frontend origin
}));

// Serve static files from "public" directory
app.use(express.static(path.join(__dirname, 'public')));

// Oracle Database connection configuration
const dbConfig = {
    user: process.env.DB_USER || 'travel_admin',
    password: process.env.DB_PASSWORD || 'Helloworld2009',
    connectString: process.env.DB_CONNECT_STRING || 'localhost:1521/travelagency'
};

// Middleware for logging requests
app.use((req, res, next) =>
{
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

// Endpoint to get customer, itinerary, bookings, and billing information
app.get('/itinerary/:customerID', async (req, res) =>
{
    const customerID = req.params.customerID;

    console.log(`Received request for itinerary of customerID: ${customerID}`);

    if (isNaN(customerID))
    {
        console.warn(`Invalid customerID provided: ${customerID}`);
        return res.status(400).json({ error: 'Invalid customer ID' });
    }

    let connection;
    try
    {
        console.log('Connecting to the database...');
        connection = await oracledb.getConnection(dbConfig);
        console.log('Database connection established');

        // Fetch customer information
        const customerQuery = `
            SELECT first_name, last_name, primary_phone, email, birth_date, address, city, province, country, postal_code
            FROM Customer
            WHERE customer_id = :customerID
        `;
        console.log(`Executing query: ${customerQuery}, with customerID: ${customerID}`);

        const customerResult = await connection.execute(customerQuery, [customerID]);

        if (customerResult.rows.length === 0)
        {
            console.warn(`Customer with ID ${customerID} not found`);
            return res.status(404).json({ message: 'Customer not found' });
        }

        // Fetch itinerary information
        const itineraryQuery = `
            SELECT itinerary_id, travel_class, booking_date, num_of_travellers
            FROM Itinerary
            WHERE customer_id = :customerID
        `;
        console.log(`Executing query: ${itineraryQuery}, with customerID: ${customerID}`);

        const itineraryResult = await connection.execute(itineraryQuery, [customerID]);

        let itineraries = [];

        for (const itineraryRow of itineraryResult.rows)
        {
            const itineraryID = itineraryRow[0];
            console.log(`Fetching bookings for itineraryID: ${itineraryID}`);

            // Fetch bookings for this itinerary
            const bookingQuery = `
                SELECT booking_id, start_date, end_date, description 
                FROM Booking 
                WHERE itinerary_id = :itineraryID
            `;
            console.log(`Executing query: ${bookingQuery}, with itineraryID: ${itineraryID}`);

            const bookingResult = await connection.execute(bookingQuery, [itineraryID]);
            let bookings = [];

            for (const bookingRow of bookingResult.rows)
            {
                const bookingID = bookingRow[0];
                console.log(`Fetching billings for bookingID: ${bookingID}`);

                // Fetch billings for this booking
                const billingQuery = `
                    SELECT billing_id, billing_date, bill_description, base_price, agency_fee, total_amount, paid_amount 
                    FROM Billing 
                    WHERE booking_id = :bookingID
                `;
                console.log(`Executing query: ${billingQuery}, with bookingID: ${bookingID}`);

                const billingResult = await connection.execute(billingQuery, [bookingID]);
                let billings = billingResult.rows.map(billing => ({
                    billing_id: billing[0],
                    billing_date: billing[1],
                    bill_description: billing[2],
                    base_price: billing[3],
                    agency_fee: billing[4],
                    total_amount: billing[5],
                    paid_amount: billing[6],
                }));

                bookings.push({
                    booking_id: bookingRow[0],
                    start_date: bookingRow[1],
                    end_date: bookingRow[2],
                    description: bookingRow[3],
                    billings: billings
                });
            }

            itineraries.push({
                itinerary_id: itineraryID,
                travel_class: itineraryRow[1],
                booking_date: itineraryRow[2],
                num_of_travellers: itineraryRow[3],
                bookings: bookings
            });
        }

        // Format the response
        const response = {
            customer: {
                first_name: customerResult.rows[0][0],
                last_name: customerResult.rows[0][1],
                primary_phone: customerResult.rows[0][2],
                email: customerResult.rows[0][3],
                birth_date: customerResult.rows[0][4],
                address: customerResult.rows[0][5],
                city: customerResult.rows[0][6],
                province: customerResult.rows[0][7],
                country: customerResult.rows[0][8],
                postal_code: customerResult.rows[0][9],
            },
            itineraries
        };

        console.log(`Successfully fetched data for customerID: ${customerID}`);
        console.log(response);
        res.json(response);
    } catch (error)
    {
        console.error('Database error:', error);
        res.status(500).json({ error: 'Database error' });
    } finally
    {
        if (connection)
        {
            try
            {
                await connection.close();
                console.log('Database connection closed');
            } catch (error)
            {
                console.error('Error closing connection:', error);
            }
        }
    }
});

// Start the server
app.listen(port, () =>
{
    console.log(`Server running on http://localhost:${port}`);
});

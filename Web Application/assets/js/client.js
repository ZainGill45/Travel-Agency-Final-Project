async function fetchItinerary(customerID)
{
    try
    {
        const response = await fetch(`http://localhost:8000/itinerary/${customerID}`);

        if (!response.ok)
        {
            console.error(`Error: ${response.status} ${response.statusText}`);
            return;
        }

        const data = await response.json();
        console.log('Fetched Itinerary Data:', data);
    } catch (error)
    {
        console.error('Request failed:', error);
    }
}

// Example usage: replace with an actual customer ID
fetchItinerary(104);

const customerItineraryInfoInsertPoint = document.querySelector('#customer-itinerary-insert-point');
const customerGeneralInfoInsertPoint = document.querySelector('#customer-general-insert-point');
const customerSearchButton = document.querySelector('#search-button');
const customerSearchInput = document.querySelector("#search-input");

document.addEventListener("DOMContentLoaded", () =>
{
    customerSearchButton.addEventListener("click", () =>
    {
        customerGeneralInfoInsertPoint.innerHTML = "";
        customerItineraryInfoInsertPoint.innerHTML = "";

        if (/^[0-9]+$/.test(customerSearchInput.value))
        {
            fetchItinerary(parseInt(customerSearchInput.value));
            customerSearchInput.value = '';
        } else
        {
            alert("This is an invalid input please try again");
        }

    });
});

async function fetchItinerary(customerID)
{
    try
    {
        const response = await fetch(`http://localhost:8000/itinerary/${customerID}`);

        if (!response.ok)
        {
            console.error(`Error: ${response.status} ${response.statusText}`);
            alert("Customer not found please check input ID")
            return;
        }

        const data = await response.json();
        console.log('Fetched Itinerary Data:', data);

        const customer = data.customer;

        RenderGeneralCustomerInfo(customer.customer_id, customer.first_name, customer.last_name, customer.email, customer.primary_phone, customer.birth_date,
            customer.address, customer.city, customer.province, customer.country, customer.postal_code);
        RenderItineraryInfo(data.itineraries);
    } catch (error)
    {
        console.error('Request failed:', error);
    }
}

function RenderGeneralCustomerInfo(customerID, firstName, lastName, email, phone, birthDate, address, city, province, country, postalCode)
{
    const fullName = `${firstName} ${lastName}`;
    const infoContainer = document.createElement("div");
    infoContainer.classList.add("info-container");

    const customerInfo = [
        { label: "Customer ID", value: customerID },
        { label: "Name", value: fullName },
        { label: "Email", value: email },
        { label: "Phone", value: phone },
        { label: "Birth Date", value: formatDate(birthDate) },
        { label: "Address", value: address },
        { label: "City", value: city },
        { label: "Province", value: province },
        { label: "Country", value: country },
        { label: "Postal Code", value: postalCode }
    ];

    customerInfo.forEach(({ label, value }) =>
    {
        const p = document.createElement("p");
        p.classList.add("info-item");

        const span = document.createElement("span");
        span.classList.add("info-label");
        span.textContent = `${label}: `;

        p.appendChild(span);
        p.appendChild(document.createTextNode(value ?? "N/A"));
        infoContainer.appendChild(p);
    });

    if (customerGeneralInfoInsertPoint)
    {
        customerGeneralInfoInsertPoint.appendChild(infoContainer);
    } else
    {
        console.error("Insert point not found!");
    }
}


function RenderItineraryInfo(itineraries)
{
    if (!customerItineraryInfoInsertPoint)
    {
        console.error('Insert point element not found');
        return;
    }

    const renderedContent = itineraries.map(itineraryElement =>
    {
        // Map bookings to HTML strings first
        const bookingsHTML = itineraryElement.bookings.map(booking =>
        {
            // Generate HTML for all billings
            const billingsHTML = booking.billings.map(billing => `
                <div class="billing-details">
                    <p class="info-item" style="font-weight: 600">Billing ID: ${billing.billing_id ?? "N/A"}</p>
                    <p class="info-item">Billing Date: ${formatDate(billing.billing_date) ?? "N/A"}</p>
                    <p class="info-item">Bill Description: ${billing.bill_description ?? "N/A"}</p>
                    <p class="info-item">Base Price: $${billing.base_price ?? "N/A"}</p>
                    <p class="info-item">Agency Fee: $${billing.agency_fee ?? "N/A"}</p>
                    <p class="info-item">Total Amount: $${billing.total_amount ?? "N/A"}</p>
                    <p class="info-item">Paid Amount: $${billing.paid_amount ?? "N/A"}</p>
                </div>
            `).join('');

            return `
                <details class="collapsible nested">
                    <summary class="collapsible-header">
                        <span>Booking: ${booking.booking_id}</span>
                        <svg class="chevron-icon" viewBox="0 0 24 24" width="24" height="24"
                            stroke="currentColor" stroke-width="2" fill="none">
                            <polyline points="6 9 12 15 18 9"></polyline>
                        </svg>
                    </summary>
                    <div class="collapsible-content">
                        <p class="info-item">Start Date: ${formatDate(booking.start_date) ?? "N/A"}</p>
                        <p class="info-item">End Date: ${formatDate(booking.end_date) ?? "N/A"}</p>
                        <p class="info-item">Description: ${booking.description ?? "N/A"}</p>

                        <h3 class="subsection-title">Billing Details</h3>
                        ${billingsHTML}
                    </div>
                </details>
            `;
        }).join('');

        let parsedTravelClass;
        switch (itineraryElement.travel_class)
        {
            case 'FST':
                parsedTravelClass = 'First Class';
                break;
            case 'BSN':
                parsedTravelClass = 'Business';
                break;
            case 'ECN':
                parsedTravelClass = 'Economy';
                break;
            case 'OCNVI':
                parsedTravelClass = 'Ocean View';
                break;
            case 'INT':
                parsedTravelClass = 'Interior';
                break;
            case 'DELX':
                parsedTravelClass = 'Deluxe';
                break;
            case 'DBL':
                parsedTravelClass = 'Double';
                break;
            case 'SNG':
                parsedTravelClass = 'Single';
                break;
            default:
                parsedTravelClass = 'Unknown';
        }

        return `
            <details class="collapsible">
                <summary class="collapsible-header">
                    <span>Itinerary: ${itineraryElement.itinerary_id}</span>
                    <svg class="chevron-icon" viewBox="0 0 24 24" width="24" height="24" stroke="currentColor"
                        stroke-width="2" fill="none">
                        <polyline points="6 9 12 15 18 9"></polyline>
                    </svg>
                </summary>
                <div class="collapsible-content">
                    <p class="info-item">Booking Date: ${formatDate(itineraryElement.booking_date)}</p>
                    <p class="info-item">Travel Class: ${parsedTravelClass}</p>
                    <p class="info-item">Number of Travellers: ${itineraryElement.num_of_travellers}</p>
                    ${bookingsHTML}
                </div>
            </details>
        `;
    }).join('');

    customerItineraryInfoInsertPoint.innerHTML = renderedContent;
}

function formatDate(dateString)
{
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
}
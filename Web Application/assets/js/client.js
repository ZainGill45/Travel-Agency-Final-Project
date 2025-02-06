const UI = {
    showUserMessage: (message, isError = false) =>
    {
        alert(message);
    },
    createChevronSVG: () => `
        <svg class="chevron-icon" viewBox="0 0 24 24" width="24" height="24"
            stroke="currentColor" stroke-width="2" fill="none">
            <polyline points="6 9 12 15 18 9"></polyline>
        </svg>
    `
};

const CONFIG = {
    API_BASE_URL: 'http://localhost:8000',
    TRAVEL_CLASS_MAPPINGS: {
        FST: 'First Class',
        BSN: 'Business',
        ECN: 'Economy',
        OCNVI: 'Ocean View',
        OCNV: 'Ocean View',
        INT: 'Interior',
        DELX: 'Deluxe',
        DLX: 'Deluxe',
        DBL: 'Double',
        SNG: 'Single'
    }
};

class CustomerItineraryManager
{
    constructor()
    {
        this.elements = {
            itineraryInfo: document.querySelector('#customer-itinerary-insert-point'),
            generalInfo: document.querySelector('#customer-general-insert-point'),
            customerSearchForm: document.querySelector('#customer-search-form'),
            searchButton: document.querySelector('#search-button'),
            searchInput: document.querySelector("#search-input")
        };

        this.init();
    }

    init()
    {
        document.addEventListener("DOMContentLoaded", () =>
        {
            this.elements.customerSearchForm.addEventListener("submit", (submitEvent) => this.handleSearch(submitEvent));
        });
    }

    async handleSearch(submitEvent)
    {
        submitEvent.preventDefault();

        this.elements.generalInfo.innerHTML = "";
        this.elements.itineraryInfo.innerHTML = "";

        try
        {
            const customerId = this.validateCustomerId(this.elements.searchInput.value);
            await this.fetchAndRenderItinerary(customerId);
            this.elements.searchInput.value = '';
        } catch (error)
        {
            UI.showUserMessage(error.message, true);
        }
    }

    validateCustomerId(input)
    {
        const customerId = input.trim();
        if (!customerId)
        {
            throw new Error('Please enter a customer ID');
        }
        if (!/^\d+$/.test(customerId))
        {
            this.elements.searchInput.value = '';
            throw new Error('Customer ID must contain only numbers');
        }
        return parseInt(customerId);
    }

    async fetchAndRenderItinerary(customerID)
    {
        try
        {
            const response = await fetch(`${CONFIG.API_BASE_URL}/itinerary/${customerID}`);

            if (!response.ok)
                throw new Error(`Customer not found (ID: ${customerID})`);

            const data = await response.json();
            this.renderCustomerData(data);
        } catch (error)
        {
            throw new Error(`Failed to fetch customer data: ${error.message}`);
        }
    }

    renderCustomerData(data)
    {
        const { customer, itineraries } = data;

        this.renderGeneralInfo(customer);
        this.renderItineraries(itineraries);
    }

    renderGeneralInfo(customer)
    {
        const infoContainer = document.createElement("div");
        infoContainer.classList.add("info-container");

        const customerInfo = [
            { label: "Customer ID", value: customer.customer_id },
            { label: "Name", value: `${customer.first_name} ${customer.last_name}` },
            { label: "Email", value: customer.email },
            { label: "Phone", value: customer.primary_phone },
            { label: "Birth Date", value: this.formatDate(customer.birth_date) },
            { label: "Address", value: customer.address },
            { label: "City", value: customer.city },
            { label: "Province", value: customer.province },
            { label: "Country", value: customer.country },
            { label: "Postal Code", value: customer.postal_code }
        ];

        infoContainer.innerHTML = customerInfo
            .map(({ label, value }) => `
                <p class="info-item">
                    <span class="info-label">${label}: </span>
                    ${value ?? "N/A"}
                </p>
            `).join('');

        this.elements.generalInfo.appendChild(infoContainer);
    }

    renderItineraries(itineraries)
    {
        if (!this.elements.itineraryInfo) return;

        const itinerariesHTML = itineraries.map(itinerary => this.createItineraryHTML(itinerary)).join('');
        this.elements.itineraryInfo.innerHTML = itinerariesHTML;
    }

    calculatePaymentStatus(billings)
    {
        const totalAmount = billings.reduce((sum, billing) => sum + (billing.total_amount || 0), 0);
        const paidAmount = billings.reduce((sum, billing) => sum + (billing.paid_amount || 0), 0);

        // Using small epsilon for floating point comparison
        return Math.abs(totalAmount - paidAmount) < 0.01;
    }

    createItineraryHTML(itinerary)
    {
        const allBookingBillings = itinerary.bookings.flatMap(booking => booking.billings);
        const isFullyPaid = this.calculatePaymentStatus(allBookingBillings);
        const paymentStatusClass = isFullyPaid ? 'paid' : 'unpaid';

        return `
            <details class="collapsible ${paymentStatusClass}">
                <summary class="collapsible-header">
                    <span>Itinerary: ${itinerary.itinerary_id}</span>
                    ${UI.createChevronSVG()}
                </summary>
                <div class="collapsible-content">
                    <p class="info-item">Booking Date: ${this.formatDate(itinerary.booking_date)}</p>
                    <p class="info-item">Travel Class: ${this.getTravelClassName(itinerary.travel_class)}</p>
                    <p class="info-item">Number of Travellers: ${itinerary.num_of_travellers}</p>
                    ${this.createBookingsHTML(itinerary.bookings)}
                </div>
            </details>
        `;
    }

    createBookingsHTML(bookings)
    {
        return bookings.map(booking =>
        {
            const isFullyPaid = this.calculatePaymentStatus(booking.billings);
            const paymentStatusClass = isFullyPaid ? 'paid' : 'unpaid';

            return `
                <details class="collapsible nested ${paymentStatusClass}">
                    <summary class="collapsible-header">
                        <span>Booking: ${booking.booking_id}</span>
                        ${UI.createChevronSVG()}
                    </summary>
                    <div class="collapsible-content">
                        <p class="info-item">Start Date: ${this.formatDate(booking.start_date)}</p>
                        <p class="info-item">End Date: ${this.formatDate(booking.end_date)}</p>
                        <p class="info-item">Description: ${booking.description ?? "N/A"}</p>
                        
                        ${this.createBillingsHTML(booking.billings)}
                    </div>
                </details>
            `;
        }).join('');
    }

    createBillingsHTML(billings)
    {
        return `
                ${billings.map(billing => `
            <div class="billing-detail">
                    <p class="info-item billing-id">Billing ID: ${billing.billing_id ?? "N/A"}</p>
                    <hr>
                    <p class="info-item">Billing Date: ${this.formatDate(billing.billing_date)}</p>
                    <p class="info-item">Bill Description: ${billing.bill_description ?? "N/A"}</p>
                    <p class="info-item">Base Price: $${billing.base_price ?? "N/A"}</p>
                    <p class="info-item">Agency Fee: $${billing.agency_fee ?? "N/A"}</p>
                    <p class="info-item">Total Amount: $${billing.total_amount ?? "N/A"}</p>
                    <p class="info-item">Paid Amount: $${billing.paid_amount ?? "N/A"}</p>
            </div>
                `).join('')}
        `;
    }

    getTravelClassName(code)
    {
        return CONFIG.TRAVEL_CLASS_MAPPINGS[code] || 'Unknown';
    }

    formatDate(dateString)
    {
        if (!dateString) return 'N/A';
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }
}

const customerManager = new CustomerItineraryManager();
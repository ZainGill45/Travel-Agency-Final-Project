BEGIN 
    create_ta_database;
END;
/

CREATE OR PROCEDURE create_travel_agency_tables AS
    v_table_exists NUMBER;
BEGIN
    -- Drop existing tables if they exist
    FOR t IN (
        SELECT table_name
        FROM (
            SELECT 'TAX' AS table_name FROM DUAL
            UNION ALL SELECT 'TAX_TYPE' FROM DUAL
            UNION ALL SELECT 'BILLING' FROM DUAL
            UNION ALL SELECT 'BOOKING' FROM DUAL
            UNION ALL SELECT 'ITINERARY' FROM DUAL
            UNION ALL SELECT 'DESTINATION' FROM DUAL
            UNION ALL SELECT 'CUSTOMER' FROM DUAL
            UNION ALL SELECT 'AGENT' FROM DUAL
            UNION ALL SELECT 'PRODUCT' FROM DUAL
            UNION ALL SELECT 'SUPPLIER' FROM DUAL
            UNION ALL SELECT 'REPRESENT' FROM DUAL
            UNION ALL SELECT 'AFFILIATION' FROM DUAL
        )
    ) LOOP
        SELECT COUNT(*)
        INTO v_table_exists
        FROM user_tables
        WHERE table_name = t.table_name;

        IF v_table_exists > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
        END IF;
    END LOOP;

    -- Create tables
    EXECUTE IMMEDIATE '
        CREATE TABLE AFFILIATION (
            affiliation_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            name VARCHAR2(128) NOT NULL,
            CONSTRAINT pk_affiliation PRIMARY KEY (affiliation_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE REPRESENT (
            represent_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            name VARCHAR2(128) NOT NULL,
            CONSTRAINT pk_represent PRIMARY KEY (represent_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE SUPPLIER (
            supplier_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            affiliation_id NUMBER,
            represent_id NUMBER,
            contact_name VARCHAR2(64),
            phone VARCHAR2(15),
            fax VARCHAR2(15),
            email VARCHAR2(128),
            website VARCHAR2(128),
            address VARCHAR2(128),
            city VARCHAR2(64),
            province VARCHAR2(128),
            country VARCHAR2(128),
            postal_code VARCHAR2(10),
            CONSTRAINT pk_supplier PRIMARY KEY (supplier_id),
            CONSTRAINT fk_supplier_affiliation FOREIGN KEY (affiliation_id)
                REFERENCES AFFILIATION (affiliation_id),
            CONSTRAINT fk_supplier_represent FOREIGN KEY (represent_id)
                REFERENCES REPRESENT (represent_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE PRODUCT (
            product_category_id NUMBER NOT NULL,
            supplier_id NUMBER NOT NULL,
            company_name VARCHAR2(64) NOT NULL,
            product_description VARCHAR2(64) NOT NULL,
            CONSTRAINT pk_product PRIMARY KEY (product_category_id, supplier_id),
            CONSTRAINT fk_product_supplier FOREIGN KEY (supplier_id)
                REFERENCES SUPPLIER (supplier_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE AGENT (
            agent_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            first_name VARCHAR2(64) NOT NULL,
            last_name VARCHAR2(64) NOT NULL,
            contact_number VARCHAR2(15),
            emergency_contact_number VARCHAR2(15),
            address VARCHAR2(128),
            email VARCHAR2(128),
            birth_date DATE,
            hire_date DATE,
            end_date DATE,
            CONSTRAINT pk_agent PRIMARY KEY (agent_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE CUSTOMER (
            customer_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            first_name VARCHAR2(64) NOT NULL,
            last_name VARCHAR2(64) NOT NULL,
            primary_phone VARCHAR2(15) NOT NULL,
            email VARCHAR2(128),
            secondary_phone VARCHAR2(15),
            birth_date DATE,
            address VARCHAR2(128),
            city VARCHAR2(64),
            province VARCHAR2(128),
            country VARCHAR2(128),
            postal_code VARCHAR2(10),
            CONSTRAINT pk_customer PRIMARY KEY (customer_id),
            CONSTRAINT uk_customer_email UNIQUE (email)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE ITINERARY (
            itinerary_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            customer_id NUMBER NOT NULL,
            agent_id NUMBER NOT NULL,
            booking_date DATE NOT NULL,
            travel_class VARCHAR2(5),
            num_of_travellers NUMBER,
            CONSTRAINT pk_itinerary PRIMARY KEY (itinerary_id),
            CONSTRAINT fk_itinerary_customer FOREIGN KEY (customer_id)
                REFERENCES CUSTOMER (customer_id),
            CONSTRAINT fk_itinerary_agent FOREIGN KEY (agent_id)
                REFERENCES AGENT (agent_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE BOOKING (
            booking_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            product_category_id NUMBER,
            supplier_id NUMBER,
            itinerary_id NUMBER,
            start_date DATE NOT NULL,
            end_date DATE NOT NULL,
            commision_owed NUMERIC(10, 2),
            commision_received NUMERIC(10, 2),
            description VARCHAR2(255),
            CONSTRAINT pk_booking PRIMARY KEY (booking_id),
            CONSTRAINT fk_booking_product FOREIGN KEY (product_category_id, supplier_id)
                REFERENCES PRODUCT (product_category_id, supplier_id),
            CONSTRAINT fk_booking_itinerary FOREIGN KEY (itinerary_id)
                REFERENCES ITINERARY (itinerary_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE BILLING (
            billing_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            customer_id NUMBER,
            billing_date DATE NOT NULL,
            bill_description VARCHAR2(64),
            base_price NUMERIC(10, 2) NOT NULL,
            agency_fee NUMERIC(10, 2),
            total_amount NUMERIC(10, 2),
            paid_amount NUMERIC(10, 2),
            CONSTRAINT pk_billing PRIMARY KEY (billing_id),
            CONSTRAINT fk_billing_customer FOREIGN KEY (customer_id)
                REFERENCES CUSTOMER (customer_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE TAX_TYPE (
            tax_type_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            tax_type VARCHAR2(64) NOT NULL,
            CONSTRAINT pk_tax_type PRIMARY KEY (tax_type_id)
        )';

    EXECUTE IMMEDIATE '
        CREATE TABLE TAX (
            tax_id NUMBER GENERATED BY DEFAULT AS IDENTITY,
            billing_id NUMBER,
            tax_type_id NUMBER,
            tax_amount NUMERIC(10, 2),
            CONSTRAINT pk_tax PRIMARY KEY (tax_id),
            CONSTRAINT fk_tax_billing FOREIGN KEY (billing_id)
                REFERENCES BILLING (billing_id),
            CONSTRAINT fk_tax_type FOREIGN KEY (tax_type_id)
                REFERENCES TAX_TYPE (tax_type_id)
        )';

    -- Insert legacy data
    INSERT INTO AGENT (agent_id, first_name, last_name)
    VALUES (0, 'Legacy', 'Agent');

    INSERT INTO SUPPLIER (supplier_id, contact_name)
    VALUES (0, 'LEGACY SUPPLIER');

    INSERT INTO PRODUCT (product_category_id, supplier_id, company_name, product_description)
    VALUES (0, 0, 'LEGACY PRODUCT', 'PRODUCT DESCRIPTION');

    INSERT INTO TAX_TYPE (tax_type_id, tax_type)
    VALUES (0, 'LEGACY TAX');

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/
BEGIN
    migrate_customer_data;
END;
/

CREATE OR REPLACE PROCEDURE migrate_customer_data AUTHID CURRENT_USER AS
    v_current_email VARCHAR2(128);
    v_current_postal_code VARCHAR2(10);
BEGIN
    FOR legacy_customer IN (SELECT * FROM LEGACY_CUSTOMER) LOOP
        BEGIN
            v_current_email := NULL;
            v_current_postal_code := NULL;

            IF legacy_customer.email != ' ' THEN
                v_current_email := legacy_customer.email;
            END IF;

            -- Remove all whitespace from a given postal code or zip code
            SELECT REPLACE(legacy_customer.POSTAL_CODE, ' ', '')
            INTO v_current_postal_code
            FROM dual;

            INSERT INTO CUSTOMER (
                CUSTOMER_ID,
                FIRST_NAME,
                LAST_NAME,
                EMAIL,
                PRIMARY_PHONE,
                SECONDARY_PHONE,
                BIRTH_DATE,
                ADDRESS,
                CITY,
                PROVINCE,
                COUNTRY,
                POSTAL_CODE
            ) VALUES (
                legacy_customer.CUST_ID,
                legacy_customer.FIRST_NAME,
                legacy_customer.LAST_NAME,
                v_current_email,
                legacy_customer.HOME_PHONE,
                legacy_customer.BUSINESS_PHONE,
                legacy_customer.BIRTH_DATE,
                legacy_customer.ADDRESS,
                legacy_customer.CITY,
                legacy_customer.PROVINCE,
                legacy_customer.COUNTRY,
                v_current_postal_code
            );
        END;
    END LOOP;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
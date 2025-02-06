BEGIN
    migrate_sale_data;
END;
/

CREATE OR REPLACE PROCEDURE migrate_sale_data AUTHID CURRENT_USER AS
    v_current_class            VARCHAR2(5);
    v_current_bill_description VARCHAR2(64);
    v_agent_id                 NUMBER;
    v_itinerary_exists         NUMBER;
    v_product_exists           NUMBER;
    v_product_category_id      NUMBER;
    v_product_supplier_id      NUMBER;
    v_booking_tax_amount       NUMBER;
    v_booking_total_amount     NUMBER;
    v_current_billing_id       NUMBER;
    v_current_booking_id       NUMBER;
BEGIN
    FOR legacy IN (SELECT * FROM LEGACY_SALE)
        LOOP
            /*#region Handle Agent Assignment*/
            IF legacy.AGENT IS NULL THEN
                v_agent_id := 0;
            ELSE
                DECLARE
                    v_agent_first_name VARCHAR2(1) := SUBSTR(legacy.AGENT, 1, 1);
                    v_agent_last_name  VARCHAR2(1) := SUBSTR(legacy.AGENT, 2, 1);
                BEGIN
                    BEGIN
                        SELECT agent_id
                        INTO v_agent_id
                        FROM AGENT
                        WHERE FIRST_NAME = v_agent_first_name
                          AND LAST_NAME = v_agent_last_name;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            -- Insert the agent if not found
                            INSERT INTO AGENT (FIRST_NAME, LAST_NAME)
                            VALUES (v_agent_first_name, v_agent_last_name)
                            RETURNING agent_id INTO v_agent_id;
                    END;
                END;
            END IF;
            /*#endregion Handle Agent Assignment*/

            /*#region Class Insertion*/
            IF legacy.CLASS = ' ' THEN
                v_current_class := NULL;
            ELSE
                v_current_class := legacy.CLASS;
            END IF;
            /*#endregion*/

            /*#region Itinerary Duplication Prevention*/
            SELECT COUNT(*)
            INTO v_itinerary_exists
            FROM ITINERARY
            WHERE ITINERARY_ID = legacy.ITINERARY_#;

            IF v_itinerary_exists = 0 THEN
                INSERT INTO ITINERARY (ITINERARY_ID,
                                       CUSTOMER_ID,
                                       AGENT_ID,
                                       BOOKING_DATE,
                                       TRAVEL_CLASS,
                                       NUM_OF_TRAVELLERS)
                VALUES (legacy.ITINERARY_#,
                        legacy.CUST_ID,
                        v_agent_id,
                        legacy.SALE_DATE,
                        v_current_class,
                        legacy.NUM_OF_TRAVELLERS);
            END IF;
            /*#endregion*/

            /*#region Product Validity Check*/
            SELECT COUNT(*)
            INTO v_product_exists
            FROM PRODUCT
            WHERE PRODUCT_CATEGORY_ID = legacy.PRODUCT_CATEGORY
              AND SUPPLIER_ID = legacy.PRODUCT_SUPPLIER_ID;

            IF v_product_exists = 0 THEN
                v_product_category_id := 0;
                v_product_supplier_id := 0;
            ELSE
                -- Fetch IDs for existing product
                SELECT PRODUCT_CATEGORY_ID, SUPPLIER_ID
                INTO v_product_category_id, v_product_supplier_id
                FROM PRODUCT
                WHERE PRODUCT_CATEGORY_ID = legacy.PRODUCT_CATEGORY
                  AND SUPPLIER_ID = legacy.PRODUCT_SUPPLIER_ID;
            END IF;
            /*#endregion*/

            /*#region Update Booking Table*/
            INSERT INTO BOOKING (PRODUCT_CATEGORY_ID,
                                 SUPPLIER_ID,
                                 ITINERARY_ID,
                                 START_DATE,
                                 END_DATE,
                                 COMMISION_OWED,
                                 COMMISION_RECEIVED,
                                 DESCRIPTION)
            VALUES (v_product_category_id,
                    v_product_supplier_id,
                    legacy.ITINERARY_#,
                    legacy.TRIP_START,
                    legacy.TRIP_END,
                    legacy.AGENCY_COMMISSION,
                    0,
                    legacy.DESCRIPTION);
            /*#endregion*/
        END LOOP;
    COMMIT;

    FOR legacy IN (SELECT * FROM LEGACY_SALE)
        LOOP
            v_booking_tax_amount := legacy.TOTAL_PRICE_INCLUDING_TAXES_EXCLUDING_FEES - legacy.BASE_PRICE_EXCLUDING_TAX;
            v_booking_total_amount := legacy.TOTAL_PRICE_INCLUDING_TAXES_EXCLUDING_FEES + legacy.AGENCY_FEE_AMOUNT;

            if legacy.BILL_DESCRIPTION = ' ' OR legacy.BILL_DESCRIPTION IS NULL THEN
                if legacy.BILLED_AMOUNT_INCLUDING_FEES = 0 AND legacy.AGENCY_FEE_AMOUNT = 0 THEN
                    v_current_bill_description := 'OTHER PAYMENT';
                ELSIF legacy.BILLED_AMOUNT_INCLUDING_FEES = legacy.AGENCY_FEE_AMOUNT THEN
                    v_current_bill_description := 'AGENCY PAYMENT';
                else
                    v_current_bill_description := 'OTHER PAYMENT';
                end if;
            else
                v_current_bill_description := legacy.BILL_DESCRIPTION;
            end if;

            BEGIN
                SELECT booking_id
                INTO v_current_booking_id
                FROM BOOKING b
                WHERE b.product_category_id = legacy.product_category
                    AND b.supplier_id = legacy.product_supplier_id
                    AND b.itinerary_id = legacy.itinerary_#
                ORDER BY booking_id
                FETCH FIRST 1 ROW ONLY;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    DBMS_OUTPUT.PUT_LINE('No matching booking found for legacy sale: ' || legacy.itinerary_#);
                    v_current_booking_id := 0;
                WHEN TOO_MANY_ROWS THEN
                    SELECT booking_id
                    INTO v_current_booking_id
                    FROM BOOKING b
                    WHERE b.product_category_id = legacy.product_category
                        AND b.supplier_id = legacy.product_supplier_id
                        AND b.itinerary_id = legacy.itinerary_#
                    ORDER BY booking_id
                    FETCH FIRST 1 ROW ONLY;
            END;


            INSERT INTO BILLING (BOOKING_ID,
                                 BILLING_DATE,
                                 BILL_DESCRIPTION,
                                 BASE_PRICE,
                                 AGENCY_FEE,
                                 TOTAL_AMOUNT,
                                 PAID_AMOUNT)
            VALUES (v_current_booking_id,
                    legacy.SALE_DATE,
                    v_current_bill_description,
                    legacy.BASE_PRICE_EXCLUDING_TAX,
                    legacy.AGENCY_FEE_AMOUNT,
                    v_booking_total_amount,
                    legacy.BILLED_AMOUNT_INCLUDING_FEES)
            RETURNING BILLING_ID into v_current_billing_id;

            insert into TAX (BILLING_ID,
                             TAX_TYPE_ID,
                             TAX_AMOUNT)
            values (v_current_billing_id,
                    0,
                    v_booking_tax_amount);
        END LOOP;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
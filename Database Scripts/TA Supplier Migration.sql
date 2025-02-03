BEGIN
    migrate_supplier_data;
END;
/

CREATE OR REPLACE PROCEDURE migrate_supplier_data AS
    v_current_email VARCHAR2(128);
    v_current_web VARCHAR2(128);
    v_current_country VARCHAR2(128);
    v_current_postal_code VARCHAR2(10);
    v_affiliation_id NUMBER;
    v_represent_id NUMBER;
    v_supplier_exists NUMBER;
    v_current_affiliation_id NUMBER;
    v_current_represent_id NUMBER;
BEGIN
    FOR legacy_supplier IN (SELECT * FROM LEGACY_SUPPLIER) LOOP
        BEGIN
            -- Reset variables for each iteration
            v_affiliation_id := NULL;
            v_represent_id := NULL;
            v_current_email := NULL;
            v_current_web := NULL;
            v_current_country := NULL;
            v_current_postal_code := NULL;

            -- Check if this supplier already exists
            BEGIN
                SELECT AFFILIATION_ID, REPRESENT_ID
                INTO v_current_affiliation_id, v_current_represent_id
                FROM SUPPLIER
                WHERE SUPPLIER_ID = legacy_supplier.PRODUCT_SUPPLIER_ID;

                v_supplier_exists := 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_supplier_exists := 0;
                    v_current_affiliation_id := NULL;
                    v_current_represent_id := NULL;
            END;

            -- Process affiliation if present in current record
            IF REGEXP_LIKE(legacy_supplier.AFFILIATION, '[a-zA-Z0-9]+') THEN
                BEGIN
                    SELECT affiliation_id
                    INTO v_affiliation_id
                    FROM AFFILIATION
                    WHERE name = legacy_supplier.AFFILIATION
                    FETCH FIRST 1 ROWS ONLY;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        INSERT INTO AFFILIATION (name)
                        VALUES (legacy_supplier.AFFILIATION)
                        RETURNING affiliation_id INTO v_affiliation_id;
                END;
            END IF;

            -- Process represent if present in current record
            IF REGEXP_LIKE(legacy_supplier.REPRESENTS, '[a-zA-Z0-9]+') THEN
                BEGIN
                    SELECT represent_id
                    INTO v_represent_id
                    FROM REPRESENT
                    WHERE name = legacy_supplier.REPRESENTS
                    FETCH FIRST 1 ROWS ONLY;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        INSERT INTO REPRESENT (name)
                        VALUES (legacy_supplier.REPRESENTS)
                        RETURNING represent_id INTO v_represent_id;
                END;
            END IF;

            -- Check to see if email is not an empty string and if it's not then switch the value of v_current_email from null to the current value we are evaluating 
            IF legacy_supplier.EMAIL != ' ' THEN
                v_current_email := legacy_supplier.EMAIL;
            END IF;

            -- Check to see if web is not an empty string and if it's not then switch the value of v_current_web from null to the current value we are evaluating
            IF legacy_supplier.WEB != ' ' THEN
                v_current_web := legacy_supplier.WEB;
            END IF;

            -- Check to see if country is not an empty string and if it's not then switch the value of v_current_country from null to the current value we are evaluating
            IF legacy_supplier.COUNTRY != ' ' THEN
                v_current_country := legacy_supplier.COUNTRY;
            END IF;

            -- Remove all whitespace from a given postal code or zip code
            SELECT REPLACE(legacy_supplier.ZIP_OR_POSTAL_CODE, ' ', '')
            INTO v_current_postal_code
            FROM dual;

            IF v_supplier_exists = 0 THEN
                -- Insert new unique supplier
                INSERT INTO SUPPLIER (
                    SUPPLIER_ID,
                    AFFILIATION_ID,
                    REPRESENT_ID,
                    CONTACT_NAME,
                    PHONE,
                    FAX,
                    EMAIL,
                    WEBSITE,
                    ADDRESS,
                    CITY,
                    PROVINCE,
                    COUNTRY,
                    POSTAL_CODE
                ) VALUES (
                    legacy_supplier.PRODUCT_SUPPLIER_ID,
                    v_affiliation_id,
                    v_represent_id,
                    legacy_supplier.CONTACT_NAME,
                    legacy_supplier.PHONE,
                    legacy_supplier.FAX,
                    v_current_email,
                    v_current_web,
                    legacy_supplier.ADDRESS_1,
                    legacy_supplier.CITY,
                    legacy_supplier.PROVINCE_OR_STATE,
                    v_current_country,
                    v_current_postal_code
                );
            ELSE
                -- Update existing supplier if we found new affiliation or represent values
                IF (v_affiliation_id IS NOT NULL AND v_current_affiliation_id IS NULL) OR 
                   (v_represent_id IS NOT NULL AND v_current_represent_id IS NULL) THEN

                    UPDATE SUPPLIER
                    SET AFFILIATION_ID = COALESCE(v_affiliation_id, AFFILIATION_ID),
                        REPRESENT_ID = COALESCE(v_represent_id, REPRESENT_ID)
                    WHERE SUPPLIER_ID = legacy_supplier.PRODUCT_SUPPLIER_ID;

                END IF;
            END IF;

            -- Insert the product
            INSERT INTO PRODUCT (
                PRODUCT_CATEGORY_ID,
                SUPPLIER_ID,
                COMPANY_NAME,
                PRODUCT_DESCRIPTION
            ) VALUES (
                legacy_supplier.PRODUCT_CATEGORY,
                legacy_supplier.PRODUCT_SUPPLIER_ID,
                legacy_supplier.COMPANY,
                legacy_supplier.PRODUCT_DESCRIPTION
            );

            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error processing supplier: ' || legacy_supplier.product_supplier_id);
                DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
                ROLLBACK;
        END;
    COMMIT;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
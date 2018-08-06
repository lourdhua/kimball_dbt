---------- USERS_SCREEN SCREEN
---- Screens are source-data-quality tests that we use to investigate and record data quality.
---- You pass screens to the screen_collection list (below) for them to be run and error events collected.

---- target_audit_properties contains meta about the current audit. it also accepts an exception_action key with
---- one of 4 values:
---- - Ignore : pass the record without action, but record the error
---- - Flag : pass the record but flag it as a quality issue
---- - Reject : discard the record, record the error
---- - Halt : stop ETL process and sound alarm
---- default is Flag.

---------- STATEMENTS [leave this section alone!]
---- Statements populate the python context with information about the subject audit.
    {%- call statement('target_audit', fetch_result=True) -%}
        SELECT
            audit_key,
            cdc_target,
            lowest_cdc,
            highest_cdc,
            data_type
        FROM
            {{this.database}}.{{this.schema}}.audit
        LEFT JOIN
            "RAW".information_schema.columns
        ON
            table_schema = 'ERP'
        AND
            column_name = cdc_target
        AND
            table_name = entity_key
        WHERE
            database_key = 'RAW'
        AND
            schema_key = 'ERP'
        AND
            entity_key = 'DW_USERS_VIEW'
        AND
            audit_status = 'In Process'
        ORDER BY audit_key DESC
        LIMIT 1

    {%- endcall -%}
{% set audit_response_data_object = load_result('target_audit')['data']%}
---------- END STATMENTS

---- if there is no new data, skip the entire screen model
{% if audit_response_data_object | length > 0 %}

    {%- set audit_response = audit_response_data_object[0] -%}
-- update the record identifier to match the table primary key

        {%- set target_audit_properties = {
                                'database' : 'RAW',
                                'schema' : 'ERP',
                                'entity' : 'DW_USERS_VIEW',
                                'audit_key' :  audit_response[0],
                                'cdc_target' : audit_response[1],
                                'lowest_cdc' : audit_response[2],
                                'highest_cdc' : audit_response[3],
                                'cdc_data_type' : audit_response[4],
                                'record_identifier' : 'id' } -%}


---------- SCREENS
---- All screens are flag unless noted

---------- AGE_RANGE
---- valid values are [4,3,2,7,5 and NULL]
{% set age_range_valid_values = {'column':'AGE_RANGE', 'type' : 'valid_values','valid_values' : [4,3,2,7,5], 'allow_null' : True, 'value_type' : 'number'} %}
---- all users created > 2015-02-01 are null. Older users are still updated daily due to facebook.
{% set age_range_created_before_2015 = {'column':'AGE_RANGE', 'type' : 'custom',
    'sql_where' : "age_range IS NOT NULL and created_at > '2015-02-01'", 'screen_name' : 'age_range_created_before_2015'} %}

---------- BIRTH_DATE
---- all birth dates must be before the current date
{% set birth_date_at_least_today = {'column': 'birth_date', 'type' : 'values_at_least', 'provided_value' : current_date} %}

---------- BRAINTREE_CUSTOMER_ID
---- TODO: ARE SCREENS NEEDED?

---------- COUNTRY_OF_RESIDENCE
---- valid values must have a length of 3 characters
{% set country_of_residence_length_must_be_three = {'column': 'country_of_residence', 'type' : 'exact_length', 'exact_length' : 3} %}
---- strings must be uppercase
{% set country_of_residence_must_be_uppercase = {'column':'country_of_residence', 'type' : 'custom', 'sql_where' : "UPPER(country_of_residence) <> country_of_residence AND country_of_residence IS NOT NULL", 'screen_name' : 'country_of_residence_must_be_uppercase' } %}

---------- CREATED_AT
---- date_range_within_history of RevZilla
{% set created_at_range_within_history = {'column':'created_at', 'type':'date_range_within_history'} %}

---------- DEALER_ID
---- TODO: ARE SCREENS NEEDED?

---------- DEPARTMENT_ID
---- valid values are [3,1,6,2,5,4,10,11,9,8,7, and NULL]
{% set department_id_valid_values = {'column':'department_id', 'type' : 'valid_values','valid_values' : [3,1,6,2,5,4,10,11,9,8,7], 'allow_null' : True, 'value_type' : 'number'} %}

--------- EMAIL_ADDRESS
---- must only be null if user is_anaonymous
{% set email_only_null_for_anon = {'column':'email_address','type' : 'custom', 'sql_where' : 'email_address IS NULL AND NOT is_anonymous','screen_name':'email_only_null_for_anon'} %}
---- must be in the format <string>@<string> or NULL
{% set email_minimal_format = {'column':'email_address', 'type' : 'custom', 'sql_where' : "email_address NOT ILIKE '%@%'", 'screen_name' : 'email_minimal_format' } %}
---- flag for the email 'robaan@web.com'. this single user has 134k accounts.
{% set email_is_robaan_at_web_dot_com = {'column': 'email_address', 'type' : 'blacklist', 'blacklist_values' : ['robaan@web.com','ROBAAN@WEB.COM'], 'value_type' : 'varchar', 'exception_action':'Reject'} %}

---------- ESP_ID
---- valid values must have a length of 3 characters
{% set esp_id_length_must_be_thirty_six = {'column': 'esp_id', 'type' : 'exact_length', 'exact_length' : 36} %}
---- esp_id must match esp_id = '________000000000000000000000_______' OR esp_id = '________-____-____-____-____________' OR esp_id IS NULL
{% set esp_id_must_fit_these_two_formats = {'column':'esp_id', 'type' : 'custom', 'sql_where' : "esp_id NOT LIKE '________000000000000000000000_______' AND esp_id NOT LIKE '________-____-____-____-____________' AND esp_id IS NOT NULL", 'screen_name' : 'esp_id_must_fit_these_two_formats' } %}

---------- FIRST_NAME
---- Must be only alphabetical characters and spaces
{% set first_name_valid = {'column':'first_name', 'type' : 'valid_name'} %}
---- Must not equal 'revzilla'
{% set first_name_not_revzilla = {'column': 'first_name', 'type' : 'blacklist', 'blacklist_values' : ['revzilla','revzilla.com','REVZILLA','REVZILLA.COM', 'RevZilla', 'RevZilla.com'], 'value_type' : 'varchar'} %}
---- Must not equal 'cycle gear'
{% set first_name_not_cycle_gear = {'column': 'first_name', 'type' : 'blacklist', 'blacklist_values' : ['cyclegear','cyclegear.com','cycle gear','CYCLEGEAR', 'CYCLEGEAR.COM', 'CYCLE GEAR'], 'value_type' : 'varchar'} %}
---- Must be > 1 character
{% set first_name_min_length = {'column' : 'first_name', 'type' : 'min_length', 'min_length' : 1} %}

---------- GENDER
---- Current gender values are either 'female' or 'male'
{% set gender_valid_values = {'column':'gender', 'type' : 'valid_values','valid_values' : ['female','male'], 'allow_null' : True, 'value_type' : 'STRING'} %}
---- TODO: why do anon accounts have genders assigned?

---------- ID
---- not_null
{% set id_not_null = {'column':'id', 'type':'not_null'} %}
---- unique
{% set id_is_unique = {'column':'id', 'type':'unique'} %}
---- values_at_least (1)
{% set id_at_least_one = {'column':'id', 'type':'values_at_least', 'provided_value':'1'} %}

---------- SEGMENT_MASK
---- must be a bitwise AND with at least one id from segments
{% set segment_mask_bitmask = {'column' : 'segment_mask', 'type' : 'custom', 'sql_where' : 'id in (SELECT id FROM (SELECT raw.erp.dw_users_view.id, MAX(BITAND(segment_mask,raw.erp.segments.id)) AS in_mask FROM raw.erp.dw_users_view JOIN raw.erp.segments ON 1=1 WHERE segment_mask IS NOT NULL AND segment_mask <> 0 GROUP BY 1 HAVING in_mask = FALSE))', 'screen_name' : 'segment_mask_bitmask'} %}
---- not used on records created > 2014-01-01
{% set segment_mask_null_after_2014 = {'column' : 'segment_mask', 'date_column': 'created_at', 'type' : 'static_value_after', 'before' : '2014-01-01'} %}

---------- LAST_LOGIN_AT
---- should be > created_at - however there is an application bug where this is not rarely not the case
{% set last_login_at_after_created_at = {'type': 'column_order', 'greater_column' : 'last_login_at', 'lesser_column' : 'created_at', 'data_type' : 'TIMESTAMP_LTZ' } %}


---------- IS_DELETED
----
---------- PASSWORD_RESET_REQUESTED_AT
----
---------- IS_ACTIVE
----
---------- ROLE_ID
----
---------- ID_HASH_KEY
----
---------- LAST_NAME
----
---------- XMIN
----
---------- IS_FRAUD
----
---------- TRANSPARENT_SIGNUP
----
---------- PROFILE_IMAGE
----
---------- UPDATED_AT
----
---------- IS_FRAUD_VERIFIED
----
---------- IS_ANONYMOUS
----
---------- PERMISSION_SECTION_GROUP_ID
----
---------- SEND_REVIEW_FOLLOWUP
----
---------- SITE_ID
----
---------- XMIN__TEXT__BIGINT


    {% set screen_collection =  [
                                    age_range_created_before_2015,
                                    age_range_valid_values,
                                    birth_date_at_least_today,
                                    country_of_residence_length_must_be_three,
                                    country_of_residence_must_be_uppercase,
                                    created_at_range_within_history,
                                    department_id_valid_values,
                                    email_only_null_for_anon,
                                    email_is_robaan_at_web_dot_com,
                                    email_minimal_format,
                                    esp_id_length_must_be_thirty_six,
                                    esp_id_must_fit_these_two_formats,
                                    first_name_valid,
                                    first_name_not_cycle_gear,
                                    first_name_not_revzilla,
                                    first_name_min_length,
                                    gender_valid_values,
                                    id_not_null,
                                    id_is_unique,
                                    id_at_least_one,
                                    last_login_at_after_created_at,
                                    segment_mask_bitmask,
                                    segment_mask_null_after_2014
                                ]%}

    WITH

        {{screen_declaration(screen_collection, target_audit_properties)}}


---------- UNION
    SELECT
        *
    FROM
        (
            {{screen_union_statement(screen_collection, target_audit_properties)}}

        )

{% else %}

---- when no new data is present, return an empty table
    SELECT
        *
    FROM
        {{this.database}}.{{this.schema}}.error_event_fact
    WHERE 1=0
{% endif %}



---------- MODEL CONFIGURATION
{{config({

    "materialized":"ephemeral",
    "sql_where":"TRUE",
    "schema":"QUALITY"

})}}

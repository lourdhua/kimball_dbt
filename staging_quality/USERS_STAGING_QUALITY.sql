---------- <model_name> TABLE
----
---- Staging Quality tables are cleaned and transform-ready source tables.     
---- The data in Staging Quality tables are completely untransformed source data, with one exception: they 
---- have additional attributes AUDIT_KEY, ROW_QUALITY_SCORE and AUDIT_QUALITY_SCORE. 
----
---- AUDIT_KEY is the FKey to the audit that added (or last updated) the subject row.
----
---- ROW_QUALITY_SCORE represents the quality performance of the subject row. Options are:
----    - Passed: row is considered quality data
----    - Flagged: row has failed one or more quality screens, and should be considered suspect
----
---- AUDIT_QUALITY_SCORE represents the quality perfomance of the row in the context of the audit. Options are:
----    - passed: row is considered quality data in the context of the audit
----    - flagged: row is suspect in the context of the audit
----


---------- STATEMENTS [leave this section alone!]
---- Statements populate the python context with information about the subject audit.
    {%- call statement('target_audit', fetch_result=True) -%}
        SELECT
            audit_key,
            cdc_target,
            lowest_cdc,
            highest_cdc,
            target.data_type AS cdc_data_type,
            record_identifier.data_type AS record_identifier_data_type
        FROM
            {{this.database}}.{{this.schema | replace('STAGING_QUALITY','QUALITY')}}.audit

        LEFT JOIN
            "<database>".information_schema.columns target
        ON
            table_schema = '<schema>'
        AND
            column_name = cdc_target
        AND
            table_name = entity_key
    
        LEFT JOIN
            "database".information_schema.columns record_identifier
        ON
            table_schema = '<schema>'
        AND
            column_name = '<record_identifier>'
        AND
            table_name = entity_key

        WHERE
            database_key = '<database>'
        AND
            schema_key = '<schema>'
        AND
            entity_key = '<entity>'
        ORDER BY audit_key DESC 
        LIMIT 1

    {%- endcall -%}

{% set audit_response = load_result('target_audit')['data']%}
---------- END STATMENTS

---- if there is no new data, skip the entire staging quality incremental build

    {% if audit_response[0] | length > 0 %}
    {% set audit_data = {
                            'audit_key' :  audit_response[0][0],
                            'cdc_target' : audit_response[0][1],
                            'lowest_cdc' : audit_response[0][2],
                            'highest_cdc' : audit_response[0][3],
                            'cdc_data_type' : audit_response[0][4], 
                            'record_identifier_data_type' : audit_response[0][5]} -%}

    WITH
    audit_source_records AS (

        SELECT 
            *,
            {{audit_data['audit_key']}} AS audit_key
        FROM
           <database>.<schema>.<entity> 
        WHERE
            {{audit_data['cdc_target']}}
        BETWEEN
        
        {% if audit_data['record_identifier'] in ('TEXT','TIMESTAMP_NTZ') %}
            '{{audit_data["lowest_cdc"]}}' AND '{{audit_data["highest_cdc"]}}'
        {% else %}
            {{audit_data['lowest_cdc']}} AND {{audit_data['highest_cdc']}}
        {% endif %}
    ),

    error_events AS (
        SELECT
            error_event_action,

            -- for audit-level error events this will be NULL so we will remove them later
            -- and use the presence of NULL values to flag an audit-level event
            TRY_CAST(record_identifier AS {{audit_data['record_identifier_data_type']}}) AS <record_identifier>           
        FROM
            {{this.database}}.{{this.schema | replace('STAGING_QUALITY','QUALITY')}}.error_event_fact
        WHERE
            audit_key = {{audit_data['audit_key']}}
    )




---- remove rejected rows, flag flagged rows, and add audit-level flag 
    SELECT 
        audit_source_records.*, 

        CASE
            WHEN error_event_action IS NULL THEN 'Passed'
            ELSE error_event_action
        END AS row_quality_score,
        
        (SELECT
            CASE
                WHEN COUNT(*) > 0 THEN 'Flagged' 
                ELSE 'Passed'
            END 
        FROM
            error_events
        WHERE 
            record_identifier IS NULL) AS audit_quality_score    
    FROM
        audit_source_records
    LEFT JOIN
        error_events 
    ON 
        error_events.<record_identifier> = audit_source_records.record_identifier

    WHERE
        error_event_action <> 'Reject'

{% else %}

---- when no new data is present, return an empty table
    SELECT
        *
    FROM
        {{this}}       
    WHERE 1=0

{% endif %} 

---------- CONFIGURATION [leave this section alone!]
{{config({

    "materialized":"incremental",
    "sql_where":"TRUE",
    "schema":"STAGING_QUALITY"

})}}
    
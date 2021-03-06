{% macro add_constraints(constraints, schema, entity, attribute, fkey_entity = None, fkey_attribute = None, materialization = 'table') %}
{#---- INTENT: creates DDL constraint strings for use in post-hooks
---- ARGS:
----    - constraints (list) a list of constraints to apply. Options are Pkey, FKey, Unique
----    - attribute (string) the name of the column to apply the constraint against.
----    - entity (string) the fully qualified entity path
----    - fkey_entity (string) the entity name to fkey against
----    - fkey_attribute (string) the attribute to fkey against
----    - materialization (string) the type of dbt construct, default table
---- RETURNS: string the compiled DDL statement

#}
    -- Only run if this is the initial creation of the entity. 
    -- There is no catchable crud operation for constraints :( 
    {% if not adapter.already_exists(this.schema, this.name) %}
        {% for con in constraints %}
            ALTER TABLE {{schema}}.{{entity}}
            {% if con == 'Null' %}
                ALTER COLUMN {{attribute}} NOT NULL
            {% elif con == 'Fkey' %}
                {% if adapter.already_exists(schema, fkey_entity) %}
                    ADD CONSTRAINT {{con}}_{{attribute}}
                    FOREIGN KEY ({{attribute}}) REFERENCES {{fkey_entity}} ({{fkey_attribute}})
                {% else %}
                    UNSET DATA_RETENTION_TIME_IN_DAYS
                {% endif %}
            {% elif con == 'Pkey' %}
                ADD CONSTRAINT {{con}}_{{attribute}}
                PRIMARY KEY ({{attribute}})
            {% elif con == 'Unique' %}
                ADD CONSTRAINT {{con}}_{{attribute}}
                UNIQUE ({{attribute}})
            {% endif %};
        {% endfor %}        
    {% else %}
    -- post-hooks can't return an empty statement
        SELECT NULL WHERE 1=0;
    {% endif %}
{% endmacro %}

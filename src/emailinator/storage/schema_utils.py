from sqlalchemy import Integer, String, Text, Date


def sqlalchemy_to_jsonschema(model):
    """Convert a SQLAlchemy model into a JSON Schema for OpenAI Responses API."""
    type_map = {
        Integer: {"type": "integer"},
        String: {"type": "string"},
        Text: {"type": "string"},
        Date: {"type": "string", "format": "date"},
    }

    properties = {}
    required_fields = []

    for column in model.__table__.columns:
        col_type = type(column.type)
        json_type = type_map.get(col_type, {"type": "string"})
        properties[column.name] = json_type

        if not column.nullable and not column.primary_key:
            required_fields.append(column.name)

    schema = {
        "type": "object",
        "properties": {
            "tasks": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": properties,
                    "required": required_fields,
                },
            }
        },
        "required": ["tasks"],
    }

    return {
        "type": "json_schema",
        "json_schema": {"name": f"{model.__tablename__}_list", "schema": schema},
    }

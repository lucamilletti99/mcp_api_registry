/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
/**
 * Model for a registered API using UC HTTP Connections.
 */
export type RegisteredAPI = {
    api_id: string;
    api_name: string;
    description?: (string | null);
    connection_name: string;
    api_path: string;
    documentation_url?: (string | null);
    http_method?: string;
    status?: string;
    user_who_requested?: (string | null);
    created_at?: (string | null);
    modified_date?: (string | null);
    validation_message?: (string | null);
};


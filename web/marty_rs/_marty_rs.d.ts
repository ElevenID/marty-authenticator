/* tslint:disable */
/* eslint-disable */

/**
 * Create an OID4VP authorization response
 *
 * # Arguments
 * * `vp_token` - The VP JWT
 * * `presentation_submission_json` - Presentation submission descriptor
 * * `state` - State from the authorization request
 *
 * # Returns
 * JSON authorization response
 */
export function create_authorization_response(vp_token: string, presentation_submission_json: string, state?: string | null): string;

/**
 * Create an OID4VCI credential offer
 *
 * # Arguments
 * * `issuer_url` - Base URL of the credential issuer
 * * `credential_types` - JSON array of credential type IDs
 * * `pre_authorized_code` - Optional pre-authorized code for immediate issuance
 * * `user_pin_required` - Whether a PIN is required
 *
 * # Returns
 * JSON credential offer object
 */
export function create_credential_offer(issuer_url: string, credential_types_json: string, pre_authorized_code: string | null | undefined, user_pin_required: boolean): string;

/**
 * Normalize a DTC payload (JSON in/out).
 *
 * # Arguments
 * * `request_json` - JSON payload describing the DTC record
 *
 * # Returns
 * JSON: normalized DTC record
 */
export function dtc_create(request_json: string): string;

/**
 * Verify a DTC payload (JSON in/out).
 *
 * # Arguments
 * * `request_json` - JSON payload with DTC record + signer_public_key_pem
 *
 * # Returns
 * JSON: verification result
 */
export function dtc_verify(request_json: string): string;

/**
 * Extract credential from a VP JWT
 *
 * # Arguments
 * * `vp_jwt` - The VP JWT string
 *
 * # Returns
 * JSON array of credential objects
 */
export function extract_credentials_from_vp(vp_jwt: string): string;

/**
 * Generate a credential offer URI for QR code display
 *
 * # Arguments
 * * `issuer_url` - Base URL of the credential issuer
 * * `offer_id` - Unique identifier for this offer
 * * `format` - URI format: "oid4vci" (default) or "microsoft"
 *
 * # Returns
 * URI string for QR code encoding
 */
export function generate_offer_uri(issuer_url: string, offer_id: string, format: string): string;

/**
 * Get the version of marty-rs WASM module
 */
export function get_version(): string;

/**
 * Check if WASM module is initialized correctly
 */
export function health_check(): string;

export function init_panic_hook(): void;

/**
 * Verify an Open Badges v2 assertion.
 *
 * # Arguments
 * * `request_json` - JSON payload with assertion + document_store
 *
 * # Returns
 * JSON: { "valid": true|false, "version": "2.0", "errors": [...], "warnings": [...] }
 */
export function open_badge_ob2_verify(request_json: string): string;

/**
 * Verify an Open Badges v3 credential with Data Integrity proof.
 *
 * # Arguments
 * * `request_json` - JSON payload with credential + document_store
 *
 * # Returns
 * JSON: { "valid": true|false, "version": "3.0", "errors": [...], "warnings": [...] }
 */
export function open_badge_ob3_verify(request_json: string): Promise<string>;

/**
 * Verify a JWT structure and claims (does NOT verify cryptographic signature)
 *
 * # Arguments
 * * `jwt` - The JWT string to verify
 * * `expected_issuer` - Optional expected issuer
 * * `expected_audience` - Optional expected audience
 *
 * # Returns
 * JSON: { "valid": bool, "payload": {...}, "error": "..." }
 */
export function verify_jwt_claims(jwt: string, expected_issuer?: string | null, expected_audience?: string | null): string;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly create_authorization_response: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => void;
    readonly create_credential_offer: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number) => void;
    readonly dtc_create: (a: number, b: number, c: number) => void;
    readonly dtc_verify: (a: number, b: number, c: number) => void;
    readonly extract_credentials_from_vp: (a: number, b: number, c: number) => void;
    readonly generate_offer_uri: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => void;
    readonly get_version: (a: number) => void;
    readonly health_check: (a: number) => void;
    readonly open_badge_ob2_verify: (a: number, b: number, c: number) => void;
    readonly open_badge_ob3_verify: (a: number, b: number) => number;
    readonly verify_jwt_claims: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => void;
    readonly init_panic_hook: () => void;
    readonly __wasm_bindgen_func_elem_4455: (a: number, b: number, c: number, d: number) => void;
    readonly __wasm_bindgen_func_elem_4469: (a: number, b: number, c: number, d: number) => void;
    readonly __wbindgen_export: (a: number) => void;
    readonly __wbindgen_export2: (a: number, b: number, c: number) => void;
    readonly __wbindgen_export3: (a: number, b: number) => number;
    readonly __wbindgen_export4: (a: number, b: number, c: number, d: number) => number;
    readonly __wbindgen_export5: (a: number, b: number) => void;
    readonly __wbindgen_add_to_stack_pointer: (a: number) => number;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;

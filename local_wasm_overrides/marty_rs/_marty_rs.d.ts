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
 * Create a verifiable presentation from credentials
 *
 * # Arguments
 * * `holder_did` - DID of the holder
 * * `holder_jwk_json` - JWK of the holder as JSON string
 * * `credential_jwts_json` - JSON array of credential JWTs
 * * `audience` - DID or URL of the verifier
 * * `nonce` - Optional nonce from the presentation request
 *
 * # Returns
 * VP JWT string
 */
export function create_presentation(holder_did: string, holder_jwk_json: string, credential_jwts_json: string, audience: string, nonce?: string | null): string;

/**
 * Create a verifiable credential and sign it as a JWT
 *
 * # Arguments
 * * `issuer_did` - DID of the issuer
 * * `issuer_jwk_json` - JWK of the issuer as JSON string
 * * `subject_id` - Optional DID of the subject
 * * `credential_type` - Type of credential (e.g., "TravelDocument")
 * * `claims_json` - Claims as JSON object string
 * * `expiration_seconds` - Optional expiration in seconds from now
 *
 * # Returns
 * JSON: { "jwt": "...", "credentialId": "urn:uuid:..." }
 */
export function create_verifiable_credential(issuer_did: string, issuer_jwk_json: string, subject_id: string | null | undefined, credential_type: string, claims_json: string, expiration_seconds?: bigint | null): string;

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
 * Generate an Ed25519 key pair
 * Returns JSON: { "did": "did:key:...", "jwk": {...}, "keyId": "..." }
 */
export function generate_ed25519_key(): string;

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
 * Generate a P-256 key pair for OID4VCI
 * Returns JSON: { "did": "did:jwk:...", "jwk": {...}, "keyId": "..." }
 */
export function generate_p256_key(): string;

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
  readonly create_authorization_response: (a: number, b: number, c: number, d: number, e: number, f: number) => [number, number, number, number];
  readonly create_credential_offer: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => [number, number, number, number];
  readonly create_presentation: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number) => [number, number, number, number];
  readonly create_verifiable_credential: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: bigint) => [number, number, number, number];
  readonly extract_credentials_from_vp: (a: number, b: number) => [number, number, number, number];
  readonly generate_ed25519_key: () => [number, number, number, number];
  readonly generate_offer_uri: (a: number, b: number, c: number, d: number, e: number, f: number) => [number, number];
  readonly generate_p256_key: () => [number, number, number, number];
  readonly get_version: () => [number, number];
  readonly health_check: () => [number, number];
  readonly verify_jwt_claims: (a: number, b: number, c: number, d: number, e: number, f: number) => [number, number, number, number];
  readonly init_panic_hook: () => void;
  readonly __wbindgen_exn_store: (a: number) => void;
  readonly __externref_table_alloc: () => number;
  readonly __wbindgen_externrefs: WebAssembly.Table;
  readonly __wbindgen_free: (a: number, b: number, c: number) => void;
  readonly __wbindgen_malloc: (a: number, b: number) => number;
  readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
  readonly __externref_table_dealloc: (a: number) => void;
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

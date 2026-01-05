/* tslint:disable */
/* eslint-disable */
export const memory: WebAssembly.Memory;
export const create_authorization_response: (a: number, b: number, c: number, d: number, e: number, f: number) => [number, number, number, number];
export const create_credential_offer: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => [number, number, number, number];
export const create_presentation: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number) => [number, number, number, number];
export const create_verifiable_credential: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: bigint) => [number, number, number, number];
export const extract_credentials_from_vp: (a: number, b: number) => [number, number, number, number];
export const generate_ed25519_key: () => [number, number, number, number];
export const generate_offer_uri: (a: number, b: number, c: number, d: number, e: number, f: number) => [number, number];
export const generate_p256_key: () => [number, number, number, number];
export const get_version: () => [number, number];
export const health_check: () => [number, number];
export const verify_jwt_claims: (a: number, b: number, c: number, d: number, e: number, f: number) => [number, number, number, number];
export const init_panic_hook: () => void;
export const __wbindgen_exn_store: (a: number) => void;
export const __externref_table_alloc: () => number;
export const __wbindgen_externrefs: WebAssembly.Table;
export const __wbindgen_free: (a: number, b: number, c: number) => void;
export const __wbindgen_malloc: (a: number, b: number) => number;
export const __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
export const __externref_table_dealloc: (a: number) => void;
export const __wbindgen_start: () => void;
